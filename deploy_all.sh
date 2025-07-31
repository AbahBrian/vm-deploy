#!/bin/bash
set -e

# Create shared docker network if not exists
docker network inspect homelab_net >/dev/null 2>&1 || docker network create homelab_net

# Deploy each service
for dir in npm adguard homeassistant tailscale cloudflared; do
  echo "Deploying $dir..."
  cd $dir
  docker compose up -d
  cd ..
done

echo "All services deployed."