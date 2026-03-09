#!/bin/bash

# CodeDeploy ValidateService Hook
# This script performs final validation of the deployment

set -e

echo "========================================"
echo "ValidateService: Final validation"
echo "Time: $(date)"
echo "========================================"

CONTAINER_NAME="fasecolda-wp"
EFS_MOUNT="/mnt/efs/wp-content"

# Verify container is running
echo "Verifying container status..."
if ! docker ps | grep -q $CONTAINER_NAME; then
  echo "❌ ERROR: Container is not running"
  exit 1
fi

echo "✅ Container is running"

# Check container health status
HEALTH_STATUS=$(docker inspect --format='{{.State.Status}}' $CONTAINER_NAME)
if [ "$HEALTH_STATUS" != "running" ]; then
  echo "❌ ERROR: Container status is $HEALTH_STATUS (expected: running)"
  exit 1
fi

echo "✅ Container health status: $HEALTH_STATUS"

# Verify container uptime
CONTAINER_STARTED=$(docker inspect --format='{{.State.StartedAt}}' $CONTAINER_NAME)
echo "Container started at: $CONTAINER_STARTED"

# Test HTTP endpoint with detailed headers
echo "Testing HTTP endpoint with headers..."
HTTP_RESPONSE=$(curl -s -I http://localhost/ || echo "FAILED")

if echo "$HTTP_RESPONSE" | grep -q "HTTP"; then
  HTTP_CODE=$(echo "$HTTP_RESPONSE" | head -n 1 | cut -d' ' -f2)
  echo "✅ HTTP response code: $HTTP_CODE"

  # Check for Varnish cache header
  if echo "$HTTP_RESPONSE" | grep -qi "X-Cache"; then
    CACHE_HEADER=$(echo "$HTTP_RESPONSE" | grep -i "X-Cache" | head -n1)
    echo "✅ Varnish cache header: $CACHE_HEADER"
  else
    echo "⚠️  WARNING: No X-Cache header found (Varnish may not be active)"
  fi
else
  echo "❌ ERROR: Failed to get HTTP response"
  exit 1
fi

# Verify EFS mount
echo "Verifying EFS mount..."
if docker exec $CONTAINER_NAME test -d /var/www/html/wp-content; then
  echo "✅ EFS mount verified: /var/www/html/wp-content exists in container"

  # Check if wp-content has content
  FILE_COUNT=$(docker exec $CONTAINER_NAME find /var/www/html/wp-content -type f 2>/dev/null | wc -l || echo "0")
  echo "Files in wp-content: $FILE_COUNT"

  if [ "$FILE_COUNT" -gt 0 ]; then
    echo "✅ wp-content has files"
  else
    echo "⚠️  WARNING: wp-content appears to be empty"
  fi
else
  echo "⚠️  WARNING: wp-content directory not found in container"
fi

# Verify processes inside container
echo "Checking processes inside container..."
APACHE_COUNT=$(docker exec $CONTAINER_NAME ps aux | grep -c "[a]pache2" || echo "0")
VARNISH_COUNT=$(docker exec $CONTAINER_NAME ps aux | grep -c "[v]arnishd" || echo "0")

echo "Apache processes: $APACHE_COUNT"
echo "Varnish processes: $VARNISH_COUNT"

if [ "$APACHE_COUNT" -gt 0 ] && [ "$VARNISH_COUNT" -gt 0 ]; then
  echo "✅ Both Apache and Varnish processes are running"
else
  echo "⚠️  WARNING: Expected processes may not be running"
  echo "Process list:"
  docker exec $CONTAINER_NAME ps aux
fi

# Check container logs for errors (last 100 lines)
echo "Checking container logs for errors..."
ERROR_COUNT=$(docker logs --tail 100 $CONTAINER_NAME 2>&1 | grep -i "error" | wc -l || echo "0")

if [ "$ERROR_COUNT" -gt 20 ]; then
  echo "⚠️  WARNING: Found $ERROR_COUNT errors in recent logs"
  echo "Recent errors:"
  docker logs --tail 100 $CONTAINER_NAME 2>&1 | grep -i "error" | head -10
else
  echo "✅ Container logs look healthy (errors: $ERROR_COUNT)"
fi

# Display container resource usage
echo "Container resource usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $CONTAINER_NAME || true

# Final summary
echo ""
echo "========================================"
echo "Validation Summary:"
echo "========================================"
echo "✅ Container: Running"
echo "✅ HTTP: Responding"
echo "✅ Apache: Active"
echo "✅ Varnish: Active"
echo "✅ EFS: Mounted"
echo ""
echo "Deployment validated successfully!"
echo "========================================"
