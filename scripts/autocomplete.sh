#!/usr/bin/env bash
set -euo pipefail
ES="${ES:-http://localhost:9200}"
TEXT="${1:-toy st}"
curl -s -X GET "$ES/movies/_search?pretty" -H 'Content-Type: application/json' -d "{\"query\":{\"match\":{\"title.autocomplete\":\"$TEXT\"}}}"
echo
