#!/bin/bash

set -e

# Directorio base relativo al script
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$BASE_DIR/.env"
NGINX_IMAGE="nginx:alpine"
WP_CONTAINER="fasecolda-wp"
NGINX_CONTAINER="fasecolda-nginx"
NETWORK_NAME="fasecolda-net"
PORT=80
VOLUME_NAME="fasecolda-wp-data"
NGINX_CONF="$BASE_DIR/nginx/default.conf"

# Cargar variables de entorno
source $ENV_FILE

# Configurar imagen de ECR
IMAGE_NAME="$ECR_REGISTRY/$ECR_REPOSITORY:latest"

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

# Verificar e instalar AWS CLI si no existe
if ! command -v aws &> /dev/null; then
  echo "📦 Instalando AWS CLI..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Ubuntu/Debian
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get update && sudo apt-get install -y unzip
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
    rm AWSCLIV2.pkg
  fi
fi

# Autenticar con AWS ECR
echo "🔐 Autenticando con AWS ECR..."
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_REGION

# Login a ECR
echo "🔑 Haciendo login a ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Descargar imagen desde ECR
echo "📥 Descargando imagen desde ECR: $IMAGE_NAME"
docker pull $IMAGE_NAME

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