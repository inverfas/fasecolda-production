#!/bin/bash

set -e

# Directorio base relativo al script
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$BASE_DIR/.env"
WP_CONTAINER="fasecolda-wp"
PORT=80
VOLUME_NAME="fasecolda-wp-data"

# Cargar variables de entorno
source $ENV_FILE

# Configurar imagen de ECR
IMAGE_NAME="$ECR_REGISTRY/$ECR_REPOSITORY:latest"

echo "🔧 Iniciando despliegue de WordPress..."

# Validar si el archivo .env existe
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Archivo .env no encontrado en $ENV_FILE"
  exit 1
fi

# Eliminar contenedor anterior si existe
if [ "$(docker ps -aq -f name=$WP_CONTAINER)" ]; then
  echo "🧹 Eliminando contenedor existente $WP_CONTAINER..."
  docker rm -f $WP_CONTAINER
fi

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

# Build de la imagen local
echo "📦 Construyendo imagen WordPress: $IMAGE_NAME"
docker build -t $IMAGE_NAME "$BASE_DIR"

# Push de la imagen a ECR
echo "📤 Subiendo imagen a ECR: $IMAGE_NAME"
docker push $IMAGE_NAME

# Limpiar solo imágenes intermedias (sin tocar redes)
echo "🧼 Limpiando imágenes huérfanas..."
docker image prune -f

echo "✅ Imagen construida, subida a ECR y limpieza completada"

# Crear volumen si no existe
if ! docker volume ls | grep -q "$VOLUME_NAME"; then
  echo "🧱 Creando volumen persistente: $VOLUME_NAME"
  docker volume create $VOLUME_NAME
fi

# Lanzar contenedor de WordPress (Varnish + Apache)
echo "🚀 Lanzando contenedor WordPress con Varnish + Apache..."
docker run -d \
  --name $WP_CONTAINER \
  --env-file $ENV_FILE \
  -v $VOLUME_NAME:/var/www/html \
  -p $PORT:80 \
  --restart unless-stopped \
  --pids-limit=200 \
  $IMAGE_NAME

echo "✅ WordPress desplegado en http://$(curl -s ifconfig.me):$PORT"