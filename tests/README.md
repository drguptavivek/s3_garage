# Garage S3 Tests

This directory contains test scripts to verify the Garage S3 setup and rate limiting functionality.

## Available Tests

### 1. Rate Limiter Tests (`test-rate-limiter.sh`)

Tests the rate limiting functionality to ensure it's working correctly.

**What it tests:**
- Health check endpoint
- Single request handling
- Rapid fire requests (250 concurrent)
- Rate limit activation (429 response codes)
- Concurrent burst requests (100 parallel)
- Service connectivity

**Run:**
```bash
./tests/test-rate-limiter.sh
```

**Expected output:**
- ✓ Health check should pass (200)
- All requests should be proxied through the rate limiter
- If rate limit is triggered, you'll see HTTP 429 responses
- Service connectivity should be verified

### 2. Connectivity Tests (`test-connectivity.sh`)

Verifies that all components are properly connected and configured.

**What it tests:**
- Docker and docker-compose availability
- Service running status (Garage and Rate Limiter)
- Port accessibility (3900, 3901)
- Inter-service communication
- Configuration files presence
- Environment variables
- Data directories

**Run:**
```bash
./tests/test-connectivity.sh
```

**Expected output:**
- ✓ All services running
- ✓ Ports accessible
- ✓ Configuration files present
- ✓ Environment variables set
- ✓ Data directories exist

### 3. Health Check Tests (`test-health.sh`)

Checks the health status of both Garage and the rate limiter.

**What it tests:**
- Rate limiter health endpoint (port 3900)
- Garage admin API health (port 3903)
- Garage cluster initialization status
- Service restart policies
- Resource usage (memory, CPU)
- Log analysis for errors

**Run:**
```bash
./tests/test-health.sh
```

**Expected output:**
- ✓ Rate limiter health: 200 OK
- ✓ Garage health status
- Resource usage statistics
- Error count summary

## Running All Tests

```bash
# Make scripts executable (one time)
chmod +x tests/*.sh

# Run all tests in sequence
./tests/test-connectivity.sh
./tests/test-health.sh
./tests/test-rate-limiter.sh
```

Or create a test runner:

```bash
#!/bin/bash
echo "Running all tests..."
./tests/test-connectivity.sh && \
./tests/test-health.sh && \
./tests/test-rate-limiter.sh && \
echo "✓ All tests passed!"
```

## Prerequisites

- Docker and Docker Compose installed
- Garage and rate-limiter services running
- `.env` file configured with secrets
- `curl` command available

## Test Results Interpretation

### Rate Limiter Tests

**HTTP Status Codes:**
- `200`: Request processed (if Garage is ready)
- `429`: Rate limit exceeded (expected under load)
- `502`: Bad Gateway (Garage not ready - expected on first start)
- `000`: Connection refused (service not running)

**Expected behavior:**
- First test should return 200 for health check
- S3 API requests should return 502 until Garage is initialized
- Once initialized, requests should return 200 or 429 depending on rate

### Connectivity Tests

All connectivity tests should show ✓. If any show ✗:

- **Docker not available**: Install Docker
- **Services not running**: Run `docker compose up -d`
- **Ports not accessible**: Check firewall or port conflicts
- **Configuration files missing**: Check repository structure
- **Environment variables missing**: Run `./scripts/generate-secrets.sh`

### Health Tests

**Healthy state:**
- Rate limiter: 200 OK
- Garage API: 200 OK (if initialized)
- No critical errors in logs
- Restart policies set to "unless-stopped"

**Unhealthy state:**
- Health endpoints not responding
- Critical errors in logs
- High CPU or memory usage
- Services restarting repeatedly

## Troubleshooting

### "Port 3900 not accessible"

```bash
# Check if rate limiter is running
docker compose ps rate-limiter

# Check rate limiter logs
docker compose logs rate-limiter

# Restart rate limiter
docker compose restart rate-limiter
```

### "Garage API not responding"

```bash
# Check if Garage is running
docker compose ps garage

# Check Garage logs
docker compose logs garage

# Initialize Garage cluster
./scripts/init-garage.sh
```

### "Rate limiting not triggered"

Rate limiting requires requests to exceed 100 RPS (default). To test:

1. Run test-rate-limiter.sh multiple times in quick succession
2. Or adjust `.env` and lower `RATE_LIMIT_RPS` temporarily:
   ```bash
   RATE_LIMIT_RPS=10  # Lower threshold for testing
   docker compose restart rate-limiter
   ```

### "Inter-service communication fails"

```bash
# Check Docker network
docker network ls | grep garage

# Check if services can resolve hostnames
docker compose exec garage ping -c 2 rate-limiter
docker compose exec rate-limiter ping -c 2 garage
```

## Performance Baseline

When all tests pass, expect:

- **Latency**: <50ms per request
- **Rate limiter overhead**: <1ms
- **Memory usage**:
  - Rate limiter: ~30-50MB
  - Garage: ~200-400MB (depends on database)
- **Throughput**: >100 RPS (default limit)

## Continuous Testing

For continuous monitoring, you can set up a cron job:

```bash
# Add to crontab
0 * * * * cd /path/to/s3_garage && ./tests/test-health.sh >> tests/health-log.txt
```

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run connectivity tests
  run: ./tests/test-connectivity.sh

- name: Run health checks
  run: ./tests/test-health.sh

- name: Run rate limiter tests
  run: ./tests/test-rate-limiter.sh
```

## Documentation Files

- **HEALTH_CHECKS.md** - Comprehensive guide to Docker Compose health checks, monitoring, and troubleshooting
- **RESTART_TROUBLESHOOTING.md** - Detailed guide on preventing and debugging restart loops (what causes them, detection, prevention, real-world scenarios)

## Avoiding Restart Loops

If you're concerned about services getting stuck in restart loops, see **RESTART_TROUBLESHOOTING.md** for:

- What causes restart loops and how to detect them
- Why our current configuration prevents them
- Debugging steps if a loop occurs
- Real-world scenarios and solutions
- Prevention best practices

Quick summary: Our setup uses `start_period: 30s` (grace period) + `retries: 3` (requires 3 failures) + `unless-stopped` (respects manual stop) to safely handle failures without endless restart cycles.

## Contributing

To add new tests:

1. Create a new script in `tests/` directory
2. Follow naming convention: `test-*.sh`
3. Add documentation in this README
4. Make it executable: `chmod +x tests/test-mytest.sh`
5. Test that it works: `./tests/test-mytest.sh`
