#!/bin/bash
set -e

NEW_IMAGE=$1
NEW_VERSION=$2

if [ -z "$NEW_IMAGE" ] || [ -z "$NEW_VERSION" ]; then
    echo "Usage: ./scripts/deploy.sh <docker_image> <version_label>"
    exit 1
fi

NGINX_CONF="$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)/nginx/default.conf"

if grep -q "app-blue:8080" "$NGINX_CONF"; then
    TARGET_COLOR="green"
    TARGET_CONTAINER="app-green"
    OLD_CONTAINER="app-blue"
else
    TARGET_COLOR="blue"
    TARGET_CONTAINER="app-blue"
    OLD_CONTAINER="app-green"
fi

echo "🚀 Deploying $NEW_VERSION to $TARGET_COLOR ($TARGET_CONTAINER)..."

docker rm -f "$TARGET_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$TARGET_CONTAINER" --network bg-net --restart always \
  -e APP_VERSION="$NEW_VERSION (${TARGET_COLOR^^})" \
  "$NEW_IMAGE"

echo "🔍 Running health checks on http://$TARGET_CONTAINER:8080/health..."
HEALTHY=false
for i in {1..10}; do
    STATUS=$(docker run --rm --network bg-net curlimages/curl:latest -s -o /dev/null -w "%{http_code}" "http://$TARGET_CONTAINER:8080/health" || echo "000")
    if [ "$STATUS" == "200" ]; then
        HEALTHY=true
        break
    fi
    sleep 1
done

if [ "$HEALTHY" != "true" ]; then
    echo "❌ Health check FAILED (HTTP $STATUS). Rolling back..."
    docker rm -f "$TARGET_CONTAINER" >/dev/null 2>&1 || true
    echo "🛡️ Traffic remains safely on $OLD_CONTAINER."
    exit 1
fi

echo "✅ Health check PASSED (HTTP 200)!"

printf "upstream active_backend {\n    server %s:8080;\n}\n\nserver {\n    listen 80;\n\n    location / {\n        proxy_pass http://active_backend;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n    }\n}\n" "$TARGET_CONTAINER" > "$NGINX_CONF"

docker exec nginx-proxy nginx -s reload && sleep 1
echo "🔄 Nginx reloaded! Traffic switched to $TARGET_COLOR ($NEW_VERSION) with ZERO downtime."
