1️⃣ Add repos
helm repo add prometheus-community <https://prometheus-community.github.io/helm-charts>
helm repo add grafana <https://grafana.github.io/helm-charts>
helm repo update
2️⃣ Install Prometheus + Grafana
helm install monitoring prometheus-community/kube-prometheus-stack \
 --namespace monitoring \
 --create-namespace

👉 This gives you:

Prometheus
Grafana
Alertmanager
Node metrics
Kubernetes metrics
3️⃣ Install Loki (logs)
helm install loki grafana/loki-stack \
 --namespace monitoring
🔍 4️⃣ Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

Open:

<http://localhost:3000>
🔐 Get admin password
kubectl get secret -n monitoring monitoring-grafana \
 -o jsonpath="{.data.admin-password}" | base64 --decode
📊 What you get instantly
Kubernetes cluster dashboards
CPU / memory usage
Pod metrics
Node health
🔥 5️⃣ Connect Loki to Grafana

Usually auto-configured, but if not:

Go to Grafana → Data Sources

Add Loki:

<http://loki:3100>

Just in case there are version incompatibilities. You can adjust the version of grafana to make it work with LOKI.

helm upgrade monitoring prometheus-community/kube-prometheus-stack \
 -n monitoring \
 --set grafana.image.tag=9.5.15

Then rollout the service again

kubectl rollout restart deployment monitoring-grafana -n monitoring

Forward the port to 3100

Go to Grafana and select loki as data source and set the URL as <http://loki:3100>
Then test the explore functionality by adding the namespace for the query...You should get the logs from the pods...
