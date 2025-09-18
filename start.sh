#!/bin/bash

set -e

# Directorio base relativo al script
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$BASE_DIR/.env"
IMAGE_NAME="fasecolda-wp"
NGINX_IMAGE="nginx:alpine"
WP_CONTAINER="fasecolda-wp"
NGINX_CONTAINER="fasecolda-nginx"
NETWORK_NAME="fasecolda-net"
PORT=80
VOLUME_NAME="fasecolda-wp-data"
NGINX_CONF="$BASE_DIR/nginx/default.conf"

echo "🔧 Iniciando despliegue de WordPress + NGINX..."

# Validar si el archivo .env existe
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Archivo .env no encontrado en $ENV_FILE"
  exit 1
fi

# Crear red si no existe
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "🔌 Creando red interna Docker: $NETWORK_NAME"
  docker network create $NETWORK_NAME
fi

# Eliminar contenedores anteriores si existen
for c in $WP_CONTAINER $NGINX_CONTAINER; do
  if [ "$(docker ps -aq -f name=$c)" ]; then
    echo "🧹 Eliminando contenedor existente $c..."
    docker rm -f $c
  fi
done

# Build de la imagen PHP-FPM
echo "📦 Construyendo imagen WordPress (PHP-FPM): $IMAGE_NAME"
docker build -t $IMAGE_NAME "$BASE_DIR"

# Limpiar imágenes intermedias
echo "🧼 Eliminando imágenes huérfanas..."
docker image prune -f

# Crear volumen si no existe
if ! docker volume ls | grep -q "$VOLUME_NAME"; then
  echo "🧱 Creando volumen persistente: $VOLUME_NAME"
  docker volume create $VOLUME_NAME
fi

# Lanzar contenedor de WordPress (PHP-FPM)
echo "🚀 Lanzando contenedor WordPress (PHP-FPM)..."
docker run -d \
  --name $WP_CONTAINER \
  --env-file $ENV_FILE \
  --network $NETWORK_NAME \
  -v $VOLUME_NAME:/var/www/html \
  --restart always \
  $IMAGE_NAME

# Lanzar contenedor de NGINX (exponiendo puerto 80)
echo "🚀 Lanzando contenedor NGINX..."
docker run -d \
  --name $NGINX_CONTAINER \
  --network $NETWORK_NAME \
  -v $VOLUME_NAME:/var/www/html \
  -v "$NGINX_CONF":/etc/nginx/conf.d/default.conf:ro \
  -p $PORT:80 \
  --restart always \
  $NGINX_IMAGE

echo "✅ WordPress desplegado en http://$(curl -s ifconfig.me):$PORT"