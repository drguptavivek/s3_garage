# Prometheus Integration

Setup Prometheus and Grafana to monitor Garage metrics.

## Quick Setup (Separate Stack)

```bash
# 1. Create shared Docker network (one-time)
docker network create garage-monitoring

# 2. Update Garage docker-compose.yml (add at end):
# networks:
#   default:
#     external: true
#     name: garage-monitoring

# 3. Restart Garage to join network
docker compose down && docker compose up -d

# 4. Create prometheus/docker-compose-prometheus.yml with services
# (See "Complete Setup" section below)

# 5. Start Prometheus
cd prometheus/
docker compose -f docker-compose-prometheus.yml up -d

# 6. Verify in browser
# Prometheus: http://localhost:9090/targets
```

## Complete Prometheus Stack

Create `prometheus/docker-compose-prometheus.yml`:

```yaml
version: '3.9'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - garage-monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
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

## Prometheus Configuration

Create `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'garage'
    metrics_path: '/metrics'
    bearer_token: 'YOUR_METRICS_TOKEN'
    static_configs:
      - targets: ['garage:3903']
        labels:
          service: 'garage-s3'
          env: 'production'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

Replace `YOUR_METRICS_TOKEN` with value from `.env`:

```bash
grep METRICS_TOKEN ../.env
```

## Testing Connection

### Check Prometheus Discovers Garage

```bash
# Open browser
http://localhost:9090

# Go to: Status → Targets
# Should show 'garage' job as UP
```

### Test Metrics Endpoint

```bash
docker exec prometheus curl -H "Authorization: Bearer TOKEN" \
  http://garage:3903/metrics | head -20
```

## Key Metrics to Monitor

### Critical (Alert if non-zero)
```
block_resync_errored_blocks  # Data corruption risk
```

### Cluster Health
```
cluster_healthy              # 1 = healthy, 0 = down
cluster_connected_nodes      # Should = cluster_known_nodes
```

### Performance
```
rate(s3_request_counter[5m])           # Requests/second
histogram_quantile(0.95, s3_request_duration_bucket)  # P95 latency
rate(s3_error_counter[5m])             # Error rate
```

### Storage
```
(garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) * 100  # % used
increase(garage_data_dir_used_space_bytes[24h])  # Growth in 24 hours
```

See [METRICS_REFERENCE.md](./METRICS_REFERENCE.md) for complete metric list.

## Grafana Setup

### Add Data Source

1. Open Grafana: http://localhost:3000
2. Login with admin/admin
3. Settings → Data Sources → Add new
4. Select Prometheus
5. URL: `http://prometheus:9090`
6. Save

### Example Dashboard Query

Add new panel with:

```promql
# Cluster Health
cluster_healthy

# S3 Requests/sec
rate(s3_request_counter[5m])

# 95th Percentile Latency
histogram_quantile(0.95, rate(s3_request_duration_bucket[5m]))

# Disk Usage %
(garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) * 100
```

## Alert Rules

Create `prometheus/alerts.yml`:

```yaml
groups:
  - name: garage
    rules:
      - alert: GarageDataCorruption
        expr: block_resync_errored_blocks > 0
        for: 5m
        annotations:
          summary: "Garage has {{ $value }} corrupted blocks"

      - alert: GarageClusterDown
        expr: cluster_healthy == 0
        for: 2m
        annotations:
          summary: "Garage cluster is unhealthy"

      - alert: GarageDiskFull
        expr: (garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) > 0.95
        for: 5m
        annotations:
          summary: "Garage disk > 95% full"
```

Add to `prometheus.yml`:

```yaml
rule_files:
  - './alerts.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
```

## Troubleshooting

### Prometheus Can't Scrape Garage

```bash
# Check both containers on same network
docker network inspect garage-monitoring

# Test connectivity from Prometheus
docker exec prometheus curl -I http://garage:3903/metrics

# Verify token is correct
grep METRICS_TOKEN ../. env
```

### No Metrics Showing

Garage needs time to collect metrics. After 30-60 seconds, metrics appear.

### Bearer Token Errors

```bash
# Get correct token
grep METRICS_TOKEN ../.env

# Update prometheus.yml with exact token
# Restart Prometheus
docker compose -f docker-compose-prometheus.yml restart prometheus
```

## Network Options

### Same Host (Recommended)
- Prometheus and Garage on same Docker network
- Prometheus scrapes via service name: `garage:3903`
- Most secure and performant

### Different Hosts
- Bind Garage metrics to internal IP:
  ```yaml
  ports:
    - "192.168.1.100:3903:3903"
  ```
- Prometheus scrapes: `http://192.168.1.100:3903/metrics`

### Behind Reverse Proxy
- Expose metrics at `https://metrics.example.com`
- Route through TLS terminator
- More complex but very secure

## Starting & Stopping

```bash
# Start Prometheus + Grafana
cd prometheus/
docker compose -f docker-compose-prometheus.yml up -d

# Stop
docker compose -f docker-compose-prometheus.yml down

# View logs
docker compose -f docker-compose-prometheus.yml logs -f prometheus
```

## References

- [METRICS_REFERENCE.md](./METRICS_REFERENCE.md) - All metrics
- [MONITORING.md](./MONITORING.md) - Health checks
- [Prometheus Docs](https://prometheus.io/docs/)
