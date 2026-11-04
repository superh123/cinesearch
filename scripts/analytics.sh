#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ES="${ES:-http://localhost:9200}"
curl -s -X GET "$ES/movies/_search?pretty" -H 'Content-Type: application/json' -d @queries/analytics.json
echo
