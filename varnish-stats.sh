#!/bin/bash
# Varnish detailed statistics and analysis
# Usage: ./varnish-stats.sh

CONTAINER_NAME=${CONTAINER_NAME:-$(docker ps --format '{{.Names}}' | head -n 1)}

echo "=========================================="
echo "VARNISH DETAILED STATISTICS"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo ""

# Check if Varnish is running
if ! docker exec $CONTAINER_NAME pgrep varnishd > /dev/null 2>&1; then
    echo "❌ Varnish is not running in container $CONTAINER_NAME"
    exit 1
fi

echo "✅ Varnish is running"
echo ""

# Get all stats
echo "📊 CACHE PERFORMANCE"
echo "===================="
docker exec $CONTAINER_NAME varnishstat -1 | grep -E "cache_hit|cache_miss|cache_hitpass" | while read line; do
    echo "  $line"
done
echo ""

echo "🔄 BACKEND HEALTH"
echo "===================="
docker exec $CONTAINER_NAME varnishstat -1 | grep -E "backend_conn|backend_fail|backend_reuse|backend_busy" | while read line; do
    echo "  $line"
done
echo ""

echo "💾 MEMORY USAGE"
echo "===================="
docker exec $CONTAINER_NAME varnishstat -1 | grep -E "SMA\.s0\." | while read line; do
    echo "  $line"
done
echo ""

echo "📈 CACHE HIT RATE CALCULATION"
echo "===================="
stats=$(docker exec $CONTAINER_NAME varnishstat -1)
cache_hit=$(echo "$stats" | grep "MAIN.cache_hit " | awk '{print $2}')
cache_miss=$(echo "$stats" | grep "MAIN.cache_miss " | awk '{print $2}')
total=$((cache_hit + cache_miss))

if [ $total -gt 0 ]; then
    hit_rate=$(echo "scale=2; ($cache_hit * 100) / $total" | bc)
    echo "  Total Requests:      $total"
    echo "  Cache Hits:          $cache_hit"
    echo "  Cache Misses:        $cache_miss"
    echo "  Hit Rate:            ${hit_rate}%"
    echo ""

    if (( $(echo "$hit_rate >= 80" | bc -l) )); then
        echo "  ✅ EXCELLENT: Cache is working very well"
    elif (( $(echo "$hit_rate >= 60" | bc -l) )); then
        echo "  ⚡ GOOD: Cache is working properly"
    elif (( $(echo "$hit_rate >= 40" | bc -l) )); then
        echo "  ⚠️  FAIR: Cache could be improved"
    else
        echo "  ❌ POOR: Cache needs optimization"
    fi
else
    echo "  No cache statistics yet (container just started?)"
fi
echo ""

echo "🔍 OBJECTS IN CACHE"
echo "===================="
docker exec $CONTAINER_NAME varnishstat -1 | grep -E "n_object|n_expired|n_lru_nuked" | while read line; do
    echo "  $line"
done
echo ""

echo "⏱️  TIMEOUTS & ERRORS"
echo "===================="
docker exec $CONTAINER_NAME varnishstat -1 | grep -E "backend_timeout|fetch_failed|esi_errors" | while read line; do
    echo "  $line"
done
echo ""

echo "💡 RECOMMENDATIONS"
echo "===================="

# Check hit rate
if [ $total -gt 100 ] && [ -n "$hit_rate" ]; then
    if (( $(echo "$hit_rate < 60" | bc -l) )); then
        echo "⚠️  Cache hit rate is low. Consider:"
        echo "   - Increasing cache memory (currently 1G)"
        echo "   - Increasing TTL values"
        echo "   - Checking if too many cookies are preventing cache"
    fi
fi

# Check memory
g_bytes=$(echo "$stats" | grep "SMA.s0.g_bytes " | awk '{print $2}')
g_space=$(echo "$stats" | grep "SMA.s0.g_space " | awk '{print $2}')

if [ -n "$g_bytes" ] && [ -n "$g_space" ]; then
    total_mem=$((g_bytes + g_space))
    used_percent=$(echo "scale=2; ($g_bytes * 100) / $total_mem" | bc)

    if (( $(echo "$used_percent > 90" | bc -l) )); then
        echo "⚠️  Cache memory is ${used_percent}% full. Consider increasing malloc size"
    fi
fi

# Check backend failures
backend_fail=$(echo "$stats" | grep "MAIN.backend_fail " | awk '{print $2}')
if [ -n "$backend_fail" ] && [ $backend_fail -gt 0 ]; then
    echo "⚠️  Backend failures detected ($backend_fail). Apache might be overloaded"
fi

echo ""
echo "=========================================="
echo "For real-time monitoring, run:"
echo "  docker exec $CONTAINER_NAME varnishstat"
echo "=========================================="
