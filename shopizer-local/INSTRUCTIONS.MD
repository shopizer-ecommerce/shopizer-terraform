Requires python3 
Python runbook plays the role of orchestration and hot deploy when running locally

----

python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml requests

----

# set OpenAI key only in shell env (do not commit to files) 
# This is for creating embeddings for product search
export OPENAI_API_KEY='<your-openai-api-key>'

# Next command orchestrates the terraform execution to run a knind cluster locally

python -u runbook.py shopizer-local-runbook.yaml

----

# cleanup runbook

python -u runbook.py shopizer-local-cleanup-runbook.yaml


----

## Hot redeploy a service (example shop)

## ##Patch secret (example )

export OPENAI_API_KEY='...'

kubectl patch secret app-secret -n default --type merge \
  -p "{\"stringData\":{\"OPENAI_API_KEY\":\"$(printf %s "$OPENAI_API_KEY" | tr -d '\r\n')\"}}" 


./operations/hot-redeploy-service.sh \
  -a /Users/carlsamson/Documents/dev/workspace/shopizer/microservices/microservices2 \
  -s shop 
  -n default



Verify
# full value (be careful: prints secret to terminal/history)
kubectl get secret app-secret -n default -o jsonpath='{.data.OPENAI_API_KEY}' | base64 --decode; echo





