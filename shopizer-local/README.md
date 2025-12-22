# Provisions kind cluster

## Requirements

- Docker Desktop
- Terraform
- Kubectl
- java 21


Make sure you are using java 21
`
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
echo $JAVA_HOME
java --version
`

# Script execution

```d
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars
```

## Post installation

Check that the ingress is ok

`
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
`
Wait and retry when getting this response 
Unable to connect to the server: net/http: TLS handshake timeout

This is the answer we want
condition met

## Careate the ingress yaml

`
kubectl create -f k8s/ingress/ingress.yaml
`

## Adjust App secret


## Change the secret to keycloak
`
kubectl apply -f k8s/app-secret.yaml
`

## Recommanded API keys

apply app-secret with open api key
add your open api key to keys/__OPENAPI_KEY__

`
echo "open api key" > keys/__OPENAPI_KEY__
sed "s|__API_KEY__|$(base64 -w0 ./k8s/__OPENAPI_KEY__)|g" k8s/app-secret.yaml | kubectl apply -f -
`

## Remote Debug

Debug -> port forward

`
## Port forward the required service, assumes one remote debut at a time
kubectl port-forward deployment/merchant 5005:5005
kubectl port-forward deployment/shop 5008:5008
kubectl port-forward deployment/users 5007:5007

`


  `

- install nginx ** ingress **

`
kubectl create -f k8s/ingress/ingress.yaml
`

- configure keycloak

`
cd keycloak

`

- generate new client id in ** keycloak **
- if open apu is involved get ur token

- Need to use metrics server ?
install self signed certs
`
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
`

Cleanup

Delete all images by tag 

docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep ":latest" | awk '{print $2}' | xargs -r docker rmi
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "^paketobuildpacks" | awk '{print $2}' | xargs -r docker rmi

docker stop  kind-registry
docker stop terraform-kind-control-plane

docker rmi -f $(docker images kindest/node -q) || true
docker rmi -f $(docker images registry -q) || true

catch all

docker ps -aq | xargs -r docker rm -f

Performs:

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

Connect to the database from pgadmin
Host: postgres
port: 5432
user:user
password:pass

kubectl exec -it pgadmin-d6959f9b8-9gnh7 -- psql -U postgres -d shop -c '\dx'


## Keycloak

See in ../keycloak


## Services

### OpenAPI

- http://localhost/references/swagger-ui/index.html
- http://localhost/merchant/swagger-ui/index.html


http://localhost/keycloak/realms/master/protocol/openid-connect/auth?response_type=token&client_id=shopizer&redirect_uri=http%3A%2F%2Flocalhost%2Fmerchant%2Fswagger-ui%2Foauth2-redirect.html&scope=admin&state=VHVlIEp1biAyNCAyMDI1IDE1OjA3OjIxIEdNVC0wNDAwIChFYXN0ZXJuIERheWxpZ2h0IFRpbWUp

http://localhost/keycloak/realms/master/protocol/openid-connect/auth

http://localhost/keycloak/realms/master/protocol/openid-connect/token

psql -U user --d db -c '\dx'