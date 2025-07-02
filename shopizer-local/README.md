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

http://localhost/keycloak
Login with user and password from keycloak-secret.yaml
click on clients
create new client 
ClientID: shopizer
Client authentication: on
Authorization: on
Standard flow, Direct Access grant, Implicit flow, OAuth 2.0
Login theme shopizer
Cretae client scope admin
add client scope to ClientID shopizer
master realm add profile attribute org



## Services

### OpenAPI

- http://localhost/references/swagger-ui/index.html
- http://localhost/merchant/swagger-ui/index.html


http://localhost/keycloak/realms/master/protocol/openid-connect/auth?response_type=token&client_id=shopizer&redirect_uri=http%3A%2F%2Flocalhost%2Fmerchant%2Fswagger-ui%2Foauth2-redirect.html&scope=admin&state=VHVlIEp1biAyNCAyMDI1IDE1OjA3OjIxIEdNVC0wNDAwIChFYXN0ZXJuIERheWxpZ2h0IFRpbWUp

http://localhost/keycloak/realms/master/protocol/openid-connect/auth

http://localhost/keycloak/realms/master/protocol/openid-connect/token