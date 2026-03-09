#!/bin/bash

# CodeDeploy BeforeInstall Hook
# This script stops and removes the existing WordPress container

set -e

echo "========================================"
echo "BeforeInstall: Stopping existing container"
echo "Time: $(date)"
echo "========================================"

CONTAINER_NAME="fasecolda-wp"

# Check if container exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container '$CONTAINER_NAME' found"

  # Stop container if running
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping container: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME || {
      echo "Warning: Failed to stop container gracefully, forcing..."
      docker kill $CONTAINER_NAME || true
    }
    echo "✅ Container stopped"
  else
    echo "Container is not running"
  fi

  # Remove container
  echo "Removing container: $CONTAINER_NAME"
  docker rm $CONTAINER_NAME || true
  echo "✅ Container removed"
else
  echo "No existing container '$CONTAINER_NAME' found"
fi

# Clean up old images (keep last 3)
echo "Cleaning up old Docker images..."
OLD_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'fasecolda/new-site' | tail -n +4)

if [ -n "$OLD_IMAGES" ]; then
  echo "Removing old images:"
  echo "$OLD_IMAGES"
  echo "$OLD_IMAGES" | xargs -r docker rmi || echo "Warning: Some images could not be removed (may be in use)"
else
  echo "No old images to clean up"
fi

echo "========================================"
echo "Container cleanup completed"
echo "========================================"
