#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ES="${ES:-http://localhost:9200}"
TEXT="${1:-toy story}"
python3 - "$TEXT" <<'PY' > /tmp/cinesearch_relevance.json
import json, sys
q = json.load(open("queries/relevance.json"))
q["query"]["function_score"]["query"]["match"]["title"] = sys.argv[1]
print(json.dumps(q))
PY
curl -s -X GET "$ES/movies/_search?pretty" -H 'Content-Type: application/json' -d @/tmp/cinesearch_relevance.json
echo
