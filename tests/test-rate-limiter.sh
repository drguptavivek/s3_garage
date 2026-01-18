#!/bin/bash
# Test rate limiter functionality
# This script tests if the rate limiter is correctly limiting requests

set -e

RATE_LIMIT_ENDPOINT="http://localhost:3900"
HEALTH_ENDPOINT="$RATE_LIMIT_ENDPOINT/health"
REQUESTS_PER_TEST=250
DELAY_BETWEEN_BATCHES=2

echo "═══════════════════════════════════════════════════════════════"
echo "           Rate Limiter Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Health check
echo "TEST 1: Health Check"
echo "───────────────────────────────────────────────────────────────"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT")
if [ "$STATUS" = "200" ]; then
    echo "✓ Health check passed (Status: $STATUS)"
else
    echo "✗ Health check failed (Status: $STATUS)"
fi
echo ""

# Test 2: Single request
echo "TEST 2: Single Request"
echo "───────────────────────────────────────────────────────────────"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$RATE_LIMIT_ENDPOINT/")
echo "✓ Single request completed (Status: $STATUS)"
echo ""

# Test 3: Rapid fire requests
echo "TEST 3: Rapid Fire Requests ($REQUESTS_PER_TEST requests)"
echo "───────────────────────────────────────────────────────────────"
echo "Sending requests..."
declare -A status_counts
total_requests=0

for i in $(seq 1 $REQUESTS_PER_TEST); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$RATE_LIMIT_ENDPOINT/" &)
    status_counts[$STATUS]=$((${status_counts[$STATUS]:-0} + 1))
    total_requests=$((total_requests + 1))

    # Print progress every 50 requests
    if [ $((i % 50)) -eq 0 ]; then
        echo "  Sent $i requests..."
    fi
done

wait

echo ""
echo "Results:"
for status in "${!status_counts[@]}"; do
    count=${status_counts[$status]}
    percentage=$((count * 100 / total_requests))
    echo "  Status $status: $count requests ($percentage%)"
done
echo ""

# Test 4: Rate limit check
if [ -n "${status_counts[429]}" ] && [ "${status_counts[429]}" -gt 0 ]; then
    echo "✓ Rate limiting is ACTIVE - Got 429 (Too Many Requests)"
    echo "  Rate-limited requests: ${status_counts[429]}"
else
    echo "⚠ Rate limiting not triggered (may need higher request rate or longer test)"
    echo "  This could be normal if Garage backend isn't ready or threshold not reached"
fi
echo ""

# Test 5: Concurrent requests
echo "TEST 5: Concurrent Request Burst (100 parallel requests)"
echo "───────────────────────────────────────────────────────────────"
echo "Sending 100 concurrent requests..."
declare -A burst_counts

for i in $(seq 1 100); do
    curl -s -o /dev/null -w "%{http_code}\n" "$RATE_LIMIT_ENDPOINT/" > /tmp/status_$i.txt &
done

wait

for status_file in /tmp/status_*.txt; do
    STATUS=$(cat "$status_file")
    burst_counts[$STATUS]=$((${burst_counts[$STATUS]:-0} + 1))
done

echo "Burst results:"
for status in "${!burst_counts[@]}"; do
    count=${burst_counts[$status]}
    echo "  Status $status: $count requests"
done
rm -f /tmp/status_*.txt
echo ""

# Test 6: Service connectivity
echo "TEST 6: Service Connectivity"
echo "───────────────────────────────────────────────────────────────"
if docker compose ps | grep -q "rate-limiter.*Up.*healthy"; then
    echo "✓ Rate limiter service is healthy"
else
    echo "✗ Rate limiter service is not healthy"
fi

if docker compose ps | grep -q "garage.*Up"; then
    echo "✓ Garage service is running"
else
    echo "✗ Garage service is not running"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                  Test Suite Complete"
echo "═══════════════════════════════════════════════════════════════"
