#!/bin/bash
set -e

echo "🔨 Building Multi-Stage Distroless Docker image..."
docker build -t blue-green-app:v1 .

echo "🔵 Starting initial Blue container (v1.0.0) on port 8081..."
docker rm -f app-blue >/dev/null 2>&1 || true
docker run -d --name app-blue --restart always -p 8081:8080 -e APP_VERSION="v1.0.0 (BLUE)" blue-green-app:v1

echo "🌐 Starting Nginx Reverse Proxy on port 80..."
docker rm -f nginx-proxy >/dev/null 2>&1 || true
docker run -d --name nginx-proxy --restart always \
  --add-host=host.docker.internal:host-gateway \
  -p 80:80 \
  -v $(pwd)/nginx:/etc/nginx/conf.d \
  nginx:alpine

echo "✅ Initial Blue-Green environment is LIVE on http://localhost (v1.0.0 BLUE)"
