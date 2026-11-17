#!/bin/bash
set -e

NEW_IMAGE=$1
NEW_VERSION=$2

if [ -z "$NEW_IMAGE" ] || [ -z "$NEW_VERSION" ]; then
    echo "Usage: ./scripts/deploy.sh <docker_image> <version_label>"
    exit 1
fi

NGINX_CONF="$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)/nginx/default.conf"

if grep -q "8081" "$NGINX_CONF"; then
    TARGET_COLOR="green"
    TARGET_CONTAINER="app-green"
    TARGET_PORT=8082
    OLD_CONTAINER="app-blue"
else
    TARGET_COLOR="blue"
    TARGET_CONTAINER="app-blue"
    TARGET_PORT=8081
    OLD_CONTAINER="app-green"
fi

echo "🚀 Deploying $NEW_VERSION to $TARGET_COLOR (port $TARGET_PORT)..."

docker rm -f "$TARGET_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$TARGET_CONTAINER" --restart always \
  -p "$TARGET_PORT:8080" \
  -e APP_VERSION="$NEW_VERSION (${TARGET_COLOR^^})" \
  "$NEW_IMAGE"

echo "🔍 Running health checks on http://localhost:$TARGET_PORT/health..."
HEALTHY=false
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$TARGET_PORT/health" || echo "000")
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

printf "upstream active_backend {\n    server host.docker.internal:%s;\n}\n\nserver {\n    listen 80;\n\n    location / {\n        proxy_pass http://active_backend;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n    }\n}\n" "$TARGET_PORT" > "$NGINX_CONF"

docker exec nginx-proxy nginx -s reload && sleep 1
echo "🔄 Nginx reloaded! Traffic switched to $TARGET_COLOR ($NEW_VERSION) with ZERO downtime."

