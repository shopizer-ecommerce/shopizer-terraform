Requires python3 
Python runbook plays the role of orchestration and hot deploy when running locally

----

python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml requests

----

# set OpenAI key only in shell env (do not commit to files)
export OPENAI_API_KEY='<your-openai-api-key>'

python -u runbook.py shopizer-local-runbook.yaml

----

# cleanup runbook

python -u runbook.py shopizer-local-cleanup-runbook.yaml


----

Hot redeploy a service (example shop)


./operations/hot-redeploy-service.sh \
  -a /Users/carlsamson/Documents/dev/workspace/shopizer/microservices/microservices2 \
  -s shop 
  -n default

Patch secret (example )
kubectl patch secret app-secret -n default --type merge \
  -p "{\"stringData\":{\"OPENAI_API_KEY\":\"$(printf %s "$OPENAI_API_KEY" | tr -d '\r\n')\"}}" 

Verify
kubectl get secret app-secret -n default -o jsonpath='{.data.OPENAI_API_KEY}' | base64 --decode | cat -vet




