# Documentation Index

Complete guide to Garage S3 setup, operation, and monitoring.

## Quick Navigation

### Getting Started
- **[Installation](./INSTALLATION.md)** - Setup Garage and rate limiter
- **[Quick Start](./INSTALLATION.md#quick-start)** - Get running in 5 minutes

### Daily Operations
- **[Operations Guide](./OPERATIONS.md)** - Manage buckets, keys, and services
- **[Bucket Access Control](./BUCKET_ACCESS.md)** - Multiple tiers of access per bucket

### Monitoring & Troubleshooting
- **[Monitoring Guide](./MONITORING.md)** - Health checks, metrics, alerting
- **[Troubleshooting](./TROUBLESHOOTING.md)** - Common issues and solutions
- **[Prometheus Setup](./PROMETHEUS.md)** - Integrate with external Prometheus

### Reference
- **[Security](./SECURITY.md)** - Security best practices
- **[Signed URLs](./SIGNED_URLS.md)** - Secure access with Presigned URLs
- **[Metrics Reference](./METRICS_REFERENCE.md)** - All available Prometheus metrics
- **[Architecture](../CLAUDE.md)** - System design and components

---

## Documentation Structure

```
docs/
├── INDEX.md                    ← You are here
├── INSTALLATION.md             ← Setup & initialization
├── OPERATIONS.md               ← Daily operations & CLI
├── BUCKET_ACCESS.md            ← Access control for buckets
├── MONITORING.md               ← Health checks & monitoring
├── PROMETHEUS.md               ← Prometheus integration
├── TROUBLESHOOTING.md          ← Problem solving
├── SECURITY.md                 ← Security hardening
├── METRICS_REFERENCE.md        ← Prometheus metrics catalog
└── tests/
    ├── README.md               ← Test suite documentation
    ├── test-connectivity.sh
    ├── test-health.sh
    └── test-rate-limiter.sh
```

---

## Use Case Quick Links

### "I'm setting up Garage for the first time"
→ **[Installation](./INSTALLATION.md)**

### "I need to create buckets and manage access"
→ **[Operations Guide](./OPERATIONS.md)** + **[Bucket Access Control](./BUCKET_ACCESS.md)**

### "I want to monitor Garage with Prometheus"
→ **[Prometheus Setup](./PROMETHEUS.md)**

### "Services can't access buckets"
→ **[Troubleshooting](./TROUBLESHOOTING.md)** + **[Bucket Access Control](./BUCKET_ACCESS.md)**

### "Garage keeps restarting"
→ **[Troubleshooting](./TROUBLESHOOTING.md#restart-loops)**

### "I need to harden security"
→ **[Security](./SECURITY.md)**

### "I need to list all Prometheus metrics"
→ **[Metrics Reference](./METRICS_REFERENCE.md)**

---

## Key Concepts

### Rate Limiting
Built-in Nginx-based rate limiting protects Garage from overload:
- **Per-IP limiting:** 100 requests/second per IP (configurable)
- **Burst capacity:** 200 requests allowed in bursts
- **Lightweight:** ~5MB overhead
- **Stateless:** No persistent state, scales horizontally

### Health Checks
Automatic monitoring prevents issues:
- **Garage:** Health check every 30 seconds
- **Rate Limiter:** Health check every 10 seconds
- **Auto-restart:** On failure (with safeguards against loops)
- **Status:** View with `docker compose ps`

### Access Control
Granular permissions per service:
- **Buckets:** Isolated storage containers
- **Keys:** Service-specific credentials
- **Permissions:** Read-only, read+write
- **Multiple tiers:** Services + external clients

### Monitoring
Complete observability:
- **Metrics:** Prometheus-compatible endpoint at port 3903
- **Health:** Automatic monitoring + custom dashboards
- **Alerts:** Pre-configured alert rules
- **Internal only:** Metrics not exposed to internet

---

## File Structure

```
s3_garage/
├── docker-compose.yml          # Service orchestration
├── .env.example                # Configuration template
├── .gitignore                  # Version control excludes
├── README.md                   # Overview & quick start
├── CLAUDE.md                   # Developer reference
│
├── config/
│   ├── garage.toml             # Garage configuration
│   └── nginx-ratelimit.conf    # Rate limiter rules
│
├── scripts/
│   ├── generate-secrets.sh     # Generate tokens
│   ├── init-garage.sh          # Initialize cluster
│   ├── monitor-restarts.sh     # Restart loop detector
│   └── garage-entrypoint.sh    # Custom entrypoint (if needed)
│
├── data/
│   ├── garage-meta/            # Metadata storage (SSD)
│   └── garage-data/            # Object storage (HDD/SSD)
│
├── tests/
│   ├── test-connectivity.sh
│   ├── test-health.sh
│   ├── test-rate-limiter.sh
│   └── README.md
│
└── docs/                       # This documentation
    ├── INDEX.md                ← You are here
    ├── INSTALLATION.md
    ├── OPERATIONS.md
    ├── BUCKET_ACCESS.md
    ├── MONITORING.md
    ├── PROMETHEUS.md
    ├── TROUBLESHOOTING.md
    ├── SECURITY.md
    └── METRICS_REFERENCE.md
```

---

## Common Commands

### View Status
```bash
# Services status
docker compose ps

# Garage cluster status
docker compose exec garage /garage status

# Health check status
./tests/test-health.sh

# Monitor restarts
./scripts/monitor-restarts.sh
```

### Manage Buckets
```bash
# Create bucket
docker compose exec garage /garage bucket create my-bucket

# List buckets
docker compose exec garage /garage bucket list

# Delete bucket
docker compose exec garage /garage bucket delete --yes my-bucket
```

### Manage Keys
```bash
# Create key
docker compose exec garage /garage key create my-service

# List keys
docker compose exec garage /garage key list

# Grant permissions
docker compose exec garage /garage bucket allow --read --write my-bucket --key my-service

# Delete key
docker compose exec garage /garage key delete --yes my-service
```

### Monitor
```bash
# Watch for restart loops
./scripts/monitor-restarts.sh

# Health check tests
./tests/test-health.sh

# View logs
docker compose logs -f garage
docker compose logs -f rate-limiter
```

---

## Performance Baselines

**Expected resource usage:**
- Garage: 200-400MB RAM
- Rate Limiter: 30-50MB RAM
- CPU: <5% at idle

**Expected throughput:**
- S3 API latency: <50ms
- Rate limiter overhead: <1ms per request
- Default rate limit: 100 RPS per IP

**Storage:**
- Single-node: Supports 100GB-10TB+ depending on hardware
- Multi-node: Expandable by adding nodes

---

## Getting Help

1. **Check Troubleshooting first** → [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. **Check relevant operation guide** → [Operations](./OPERATIONS.md), [Monitoring](./MONITORING.md)
3. **Review logs** → `docker compose logs -f garage`
4. **Run tests** → `./tests/test-health.sh`, `./tests/test-connectivity.sh`
5. **Consult security** → [SECURITY.md](./SECURITY.md)

---

## What's Next

1. ✅ Read this INDEX
2. 👉 Follow [INSTALLATION.md](./INSTALLATION.md) to set up
3. 📖 Use [OPERATIONS.md](./OPERATIONS.md) for daily tasks
4. 📊 Setup monitoring with [PROMETHEUS.md](./PROMETHEUS.md)
5. 🔒 Harden security with [SECURITY.md](./SECURITY.md)

---

**Last Updated:** 2026-01-18
