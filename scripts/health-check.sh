#!/bin/bash

# CodeDeploy ApplicationStart Hook
# This script performs health checks on the WordPress container

set -e

echo "========================================"
echo "ApplicationStart: Health check"
echo "Time: $(date)"
echo "========================================"

CONTAINER_NAME="fasecolda-wp"
MAX_ATTEMPTS=30
ATTEMPT=0

# Verify container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
  echo "❌ ERROR: Container $CONTAINER_NAME is not running"
  exit 1
fi

echo "✅ Container is running"

# Wait for Apache to be ready
echo "Waiting for Apache to be ready (port 8080)..."
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if docker exec $CONTAINER_NAME nc -z localhost 8080 2>/dev/null; then
    echo "✅ Apache is responding on port 8080"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Apache not ready yet..."
  sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "❌ ERROR: Apache failed to start within timeout"
  echo "Container logs:"
  docker logs --tail 50 $CONTAINER_NAME
  exit 1
fi

# Wait for Varnish to be ready
echo "Waiting for Varnish to be ready (port 80)..."
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if docker exec $CONTAINER_NAME nc -z localhost 80 2>/dev/null; then
    echo "✅ Varnish is responding on port 80"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Varnish not ready yet..."
  sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "❌ ERROR: Varnish failed to start within timeout"
  echo "Container logs:"
  docker logs --tail 50 $CONTAINER_NAME
  exit 1
fi

# Test HTTP response from host
echo "Testing HTTP response from host..."
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ HTTP health check passed (HTTP $HTTP_CODE)"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Got HTTP $HTTP_CODE..."
  sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "❌ ERROR: HTTP health check failed (HTTP $HTTP_CODE)"
  echo "Container logs:"
  docker logs --tail 50 $CONTAINER_NAME
  exit 1
fi

# Check for obvious errors in logs
echo "Checking container logs for critical errors..."
ERROR_COUNT=$(docker logs $CONTAINER_NAME 2>&1 | grep -i "fatal\|critical" | wc -l || echo "0")

if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "⚠️  WARNING: Found $ERROR_COUNT critical errors in logs"
  docker logs --tail 20 $CONTAINER_NAME 2>&1 | grep -i "fatal\|critical" || true
else
  echo "✅ No critical errors found in logs"
fi

echo "========================================"
echo "Health check completed successfully"
echo "========================================"
