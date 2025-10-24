#!/bin/bash
# Apache detailed monitoring and analysis
# Usage: ./apache-stats.sh

CONTAINER_NAME=${CONTAINER_NAME:-$(docker ps --format '{{.Names}}' | head -n 1)}

echo "=========================================="
echo "APACHE DETAILED STATISTICS"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# Check if Apache is running
if ! docker exec $CONTAINER_NAME pgrep apache2 > /dev/null 2>&1; then
    echo "❌ Apache is not running in container $CONTAINER_NAME"
    exit 1
fi

echo "✅ Apache is running"
echo ""

echo "📊 PROCESS OVERVIEW"
echo "===================="
apache_count=$(docker exec $CONTAINER_NAME ps aux | grep -c '[a]pache2')
echo "  Total Apache Processes: $apache_count"

# Expected based on our config
echo "  Expected Max (config):  10"

if [ $apache_count -gt 10 ]; then
    echo "  ❌ CRITICAL: More processes than configured!"
elif [ $apache_count -gt 7 ]; then
    echo "  ⚠️  HIGH: Apache is under heavy load"
elif [ $apache_count -gt 4 ]; then
    echo "  ⚡ MODERATE: Normal load"
else
    echo "  ✅ LOW: Light load"
fi
echo ""

echo "💾 MEMORY USAGE PER PROCESS"
echo "===================="
docker exec $CONTAINER_NAME ps aux | grep '[a]pache2' | awk '{
    total_rss += $6;
    total_vsz += $5;
    count++;
    if ($6 > max_rss) max_rss = $6;
    if ($6 < min_rss || min_rss == 0) min_rss = $6;
}
END {
    if (count > 0) {
        avg_rss = total_rss / count;
        printf "  Average RSS:       %.0f MB\n", avg_rss/1024;
        printf "  Max RSS:           %.0f MB\n", max_rss/1024;
        printf "  Min RSS:           %.0f MB\n", min_rss/1024;
        printf "  Total Memory:      %.0f MB\n", total_rss/1024;
        printf "  Process Count:     %d\n", count;
        printf "\n";

        if (max_rss/1024 > 200) {
            printf "  ⚠️  Some processes using >200MB - memory leak?\n";
        }
        if (total_rss/1024 > 1500) {
            printf "  ⚠️  Total Apache memory >1.5GB - reduce workers or memory_limit\n";
        } else {
            printf "  ✅ Memory usage is within acceptable range\n";
        }
    }
}'
echo ""

echo "🔍 PROCESS DETAILS (Top 5 by Memory)"
echo "===================="
docker exec $CONTAINER_NAME ps aux --sort=-rss | grep '[a]pache2' | head -5 | awk '{
    printf "  PID: %-6s  CPU: %-5s  MEM: %-5s  RSS: %-8s  TIME: %s\n", $2, $3"%", $4"%", int($6/1024)"MB", $10
}'
echo ""

echo "⏱️  PROCESS UPTIME"
echo "===================="
docker exec $CONTAINER_NAME ps -eo pid,etime,cmd | grep '[a]pache2' | head -10 | awk '{
    printf "  PID: %-6s  Uptime: %s\n", $1, $2
}'
echo ""

echo "🔄 MPM CONFIGURATION CHECK"
echo "===================="
mpm_config=$(docker exec $CONTAINER_NAME cat /etc/apache2/mods-available/mpm_prefork.conf 2>/dev/null)

if [ -n "$mpm_config" ]; then
    echo "  StartServers:       $(echo "$mpm_config" | grep StartServers | awk '{print $2}')"
    echo "  MinSpareServers:    $(echo "$mpm_config" | grep MinSpareServers | awk '{print $2}')"
    echo "  MaxSpareServers:    $(echo "$mpm_config" | grep MaxSpareServers | awk '{print $2}')"
    echo "  MaxRequestWorkers:  $(echo "$mpm_config" | grep MaxRequestWorkers | awk '{print $2}')"
    echo "  ServerLimit:        $(echo "$mpm_config" | grep ServerLimit | awk '{print $2}')"
else
    echo "  ⚠️  Custom MPM config not found - using defaults"
fi
echo ""

echo "📈 PHP CONFIGURATION"
echo "===================="
php_config=$(docker exec $CONTAINER_NAME php -i 2>/dev/null | grep -E "memory_limit|max_execution_time|opcache.enable")
if [ -n "$php_config" ]; then
    echo "$php_config" | while read line; do
        echo "  $line"
    done

    # Check OPcache
    if echo "$php_config" | grep -q "opcache.enable => On"; then
        echo "  ✅ OPcache is enabled"
    else
        echo "  ⚠️  OPcache might be disabled"
    fi
else
    echo "  ⚠️  Could not retrieve PHP configuration"
fi
echo ""

echo "💡 RECOMMENDATIONS"
echo "===================="

# Check process count vs config
if [ $apache_count -gt 10 ]; then
    echo "⚠️  Apache is spawning more processes than configured."
    echo "   Action: Restart container to apply MPM configuration"
fi

# Check memory usage
total_mem=$(docker exec $CONTAINER_NAME ps aux | grep '[a]pache2' | awk '{total += $6} END {print total/1024}')
if (( $(echo "$total_mem > 1500" | bc -l) )); then
    echo "⚠️  Total Apache memory usage is high (${total_mem}MB)"
    echo "   Action: Consider reducing PHP memory_limit or MaxRequestWorkers"
fi

# Check for long-running processes
long_running=$(docker exec $CONTAINER_NAME ps -eo pid,etime,cmd | grep '[a]pache2' | awk '$2 ~ /-/ {print $1}' | wc -l)
if [ $long_running -gt 0 ]; then
    echo "⚠️  Found $long_running processes running for >24h"
    echo "   Action: Set MaxConnectionsPerChild to recycle processes"
fi

echo ""
echo "=========================================="
echo "To watch processes in real-time:"
echo "  watch -n 2 'docker exec $CONTAINER_NAME ps aux | grep apache2'"
echo "=========================================="
