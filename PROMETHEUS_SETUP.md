# Prometheus Integration Guide

Complete guide to integrating your centralized Prometheus with Garage metrics.

## Architecture

```
Your Central Prometheus
    ↓
Scrapes (via Docker network or host network)
    ↓
Garage Admin API: http://garage:3903/metrics
(Internal - not exposed to internet)
    ↓
Bearer Token: ${METRICS_TOKEN}
```

## Network Setup

### Same Host, Same Docker Network (Simplest)

If Prometheus is in the same Docker Compose stack or connected to same network:

```bash
# Both services on same network (default)
Prometheus scrapes: http://garage:3903/metrics
```

### Same Host, Different Docker Compose Stacks

Create a shared Docker network:

```bash
# Create bridge network
docker network create garage-monitoring

# Connect Garage stack to it
# In docker-compose.yml, add:
networks:
  default:
    external: true
    name: garage-monitoring

# Connect Prometheus stack to it
# Same networks config in prometheus docker-compose.yml
```

Then Prometheus scrapes: `http://garage:3903/metrics`

### Different Hosts

Option A: Private VPN/Overlay network
```bash
# Use Docker Swarm overlay or similar
Prometheus scrapes: http://garage:3903/metrics
```

Option B: Bind to internal NIC (not default docker0)
```bash
# Edit docker-compose.yml ports to bind to internal IP:
ports:
  - "192.168.1.100:3903:3903"  # Only accessible on internal network

# Prometheus scrapes: http://192.168.1.100:3903/metrics
```

---

## Prometheus Configuration

### 1. Get Your METRICS_TOKEN

Your token is already set in `.env`:

```bash
# Check your token
grep METRICS_TOKEN .env
```

### 2. Configure Prometheus Scrape Job

Add to your central Prometheus `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Garage metrics
  - job_name: 'garage'
    metrics_path: '/metrics'
    scheme: 'http'

    # Bearer token for authentication
    bearer_token: 'YOUR_METRICS_TOKEN_HERE'

    static_configs:
      # If Prometheus is on same Docker network:
      - targets: ['garage:3903']
        labels:
          service: 'garage'
          cluster: 'production'

      # If different host, use hostname or IP:
      # - targets: ['192.168.1.100:3903']

      # If different host with DNS:
      # - targets: ['garage-host.internal:3903']
```

### 3. Example: Full Prometheus Docker Service

If you want Prometheus in same docker-compose stack:

**docker-compose-monitoring.yml:**

```yaml
version: '3.9'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped

    # Expose only on internal/localhost
    ports:
      - "127.0.0.1:9090:9090"  # Only accessible from same host
      # - "192.168.1.100:9090:9090"  # If accessible from internal network

    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'

    environment:
      - METRICS_TOKEN=${METRICS_TOKEN}

    depends_on:
      - garage

    # Use same network as Garage
    networks:
      - garage-net

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped

    # Expose only on internal/localhost
    ports:
      - "127.0.0.1:3000:3000"  # Only accessible from same host

    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro
      - ./monitoring/grafana-dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml:ro

    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
      - GF_SECURITY_ADMIN_USER=${GRAFANA_USER:-admin}

    depends_on:
      - prometheus

    networks:
      - garage-net

volumes:
  prometheus-data:
  grafana-data:

networks:
  garage-net:
    name: garage-net
    external: true
```

To use this:

```bash
# Create the network
docker network create garage-net

# Update docker-compose.yml to join network:
# Add to end of docker-compose.yml:
# networks:
#   default:
#     external: true
#     name: garage-net

# Start monitoring stack
docker compose -f docker-compose-monitoring.yml up -d
```

---

## Prometheus Configuration File

Create `monitoring/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    environment: 'prod'

# Alerting configuration (optional)
alerting:
  alertmanagers:
    - static_configs:
        - targets: []

# Load rules files (optional)
rule_files:
  - './alerts/*.yml'

scrape_configs:
  # Garage S3 Storage
  - job_name: 'garage'
    metrics_path: '/metrics'
    scheme: 'http'

    bearer_token: '${METRICS_TOKEN}'

    # Increase timeouts for storage systems
    scrape_interval: 30s
    scrape_timeout: 10s

    static_configs:
      - targets: ['garage:3903']
        labels:
          service: 'garage-s3'
          datacenter: 'dc1'

  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter (if available)
  # - job_name: 'node'
  #   static_configs:
  #     - targets: ['node-exporter:9100']
```

---

## Grafana Data Source Setup

Create `monitoring/grafana-datasources.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

---

## Testing the Connection

### 1. Verify Garage Metrics Endpoint

From same Docker network:

```bash
docker run --rm \
  --network garage-net \
  curlimages/curl:latest \
  curl -H "Authorization: Bearer YOUR_METRICS_TOKEN" \
  http://garage:3903/metrics
```

Should return Prometheus formatted metrics (takes a moment for first metrics to appear).

### 2. Verify from Host

If you exposed 3903 to internal network:

```bash
curl -H "Authorization: Bearer YOUR_METRICS_TOKEN" \
  http://192.168.1.100:3903/metrics | head -20
```

### 3. Check Prometheus Scrape Status

```bash
# Access Prometheus
http://localhost:9090

# Go to Status → Targets
# Should show 'garage' job as UP
```

---

## Key Metrics to Monitor

### Critical Metrics (Alert if not 0)

```promql
# Should ALWAYS be 0 - indicates data corruption risk
block_resync_errored_blocks

# Should be close to 0 - indicates replication issues
cluster_known_nodes - cluster_connected_nodes
```

### Important Metrics (Dashboard)

```promql
# S3 API Performance
rate(s3_request_counter[5m])           # Requests per second
histogram_quantile(0.95, s3_request_duration)  # P95 latency

# Cluster Health
cluster_healthy                         # 1 = healthy, 0 = unhealthy
cluster_connected_nodes / cluster_known_nodes  # % connected

# Storage Usage
garage_data_dir_total_space_bytes       # Total capacity
garage_data_dir_used_space_bytes        # Current usage

# Data Operations
rate(block_manager_bytes_written[5m])   # Write throughput
rate(block_manager_bytes_read[5m])      # Read throughput

# Admin API Usage
rate(api_admin_request_counter[5m])     # Admin API calls
api_admin_error_counter                 # Admin API errors
```

---

## Example Grafana Dashboard Queries

### Cluster Health Dashboard

```promql
# Health Status (Single Value)
cluster_healthy

# Connected Nodes (Gauge)
cluster_connected_nodes

# S3 Request Rate (Graph)
rate(s3_request_counter[5m])

# S3 Error Rate (Graph)
rate(s3_error_counter[5m])

# P95 Latency (Graph)
histogram_quantile(0.95, rate(s3_request_duration_bucket[5m]))

# Data Dir Usage (Gauge)
(garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) * 100
```

### Storage Dashboard

```promql
# Write Throughput (Graph)
rate(block_manager_bytes_written[5m])

# Read Throughput (Graph)
rate(block_manager_bytes_read[5m])

# Resync Progress (Gauge)
block_resync_queue_length

# Errored Blocks Alert (Single Value - critical if > 0)
block_resync_errored_blocks
```

### Admin API Dashboard

```promql
# Admin Requests per Endpoint (Graph)
rate(api_admin_request_counter[5m])

# Admin API Errors (Graph)
rate(api_admin_error_counter[5m])

# Admin P95 Latency (Graph)
histogram_quantile(0.95, rate(api_admin_request_duration_bucket[5m]))
```

---

## Alert Rules Example

Create `monitoring/alerts/garage.yml`:

```yaml
groups:
  - name: garage
    interval: 30s
    rules:
      # CRITICAL: Data corruption risk
      - alert: GarageDataCorruption
        expr: block_resync_errored_blocks > 0
        for: 5m
        annotations:
          summary: "Garage has errored blocks (data corruption risk)"
          description: "{{ $value }} blocks failed to resync"

      # WARNING: Cluster unhealthy
      - alert: GarageClusterUnhealthy
        expr: cluster_healthy == 0
        for: 2m
        annotations:
          summary: "Garage cluster is unhealthy"

      # WARNING: Node disconnected
      - alert: GarageNodeDisconnected
        expr: (cluster_known_nodes - cluster_connected_nodes) > 0
        for: 5m
        annotations:
          summary: "Garage node(s) disconnected"
          description: "{{ $value }} node(s) not connected"

      # WARNING: High error rate
      - alert: GarageHighErrorRate
        expr: rate(s3_error_counter[5m]) > 10
        for: 2m
        annotations:
          summary: "Garage S3 API high error rate"
          description: "{{ $value }} errors per second"

      # WARNING: Disk usage high
      - alert: GarageDiskUsageHigh
        expr: (garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) > 0.85
        for: 5m
        annotations:
          summary: "Garage disk usage above 85%"
          description: "Current usage: {{ $value | humanizePercentage }}"
```

---

## Security Considerations

### Bearer Token

- `metrics_token` is sent as HTTP Bearer token header
- Should ONLY be accessible on internal networks
- Rotate periodically with `generate-secrets.sh`

### Network Isolation

Current setup:
- ✅ Port 3903 (admin API) NOT exposed to host or internet
- ✅ Only accessible from Docker network or internal services
- ✅ Metrics require valid bearer token
- ✅ Upstream Nginx handles TLS for public traffic

---

## Monitoring Setup Checklist

- [ ] Create shared Docker network (if needed)
- [ ] Update docker-compose.yml with network config
- [ ] Copy `monitoring/prometheus.yml` configuration
- [ ] Set `METRICS_TOKEN` in your Prometheus config
- [ ] Start Prometheus container
- [ ] Verify Prometheus scrapes Garage (Status → Targets)
- [ ] Set up Grafana data source pointing to Prometheus
- [ ] Import or create Grafana dashboards
- [ ] Create alert rules (optional)
- [ ] Test alerts (optional)

---

## Troubleshooting

### Prometheus Can't Scrape Garage

```bash
# Check if Garage is responding
docker exec prometheus curl -H "Authorization: Bearer TOKEN" \
  http://garage:3903/metrics

# Check Prometheus logs
docker logs prometheus | grep garage

# Check if network is shared
docker network inspect garage-net
```

### Metrics Not Appearing

Garage needs to be running for a bit to collect metrics:
```bash
# Metrics appear after initial requests
# Allow ~30 seconds after startup
```

### Bearer Token Issues

```bash
# Verify token is correct
grep METRICS_TOKEN .env

# Test with curl
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3903/metrics | head -5
```

---

## References

- [Garage Monitoring Documentation](https://garagehq.deuxfleurs.fr/documentation/cookbook/monitoring/)
- [Prometheus Scrape Config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config)
- [Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
