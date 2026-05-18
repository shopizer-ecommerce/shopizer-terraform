terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "null_resource" "ensure_postgres_data_dir" {
  # Make sure the hostPath for Postgres persistence exists before Kind starts
  provisioner "local-exec" {
    command = "mkdir -p \"${var.postgres_data_host_path}\""
  }

  triggers = {
    path = var.postgres_data_host_path
  }
}

resource "local_file" "kind_config" {
  content  = templatefile("${path.module}/kind-config.tftpl", { host_path = var.postgres_data_host_path })
  filename = "${path.module}/kind-config.generated.yaml"

  depends_on = [null_resource.ensure_postgres_data_dir]
}

resource "null_resource" "build_and_push_images" {
  depends_on = [docker_container.local_registry]
  provisioner "local-exec" {
    command = "chmod +x ./build.sh && ./build.sh ${var.app_path} ${join(" ", var.microservices)}"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "docker_image" "registry" {
  name = "registry:2"
}

resource "docker_container" "local_registry" {
  name  = "kind-registry"
  image = docker_image.registry.name

  ports {
    internal = 5000
    external = 5001
  }

  restart = "always"
}

resource "null_resource" "install_tools" {
  depends_on = [null_resource.build_and_push_images]
  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v kind >/dev/null 2>&1; then
        echo "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-$(uname)-amd64
        chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
      fi

      if ! command -v kubectl >/dev/null 2>&1; then
        echo "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
      fi
    EOT
  }
}

resource "null_resource" "create_kind_cluster" {
  depends_on = [null_resource.install_tools, null_resource.ensure_postgres_data_dir, local_file.kind_config]

  provisioner "local-exec" {
    command = <<-EOT
      if ! kind get clusters | grep -q terraform-kind; then
        kind create cluster --name terraform-kind --config ${local_file.kind_config.filename}
      else
        echo "Kind cluster 'terraform-kind' already exists."
      fi
      # Ensure the registry is connected to the 'kind' network
      docker network inspect kind >/dev/null 2>&1 || docker network create kind
      docker network connect kind kind-registry 2>/dev/null || true
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "load_images_into_kind" {
  depends_on = [null_resource.create_kind_cluster, null_resource.build_and_push_images]

  provisioner "local-exec" {
    command = <<-EOT
      for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep '^localhost:5001'); do
        echo "Loading $image into kind..."
        kind load docker-image "$image" --name terraform-kind
      done
    EOT
  }
}

resource "null_resource" "deploy_manifests" {
  depends_on = [null_resource.load_images_into_kind]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/apps/shared"
  }

  triggers = {
    app_secret_sha  = filesha256("${path.module}/k8s/apps/shared/app-secret.yaml")
    otel_config_sha = filesha256("${path.module}/k8s/apps/shared/otel-config-map.yaml")
  }
}

resource "null_resource" "verify_shared_app_manifests" {
  depends_on = [null_resource.deploy_manifests]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl get secret app-secret -n default
      kubectl get configmap otel-common-env -n default
    EOT
  }
}

resource "null_resource" "deploy_postgres" {
  depends_on = [null_resource.load_images_into_kind, null_resource.verify_shared_app_manifests]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/platform/manifests/postgres"
  }
}

resource "null_resource" "deploy_pgadmin" {
  depends_on = [null_resource.deploy_postgres]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/platform/manifests/pgadmin"
  }
}

resource "null_resource" "deploy_keycloak" {
  depends_on = [null_resource.deploy_postgres]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/platform/manifests/keycloak"
  }
}

resource "null_resource" "redis" {
  depends_on = [null_resource.deploy_postgres]
  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/platform/manifests/redis"
  }
}

resource "null_resource" "deploy_ingress_nginx" {
  # Trigger only after cluster is created
  depends_on = [null_resource.deploy_postgres]

  provisioner "local-exec" {
    command = "kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "verify_ingress_admission" {
  depends_on = [null_resource.deploy_ingress_nginx]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl rollout status deployment/ingress-nginx-controller \
        -n ingress-nginx \
        --timeout 180s

      kubectl wait job/ingress-nginx-admission-create \
        -n ingress-nginx \
        --for=condition=complete \
        --timeout 180s

      kubectl wait job/ingress-nginx-admission-patch \
        -n ingress-nginx \
        --for=condition=complete \
        --timeout 180s

      kubectl get secret ingress-nginx-admission -n ingress-nginx
      kubectl get validatingwebhookconfiguration ingress-nginx-admission

      for i in $(seq 1 30); do
        endpoints=$(kubectl get endpoints ingress-nginx-controller-admission \
          -n ingress-nginx \
          -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)

        if [ -n "$endpoints" ]; then
          echo "ingress-nginx admission endpoints: $endpoints"
          exit 0
        fi

        echo "waiting for ingress-nginx admission endpoints... ($i/30)"
        sleep 5
      done

      echo "ingress-nginx admission endpoints not ready"
      exit 1
    EOT
  }
}

resource "null_resource" "install_argocd" {
  count = var.enable_argocd ? 1 : 0

  depends_on = [null_resource.create_kind_cluster, null_resource.verify_ingress_admission]

  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v helm >/dev/null 2>&1; then
        echo "helm is required to install Argo CD"
        exit 1
      fi

      helm upgrade --install ${var.argocd_release_name} ./k8s/platform/charts/argo-cd \
        --namespace ${var.argocd_namespace} \
        --create-namespace \
        --values ./k8s/platform/values/local/argocd-values.yaml \
        --wait \
        --timeout 10m

      kubectl rollout status deployment/argocd-server \
        --namespace ${var.argocd_namespace} \
        --timeout 5m
    EOT
  }

  triggers = {
    release_name = var.argocd_release_name
    namespace    = var.argocd_namespace
    values_sha   = filesha256("${path.module}/k8s/platform/values/local/argocd-values.yaml")
    chart_sha    = filesha256("${path.module}/k8s/platform/charts/argo-cd/Chart.yaml")
  }
}

resource "null_resource" "apply_argocd_applications" {
  count = var.enable_argocd ? 1 : 0

  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = "kubectl apply -R -f ./k8s/argocd"
  }

  triggers = {
    argocd_manifests_sha = sha256(join("", [
      for file in fileset(path.module, "k8s/argocd/**/*.yaml") :
      filesha256("${path.module}/${file}")
    ]))
  }
}

resource "null_resource" "delete_kind_cluster" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "🔧 Starting destroy"
      kind get clusters | grep -q '^terraform-kind$' && kind delete cluster --name terraform-kind
      echo "Cleaning up registry and Docker network..."
      docker ps -a --format '{{.Names}}' | grep -q '^kind-registry$' && docker rm -f kind-registry || true
      docker network inspect kind >/dev/null 2>&1 && docker network rm kind || true
      echo "Removing images..."
      docker images --format "{{.Repository}}:{{.Tag}}" | grep '^localhost:5001/shopizer-' | xargs -r docker rmi
    EOT
  }
}
