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
  depends_on = [null_resource.install_tools]

  provisioner "local-exec" {
    command = <<-EOT
      if ! kind get clusters | grep -q terraform-kind; then
        kind create cluster --name terraform-kind --config kind-config.yaml
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
    command = "kubectl apply -f ./k8s"
  }
}

resource "null_resource" "deploy_postgres" {
  depends_on = [null_resource.load_images_into_kind]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/postgres"
  }
}

resource "null_resource" "deploy_pgadmin" {
  depends_on = [null_resource.deploy_postgres]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/pgadmin"
  }
}

resource "null_resource" "deploy_keycloak" {
  depends_on = [null_resource.deploy_postgres]

  provisioner "local-exec" {
    command = "kubectl apply -f ./k8s/keycloak"
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
      kind delete cluster --name terraform-kind
      echo "Cleaning up registry and Docker network..."
      docker rm -f kind-registry || true
      docker network rm kind || true
      echo "Removing images..."
      docker images --format "{{.Repository}}:{{.Tag}}" | grep '^localhost:5001/shopizer-' | xargs -r docker rmi
    EOT
  }
}







