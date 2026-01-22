#!/bin/bash
# Test Garage and Rate Limiter health
# Checks if the unified S3 service is healthy and responsive

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "           Health Check Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Rate limiter (OpenResty) health
echo "TEST 1: Rate Limiter (OpenResty) Health"
echo "───────────────────────────────────────────────────────────────"
# Check public port 3900 (Rate Limiter)
RATE_LIMITER_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3900/health 2>/dev/null || echo "000")

if [ "$RATE_LIMITER_HEALTH" = "200" ]; then
    echo "✓ Rate limiter is healthy (Health check: 200 OK)"
elif [ "$RATE_LIMITER_HEALTH" != "000" ]; then
    echo "⚠ Rate limiter responded with status $RATE_LIMITER_HEALTH"
else
    echo "✗ Rate limiter is not responding on port 3900"
fi
echo ""

# Test 2: Garage Admin API health
echo "TEST 2: Garage Admin API Health"
echo "───────────────────────────────────────────────────────────────"
# Check admin port 3903 (Internal check)
GARAGE_HEALTH=$(docker compose exec s3 curl -s -o /dev/null -w "%{http_code}" http://localhost:3903/health 2>/dev/null || echo "000")

if [ "$GARAGE_HEALTH" = "200" ]; then
    echo "✓ Garage admin API is healthy (Health check: 200 OK)"
elif [ "$GARAGE_HEALTH" != "000" ]; then
    echo "⚠ Garage admin API responded with status $GARAGE_HEALTH"
else
    echo "✗ Garage admin API is not responding on port 3903"
fi
echo ""

# Test 3: Garage status via CLI
echo "TEST 3: Garage Cluster Status"
echo "───────────────────────────────────────────────────────────────"
GARAGE_STATUS=$(docker compose exec s3 /usr/local/bin/garage status 2>/dev/null || echo "Not initialized")

if echo "$GARAGE_STATUS" | grep -q "HEALTHY NODES"; then
    echo "✓ Garage is initialized"
    # Extract node count
    NODE_COUNT=$(echo "$GARAGE_STATUS" | grep -c "ID:" || echo "?")
    echo "  Nodes: $NODE_COUNT"
else
    echo "⚠ Garage cluster not yet initialized"
    echo "  Run: ./scripts/init-garage.sh"
fi
echo ""

# Test 4: Container restart policies
echo "TEST 4: Service Restart Policy"
echo "───────────────────────────────────────────────────────────────"
S3_RESTART=$(docker inspect s3-garage --format='{{.HostConfig.RestartPolicy.Name}}')

echo "S3 service restart policy: $S3_RESTART"

if [ "$S3_RESTART" = "unless-stopped" ]; then
    echo "✓ Service has proper restart policy"
else
    echo "⚠ Restart policy may not be optimal"
fi
echo ""

# Test 5: Memory and resource usage
echo "TEST 5: Resource Usage"
echo "───────────────────────────────────────────────────────────────"
echo "Gathering resource statistics..."
echo ""

S3_STATS=$(docker stats --no-stream s3-garage 2>/dev/null | tail -1)

echo "S3 Service (OpenResty + Garage):"
echo "$S3_STATS"
echo ""

# Test 6: Log analysis
echo "TEST 6: Log Analysis"
echo "───────────────────────────────────────────────────────────────"
LOG_ERRORS=$(docker compose logs s3 2>&1 | grep -ci "error\|fatal\|critical" | tr -d '[:space:]')
# Fallback if empty
if [ -z "$LOG_ERRORS" ]; then LOG_ERRORS=0; fi

echo "Error count in logs: $LOG_ERRORS"

if [ "$LOG_ERRORS" -eq 0 ]; then
    echo "✓ No critical errors detected"
else
    echo "⚠ Some errors detected in logs"
    echo "  Review with: docker compose logs s3"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                 Health Check Complete"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "SUMMARY:"
echo "  • Rate limiter: $([ "$RATE_LIMITER_HEALTH" = "200" ] && echo "✓ Healthy" || echo "⚠ Check status")"
echo "  • Garage API: $([ "$GARAGE_HEALTH" = "200" ] && echo "✓ Healthy" || echo "⚠ Check status")"
echo "  • Memory usage: Check resource section above"
echo ""
echo "For more details, run:"
echo "  docker compose logs -f s3"
