# Installation Guide

Complete setup instructions for Garage S3 with rate limiting.

## Prerequisites

- Docker and Docker Compose
- Domain name (or plan to use localhost)
- 20GB+ disk space (for data directories)
- External reverse proxy with TLS termination (optional, for production)

## Quick Start (5 minutes)

### 1. Generate Configuration

```bash
# Generate secure tokens
./scripts/generate-secrets.sh

# This creates .env with random tokens
# Edit to set your domain
nano .env
```

Set these in `.env`:
```bash
DOMAIN=example.com              # Your domain
GARAGE_META_DIR=./data/garage-meta    # Keep defaults or customize
GARAGE_DATA_DIR=./data/garage-data
```

### 2. Start Services

```bash
# Start Garage + Rate Limiter
docker compose up -d

# Watch startup
docker compose logs -f garage
```

Wait for Garage to start (~30 seconds), then Ctrl+C.

### 3. Initialize Cluster

```bash
# Initialize with default 100GB capacity
./scripts/init-garage.sh

# Or specify custom capacity
./scripts/init-garage.sh 1T          # 1 Terabyte
./scripts/init-garage.sh 500G        # 500 Gigabytes
```

### 4. Verify Setup

```bash
# Check all services are healthy
docker compose ps
# All should show: Up (health: healthy)

# Run tests
./tests/test-connectivity.sh
./tests/test-health.sh
```

✅ **Done!** Garage is ready to use.

---

## Detailed Setup

### Step 1: Clone or Prepare Repository

```bash
git clone <repo-url> s3_garage
cd s3_garage
```

### Step 2: Generate Secrets

```bash
# Generate RPC_SECRET, ADMIN_TOKEN, METRICS_TOKEN
./scripts/generate-secrets.sh
```

This:
- Creates `.env` from `.env.example`
- Generates secure random tokens (32 bytes hex)
- Prompts for DOMAIN setting

**Manual token generation:**
```bash
# RPC_SECRET (32 bytes hex)
openssl rand -hex 32

# ADMIN_TOKEN (32 bytes base64)
openssl rand -base64 32

# METRICS_TOKEN (32 bytes base64)
openssl rand -base64 32
```

### Step 3: Configure Environment

**`.env` file settings:**

```bash
# Required
DOMAIN=example.com                    # e.g., example.com
RPC_SECRET=xxxxx...                   # From generate-secrets.sh
ADMIN_TOKEN=xxxxx...
METRICS_TOKEN=xxxxx...

# Optional (defaults shown)
S3_REGION=garage                      # AWS region ID
GARAGE_META_DIR=./data/garage-meta    # SSD recommended
GARAGE_DATA_DIR=./data/garage-data    # HDD acceptable
RUST_LOG=info                         # Logging: error, warn, info, debug
ENABLE_RATE_LIMITER=true              # Enable rate limiting
RATE_LIMIT_RPS=100                    # Requests per second per IP
RATE_LIMIT_BURST=200                  # Burst capacity
```

### Step 4: Start Services

```bash
# Start in background
docker compose up -d

# Check status
docker compose ps

# Watch logs
docker compose logs -f garage
```

**Expected output:**
```
garage          Up (health: starting)     # Grace period (30 seconds)
garage-rate-limiter  Up (healthy)         # Rate limiter starts quickly
```

Wait for Garage health to show either:
- `(health: healthy)` - Ready to use
- `(health: unhealthy)` - Not yet initialized (normal)

### Step 5: Initialize Garage Cluster

Initialize the cluster layout (required):

```bash
# Default: 100GB capacity
./scripts/init-garage.sh

# Custom capacity examples:
./scripts/init-garage.sh 1T            # 1 Terabyte
./scripts/init-garage.sh 0.5T          # 500 Gigabytes
./scripts/init-garage.sh 10G           # 10 Gigabytes
```

**What this does:**
1. Gets node ID from Garage
2. Assigns zone `dc1` with specified capacity
3. Applies layout to cluster
4. Prints next steps

**After initialization:**

```bash
# Verify cluster is healthy
docker compose exec garage /garage status
```

Expected output:
```
==== HEALTHY NODES ====
ID                Zone  Capacity  DataAvail
fcd9b303afdb60d3  dc1   100.0 GB  53.5 GB (10.8%)
```

### Step 6: Verify Installation

```bash
# Run connectivity tests
./tests/test-connectivity.sh

# Run health checks
./tests/test-health.sh

# Run rate limiter tests
./tests/test-rate-limiter.sh
```

All tests should show ✓ (green check marks).

---

## Network Configuration

### Local Network (Development)

If running locally, services are accessible on:
- **Garage (internal):** `http://localhost:3901`
- **Rate Limiter:** `http://localhost:3900`
- **Admin API:** `http://localhost:3903`

### Upstream Reverse Proxy (Production)

Configure your external reverse proxy to forward to the rate limiter:

**Nginx example:**
```nginx
upstream s3_api {
    server localhost:3900;  # Rate limiter
}

# S3 API with TLS
server {
    listen 443 ssl http2;
    server_name s3.example.com *.s3.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    location / {
        proxy_pass http://s3_api;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # For S3 large uploads
        client_max_body_size 0;
        proxy_request_buffering off;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name s3.example.com *.s3.example.com;
    return 301 https://$server_name$request_uri;
}
```

**Required DNS:**
```bash
# S3 endpoint
s3.example.com A 192.168.1.1

# Wildcard for vhost-style buckets
*.s3.example.com A 192.168.1.1
```

---

## Directory Structure Setup

After initialization, your directories should look like:

```
s3_garage/
├── docker-compose.yml
├── .env                          # Secrets (DO NOT COMMIT)
├── .env.example                  # Template
├── config/
│   ├── garage.toml               # Config file
│   └── nginx-ratelimit.conf      # Rate limiter rules
├── scripts/
│   ├── generate-secrets.sh
│   ├── init-garage.sh
│   ├── monitor-restarts.sh
│   └── (other scripts)
├── data/
│   ├── garage-meta/              # Created automatically
│   │   └── db.sqlite             # Metadata database
│   └── garage-data/              # Created automatically
│       └── (blocks)              # Object data
└── docs/
    ├── INSTALLATION.md           ← You are here
    ├── OPERATIONS.md
    └── ...
```

The `data/` directories are created automatically on first start.

---

## Troubleshooting Installation

### "Garage won't start"

```bash
# Check logs
docker compose logs garage | head -30

# Common issues:
# 1. Port already in use
lsof -i :3900
lsof -i :3901
lsof -i :3903

# 2. Permission error on data directory
ls -la data/
chmod 755 data/garage-meta data/garage-data

# 3. Configuration error
docker compose config  # Validates compose file
```

### "Health check failing"

Expected on first start before initialization:
```
garage    Up (health: unhealthy)
```

This is normal. After running `./scripts/init-garage.sh`:
```
garage    Up (health: healthy)
```

### "Can't reach S3 API"

```bash
# Verify rate limiter is running
docker compose ps rate-limiter

# Test rate limiter directly
curl http://localhost:3900/

# Check if firewall is blocking port 3900
netstat -tlnp | grep 3900
```

### "Docker permission denied"

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or use sudo
sudo docker compose ps
```

---

## Next Steps

1. ✅ **Installation complete**
2. 👉 **[Create buckets & manage access](./OPERATIONS.md)**
3. 📊 **[Setup monitoring with Prometheus](./PROMETHEUS.md)** (optional)
4. 🔒 **[Security hardening](./SECURITY.md)** (for production)

---

## Common Initial Commands

After installation, here are common operations:

```bash
# Check cluster status
docker compose exec garage /garage status

# Create first bucket
docker compose exec garage /garage bucket create media

# Create access key for an application
docker compose exec garage /garage key create app-key

# Grant permissions
docker compose exec garage /garage bucket allow \
  --read --write media --key app-key

# Get key credentials
docker compose exec garage /garage key info app-key

# View logs
docker compose logs -f garage
docker compose logs -f rate-limiter
```

See **[OPERATIONS.md](./OPERATIONS.md)** for complete command reference.

---

## Disk Space Recommendations

**Metadata directory (SSD):**
- Minimum: 10GB
- Typical: 50GB
- Formula: ~50MB per million objects

**Data directory:**
- As much as available
- HDD acceptable (cheaper)
- SSD recommended (faster)

**Example setup:**
- Metadata: 100GB SSD
- Data: 2TB HDD
- Total: ~2.1TB

---

## Resource Requirements

**Minimum:**
- 2GB RAM
- 1 CPU
- 20GB disk

**Recommended (small):**
- 4GB RAM
- 2 CPUs
- 100GB disk

**Recommended (production):**
- 8GB RAM
- 4 CPUs
- 500GB+ disk

---

## Security Checklist

- [ ] `.env` file is in `.gitignore`
- [ ] `.env` file is never committed to version control
- [ ] Tokens are strong (32+ bytes)
- [ ] DOMAIN is set correctly
- [ ] Reverse proxy has TLS enabled
- [ ] DNS wildcard configured for buckets
- [ ] Rate limiter is operational
- [ ] Health checks enabled

See **[SECURITY.md](./SECURITY.md)** for detailed hardening.

---

## Support & Troubleshooting

**For specific issues, see:**
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common problems
- **[MONITORING.md](./MONITORING.md)** - Health checks & restarts
- **[OPERATIONS.md](./OPERATIONS.md)** - Commands reference
