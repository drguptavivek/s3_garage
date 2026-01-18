# Monitoring & Health

Complete guide to health checks, monitoring, and avoiding restart loops.

## Quick Start

```bash
# Watch service status with health checks
watch -n 1 'docker compose ps'

# One-time health check
./tests/test-health.sh

# Monitor for restart loops
./scripts/monitor-restarts.sh
```

## Health Checks Explained

Docker Compose performs automatic health monitoring:

```yaml
garage:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3903/health"]
    interval: 30s         # Check every 30 seconds
    timeout: 10s          # Wait max 10 seconds
    retries: 3            # 3 failures = unhealthy
    start_period: 30s     # Grace period on startup

  restart: unless-stopped # Auto-restart on crash
```

### Health Status Values

- **starting** - Grace period (start_period) active
- **healthy** - All checks passing ✓
- **unhealthy** - Failed retries consecutive failures
- **none** - No health check configured

### View Health Status

```bash
# Current status
docker compose ps garage

# Detailed health info
docker compose inspect garage | jq '.State.Health'

# Watch in real-time
watch -n 1 'docker compose ps garage'
```

## Monitoring Setup

### 1. Check Service Health

```bash
./tests/test-health.sh
```

Output shows:
- Rate limiter health
- Garage admin API health
- Cluster status
- Restart policies
- Memory/CPU usage
- Error counts in logs

### 2. Monitor Restart Loops

```bash
./scripts/monitor-restarts.sh
```

This script:
- Updates every 5 seconds
- Shows restart count
- Alerts if restarting too frequently
- Helps detect restart loops

### 3. Test Connectivity

```bash
./tests/test-connectivity.sh
```

Verifies:
- Docker/docker-compose available
- Services running
- Ports accessible
- Inter-service communication
- Configuration files present
- Environment variables set

## Avoiding Restart Loops

### Why Loops Occur

```
Service starts → Fails immediately → Docker restarts
Service starts → Fails immediately → Docker restarts
... (repeats forever)
```

### Our Protection

Your setup prevents loops through:

1. **start_period: 30s** - App has 30 seconds to start before health checks begin
2. **retries: 3** - Requires 3 consecutive failures to mark unhealthy
3. **interval: 30s** - Checks only every 30 seconds (not rapid-fire)
4. **restart: unless-stopped** - Respects manual stop, doesn't force restart

### Detect a Loop

```bash
# Check if restart count is increasing
docker inspect garage | jq '.RestartCount'
sleep 10
docker inspect garage | jq '.RestartCount'
# If second value is much higher, it's looping

# Or use the monitoring script
./scripts/monitor-restarts.sh
```

### Fix a Loop

1. **Pause the container** to stop the restart cycle:
   ```bash
   docker compose pause garage
   ```

2. **Check logs** for the actual error:
   ```bash
   docker compose logs garage | tail -50
   ```

3. **Identify root cause** (insufficient start_period, config error, etc.)

4. **Resume and test**:
   ```bash
   docker compose unpause garage
   ```

See [RESTART_TROUBLESHOOTING.md](./RESTART_TROUBLESHOOTING.md) for detailed troubleshooting.

## Performance Baselines

When everything is working correctly:

- **Garage RAM:** 200-400MB
- **Rate Limiter RAM:** 30-50MB
- **CPU at idle:** <5%
- **S3 API latency:** <50ms
- **Rate limiter overhead:** <1ms per request
- **Default throughput:** 100 RPS per IP

## Monitoring Checklist

Daily:
```bash
docker compose ps              # Health status
docker compose logs garage | tail -20  # Recent errors
```

Weekly:
```bash
./tests/test-health.sh         # Full health check
du -sh data/                   # Monitor storage growth
```

Monthly:
```bash
./tests/test-connectivity.sh   # Full connectivity test
docker inspect garage | jq '.RestartCount'  # Restart history
```

## Alert Rules

Critical alerts:
- `cluster_healthy == 0` - Cluster unhealthy
- `block_resync_errored_blocks > 0` - Data corruption risk
- Restart count increasing rapidly - Restart loop detected

Warning alerts:
- `cluster_connected_nodes < cluster_known_nodes` - Node disconnected
- `(usage_bytes / total_bytes) > 0.85` - Disk 85% full
- High error rate - S3 API errors increasing

See [METRICS_REFERENCE.md](./METRICS_REFERENCE.md) for Prometheus metrics.

## Common Issues

### "Garage keeps restarting"

Check logs:
```bash
docker compose logs garage | grep -i "error\|panic"
```

Common causes:
- **Insufficient start_period** - App needs more time, increase to 60s
- **Config file error** - Check config/garage.toml
- **Permission denied** - Check data/ directory permissions
- **Port in use** - Check lsof -i :3900 etc.

### "Health check failing"

Before initialization (normal):
```
garage    Up (health: unhealthy)
```

Fix: Run `./scripts/init-garage.sh`

After initialization:
```
garage    Up (health: healthy)
```

If unhealthy after init:
```bash
# Test health endpoint manually
docker compose exec garage curl http://localhost:3903/health
```

### "Can't reach services"

```bash
# Test rate limiter
curl http://localhost:3900/

# Test Garage internal
docker compose exec rate-limiter curl http://garage:3901/

# Check network
docker network inspect garage-monitoring
```

## Performance Monitoring

### Disk Usage

```bash
# Current usage
du -sh data/garage-meta
du -sh data/garage-data

# Monitor growth
du -sh data/garage-data && sleep 3600 && du -sh data/garage-data
```

### Memory Usage

```bash
# Real-time
docker stats

# One-time snapshot
docker stats --no-stream
```

### Request Rate

```bash
# Via Prometheus (if configured)
curl -H "Authorization: Bearer $METRICS_TOKEN" \
  http://localhost:3903/metrics | grep s3_request_counter
```

## Log Levels

Change logging verbosity (in .env):

```bash
RUST_LOG=info      # Normal (default)
RUST_LOG=debug     # Verbose
RUST_LOG=warn      # Warnings only
RUST_LOG=error     # Errors only
```

Then restart:
```bash
docker compose restart garage
```

## References

- [HEALTH_CHECKS.md](./HEALTH_CHECKS.md) - Detailed health check documentation
- [RESTART_TROUBLESHOOTING.md](./RESTART_TROUBLESHOOTING.md) - Restart loop debugging
- [PROMETHEUS.md](./PROMETHEUS.md) - Prometheus integration
- [METRICS_REFERENCE.md](./METRICS_REFERENCE.md) - Available metrics
