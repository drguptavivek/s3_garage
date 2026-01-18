# Troubleshooting Guide

Solutions for common Garage issues.

## Quick Diagnostics

```bash
# Overall health
docker compose ps

# Detailed status
docker compose exec garage /garage status

# Health check
./tests/test-health.sh

# Connectivity test
./tests/test-connectivity.sh

# Recent errors
docker compose logs garage | grep -i error | tail -20
```

## Common Issues & Solutions

### Garage Won't Start

**Symptoms:** Container shows `Exited` or `Restarting`

**Diagnosis:**
```bash
docker compose logs garage | head -50
```

**Solutions:**

1. **Port already in use:**
   ```bash
   lsof -i :3900
   lsof -i :3901
   lsof -i :3903
   # Kill conflicting process or change port
   ```

2. **Config file error:**
   ```bash
   docker compose config  # Validates compose file
   # Check config/garage.toml syntax
   ```

3. **Permission denied on data directory:**
   ```bash
   chmod 755 data/garage-meta data/garage-data
   ```

4. **Out of disk space:**
   ```bash
   df -h data/
   # Free up space or extend partition
   ```

### Health Check Failing

**Symptoms:** `docker compose ps` shows `(health: unhealthy)`

**Normal before initialization:**
```bash
# Expected before running init-garage.sh
./scripts/init-garage.sh
```

**After initialization:**
```bash
# Test health endpoint manually
docker compose exec garage curl -v http://localhost:3903/health

# If fails, check logs
docker compose logs garage | tail -50
```

### Services Keep Restarting

**Symptoms:** `docker compose ps` shows `Restarting (X)`

**Check restart count:**
```bash
docker inspect garage | jq '.RestartCount'
# If increasing rapidly, it's a restart loop
```

**Solution:**
```bash
# 1. Pause to stop the loop
docker compose pause garage

# 2. Check logs for root cause
docker compose logs garage | grep -i error

# 3. Fix the issue (config, permissions, etc.)

# 4. Resume and test
docker compose unpause garage
docker compose ps garage
```

See [RESTART_TROUBLESHOOTING.md](./RESTART_TROUBLESHOOTING.md) for detailed debugging.

### Can't Reach S3 API

**Symptoms:** Connection refused or timeout on port 3900

**Tests:**
```bash
# Test rate limiter
curl http://localhost:3900/

# Test from another container
docker compose exec garage curl http://garage-rate-limiter:3900/

# Check if port is open
netstat -tlnp | grep 3900
```

**Solutions:**

1. **Rate limiter not running:**
   ```bash
   docker compose ps rate-limiter
   docker compose restart rate-limiter
   ```

2. **Firewall blocking:**
   ```bash
   sudo ufw allow 3900
   ```

3. **Service not binding to correct port:**
   ```bash
   docker logs garage-rate-limiter | head -20
   ```

### Access Denied Errors

**Symptoms:** S3 operations fail with "Access Denied"

**Diagnosis:**
```bash
# Verify key has permission
docker compose exec garage /garage key info my-service

# Check bucket permissions
docker compose exec garage /garage bucket info my-bucket
```

**Solutions:**

1. **Key doesn't have read permission:**
   ```bash
   docker compose exec garage /garage bucket allow --read my-bucket --key my-service
   ```

2. **Wrong bucket name:**
   ```bash
   # Verify service is accessing correct bucket
   docker compose exec garage /garage bucket list
   ```

3. **Key doesn't exist:**
   ```bash
   docker compose exec garage /garage key list
   # Create if missing
   docker compose exec garage /garage key create my-service
   ```

### Bucket Not Found

**Symptoms:** S3 operations fail with "NoSuchBucket"

**Solutions:**
```bash
# List all buckets
docker compose exec garage /garage bucket list

# Create if missing
docker compose exec garage /garage bucket create my-bucket

# Verify permissions for key
docker compose exec garage /garage bucket allow --read --write my-bucket --key my-service
```

### High Memory Usage

**Symptoms:** Garage using >1GB RAM

**Check usage:**
```bash
docker stats garage

# Or one-time:
docker inspect garage | jq '.State.OOMKilled'
```

**Solutions:**

1. **Too much data in cache:**
   - Monitor with `docker stats`
   - Adjust configuration if needed

2. **Memory limit exceeded:**
   ```bash
   # Add memory limit in docker-compose.yml
   deploy:
     resources:
       limits:
         memory: 2G
   ```

### Disk Usage Growing Rapidly

**Symptoms:** `du -sh data/garage-data` shows rapid growth

**Investigate:**
```bash
# See what's using space
du -sh data/garage-data/*

# Monitor growth over time
du -sh data/garage-data && sleep 3600 && du -sh data/garage-data
```

**Solutions:**

1. **Normal replication/rebalancing**
   - Wait for cluster to stabilize
   - Monitor with `docker compose exec garage /garage status`

2. **Large uploads**
   - Check bucket sizes
   - Delete unused data

3. **Corrupted data**
   - Check for `block_resync_errored_blocks > 0`
   - See [RESTART_TROUBLESHOOTING.md](./RESTART_TROUBLESHOOTING.md)

### Rate Limiter Not Working

**Symptoms:** No rate limiting occurring, all requests pass

**Test rate limiter:**
```bash
./tests/test-rate-limiter.sh
```

**Check configuration:**
```bash
# Verify settings in .env
grep RATE_LIMIT .env

# Check nginx config
docker exec garage-rate-limiter cat /etc/nginx/nginx.conf | grep limit
```

**Solutions:**

1. **Rate limiting disabled:**
   ```bash
   ENABLE_RATE_LIMITER=true
   docker compose restart rate-limiter
   ```

2. **Config not updated:**
   ```bash
   # Rebuild config
   docker compose down
   docker compose up -d
   ```

3. **Test with enough requests:**
   ```bash
   # Default: 100 RPS, 200 burst
   # Need to exceed these limits to see 429 responses
   ```

### Prometheus Can't Scrape Metrics

**Symptoms:** Prometheus shows 'garage' job as DOWN

**Test endpoint:**
```bash
curl -H "Authorization: Bearer $METRICS_TOKEN" \
  http://localhost:3903/metrics | head -20
```

**Solutions:**

1. **Network not shared:**
   ```bash
   docker network inspect garage-monitoring
   # Both containers should appear
   ```

2. **Bearer token wrong:**
   ```bash
   grep METRICS_TOKEN ../.env
   # Update prometheus.yml with correct token
   ```

3. **Port not accessible:**
   ```bash
   docker exec prometheus curl -I http://garage:3903/metrics
   ```

See [PROMETHEUS.md](./PROMETHEUS.md) for setup help.

### Docker Compose Permission Errors

**Error:** `permission denied while trying to connect to Docker daemon`

**Solution:**
```bash
# Add user to docker group (once)
sudo usermod -aG docker $USER
newgrp docker

# Or use sudo for commands
sudo docker compose ps
```

### Cluster Layout Issues

**Symptoms:** Garage shows "NO ROLE ASSIGNED"

**Solution:**
```bash
# Initialize cluster
./scripts/init-garage.sh

# Or manually:
NODE_ID=$(docker compose exec garage /garage status | grep "^ID" | awk '{print $1}')
docker compose exec garage /garage layout assign -z dc1 -c 100000000000 $NODE_ID
docker compose exec garage /garage layout apply --version 1
```

## Debugging Commands

```bash
# Service status
docker compose ps

# Cluster status
docker compose exec garage /garage status

# Key info
docker compose exec garage /garage key info MY_KEY

# Bucket info
docker compose exec garage /garage bucket info MY_BUCKET

# View logs (last 50 lines)
docker compose logs garage | tail -50

# Follow logs (real-time)
docker compose logs -f garage

# Search logs
docker compose logs garage | grep "ERROR\|WARN"

# Restart count
docker inspect garage | jq '.RestartCount'

# Memory usage
docker stats --no-stream garage

# Network info
docker network inspect garage-monitoring
```

## Escalation Path

1. **Check this guide** - Most common issues covered
2. **Run diagnostics** - `./tests/test-health.sh`
3. **Review logs** - `docker compose logs garage`
4. **Consult other docs:**
   - [MONITORING.md](./MONITORING.md) - Health/restart issues
   - [OPERATIONS.md](./OPERATIONS.md) - Command reference
   - [SECURITY.md](./SECURITY.md) - Access issues
5. **Reset (development only):**
   ```bash
   docker compose down
   rm -rf data/
   docker compose up -d
   ./scripts/init-garage.sh
   ```

## Getting Help

Before asking for help, gather:

```bash
# System info
docker compose ps

# Full error output
docker compose logs garage > garage.log 2>&1

# Configuration (no secrets)
cat docker-compose.yml

# Health check output
./tests/test-health.sh > health-check.log 2>&1

# Restart history
docker inspect garage | jq '.RestartCount, .State'
```

Share these logs (without credentials) for diagnosis.

## See Also

- [MONITORING.md](./MONITORING.md) - Health checks
- [RESTART_TROUBLESHOOTING.md](./RESTART_TROUBLESHOOTING.md) - Restart loops
- [OPERATIONS.md](./OPERATIONS.md) - Command reference
- [SECURITY.md](./SECURITY.md) - Permission issues
