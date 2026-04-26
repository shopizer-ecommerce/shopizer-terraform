# Provisions kind cluster

## Requirements

- Docker Desktop (recent version)
- Terraform
- Kubectl
- java 21


Make sure you are using java 21, required for building images
`
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
echo $JAVA_HOME
java --version
`

You need a host resolution for keycloak frontend ingress to be working correctly and to anser on http://keycloak


cat /etc/hosts

`
127.0.0.1 keycloak
`



# use the python runbook to deploy the cluster and hot deploy a service
### see --> INSTRUCTIONS.MD <--

# This is to run the installation manually (Use the runbook preferably)
# Script execution

```
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars
```

## Operations

Collect pod errors from logs in selected namespaces and generate a markdown report:

```
cd shopizer-local
./operations/pod-error-report.sh -n default,ingress-nginx -s 2h -t 1000
```

Reports are written to `shopizer-local/operations/reports/` by default.

Hot redeploy a single microservice (build image, push to local registry, update deployment image, wait rollout):

```
cd shopizer-local
./operations/hot-redeploy-service.sh \
  -a /Users/carlsamson/Documents/dev/workspace/shopizer \
  -s merchants \
  -n default
```

## Post installation (when executed manually)

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

## restart pods that are dependant to secrets

` 
kubectl rollout restart deployment/users
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
kubectl port-forward deployment/references 5004:5004
kubectl port-forward deployment/merchants 5005:5005
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
cd ../keycloak

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

docker builder prune -af
docker image prune -af

terraform init

Ultimately if a port is stocked
lsof -iTCP:5001 -sTCP:LISTEN
kill -9 the process id

Performs:

complete terraform destroy flow that removes 
registry
containers
docker images
kind cluster
initialize terraform

Raw srap it

kind delete cluster
terraform init

# Post installation

## Postgres
Open pgadmin

`
localhost/
`

User: admin@shopizer.com
password: Sunshine001!

### Register databases in

Connect to the database from pgadmin
Host: postgres
port: 5432
user:user
password:pass

kubectl exec -it pgadmin-d6959f9b8-9gnh7 -- psql -U postgres -d shop -c '\dx'

