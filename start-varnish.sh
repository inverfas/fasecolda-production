#!/bin/bash
set -e

# Start Apache in the background
apache2-foreground &

# Wait for Apache to be ready
echo "Waiting for Apache to start on port 8080..."
timeout=30
counter=0
while ! nc -z localhost 8080; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "Apache failed to start within ${timeout} seconds"
        exit 1
    fi
done

echo "Apache is running on port 8080"

# Start Varnish in the foreground
echo "Starting Varnish on port 80..."
exec varnishd \
    -F \
    -f /etc/varnish/default.vcl \
    -s malloc,256m \
    -a :80 \
    -T localhost:6082 \
    -p feature=+esi_ignore_https \
    -p feature=+esi_disable_xml_check \
    -p vcc_allow_inline_c=on
