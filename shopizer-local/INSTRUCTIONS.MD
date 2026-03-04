ollama pull llama3.1
ollama list

----

python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml requests

----

python -u runbook.py shopizer-local-runbook.yaml

----

# cleanup runbook

python -u runbook.py shopizer-local-cleanup-runbook.yaml


----




