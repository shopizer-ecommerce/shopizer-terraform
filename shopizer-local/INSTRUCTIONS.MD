ollama pull llama3.1
ollama list

----

python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml requests

----

python -u runbook_agent.py shopizer-local-runbook.yaml

----

# cleanup runbook

python -u runbook_agent.py shopizer-local-cleanup-runbook.yaml


----

# Create a wrapper

cat > shopizer-agent <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate
python runbook_agent.py "/Users/carlsamson/Documents/dev/workspace/shopizer/shopizer-assistant/shopizer-local-runbook.yaml"
EOF
chmod +x shopizer-agent

----

# raw runbook

python runbook_agent.py "/Users/carlsamson/Documents/dev/workspace/shopizer/shopizer-assistant/shopizer-local-runbook.yaml"

python -X faulthandler -u runbook_agent.py /Users/carlsamson/Documents/dev/workspace/shopizer/shopizer-assistant/shopizer-local.yaml
echo $?
