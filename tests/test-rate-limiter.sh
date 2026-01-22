#!/bin/bash
# Test rate limiter functionality
# This script tests if the rate limiter is correctly limiting requests
# Compatible with Bash 3.2 (macOS)

set -e

RATE_LIMIT_ENDPOINT="http://localhost:3900"
HEALTH_ENDPOINT="$RATE_LIMIT_ENDPOINT/health"
# Burst is 200, Rate is 100r/s. We need > 200 requests very fast to trigger it.
REQUESTS_PER_TEST=400 

echo "═══════════════════════════════════════════════════════════════"
echo "           Rate Limiter Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Health check
echo "TEST 1: Health Check"
echo "───────────────────────────────────────────────────────────────"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT")
STATUS=$(echo "$STATUS" | tr -d '[:space:]')
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
STATUS=$(echo "$STATUS" | tr -d '[:space:]')
echo "✓ Single request completed (Status: $STATUS)"
echo ""

# Test 3: Rapid fire requests
echo "TEST 3: Rapid Fire Requests ($REQUESTS_PER_TEST requests)"
echo "───────────────────────────────────────────────────────────────"
echo "Sending requests in parallel to trigger rate limit..."

# Create temp file for results
RESULTS_FILE=$(mktemp /tmp/rate_limit_results.XXXXXX)

# Function to send a batch of requests
send_batch() {
    local count=$1
    for i in $(seq 1 "$count"); do
        curl -s -o /dev/null -w "%{http_code}\n" "$RATE_LIMIT_ENDPOINT/" >> "$RESULTS_FILE" &
    done
    wait
}

# Send all requests in parallel chunks to maximize concurrency
# We need to be faster than the refill rate (100/s)
BATCH_SIZE=100
echo "Sending $REQUESTS_PER_TEST requests in batches of $BATCH_SIZE..."

for i in $(seq 1 $BATCH_SIZE $REQUESTS_PER_TEST); do
    send_batch "$BATCH_SIZE"
done

echo ""
echo "Results:"
TOTAL_REQUESTS=$(wc -l < "$RESULTS_FILE" | tr -d '[:space:]')
COUNT_200=$(grep -c "200" "$RESULTS_FILE" | tr -d '[:space:]' || echo 0)
COUNT_403=$(grep -c "403" "$RESULTS_FILE" | tr -d '[:space:]' || echo 0)
COUNT_429=$(grep -c "429" "$RESULTS_FILE" | tr -d '[:space:]' || echo 0)

echo "  Status 200: $COUNT_200"
echo "  Status 403: $COUNT_403"
echo "  Status 429: $COUNT_429 (Rate Limited)"

# Test 4: Rate limit check
if [ "$COUNT_429" -gt 0 ]; then
    echo ""
    echo "✓ Rate limiting is ACTIVE - Got $COUNT_429 responses with status 429"
else
    echo ""
    echo "✗ Rate limiting FAILED to trigger."
    echo "  Total requests: $TOTAL_REQUESTS"
    echo "  Configured Burst: 200"
    echo "  If this fails, the test might be too slow or the limiter is disabled."
    exit 1
fi
echo ""

rm "$RESULTS_FILE"

# Test 6: Service connectivity
echo "TEST 6: Service Connectivity"
echo "───────────────────────────────────────────────────────────────"
if docker compose ps | grep -q "s3.*Up"; then
    echo "✓ S3 Service (OpenResty+Garage) is running"
else
    echo "✗ S3 Service is not running"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                  Test Suite Complete"
echo "═══════════════════════════════════════════════════════════════"
