#!/bin/bash
# WordPress + Varnish Performance Monitoring Script
# Usage: ./monitor.sh [interval_seconds]

INTERVAL=${1:-5}
CONTAINER_NAME=${CONTAINER_NAME:-$(docker ps --format '{{.Names}}' | head -n 1)}

echo "=========================================="
echo "WordPress + Varnish Performance Monitor"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo "=========================================="
echo ""

# Function to get timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to get CPU usage
get_cpu() {
    docker stats $CONTAINER_NAME --no-stream --format "{{.CPUPerc}}" | sed 's/%//'
}

# Function to get memory usage
get_memory() {
    docker stats $CONTAINER_NAME --no-stream --format "{{.MemUsage}}"
}

# Function to count Apache processes
count_apache() {
    docker exec $CONTAINER_NAME ps aux | grep -c '[a]pache2' || echo "0"
}

# Function to get Varnish stats
get_varnish_stats() {
    docker exec $CONTAINER_NAME varnishstat -1 2>/dev/null || echo "Varnish not responding"
}

# Function to calculate cache hit rate
get_cache_hit_rate() {
    local stats=$(get_varnish_stats)
    local cache_hit=$(echo "$stats" | grep "MAIN.cache_hit " | awk '{print $2}' | tr -d '\n' | tr -d ' ')
    local cache_miss=$(echo "$stats" | grep "MAIN.cache_miss " | awk '{print $2}' | tr -d '\n' | tr -d ' ')

    if [ -n "$cache_hit" ] && [ -n "$cache_miss" ] && [ "$cache_hit" != "N/A" ]; then
        local total=$((cache_hit + cache_miss))
        if [ $total -gt 0 ]; then
            echo "scale=2; ($cache_hit * 100) / $total" | bc 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    else
        echo "N/A"
    fi
}

# Function to get backend connections
get_backend_conn() {
    local stats=$(get_varnish_stats)
    echo "$stats" | grep "MAIN.backend_conn " | awk '{print $2}' | tr -d '\n' | tr -d ' ' || echo "0"
}

# Function to get Varnish memory usage
get_varnish_memory() {
    local stats=$(get_varnish_stats)
    local used=$(echo "$stats" | grep "SMA.s0.g_bytes" | awk '{print $2}')
    local avail=$(echo "$stats" | grep "SMA.s0.g_space" | awk '{print $2}')

    if [ -n "$used" ] && [ -n "$avail" ]; then
        local used_mb=$((used / 1024 / 1024))
        local avail_mb=$((avail / 1024 / 1024))
        local total_mb=$((used_mb + avail_mb))
        echo "${used_mb}MB / ${total_mb}MB"
    else
        echo "N/A"
    fi
}

# Main monitoring loop
while true; do
    clear
    echo "=========================================="
    echo "$(timestamp) - Performance Metrics"
    echo "=========================================="
    echo ""

    # CPU and Memory
    echo "📊 SYSTEM RESOURCES"
    echo "  CPU Usage:           $(get_cpu)%"
    echo "  Memory Usage:        $(get_memory)"
    echo ""

    # Apache
    echo "🌐 APACHE"
    apache_count=$(count_apache)
    echo "  Active Processes:    $apache_count"
    if [ $apache_count -gt 10 ]; then
        echo "  ⚠️  WARNING: More than 10 Apache processes!"
    elif [ $apache_count -gt 5 ]; then
        echo "  ⚡ Moderate load"
    else
        echo "  ✅ Normal load"
    fi
    echo ""

    # Varnish
    echo "🚀 VARNISH CACHE"
    hit_rate=$(get_cache_hit_rate)
    echo "  Cache Hit Rate:      ${hit_rate}%"

    if [ "$hit_rate" != "N/A" ]; then
        if (( $(echo "$hit_rate >= 80" | bc -l) )); then
            echo "  ✅ Excellent cache performance"
        elif (( $(echo "$hit_rate >= 60" | bc -l) )); then
            echo "  ⚡ Good cache performance"
        else
            echo "  ⚠️  Low cache hit rate - needs optimization"
        fi
    fi

    echo "  Cache Memory:        $(get_varnish_memory)"
    echo "  Backend Connections: $(get_backend_conn)"

    # Detailed Varnish stats
    stats=$(get_varnish_stats)
    cache_hit=$(echo "$stats" | grep "MAIN.cache_hit " | awk '{print $2}' | tr -d '\n' | tr -d ' ')
    cache_miss=$(echo "$stats" | grep "MAIN.cache_miss " | awk '{print $2}' | tr -d '\n' | tr -d ' ')
    backend_fail=$(echo "$stats" | grep "MAIN.backend_fail " | awk '{print $2}' | tr -d '\n' | tr -d ' ')

    echo "  Cache Hits:          ${cache_hit:-0}"
    echo "  Cache Misses:        ${cache_miss:-0}"
    echo "  Backend Failures:    ${backend_fail:-0}"

    if [ "${backend_fail:-0}" -gt 0 ]; then
        echo "  ⚠️  Backend failures detected!"
    fi

    echo ""
    echo "=========================================="
    echo "Next update in ${INTERVAL}s (Ctrl+C to stop)"
    echo "=========================================="

    sleep $INTERVAL
done
