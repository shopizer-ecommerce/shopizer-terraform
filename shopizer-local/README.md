# Provisions kind cluster

## Requirements

- Docker Desktop
- Terraform
- Kubectl

# Script execution

```
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars
```

Delete all images by tag 
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep ":4.0.1.2" | awk '{print $2}' | xargs -r docker rmi


Delete images with repo starting with
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "^paketobuildpacks" | awk '{print $2}' | xargs -r docker rmi

complete terraform destroy flow that removes 
registry
containers
docker images
kind cluster

# Post installation

## Postgres

Open localhost/pgadmin

User: admin@shopizer.com
password: Sunshine001!

Connect to the database
Host: postgres
port: 5432
user:user
password:pass

## Keycloak


