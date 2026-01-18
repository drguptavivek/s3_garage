# Avoiding Restart Loops: Complete Guide

This document explains what causes restart loops and how to prevent them in our Garage S3 setup.

## What is a Restart Loop?

A **restart loop** occurs when a container repeatedly crashes and restarts in a cycle, never reaching a stable "healthy" state. Instead of staying running, you see patterns like:

```
Container starts → Health check fails → Container marked unhealthy → Container restarts
Container starts → Health check fails → Container marked unhealthy → Container restarts
...continues indefinitely...
```

This is different from a normal restart, which happens once after a crash and then stabilizes.

## Detecting Restart Loops

### 1. Check Restart Count

```bash
# High and rapidly increasing restart count indicates a loop
docker inspect garage | jq '.RestartCount'

# Compare over time - if it keeps growing, there's a loop
docker inspect garage | jq '.RestartCount'  # Check 1
sleep 5
docker inspect garage | jq '.RestartCount'  # Check 2 - if higher, it's restarting
```

### 2. Check Recent Container State

```bash
# See container state and last exit reason
docker inspect garage | jq '.State'

# Output example (healthy):
# {
#   "Status": "running",
#   "Running": true,
#   "Paused": false,
#   "Restarting": false,
#   "FinishedAt": "0001-01-01T00:00:00Z",
#   "Health": {
#     "Status": "healthy",
#     "FailingStreak": 0
#   }
# }

# Output example (restart loop):
# {
#   "Status": "restarting",
#   "Restarting": true,
#   "ExitCode": 1,
#   "Error": "process exited with code 1"
# }
```

### 3. Watch Real-Time

```bash
# Monitor status updates in real-time (1-second refresh)
watch -n 1 'docker inspect garage | jq -r ".State | \"\(.Status) - Restarting: \(.Restarting) - Restart Count: .RestartCount\""'

# Or simpler:
watch -n 1 'docker compose ps garage'
```

### 4. Check Logs for Crash Pattern

```bash
# Look for repeated startup/crash messages
docker compose logs garage | tail -100 | grep -E "starting|exited|panic|error"

# If you see rapid timestamps (same second), it's a loop:
# Timestamp: 10:23:45 - Starting
# Timestamp: 10:23:47 - Exited
# Timestamp: 10:23:49 - Starting
# Timestamp: 10:23:51 - Exited
```

## Why Our Configuration Prevents Restart Loops

Our setup is designed to **avoid** restart loops:

```yaml
garage:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
    interval: 30s          # Check every 30 seconds
    timeout: 10s           # Wait 10 seconds for response
    retries: 3             # 3 consecutive failures before unhealthy
    start_period: 30s      # 30-second grace period on startup

  restart: unless-stopped  # Only restart if explicitly stopped or crashed
```

**How this prevents loops:**

1. **start_period: 30s** - Application gets 30 seconds to start up before health checks begin
   - Prevents immediate restart if app needs time to initialize
   - Garage typically starts in 5-15 seconds, so 30s is safe

2. **retries: 3** - Requires **3 consecutive** failures before marking unhealthy
   - Prevents single temporary failures from triggering restart
   - Must fail multiple times in a row (90 seconds of failures at 30s interval)
   - Single hiccup won't cause restart

3. **timeout: 10s** - Health check command has 10 seconds to complete
   - Prevents hanging health checks from blocking
   - If health check itself fails, it counts as 1 failure (not instant restart)

4. **interval: 30s** - Checks only every 30 seconds
   - Prevents rapid-fire failure cascades
   - Gives container time to recover between checks

5. **restart: unless-stopped** - Only auto-restarts on crash or daemon restart
   - Respects manual `docker compose stop`
   - Doesn't trap you in forced restart loop
   - Actually allows you to stop container for debugging

## Root Causes of Restart Loops

### 1. Insufficient start_period

**Problem:** Application needs 60 seconds to initialize, but start_period is only 30s

```yaml
# BAD - causes health check to fail while app is still starting
healthcheck:
  start_period: 30s   # Too short!
  interval: 10s
```

**Solution:** Increase start_period to match your app's startup time

```yaml
# GOOD
healthcheck:
  start_period: 60s   # Matches Garage startup time
  interval: 30s
```

### 2. Failing Health Check Command

**Problem:** Health check command itself is broken or unreachable

```bash
# Example: Port doesn't exist or service not listening
test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
# If Garage isn't listening on 3903, this always fails
```

**Solution:** Verify the health check command works manually

```bash
# Test directly in container
docker compose exec garage curl -f http://localhost:3903/health

# If it fails, check:
# 1. Is Garage listening on 3903?
docker compose exec garage netstat -tlnp | grep 3903

# 2. Is the endpoint working?
docker compose exec garage curl -v http://localhost:3903/health
```

### 3. Service Crashes Immediately on Startup

**Problem:** Application terminates right after starting

```bash
# Check logs - look for startup errors
docker compose logs garage | grep -i "error\|panic\|fatal"

# Common causes:
# - Configuration file is invalid
# - Required directories don't exist or aren't writable
# - Port is already in use
# - Required environment variables missing
```

**Solution:** Fix the root cause, don't increase retries

```bash
# Fix configuration
docker compose exec garage /garage -c /etc/garage.toml validate

# Fix permissions
docker compose down
docker volume prune  # or: rm -rf data/garage-*
docker compose up -d

# Check for port conflicts
lsof -i :3900  # Port should be free
```

### 4. Too Few Retries

**Problem:** Health check set to `retries: 1` - any single failure restarts

```yaml
# BAD - restart on first failure
healthcheck:
  retries: 1   # Too strict!
  interval: 10s
```

**Solution:** Use retries: 3 (our default)

```yaml
# GOOD - requires 3 failures in a row
healthcheck:
  retries: 3   # Allows recovery from transient failures
  interval: 30s
```

### 5. Tight Loop Restart Policy

**Problem:** Using `restart: always` with crashing app

```yaml
# DANGEROUS - will restart constantly if app crashes
restart: always
healthcheck:
  retries: 0   # Restart immediately on first failure
```

**Solution:** Use `restart: unless-stopped` with sensible retries

```yaml
# SAFE - only restarts after multiple failures
restart: unless-stopped
healthcheck:
  retries: 3
```

## Debugging a Suspected Restart Loop

### Step 1: Confirm it's actually a restart loop

```bash
# Get baseline restart count
BASELINE=$(docker inspect garage | jq '.RestartCount')
echo "Current restart count: $BASELINE"

# Wait 30 seconds
sleep 30

# Check if it increased
CURRENT=$(docker inspect garage | jq '.RestartCount')
echo "New restart count: $CURRENT"

if [ "$CURRENT" -gt "$BASELINE" ]; then
    echo "Container restarted - this is a restart loop"
else
    echo "Container is stable"
fi
```

### Step 2: Check Health Status

```bash
# Get detailed health information
docker inspect garage | jq '.State.Health'

# Look for:
# - Status: "healthy" (good) vs "unhealthy" (problem)
# - FailingStreak: 0 (good) vs >0 (failing)
# - Passes/Fails counts
```

### Step 3: Pause Container and Debug

```bash
# Stop the restart cycle by pausing
docker compose pause garage

# Now examine logs without rapid restart interference
docker compose logs garage | tail -50

# Test health check manually
docker compose exec garage curl -v http://localhost:3903/health

# Check what's actually running
docker compose exec garage ps aux

# Look at configuration
docker compose exec garage cat /etc/garage.toml
```

### Step 4: Fix and Resume

```bash
# After identifying the problem:

# Option A: Increase start_period (if startup time issue)
# Edit docker-compose.yml and increase start_period value
vi docker-compose.yml

# Option B: Fix configuration
# Edit config files and restart
docker compose down
# Make changes
docker compose up -d

# Resume paused container
docker compose unpause garage

# Monitor status
watch -n 1 'docker compose ps'
```

## Real-World Scenarios

### Scenario 1: First-Time Startup (Expected Behavior)

**What you'll see:**
```
garage     Starting (health: starting)   # start_period grace period active
garage     Up (health: starting)         # Still in grace period
garage     Up (health: starting)         # Still waiting
garage     Up (health: unhealthy)        # Grace period ended, health check fails (expected - Garage not initialized)
garage     Up (health: unhealthy)        # Continues failing until initialized
```

**Is this a problem?** NO - this is expected behavior.

**When does it become healthy?** After you run `./scripts/init-garage.sh`

```bash
./scripts/init-garage.sh
# Then check
docker compose ps garage
# Should show: Up (health: healthy) ✓
```

### Scenario 2: Actual Restart Loop (Bad)

**What you'll see:**
```
garage     Restarting (0) 1 second ago      # Container exited
garage     Up (health: starting)            # Restarted
garage     Restarting (1) 5 seconds ago     # Exited again
garage     Up (health: starting)            # Restarted again
garage     Restarting (2) 10 seconds ago    # This pattern repeats...
```

**What to check:**
```bash
# 1. Get restart count - should be increasing
docker inspect garage | jq '.RestartCount'

# 2. Check exit reason
docker inspect garage | jq '.State.ExitCode'  # Non-zero = crashed

# 3. Check recent logs
docker compose logs garage | tail -20

# 4. Pause and debug
docker compose pause garage
docker compose logs garage | grep -i error
```

### Scenario 3: Health Check Hanging

**Symptom:** Container never reaches healthy state, but doesn't restart

**Check:**
```bash
# Health status shows "starting" forever after start_period
docker inspect garage | jq '.State.Health.Status'

# Check if health check is stuck
docker compose logs garage | grep health

# Test the command directly
docker compose exec garage curl -v http://localhost:3903/health
```

**Fix:** Increase timeout or add debugging

```bash
# Check if endpoint exists
docker compose exec garage curl -i http://localhost:3903/health

# If it hangs, there's a network or service issue
# Increase timeout temporarily for debugging:
# timeout: 30s  # Instead of 10s
```

## Monitoring Checklist

Use this checklist to ensure your setup won't loop:

```bash
# 1. Verify restart policy
docker inspect garage | jq '.HostConfig.RestartPolicy'
# Should output: { "Name": "unless-stopped", "MaximumRetryCount": 0 }

# 2. Check health is not in failure streak
docker inspect garage | jq '.State.Health.FailingStreak'
# Should be 0 or very low (1-2 is okay)

# 3. Verify restart count is stable
docker inspect garage | jq '.RestartCount'
# Should be 0 (if never crashed) or stable (not increasing)

# 4. Check logs for errors
docker compose logs garage | tail -10 | grep -i error
# Should show no repeated errors

# 5. Verify service is actually healthy
curl -f http://localhost:3903/health
# Should return 200 OK
```

## Prevention Best Practices

1. **Always set start_period** - Give app time to start
   ```yaml
   start_period: 60s  # Adjust to your app's startup time
   ```

2. **Use reasonable retries** - Don't restart on first hiccup
   ```yaml
   retries: 3  # Requires 3 consecutive failures
   ```

3. **Test health check command** - Verify it actually works
   ```bash
   docker compose exec garage curl -f http://localhost:3903/health
   ```

4. **Use unless-stopped** - Don't force permanent restart
   ```yaml
   restart: unless-stopped  # Allows graceful stop
   ```

5. **Monitor restart count** - Catch loops early
   ```bash
   # Add to your monitoring
   docker inspect garage | jq '.RestartCount'
   ```

6. **Fix root causes** - Don't increase retries as a workaround
   ```bash
   # Bad: Makes loop slower but doesn't fix it
   retries: 10

   # Good: Fix the actual problem
   # Update config, fix permissions, increase start_period, etc.
   ```

## Commands Reference

```bash
# Detect restart loop
docker inspect garage | jq '.RestartCount'
docker compose logs garage | tail -50

# Pause container to stop restart cycle
docker compose pause garage

# Resume
docker compose unpause garage

# Force full restart
docker compose down
docker compose up -d

# Monitor in real-time
watch -n 1 'docker compose ps'
watch -n 1 'docker inspect garage | jq ".State.Health.Status"'

# Check health manually
curl http://localhost:3903/health
docker compose exec garage curl http://localhost:3903/health

# View complete health state
docker inspect garage | jq '.State.Health'
```

## Summary

Our current configuration:

✅ **Prevents restart loops** through:
- 30-second start_period (ample startup grace)
- 3-retry requirement (requires sustained failure)
- 30-second check interval (gradual not rapid)
- unless-stopped restart policy (allows manual stop)

✅ **Detects problems early** through:
- Regular health checks every 30 seconds
- Clear status reporting (healthy/unhealthy)
- Accessible logs and metrics

✅ **Debuggable** through:
- Pause/unpause for inspection
- Manual health check testing
- Clear error messages

**If you experience a restart loop:**
1. Pause the container with `docker compose pause`
2. Check logs: `docker compose logs garage`
3. Test health manually: `docker compose exec garage curl http://localhost:3903/health`
4. Fix the root cause (config, permissions, startup time)
5. Resume: `docker compose unpause`
