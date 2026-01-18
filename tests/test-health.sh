#!/bin/bash
# Test Garage and Rate Limiter health
# Checks if both services are healthy and responsive

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "           Health Check Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Rate limiter health
echo "TEST 1: Rate Limiter Health"
echo "───────────────────────────────────────────────────────────────"
RATE_LIMITER_HEALTH=$(docker compose exec -T rate-limiter curl -s -o /dev/null -w "%{http_code}" localhost:3900/health 2>/dev/null || echo "000")

if [ "$RATE_LIMITER_HEALTH" = "200" ]; then
    echo "✓ Rate limiter is healthy (Health check: 200 OK)"
elif [ "$RATE_LIMITER_HEALTH" != "000" ]; then
    echo "⚠ Rate limiter responded with status $RATE_LIMITER_HEALTH"
else
    echo "✗ Rate limiter is not responding"
fi
echo ""

# Test 2: Garage API health
echo "TEST 2: Garage API Health"
echo "───────────────────────────────────────────────────────────────"
GARAGE_HEALTH=$(docker compose exec -T garage curl -s -o /dev/null -w "%{http_code}" localhost:3903/health 2>/dev/null || echo "000")

if [ "$GARAGE_HEALTH" = "200" ]; then
    echo "✓ Garage admin API is healthy (Health check: 200 OK)"
elif [ "$GARAGE_HEALTH" != "000" ]; then
    echo "⚠ Garage admin API responded with status $GARAGE_HEALTH"
else
    echo "✗ Garage admin API is not responding"
fi
echo ""

# Test 3: Garage status
echo "TEST 3: Garage Cluster Status"
echo "───────────────────────────────────────────────────────────────"
GARAGE_STATUS=$(docker compose exec -T garage /garage status 2>/dev/null || echo "Not initialized")

if echo "$GARAGE_STATUS" | grep -q "Garage"; then
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
echo "TEST 4: Service Restart Policies"
echo "───────────────────────────────────────────────────────────────"
RATE_LIMITER_RESTART=$(docker inspect garage-rate-limiter --format='{{.HostConfig.RestartPolicy.Name}}')
GARAGE_RESTART=$(docker inspect garage --format='{{.HostConfig.RestartPolicy.Name}}')

echo "Rate limiter restart policy: $RATE_LIMITER_RESTART"
echo "Garage restart policy: $GARAGE_RESTART"

if [ "$RATE_LIMITER_RESTART" = "unless-stopped" ] && [ "$GARAGE_RESTART" = "unless-stopped" ]; then
    echo "✓ Both services have proper restart policies"
else
    echo "⚠ Restart policies may not be optimal"
fi
echo ""

# Test 5: Memory and resource usage
echo "TEST 5: Resource Usage"
echo "───────────────────────────────────────────────────────────────"
echo "Gathering resource statistics..."
echo ""

RATE_LIMITER_STATS=$(docker stats --no-stream garage-rate-limiter 2>/dev/null | tail -1)
GARAGE_STATS=$(docker stats --no-stream garage 2>/dev/null | tail -1)

echo "Rate Limiter:"
echo "$RATE_LIMITER_STATS"
echo ""
echo "Garage:"
echo "$GARAGE_STATS"
echo ""

# Test 6: Log analysis
echo "TEST 6: Log Analysis"
echo "───────────────────────────────────────────────────────────────"
RATE_LIMITER_ERRORS=$(docker compose logs rate-limiter 2>/dev/null | grep -ci "error\|fatal\|critical" || echo "0")
GARAGE_CRITICAL=$(docker compose logs garage 2>/dev/null | grep -ci "fatal\|critical" || echo "0")

echo "Rate limiter error count: $RATE_LIMITER_ERRORS"
echo "Garage critical error count: $GARAGE_CRITICAL"

if [ "$RATE_LIMITER_ERRORS" -eq 0 ] && [ "$GARAGE_CRITICAL" -eq 0 ]; then
    echo "✓ No critical errors detected"
else
    echo "⚠ Some errors detected in logs"
    echo "  Review with: docker compose logs"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                 Health Check Complete"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "SUMMARY:"
echo "  • Rate limiter: $([ "$RATE_LIMITER_HEALTH" = "200" ] && echo "✓ Healthy" || echo "⚠ Check status")"
echo "  • Garage API: $([ "$GARAGE_HEALTH" = "200" ] && echo "✓ Healthy" || echo "⚠ Not initialized")"
echo "  • Memory usage: Check resource section above"
echo ""
echo "For more details, run:"
echo "  docker compose logs -f garage"
echo "  docker compose logs -f rate-limiter"
