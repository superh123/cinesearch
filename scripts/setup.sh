#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ES="${ES:-http://localhost:9200}"

echo "Waiting for Elasticsearch to be green..."
until curl -s "$ES/_cluster/health?wait_for_status=green&timeout=30s" | grep -q '"status":"green"'; do
  sleep 2
done

echo "Creating movies index..."
curl -s -X PUT "$ES/movies" -H 'Content-Type: application/json' -d @elasticsearch/mapping.json
echo

echo "Bulk-indexing 9,742 movies..."
curl -s -X POST "$ES/_bulk?refresh=true" -H 'Content-Type: application/x-ndjson' --data-binary @data/movies_bulk.ndjson | tail -c 200
echo
curl -s "$ES/movies/_count"
echo

echo "Adding autocomplete: close -> settings -> open -> mapping -> update_by_query"
curl -s -X POST "$ES/movies/_close"
echo
curl -s -X PUT "$ES/movies/_settings" -H 'Content-Type: application/json' -d @elasticsearch/autocomplete.json
echo
curl -s -X POST "$ES/movies/_open"
echo
curl -s -X PUT "$ES/movies/_mapping" -H 'Content-Type: application/json' -d @elasticsearch/autocomplete_mapping.json
echo
curl -s -X POST "$ES/movies/_update_by_query?refresh=true&conflicts=proceed"
echo
echo "Done. Try: ./scripts/search.sh \"toy story\""
