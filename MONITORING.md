# Monitoring and Troubleshooting Guide

Complete guide to monitoring your Garage S3 setup and avoiding common issues like restart loops.

## Quick Reference

### Current Service Status

```bash
# See all services and their health
docker compose ps

# Output example:
# NAME              STATUS              HEALTH
# garage            Up (health: healthy)
# garage-rate-limiter Up (health: healthy)
```

### Monitor for Restart Loops

```bash
# Real-time monitoring with automatic detection
./scripts/monitor-restarts.sh

# One-time check of restart count
docker inspect garage | jq '.RestartCount'
```

### Check Service Health

```bash
# Detailed health status
docker inspect garage | jq '.State.Health'

# Test health endpoint manually
docker compose exec garage curl http://localhost:3903/health
```

### View Service Logs

```bash
# Follow logs in real-time
docker compose logs -f garage
docker compose logs -f rate-limiter

# View last 50 lines
docker compose logs garage | tail -50

# Search for errors
docker compose logs garage | grep -i error
```

## Monitoring Tools and Scripts

### 1. monitor-restarts.sh

**Purpose:** Detect if services are stuck in restart loops

**Usage:**
```bash
./scripts/monitor-restarts.sh
```

**What it does:**
- Displays real-time status of both services every 5 seconds
- Shows health status (healthy/unhealthy/starting)
- Tracks restart count changes
- Alerts if restart count increases by >2 in 15 seconds (indicates loop)
- Shows current service status (running/restarting)

**Example output:**
```
GARAGE SERVICE:
  Status: running
  Health: healthy
  Restarts: 0

RATE LIMITER SERVICE:
  Status: running
  Health: healthy
  Restarts: 0

RESTART TREND (Last 15+ seconds):
  Garage restarts increase: +0
  Rate Limiter restarts increase: +0
  ✓ No restart loop detected
```

**When to use:** Run this when starting services for the first time or if you suspect restart issues

### 2. test-health.sh

**Purpose:** Comprehensive health status report

**Usage:**
```bash
./tests/test-health.sh
```

**What it checks:**
- Rate limiter health endpoint
- Garage admin API health
- Garage cluster status
- Service restart policies
- Memory and CPU usage
- Error count in logs

**Example output:**
```
✓ Rate limiter is healthy (Health check: 200 OK)
✓ Garage admin API is healthy (Health check: 200 OK)
✓ Garage is initialized
✓ Both services have proper restart policies
Rate limiter memory: 45MB
Garage memory: 250MB
✓ No critical errors detected
```

**When to use:** Run periodically to ensure services are healthy, or after major changes

### 3. test-connectivity.sh

**Purpose:** Verify infrastructure setup and connectivity

**Usage:**
```bash
./tests/test-connectivity.sh
```

**What it checks:**
- Docker and docker-compose availability
- Services running status
- Port accessibility (3900, 3901)
- Inter-service communication
- Configuration files present
- Environment variables set
- Data directory existence

**When to use:** After initial setup or if services aren't communicating

### 4. test-rate-limiter.sh

**Purpose:** Validate rate limiting functionality

**Usage:**
```bash
./tests/test-rate-limiter.sh
```

**What it checks:**
- Health check endpoint
- Single request handling
- Rapid concurrent requests
- Rate limit activation (429 responses)
- Service connectivity

**When to use:** To verify rate limiting is working and requests are being handled correctly

## Documentation Files

### HEALTH_CHECKS.md (tests/)

**Covers:**
- How Docker Compose health checks work
- Configuration parameters (test, interval, timeout, retries, start_period)
- Monitoring commands
- Health status interpretation
- Troubleshooting guide
- Advanced: Custom health check scripts
- Production recommendations

**Use when:** You need to understand or adjust health check configuration

### RESTART_TROUBLESHOOTING.md (tests/)

**Covers:**
- What causes restart loops
- How to detect restart loops
- Why our configuration prevents them
- Root causes of restart loops (insufficient start_period, failing health check, immediate crashes, etc.)
- Step-by-step debugging guide
- Real-world scenarios (first-time startup, actual loops, hanging health checks)
- Prevention best practices
- Commands reference

**Use when:** You're troubleshooting service restart issues or want to understand the restart mechanism

## Common Scenarios

### Scenario 1: Initial Startup (Expected Behavior)

**What you'll see:**
```
garage  Up (health: starting)     # Grace period active
garage  Up (health: unhealthy)    # Health checks start, Garage not yet initialized
```

**Is this a problem?** NO - This is completely normal.

**Solution:** Run initialization:
```bash
./scripts/init-garage.sh
```

After initialization:
```
garage  Up (health: healthy)  ✓
```

### Scenario 2: Services Running Normally

**What you'll see:**
```
$ docker compose ps
NAME                 STATUS              HEALTH
garage               Up                  healthy
garage-rate-limiter  Up                  healthy
```

**Restart count is stable:**
```bash
$ docker inspect garage | jq '.RestartCount'
0  # No restarts if services never crashed
```

### Scenario 3: Service Crashed and Auto-Restarted (Normal Recovery)

**What you'll see:**
```
# Before restart
garage  Up (health: unhealthy)
garage  Restarting (0)              # Docker detects failure and restarts

# After restart
garage  Up (health: healthy)        # Service recovered
```

**Restart count increased by 1:**
```bash
docker inspect garage | jq '.RestartCount'
1  # One restart recorded
```

**Is this a problem?** NO - This is the auto-restart mechanism working.

**Next step:** Check logs to understand why it crashed:
```bash
docker compose logs garage | tail -20
```

### Scenario 4: Restart Loop (Problem)

**What you'll see:**
```
garage  Restarting (0) 3 seconds ago
garage  Up (health: starting)
garage  Restarting (1) 6 seconds ago
garage  Up (health: starting)
garage  Restarting (2) 9 seconds ago     # Pattern repeats
```

**Restart count rapidly increasing:**
```bash
# Check 1
docker inspect garage | jq '.RestartCount'
5

# Wait 10 seconds
docker inspect garage | jq '.RestartCount'
8  # Increased - it's looping
```

**Monitor script shows:**
```
RESTART TREND (Last 15+ seconds):
  Garage restarts increase: +5
  ⚠️  WARNING: Garage appears to be in a restart loop!
```

**How to fix:** See RESTART_TROUBLESHOOTING.md for detailed debugging steps

## Monitoring Checklist

Use this daily/weekly to ensure healthy operation:

```bash
# Daily check (< 1 minute)
docker compose ps                  # Should show all healthy
docker inspect garage | jq '.RestartCount'  # Should be stable (0 if never crashed)
docker compose logs garage | grep -i error  # Should be minimal

# Weekly check (< 5 minutes)
./tests/test-connectivity.sh       # Should show all ✓
./tests/test-health.sh             # Should show healthy status
du -sh data/garage-*               # Monitor data growth

# Monthly check
./tests/test-rate-limiter.sh       # Verify rate limiting still works
docker system df                   # Check for unused resources
```

## Performance Baseline

When everything is working correctly, expect:

**Resource usage:**
- Garage: 200-400MB RAM (depends on data size)
- Rate Limiter: 30-50MB RAM
- Combined CPU: <5% at idle

**Response times:**
- S3 API latency: <50ms
- Rate limiter overhead: <1ms

**Throughput:**
- Default rate limit: 100 requests/second per IP
- Burst capacity: 200 requests

## Alerting Setup

### Manual Monitoring Script

Add to your cron for periodic checks:

```bash
# Check every hour
0 * * * * cd /path/to/s3_garage && ./tests/test-health.sh >> monitoring.log

# Check for restart loops every 5 minutes
*/5 * * * * cd /path/to/s3_garage && docker inspect garage | jq -r '.RestartCount' >> restart-count.log
```

### Simple Alert Script

Create `scripts/check-and-alert.sh`:

```bash
#!/bin/bash

# Get restart count
RESTART_COUNT=$(docker inspect garage | jq '.RestartCount')
MAX_ALLOWED=2

if [ "$RESTART_COUNT" -gt "$MAX_ALLOWED" ]; then
    echo "ALERT: Garage has restarted $RESTART_COUNT times (limit: $MAX_ALLOWED)"
    echo "Details: $(docker compose ps garage)"

    # Send alert (email, webhook, etc.)
    # curl -X POST http://alerts.example.com/webhook -d "..."
fi

# Check health
if ! docker compose exec -T garage curl -s -f http://localhost:3903/health > /dev/null; then
    echo "ALERT: Garage health check failed"
fi
```

Make it executable and add to cron:
```bash
chmod +x scripts/check-and-alert.sh
# */10 * * * * cd /path/to/s3_garage && ./scripts/check-and-alert.sh
```

## Debugging Workflow

If something goes wrong:

### Step 1: Quick Status Check

```bash
docker compose ps                    # See if services are running
docker inspect garage | jq '.State'  # Detailed state
docker compose logs garage | tail -20 # Recent errors
```

### Step 2: Test Health Manually

```bash
# Test Garage health
docker compose exec garage curl -v http://localhost:3903/health

# Test Rate Limiter
docker compose exec rate-limiter curl -v http://localhost:3900/health
```

### Step 3: If Services Keep Restarting

```bash
# Stop and inspect (prevents restart loop)
docker compose pause garage

# Now you can safely examine
docker compose logs garage | grep -i error | head -10

# Check configuration
docker compose exec garage cat /etc/garage.toml | grep -A5 "\[s3_api\]"

# Resume when ready to test fix
docker compose unpause garage
```

### Step 4: Access Logs for Debugging

```bash
# Follow logs in real-time
docker compose logs -f garage

# Search for specific errors
docker compose logs garage | grep "error\|warn\|panic"

# Show context (5 lines before and after error)
docker compose logs garage | grep -C5 "error"
```

## More Information

- **Health Check Details:** See `tests/HEALTH_CHECKS.md`
- **Restart Troubleshooting:** See `tests/RESTART_TROUBLESHOOTING.md`
- **Test Documentation:** See `tests/README.md`
- **Garage Docs:** https://garagehq.deuxfleurs.fr/documentation/
