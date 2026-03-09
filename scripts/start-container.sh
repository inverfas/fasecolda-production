#!/bin/bash

# CodeDeploy AfterInstall Hook
# This script pulls the latest Docker image and starts the WordPress container

set -e

echo "========================================"
echo "AfterInstall: Starting WordPress container"
echo "Time: $(date)"
echo "========================================"

# Configuration
AWS_REGION="us-east-1"
CONTAINER_NAME="fasecolda-wp"
ECR_REGISTRY="823365583633.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPOSITORY="fasecolda/new-site"
ENV_FILE="/opt/fasecolda/.env"
EFS_MOUNT="/mnt/efs/wp-content"

# Read image tag from deployment (if available)
DEPLOYMENT_ROOT="/opt/codedeploy-agent/deployment-root"
IMAGE_TAG_FILE=""

if [ -n "$DEPLOYMENT_GROUP_ID" ] && [ -n "$DEPLOYMENT_ID" ]; then
  IMAGE_TAG_FILE="$DEPLOYMENT_ROOT/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/image-tag.txt"
fi

if [ -f "$IMAGE_TAG_FILE" ]; then
  IMAGE_TAG=$(cat "$IMAGE_TAG_FILE")
  echo "Using image tag from deployment: $IMAGE_TAG"
else
  IMAGE_TAG="latest"
  echo "Using default image tag: latest"
fi

IMAGE="$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "Docker image: $IMAGE"

# Verify .env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ ERROR: .env file not found at $ENV_FILE"
  echo "Please create the .env file with the required environment variables"
  exit 1
fi

echo "✅ Found .env file at $ENV_FILE"

# Verify EFS mount exists
if [ ! -d "$EFS_MOUNT" ]; then
  echo "⚠️  WARNING: EFS mount not found at $EFS_MOUNT"
  echo "Creating directory..."
  mkdir -p $EFS_MOUNT
fi

echo "✅ EFS mount available at $EFS_MOUNT"

# ECR Login
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

if [ $? -ne 0 ]; then
  echo "❌ ERROR: Failed to login to ECR"
  exit 1
fi

echo "✅ Logged into ECR successfully"

# Pull latest image
echo "Pulling Docker image: $IMAGE"
docker pull $IMAGE

if [ $? -ne 0 ]; then
  echo "❌ ERROR: Failed to pull Docker image"
  exit 1
fi

echo "✅ Docker image pulled successfully"

# Create log directory
mkdir -p /var/log/wordpress

# Start WordPress container
# IMPORTANTE: Solo usamos EFS para persistencia, NO volúmenes Docker locales
# Esto permite migrar a nuevo EC2 sin perder datos
echo "Starting WordPress container..."
echo "Version: $IMAGE_TAG"
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  --pids-limit=200 \
  -p 80:80 \
  --env-file $ENV_FILE \
  -v $EFS_MOUNT:/var/www/html/wp-content \
  $IMAGE

if [ $? -ne 0 ]; then
  echo "❌ ERROR: Failed to start Docker container"
  docker logs $CONTAINER_NAME 2>&1 || true
  exit 1
fi

echo "✅ Container started successfully"

# Wait for container to be running
echo "Waiting for container to be in running state..."
sleep 5

# Verify container is running
if docker ps | grep -q $CONTAINER_NAME; then
  echo "✅ Container $CONTAINER_NAME is running"

  # Show container info
  echo ""
  echo "Container details:"
  docker ps --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

  # Show version info
  echo ""
  echo "Deployed version:"
  echo "  Image: $IMAGE"
  echo "  Tag: $IMAGE_TAG"

  # Show image labels if available
  IMAGE_LABELS=$(docker inspect $IMAGE --format='{{json .Config.Labels}}' 2>/dev/null || echo "{}")
  if [ "$IMAGE_LABELS" != "{}" ]; then
    echo "  Labels: $IMAGE_LABELS"
  fi
else
  echo "❌ ERROR: Container failed to start"
  echo "Container logs:"
  docker logs $CONTAINER_NAME 2>&1 || true
  exit 1
fi

echo "========================================"
echo "✅ Container deployment completed"
echo "✅ Version: $IMAGE_TAG"
echo "========================================"
