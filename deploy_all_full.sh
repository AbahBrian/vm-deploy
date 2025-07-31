#!/bin/bash
set -e

# Buat Docker network jika belum ada
docker network inspect homelab_net >/dev/null 2>&1 || {
  echo "🚧 Membuat network 'homelab_net'..."
  docker network create homelab_net
}

# Buat dan deploy setiap container
declare -A services

services[npm]='
version: "3"
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - homelab_net

networks:
  homelab_net:
    external: true
'

services[adguard]='
version: "3"
services:
  adguard:
    image: adguard/adguardhome
    container_name: adguard
    ports:
      - "3000:3000"
      - "53:53/udp"
    volumes:
      - ./data:/opt/adguardhome/conf
    networks:
      - homelab_net

networks:
  homelab_net:
    external: true
'

services[homeassistant]='
version: "3"
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - ./config:/config
    restart: unless-stopped
    privileged: true
    network_mode: host
'

services[tailscale]='
version: "3"
services:
  tailscale:
    image: tailscale/tailscale
    container_name: tailscale
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
    volumes:
      - ./state:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    networks:
      - homelab_net

networks:
  homelab_net:
    external: true
'

services[cloudflared]='
version: "3"
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - homelab_net

networks:
  homelab_net:
    external: true
'

# Loop dan setup setiap layanan
for dir in "${!services[@]}"; do
  echo "📁 Menyiapkan direktori dan file untuk $dir..."
  mkdir -p "$dir"
  echo "${services[$dir]}" > "$dir/docker-compose.yml"

  echo "🚀 Men-deploy $dir..."
  cd "$dir"
  docker compose up -d
  cd ..
done

echo "✅ Semua service berhasil dijalankan."
