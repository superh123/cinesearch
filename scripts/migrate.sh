#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ES="${ES:-http://localhost:9200}"

echo "Creating movies_v2 (avg_rating as scaled_float)..."
curl -s -X PUT "$ES/movies_v2" -H 'Content-Type: application/json' -d @elasticsearch/mapping_v2.json
echo

echo "Reindexing movies -> movies_v2..."
curl -s -X POST "$ES/_reindex?wait_for_completion=true&refresh=true" -H 'Content-Type: application/json' -d '{"source":{"index":"movies"},"dest":{"index":"movies_v2"}}'
echo

echo "Verification (do not swing the alias until these agree):"
echo "movies count:"; curl -s "$ES/movies/_count"; echo
echo "movies_v2 count:"; curl -s "$ES/movies_v2/_count"; echo
echo "movies doc 1:"; curl -s "$ES/movies/_doc/1"; echo
echo "movies_v2 doc 1:"; curl -s "$ES/movies_v2/_doc/1"; echo

echo "Swinging cinesearch alias to movies_v2 (old index kept, not deleted)..."
# Remove the alias from movies first if it is there; ignore failure if it is not.
curl -s -X POST "$ES/_aliases" -H 'Content-Type: application/json' -d '{"actions":[{"remove":{"index":"movies","alias":"cinesearch"}}]}' || true
echo
curl -s -X POST "$ES/_aliases" -H 'Content-Type: application/json' -d '{"actions":[{"add":{"index":"movies_v2","alias":"cinesearch"}}]}'
echo
curl -s "$ES/_alias/cinesearch"
echo
echo "Search through the alias:"
curl -s "$ES/cinesearch/_search?q=title:Toy%20Story&size=3"
echo
