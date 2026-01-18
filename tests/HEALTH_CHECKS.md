# Health Checks & Auto-Restart Guide

Docker Compose supports health checks with automatic restart capabilities. This document explains how they work in our setup.

## How Health Checks Work

```
Container Running
    ↓
Health Check (every interval)
    ↓
    ├─ PASS → Status: "healthy" ✓
    │         Continue running
    │
    └─ FAIL → Increment failure counter
             ↓
             └─ retries exceeded?
                ├─ YES → Status: "unhealthy" ✗
                │        Docker marks as unhealthy
                │        Restart policy may trigger
                │
                └─ NO → Wait and retry on next interval

```

## Our Configuration

### Garage Service

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
  interval: 30s         # Check every 30 seconds
  timeout: 10s          # Wait max 10 seconds for response
  retries: 3            # Mark unhealthy after 3 failures
  start_period: 30s     # Grace period on startup

restart: unless-stopped # Auto-restart if stopped unexpectedly
```

**Timeline:**
```
Container starts
    ↓
Wait 30 seconds (start_period)
    ↓
Check 1: curl health endpoint (30s interval)
    ↓
If fails 3 times in a row → Marked unhealthy
    ↓
Docker restarts the container automatically
```

### Rate Limiter Service

```yaml
healthcheck:
  test: ["CMD", "nc", "-z", "127.0.0.1", "3900"]
  interval: 10s         # Check every 10 seconds (more frequent)
  timeout: 5s           # Wait max 5 seconds
  retries: 3            # Mark unhealthy after 3 failures
  start_period: 5s      # Quick startup grace period

restart: unless-stopped # Auto-restart if stopped unexpectedly
```

**Timeline:**
```
Container starts
    ↓
Wait 5 seconds (start_period)
    ↓
Check 1: netcat port 3900 (10s interval)
    ↓
If fails 3 times → Unhealthy
    ↓
Docker restarts automatically
```

## Health Check Parameters Explained

### `test`
The command to run to check health.

**Options:**
- `["CMD", "command", "args"]` - Run command directly
- `["CMD-SHELL", "command"]` - Run command in shell

**Examples:**
```yaml
# Check HTTP endpoint
test: ["CMD", "curl", "-f", "http://localhost:3900/health"]

# Check port is open
test: ["CMD", "nc", "-z", "127.0.0.1", "3900"]

# Check file exists
test: ["CMD", "test", "-f", "/var/run/app.pid"]

# Run shell command
test: ["CMD-SHELL", "curl -f http://localhost:3900 || exit 1"]
```

### `interval`
How often to run the health check.

- Default: 30s
- Minimum: 1ms
- Use shorter intervals (10s-15s) for critical services
- Use longer intervals (30s-60s) for stable services

### `timeout`
How long to wait for the health check command to complete.

- Default: 30s
- If command doesn't complete in this time, check fails
- Should be less than `interval`

### `retries`
Number of consecutive failures before marking container unhealthy.

- Default: 3
- After N failures in a row, status changes to "unhealthy"
- Resets to 0 when a check passes

### `start_period`
Grace period after container starts before checking health.

- Default: 0s
- Useful for slow-starting applications
- Docker won't mark container unhealthy during this period

## Restart Policies

The `restart` policy controls what happens when container stops or becomes unhealthy.

### Available Policies

| Policy | Behavior |
|--------|----------|
| `no` | Do not automatically restart (default) |
| `always` | Always restart if stops (even if manually stopped) |
| `unless-stopped` | Always restart unless explicitly stopped |
| `on-failure` | Restart only if exit code is non-zero |
| `on-failure:5` | Restart on failure, max 5 attempts |

### Our Configuration: `unless-stopped`

```yaml
restart: unless-stopped
```

**What it does:**
- ✓ Auto-restarts if container crashes
- ✓ Auto-restarts if container is killed
- ✓ Auto-restarts after Docker daemon restart
- ✗ Does NOT restart if you run `docker compose stop`

## Monitoring Health Status

### View Current Status

```bash
# See all containers with health status
docker compose ps

# OUTPUT:
# NAME          STATUS              PORTS
# garage        Up (health: starting)
# rate-limiter  Up (healthy)
```

### Health Status Values

- **starting**: Container is in grace period (start_period)
- **healthy**: Latest health check passed
- **unhealthy**: Health check failed retries times
- **none**: No health check configured

### View Health Check Details

```bash
# Inspect specific container
docker inspect garage | jq '.State.Health'

# OUTPUT:
# {
#   "Status": "healthy",
#   "FailingStreak": 0,
#   "Passes": 125,
#   "StartedAt": "2026-01-18T04:50:00.123456789Z"
# }
```

### Watch Health Changes in Real-time

```bash
# Monitor health continuously (1 second updates)
watch -n 1 'docker compose ps'

# Or use watch with docker inspect
watch -n 1 "docker inspect garage | jq '.State.Health.Status'"
```

### View Health Check History in Logs

```bash
# See health check execution in daemon logs
docker compose logs garage | grep -i "health"

# Enable debug mode for more detail
DOCKER_BUILDKIT=1 docker compose logs garage
```

## Testing Health Checks

### Test Garage Health

```bash
# Simulate health check
curl -f http://localhost:3903/health
echo $?  # Should output 0 if healthy

# Monitor health check execution
while true; do
  status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3903/health)
  timestamp=$(date '+%H:%M:%S')
  echo "$timestamp: Status $status"
  sleep 5
done
```

### Test Rate Limiter Health

```bash
# Simulate health check
nc -z 127.0.0.1 3900
echo $?  # Should output 0 if healthy

# Or use curl instead
curl -s -o /dev/null http://localhost:3900/health
```

### Force Unhealthy State (for testing)

```bash
# Stop Garage to trigger health check failures
docker compose pause garage

# Watch health checks fail
watch -n 1 'docker compose ps garage'

# After 3 failures at 30s intervals = ~90s to unhealthy
# Then restart kicks in

# Resume it
docker compose unpause garage
```

## Troubleshooting

### Container keeps restarting

```bash
# Check restart count
docker inspect garage | jq '.RestartCount'

# Check logs
docker compose logs garage | tail -50

# Check if health check is passing
docker compose ps garage
```

**Solutions:**
1. Increase `start_period` if app needs more startup time
2. Check if health check command is working
3. Verify service is actually starting correctly

### Health check command fails

```bash
# Test the command manually
docker compose exec garage curl -f http://localhost:3903/health

# Or for rate limiter
docker compose exec rate-limiter nc -z 127.0.0.1 3900
```

**Common issues:**
- Service not listening on expected port
- Health endpoint doesn't exist
- Command not found in container
- Network connectivity issue

### Health status is "starting" forever

```bash
# Increase start_period in docker-compose.yml
# If app needs 60 seconds to start:
start_period: 60s
```

### Container runs but health is unhealthy

```bash
# Check if service is actually working
docker compose exec garage /garage status

# Check service logs
docker compose logs garage | tail -20

# May need to manually restart
docker compose restart garage
```

## Production Recommendations

### For Critical Services

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
  interval: 10s           # Check more frequently
  timeout: 5s             # Fail fast
  retries: 2              # Restart sooner (2 failed checks)
  start_period: 30s       # Allow startup time

restart: always           # Always restart if unhealthy
```

### For Stable Services

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
  interval: 30s           # Check less frequently
  timeout: 10s
  retries: 3              # Allow some resilience
  start_period: 60s       # More startup time

restart: unless-stopped   # Restart unless manually stopped
```

## Advanced: Custom Health Check Script

Create `scripts/health-check.sh`:

```bash
#!/bin/bash
# Custom health check with multiple conditions

# Check if admin API is responding
if ! curl -f http://localhost:3903/health; then
    exit 1
fi

# Check if storage directories exist
if [ ! -d "/var/lib/garage/meta" ]; then
    exit 1
fi

# Check if data is being written
if [ ! -f "/var/lib/garage/meta/db.sqlite" ]; then
    exit 1
fi

# All checks passed
exit 0
```

Use in docker-compose.yml:

```yaml
healthcheck:
  test: ["CMD", "/scripts/health-check.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

## Monitoring with External Tools

### Use Prometheus metrics

```bash
# Expose health check metrics
curl http://localhost:3903/metrics | grep health
```

### Integration with monitoring systems

```bash
# Check health and report to monitoring system
docker compose ps garage | grep -q "healthy" && \
  curl -X POST http://monitoring/api/health/garage/ok || \
  curl -X POST http://monitoring/api/health/garage/fail
```

## Summary

Our setup provides:

✅ **Automatic health monitoring**
- Garage: Every 30 seconds
- Rate Limiter: Every 10 seconds

✅ **Automatic restart on failure**
- Restarts when health checks fail
- Respects `unless-stopped` policy
- Logs all restart attempts

✅ **Configurable thresholds**
- Adjust intervals and retries in docker-compose.yml
- Grace periods allow slow startup
- Different settings for each service

✅ **Easy monitoring**
- `docker compose ps` shows status
- Inspect detailed health info
- Watch real-time changes

The health checks ensure your S3 Garage setup stays running and automatically recovers from failures!
