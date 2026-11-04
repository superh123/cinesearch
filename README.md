# CineSearch

A faceted movie search engine built on Elasticsearch, over the MovieLens
(ml-latest-small) dataset: **9,742 movies, 100,836 ratings**.

It is a search system: mappings, indexing, autocomplete, analytics,
relevance tuning, and a zero-downtime index migration, all driven through the
Elasticsearch API.

## What it demonstrates

- **Explicit mappings, typed for the query, not the data.** `title` is
  `text` with a `keyword` sub-field for sorting, `genres` is `keyword`,
  `year` and `ratings_count` are integers, `avg_rating` starts as `float`.
- **Full-text search with filters.** `match` vs `match_phrase` (positions, not
  keyword search), filter context vs `must` scoring, and sorting via doc
  values (`title.keyword` sorts; analyzed `title` does not).
- **Autocomplete via a custom edge-n-gram analyzer.** Edge n-grams at index
  time only, standard analyzer at search time, added with the
  close → settings → open → mapping → `_update_by_query` sequence.
- **Analytics.** Average rating by genre, ratings by decade, and a distinct
  genre count (19). Genre averages are unweighted per-movie averages, and a
  movie counts once per genre it belongs to.
- **Relevance tuning with `function_score`.** BM25 text score stays the gate
  (`boost_mode: multiply`); popularity is blended in with
  `field_value_factor` on `ratings_count`, factor 1, modifier `log2p`,
  `missing: 1` (no ratings = popularity-neutral, not penalised).
- **Zero-downtime migration.** A second index (`movies_v2`) is built beside
  the first, verified, and the `cinesearch` alias is swung to it. The old
  index is kept, not deleted, until the verification checks pass.

## Dataset

MovieLens ml-latest-small, from GroupLens (University of Minnesota).
9,742 movies, 100,836 ratings, 3,683 tag applications, 610 users.
The prepared bulk file is in `data/movies_bulk.ndjson` (one action line +
one document line per movie). Fields:

| Field | Type | Notes |
|---|---|---|
| `movie_id` | integer | MovieLens id |
| `title` | text + keyword | `title.keyword` for sorting |
| `year` | integer | 13 movies have no year |
| `genres` | keyword | 19 distinct genres |
| `avg_rating` | float → scaled_float | 18 movies have no rating; 3 decimal places, so `scaling_factor: 1000` in v2 |
| `ratings_count` | integer | Number of ratings behind `avg_rating` |

No endorsement from the University of Minnesota or the GroupLens Research
Group is stated or implied.

## Quickstart

Requirements: Docker and `curl` (or `jq` for pretty output).

```bash
docker compose up -d
./scripts/setup.sh          # waits for green health, creates the index, bulk-indexes, adds autocomplete
./scripts/search.sh "toy story"
./scripts/autocomplete.sh "toy st"
./scripts/analytics.sh
./scripts/relevance.sh "toy story"
./scripts/migrate.sh        # builds movies_v2, verifies, swings the cinesearch alias
docker compose down         # add -v to remove the data volume
```

Elasticsearch runs at `http://localhost:9200` with security disabled for
local development only. Do not expose that port publicly.

After `setup.sh`, the document count should be **9,742**:

```bash
curl -s "localhost:9200/movies/_count"
```

After `migrate.sh`, a search through the alias should return results, and
document 1 should still read `avg_rating: 3.921` in both indexes:

```bash
curl -s "localhost:9200/cinesearch/_search?q=title:Toy%20Story"
curl -s "localhost:9200/movies/_doc/1"
curl -s "localhost:9200/movies_v2/_doc/1"
```

## Layout

```
docker-compose.yml            Single-node Elasticsearch 9.3.2
elasticsearch/
  mapping.json                v1 mapping (avg_rating as float)
  mapping_v2.json             v2 mapping (avg_rating as scaled_float, factor 1000)
  autocomplete.json           Edge-n-gram analyzer settings (min_gram 2, max_gram 20)
  autocomplete_mapping.json   title.autocomplete sub-field (edge-n-gram at index, standard at search)
queries/
  search.json                 Full-text search with a genre filter
  phrase.json                 match_phrase example
  autocomplete.json           Autocomplete query
  analytics.json              Genre avg, decade histogram, genre cardinality
  relevance.json              function_score: BM25 x log2p(ratings_count)
scripts/
  setup.sh                    Health gate, index, bulk load, autocomplete
  search.sh                   Search by title text
  autocomplete.sh             Autocomplete by prefix text
  analytics.sh                Run the analytics aggregations
  relevance.sh                Run the relevance-tuned query
  migrate.sh                  Reindex to movies_v2, verify, swing alias
data/
  movies_bulk.ndjson          Prepared MovieLens bulk file (9,742 movies)
```
