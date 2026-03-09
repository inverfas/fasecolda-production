#!/bin/bash
set -e

# Copy WordPress core files (without overwriting existing files like wp-config.php)
# This is needed because the entrypoint skips copying when wp-content already exists
echo "Copying WordPress core files..."
cp -rn /usr/src/wordpress/. /var/www/html/
echo "WordPress core files ready"

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

# Build runtime VCL: inject CACHE_EXCLUDE_URLS if defined
# Format: comma-separated URL paths, e.g. /carrito/,/finalizar-compra/
VCL_FILE="/etc/varnish/default.vcl"
RUNTIME_VCL="/tmp/default-runtime.vcl"

if [ -n "${CACHE_EXCLUDE_URLS:-}" ]; then
    echo "Applying CACHE_EXCLUDE_URLS exclusions: $CACHE_EXCLUDE_URLS"
    # Convert comma-separated paths to pipe-separated regex
    VCL_PATTERN=$(echo "$CACHE_EXCLUDE_URLS" | tr ',' '|' | tr -d ' ')
    # Use awk to replace placeholder with VCL rule (avoids sed delimiter conflicts)
    awk -v pattern="^(${VCL_PATTERN})" '
        /# __CACHE_EXCLUDE_URLS__/ {
            print "    # Exclusions from CACHE_EXCLUDE_URLS env var"
            print "    if (req.url ~ \"" pattern "\") { return (pass); }"
            next
        }
        { print }
    ' "$VCL_FILE" > "$RUNTIME_VCL"
    VCL_FILE="$RUNTIME_VCL"
else
    echo "No CACHE_EXCLUDE_URLS set, using default VCL"
    cp "$VCL_FILE" "$RUNTIME_VCL"
    sed -i '/# __CACHE_EXCLUDE_URLS__/d' "$RUNTIME_VCL"
    VCL_FILE="$RUNTIME_VCL"
fi

# Start Varnish in the foreground with resource limits
echo "Starting Varnish on port 80..."
exec varnishd \
    -F \
    -f "$VCL_FILE" \
    -s malloc,1G \
    -a :80 \
    -T localhost:6082 \
    -p thread_pool_min=50 \
    -p thread_pool_max=500 \
    -p thread_pools=2 \
    -p feature=+esi_ignore_https \
    -p feature=+esi_disable_xml_check \
    -p vcc_allow_inline_c=on
