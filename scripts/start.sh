#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || { echo 'Install and open Docker Desktop first.' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'Open Docker Desktop and wait until its engine is running.' >&2; exit 1; }
docker compose version >/dev/null
[[ -s data/supply_chain_demo.db ]] || {
  echo 'Database missing. Activate .venv, then run: python3 scripts/load.py' >&2
  exit 1
}
[[ -f schema.json ]] || { echo 'schema.json is missing.' >&2; exit 1; }

docker compose config --quiet
docker compose up -d
echo 'Waiting for PuppyGraph (up to 5 minutes after the image download)...'
ready=false
deadline=$((SECONDS + 300))
while (( SECONDS < deadline )); do
  status=$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --connect-timeout 2 --max-time 5 --user 'puppygraph:puppygraph123' \
    http://localhost:8081/schema) || status=000
  case "$status" in
    2??) ready=true; break ;;
    401|403) echo 'PuppyGraph rejected the configured credentials. Check this demo container and port 8081.' >&2; exit 1 ;;
  esac
  sleep 3
done
if [[ "$ready" != true ]]; then
  echo 'PuppyGraph did not become ready. Recent logs:' >&2
  docker compose logs --tail=60 puppygraph
  exit 1
fi

echo 'Applying schema.json to this demo instance...'
response=$(mktemp)
trap 'rm -f "$response"' EXIT
status=$(curl --silent --show-error --output "$response" --write-out '%{http_code}' \
  --connect-timeout 5 --max-time 180 \
  --user 'puppygraph:puppygraph123' \
  --header 'Content-Type: application/json' \
  --data-binary @schema.json \
  'http://localhost:8081/schema?postUploadBehavior=none') || {
    cat "$response" >&2
    echo 'Schema request failed; check docker compose logs --tail=60 puppygraph' >&2
    exit 1
  }
case "$status" in
  2??) cat "$response"; printf '\n' ;;
  *) cat "$response" >&2; printf '\nSchema upload failed (HTTP %s).\n' "$status" >&2; exit 1 ;;
esac
echo 'Schema request accepted. Open http://localhost:8081'
echo 'Username: puppygraph   Password: puppygraph123'
echo 'Open Query, select Cypher, and run queries/01-check-counts.cypher one statement at a time.'
