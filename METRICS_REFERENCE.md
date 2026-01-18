# Garage Prometheus Metrics - Quick Reference

Complete list of Prometheus metrics exposed by Garage for monitoring.

## Metric Access

**Endpoint:** `http://garage:3903/metrics`

**Authentication:** Bearer token (use `${METRICS_TOKEN}` from `.env`)

```bash
curl -H "Authorization: Bearer $METRICS_TOKEN" http://garage:3903/metrics
```

---

## System Metrics

### Build Information
```
garage_build_info{version="1.0.1"}
```

### Replication Configuration
```
garage_replication_factor
```

### Disk Space (by volume)

```promql
# Data storage volume
garage_data_dir_total_space_bytes     # Total capacity
garage_data_dir_used_space_bytes      # Currently used
garage_data_dir_available_space_bytes # Free space

# Metadata storage volume
garage_meta_dir_total_space_bytes
garage_meta_dir_used_space_bytes
garage_meta_dir_available_space_bytes
```

---

## Cluster Health Metrics

### Cluster Status
```promql
cluster_healthy         # 1 = healthy, 0 = unhealthy
cluster_available       # 1 = available, 0 = not available
cluster_known_nodes     # Total nodes in cluster
cluster_connected_nodes # Currently connected nodes
```

### Node Status
```promql
cluster_layout_node_connected{id="NODE_ID"}      # 1 = connected, 0 = disconnected
cluster_layout_node_connected_since_unix_timestamp{id="NODE_ID"}  # When connected
```

---

## S3 API Metrics

### Request Counts
```promql
# Total S3 API requests
s3_request_counter{method="GET", path="/..."}
s3_request_counter{method="PUT", path="/..."}
s3_request_counter{method="DELETE", path="/..."}

# By bucket
s3_request_counter{bucket="my-bucket"}
```

### Request Duration (Histogram)
```promql
# Latency percentiles
histogram_quantile(0.50, s3_request_duration_bucket)    # P50 (median)
histogram_quantile(0.95, s3_request_duration_bucket)    # P95
histogram_quantile(0.99, s3_request_duration_bucket)    # P99
histogram_quantile(1.0, s3_request_duration_bucket)     # Max

# Average latency
avg(rate(s3_request_duration_sum[5m])) / avg(rate(s3_request_duration_count[5m]))
```

### Error Tracking
```promql
# S3 API errors
s3_error_counter{method="GET"}
s3_error_counter{method="PUT"}
s3_error_counter{method="DELETE"}

# Error rate
rate(s3_error_counter[5m])
```

---

## K2V API Metrics

Similar to S3 API:

```promql
k2v_request_counter
k2v_request_duration_bucket
k2v_error_counter
```

---

## Admin API Metrics

### Request Counts
```promql
api_admin_request_counter{api_endpoint="Buckets"}
api_admin_request_counter{api_endpoint="Keys"}
api_admin_request_counter{api_endpoint="Layout"}
api_admin_request_counter{api_endpoint="Metrics"}
api_admin_request_counter{api_endpoint="Status"}
```

### Request Duration
```promql
api_admin_request_duration_bucket
api_admin_request_duration_sum
api_admin_request_duration_count
```

### Errors
```promql
api_admin_error_counter
```

---

## Storage/Block Manager Metrics

### Data Transfer
```promql
# Bytes written (uploads, replication, etc.)
block_manager_bytes_written

# Bytes read (downloads, replication, etc.)
block_manager_bytes_read

# Compression information
block_manager_compression_ratio
```

### Resync Operations
```promql
# Queue of blocks waiting for resync
block_resync_queue_length

# ⚠️ CRITICAL: Should always be 0
# Non-zero indicates data corruption risk
block_resync_errored_blocks

# Time spent on resync
block_resync_duration_seconds
```

### Block Operations
```promql
block_manager_blocks_deleted
block_manager_blocks_written
block_manager_blocks_read
```

---

## RPC (Internal Node Communication) Metrics

### Request Tracking
```promql
# RPC requests between nodes
rpc_request_counter{rpc="*"}

# RPC request duration
rpc_request_duration_bucket

# RPC errors
rpc_error_counter
```

### Connection Status
```promql
# RPC connection status with specific nodes
rpc_connection_established{to="NODE_ID"}

# RPC timeouts
rpc_request_timeout_counter
```

---

## Metadata Table Metrics

### Table Operations
```promql
# Garage's internal table operations
table_gc_todo_queue_length
table_sync_changes_sent_counter
table_sync_items_received_counter
table_sync_items_sent_counter
```

### Garbage Collection
```promql
table_gc_queue_length
table_gc_rows_deleted_counter
```

---

## Essential Monitoring: Top 5 Metrics

### 1. Data Corruption Alert (CRITICAL)
```promql
block_resync_errored_blocks > 0
# Should be ZERO - non-zero means data is corrupted
```

### 2. Cluster Health
```promql
cluster_healthy == 0
# 0 = unhealthy, should be 1
```

### 3. Node Connectivity
```promql
cluster_connected_nodes < cluster_known_nodes
# Some nodes are disconnected
```

### 4. Error Rate
```promql
rate(s3_error_counter[5m]) > 10
# High error rate from S3 API
```

### 5. Disk Usage
```promql
(garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) > 0.85
# Data storage more than 85% full
```

---

## Common PromQL Queries

### S3 Throughput
```promql
# Requests per second
rate(s3_request_counter[5m])

# Requests per second by method
rate(s3_request_counter[5m]) by (method)

# Requests per second by bucket
rate(s3_request_counter[5m]) by (bucket)
```

### S3 Performance
```promql
# 95th percentile latency in seconds
histogram_quantile(0.95, rate(s3_request_duration_bucket[5m]))

# Average latency
rate(s3_request_duration_sum[5m]) / rate(s3_request_duration_count[5m])

# Latency by method
histogram_quantile(0.95, rate(s3_request_duration_bucket[5m])) by (method)
```

### Data Transfer
```promql
# Write throughput (bytes per second)
rate(block_manager_bytes_written[5m])

# Read throughput (bytes per second)
rate(block_manager_bytes_read[5m])

# Total data transferred
rate(block_manager_bytes_written[5m]) + rate(block_manager_bytes_read[5m])
```

### Storage Capacity
```promql
# Used percentage
(garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) * 100

# Free space in GB
(garage_data_dir_available_space_bytes / 1024 / 1024 / 1024)

# Growth rate (bytes per day)
increase(garage_data_dir_used_space_bytes[24h])
```

### Cluster Status
```promql
# Percentage of nodes connected
(cluster_connected_nodes / cluster_known_nodes) * 100

# Nodes disconnected
cluster_known_nodes - cluster_connected_nodes
```

### Admin API Usage
```promql
# Admin API calls per minute by endpoint
rate(api_admin_request_counter[1m]) by (api_endpoint)

# Admin API error rate
rate(api_admin_error_counter[5m])
```

---

## Alert Rules Template

```yaml
groups:
  - name: garage-alerts
    rules:
      # CRITICAL ALERTS
      - alert: GarageDataCorruption
        expr: block_resync_errored_blocks > 0
        for: 5m
        severity: critical
        annotations:
          summary: "Garage: Data corruption detected (errored blocks)"
          value: "{{ $value }}"

      - alert: GarageClusterUnhealthy
        expr: cluster_healthy == 0
        for: 2m
        severity: critical

      # WARNING ALERTS
      - alert: GarageNodeDisconnected
        expr: cluster_known_nodes - cluster_connected_nodes > 0
        for: 5m
        severity: warning

      - alert: GarageHighErrorRate
        expr: rate(s3_error_counter[5m]) > 10
        for: 2m
        severity: warning

      - alert: GarageDiskFull
        expr: (garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) > 0.95
        for: 5m
        severity: warning

      - alert: GarageDiskUsageHigh
        expr: (garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) > 0.85
        for: 15m
        severity: warning
```

---

## Integration Examples

### Prometheus Recording Rules
```yaml
groups:
  - name: garage
    interval: 30s
    rules:
      - record: garage:s3:requests:5m
        expr: rate(s3_request_counter[5m])

      - record: garage:s3:errors:5m
        expr: rate(s3_error_counter[5m])

      - record: garage:storage:usage:percent
        expr: (garage_data_dir_used_space_bytes / garage_data_dir_total_space_bytes) * 100

      - record: garage:cluster:health
        expr: cluster_healthy
```

### Grafana Dashboard Variables
```
# Node selector
query: cluster_layout_node_connected

# Bucket selector
query: s3_request_counter

# Time range
default: last 6 hours
```

---

## References

- [Garage Monitoring Docs](https://garagehq.deuxfleurs.fr/documentation/reference-manual/monitoring/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)
