# Prometheus on Separate Docker Compose Stack

Setup for running Prometheus in a separate docker-compose stack on the same host, monitoring Garage metrics internally.

## Quick Setup

### Step 1: Create Shared Docker Network

```bash
# One-time setup on your host
docker network create garage-monitoring
```

This creates a bridge network that both docker-compose stacks can join.

### Step 2: Update Garage docker-compose.yml

Add network configuration to the end of your existing `docker-compose.yml`:

```yaml
# At the very end of docker-compose.yml, add:

networks:
  default:
    external: true
    name: garage-monitoring
```

Full example:

```yaml
services:
  garage:
    image: dxflrs/garage:v1.0.1
    # ... rest of config ...

  rate-limiter:
    image: nginx:alpine
    # ... rest of config ...

# ADD THIS:
networks:
  default:
    external: true
    name: garage-monitoring
```

### Step 3: Restart Garage to Join Network

```bash
docker compose down
docker compose up -d
```

Verify it's on the network:

```bash
docker network inspect garage-monitoring
# Should show garage and garage-rate-limiter containers
```

### Step 4: Create Prometheus Stack

Create `docker-compose-prometheus.yml` in a separate directory (e.g., `./monitoring/`):

```yaml
version: '3.9'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped

    # Only accessible from localhost or internal network
    ports:
      - "127.0.0.1:9090:9090"

    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'

    # Join the garage-monitoring network
    networks:
      - garage-monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped

    # Only accessible from localhost or internal network
    ports:
      - "127.0.0.1:3000:3000"

    volumes:
      - grafana-data:/var/lib/grafana

    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SECURITY_ADMIN_USER=admin

    networks:
      - garage-monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  garage-monitoring:
    external: true
```

### Step 5: Create Prometheus Config

Create `monitoring/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'garage'
    metrics_path: '/metrics'

    # Use the bearer token from Garage .env
    bearer_token: 'YOUR_METRICS_TOKEN_HERE'

    static_configs:
      # Prometheus can reach Garage via service name on shared network
      - targets: ['garage:3903']
        labels:
          service: 'garage-s3'
          env: 'production'
```

**Get your METRICS_TOKEN:**

```bash
# From your Garage directory
grep METRICS_TOKEN .env
```

Replace `YOUR_METRICS_TOKEN_HERE` with the actual token value.

### Step 6: Start Prometheus Stack

```bash
cd monitoring/
docker compose -f docker-compose-prometheus.yml up -d
```

### Step 7: Verify Connection

Check Prometheus targets:

```bash
# Open in browser
http://localhost:9090

# Go to: Status → Targets
# Should show 'garage' job as UP
```

Or test from command line:

```bash
docker exec prometheus curl -H "Authorization: Bearer YOUR_METRICS_TOKEN" \
  http://garage:3903/metrics | head -20
```

---

## Directory Structure

```
your-host/
├── garage-stack/
│   ├── docker-compose.yml         # Garage + Rate Limiter
│   ├── .env                       # Contains METRICS_TOKEN
│   ├── config/
│   │   ├── garage.toml
│   │   └── nginx-ratelimit.conf
│   ├── data/
│   │   ├── garage-meta/
│   │   └── garage-data/
│   └── scripts/
│
└── monitoring-stack/
    ├── docker-compose-prometheus.yml
    ├── prometheus.yml              # Scrape config
    ├── prometheus-data/            # Volume
    └── grafana-data/               # Volume
```

---

## Network Communication Flow

```
Prometheus Container (monitoring-stack)
    ↓ (internal Docker network)
Garage Container (garage-stack)
    ↓ Port 3903
Admin API Metrics Endpoint
    ↓ Requires bearer_token
Returns Prometheus-formatted metrics
```

**Key Point:** Both containers must be on the `garage-monitoring` network to communicate via service name (`garage:3903`).

---

## Common Configurations

### Option A: Prometheus on Same Host, Different Directories

```
/opt/garage/docker-compose.yml
/opt/monitoring/docker-compose-prometheus.yml
```

Commands:

```bash
# Start Garage
cd /opt/garage && docker compose up -d

# Start Monitoring
cd /opt/monitoring && docker compose -f docker-compose-prometheus.yml up -d

# View both stacks
docker network inspect garage-monitoring
```

### Option B: Prometheus on Different Host (Future)

If you later move Prometheus to a different host, change the scrape target:

```yaml
# In prometheus.yml, instead of:
# - targets: ['garage:3903']

# Use hostname or IP:
- targets: ['192.168.1.100:3903']

# Or bind Garage to internal interface (not recommended):
# In docker-compose.yml:
# ports:
#   - "192.168.1.100:3903:3903"
```

---

## Accessing Services

### From Your Host

```bash
# Prometheus
http://localhost:9090

# Grafana
http://localhost:3000
```

### From Other Hosts on Internal Network

```bash
# Prometheus
http://your-host-ip:9090

# Grafana
http://your-host-ip:3000

# Garage (via rate limiter)
http://your-host-ip:3900
```

---

## Troubleshooting

### Prometheus Can't Scrape Garage

**Problem:** Prometheus shows 'garage' job as DOWN

**Solutions:**

```bash
# 1. Verify both containers are on same network
docker network inspect garage-monitoring

# 2. Check Prometheus can reach Garage
docker exec prometheus curl -I http://garage:3903/metrics

# 3. Check bearer token is correct
# Edit prometheus.yml, verify token matches:
grep METRICS_TOKEN /path/to/garage/.env

# 4. Check Prometheus logs
docker logs prometheus | grep garage

# 5. Restart Prometheus
docker compose -f docker-compose-prometheus.yml restart prometheus
```

### "Unknown Host" Error

**Problem:** `curl: (6) Could not resolve host name`

**Solution:** Container not on shared network

```bash
# Verify garage is on network
docker network inspect garage-monitoring | grep garage

# If not, update docker-compose.yml and restart:
docker compose down
docker compose up -d
```

### Metrics Not Showing in Prometheus

**Prometheus is UP but no metrics:**

```bash
# 1. Garage needs time to collect metrics
# Wait 30-60 seconds after startup

# 2. Verify metrics endpoint works
docker exec prometheus curl -H "Authorization: Bearer TOKEN" \
  http://garage:3903/metrics | wc -l
# Should return > 100 lines

# 3. Check Prometheus scrape log
# Navigate to: http://localhost:9090/graph
# Query: up{job="garage"}
# Should return: 1
```

### Bearer Token Errors

**Problem:** `401 Unauthorized`

**Solution:**

```bash
# Verify token is set
grep METRICS_TOKEN /path/to/garage/.env

# Update prometheus.yml with correct token
# Test token directly:
curl -H "Authorization: Bearer ACTUAL_TOKEN" \
  http://localhost:3903/metrics
```

---

## Security Checklist

✅ **Current Setup:**
- Prometheus only accessible on `127.0.0.1:9090` (localhost only)
- Grafana only accessible on `127.0.0.1:3000` (localhost only)
- Garage admin API (3903) not exposed to host
- Metrics require bearer token authentication
- Internal Docker network only

✅ **To enable monitoring from other hosts:**
```yaml
# In prometheus service:
ports:
  - "127.0.0.1:9090:9090"    # Current: localhost only
  # - "0.0.0.0:9090:9090"    # To allow all hosts (less secure)
  # - "192.168.1.100:9090:9090"  # Internal network only (recommended)
```

---

## Monitoring Both Stacks

If you want to monitor Prometheus itself:

```yaml
# In prometheus.yml, add:
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'garage'
    bearer_token: 'YOUR_METRICS_TOKEN'
    static_configs:
      - targets: ['garage:3903']
```

---

## Quick Commands Reference

```bash
# View network
docker network inspect garage-monitoring

# Check both stacks are running
docker ps | grep -E "garage|prometheus|grafana"

# View Garage logs
cd /path/to/garage && docker compose logs -f garage

# View Prometheus logs
cd /path/to/monitoring && docker compose -f docker-compose-prometheus.yml logs -f prometheus

# Restart just Prometheus
cd /path/to/monitoring && docker compose -f docker-compose-prometheus.yml restart prometheus

# Stop both stacks
cd /path/to/garage && docker compose down
cd /path/to/monitoring && docker compose -f docker-compose-prometheus.yml down

# Full cleanup (REMOVES DATA!)
docker network rm garage-monitoring
docker volume prune -f
```

---

## Next Steps

1. ✅ Create shared network
2. ✅ Update Garage docker-compose.yml
3. ✅ Create Prometheus docker-compose.yml
4. ✅ Create prometheus.yml config
5. Set up Grafana data source
6. Import dashboards
7. Configure alerts

For dashboards and alerts, see:
- `METRICS_REFERENCE.md` - All available metrics
- `PROMETHEUS_SETUP.md` - Full monitoring guide
