# Garage S3 Docker Setup

Production-ready, self-hosted S3-compatible object storage with automatic rate limiting and health checks.

## Key Features

- ✅ Single-node Garage (S3) + OpenResty (Rate Limiting) in one container
- ✅ Built-in OpenResty rate limiter (100 RPS per IP, configurable)
- ✅ Automatic health checks and restart protection
- ✅ Granular bucket access control (per-service permissions)
- ✅ Prometheus-compatible metrics endpoint
- ✅ TLS termination via external reverse proxy
- ✅ Vhost-style bucket access (`bucket.s3.example.com`)

## Quick Start (5 minutes)

```bash
# 1. Generate secure configuration
./scripts/generate-secrets.sh

# 2. Edit .env and set your DOMAIN
nano .env

# 3. Start services
docker compose up -d

# 4. Initialize Garage cluster
./scripts/init-garage.sh

# 5. Verify setup
./tests/test-health.sh
```

✅ **Done!** Garage is ready to use.

## Documentation

Complete guides in `docs/` folder:

| Document | Purpose |
|----------|---------|
| **[docs/INDEX.md](docs/INDEX.md)** | 📚 Navigation hub - start here |
| **[docs/INSTALLATION.md](docs/INSTALLATION.md)** | 🚀 Setup and initialization |
| **[docs/OPERATIONS.md](docs/OPERATIONS.md)** | ⚙️ Daily commands and management |
| **[docs/BUCKET_ACCESS.md](docs/BUCKET_ACCESS.md)** | 🔐 Access control and permissions |
| **[docs/MONITORING.md](docs/MONITORING.md)** | 📊 Health checks and monitoring |
| **[docs/PROMETHEUS.md](docs/PROMETHEUS.md)** | 📈 Prometheus/Grafana integration |
| **[docs/SECURITY.md](docs/SECURITY.md)** | 🔒 Security hardening |
| **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | 🐛 Common issues & solutions |
| **[docs/METRICS_REFERENCE.md](docs/METRICS_REFERENCE.md)** | 📋 All Prometheus metrics |

**👉 Start with [docs/INDEX.md](docs/INDEX.md) for guided navigation.**

## Common Tasks

### Create a Bucket

```bash
docker compose exec s3 /usr/local/bin/garage bucket create my-bucket
```

### Create Access Key

```bash
docker compose exec s3 /usr/local/bin/garage key create my-service
```

### Grant Permissions

```bash
docker compose exec s3 /usr/local/bin/garage bucket allow \
  --read --write my-bucket --key my-service
```

### Get Key Credentials

```bash
docker compose exec s3 /usr/local/bin/garage key info my-service
```

### Check Status

```bash
docker compose ps
./tests/test-health.sh
```

See **[docs/OPERATIONS.md](docs/OPERATIONS.md)** for complete command reference.

## Architecture

```
Internet → HTTPS Reverse Proxy (TLS termination)
  ↓
Container (s3-garage)
  ├── OpenResty (Rate Limiting)
  │     ↓ (localhost:3905)
  └── Garage S3 API
        ↓
      Storage (bind-mounted local directories)
      ├── Metadata (SSD recommended)
      └── Object Data (HDD acceptable)
```

## Network Security

- **Port 3900**: S3 API (exposed to reverse proxy)
- **Port 3901**: Garage internal RPC (Docker network only)
- **Port 3903**: Admin API (Docker network only, not exposed)
- **All external traffic**: Via TLS reverse proxy

## Health & Reliability

- **Automatic health checks** every 30 seconds
- **Auto-restart** on failure with loop protection
- **Rate limiting** prevents overload
- **Metrics endpoint** for external monitoring
- **Health tests** included for verification

## Getting Started

1. **First time?** → [INSTALLATION.md](docs/INSTALLATION.md)
2. **Create buckets/keys?** → [OPERATIONS.md](docs/OPERATIONS.md)
3. **Need monitoring?** → [PROMETHEUS.md](docs/PROMETHEUS.md)
4. **Production use?** → [SECURITY.md](docs/SECURITY.md)
5. **Something broken?** → [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## File Structure

```
.
├── README.md                    # This file
├── docker-compose.yml           # Service config
├── .env.example                 # Configuration template
├── config/
│   ├── garage.toml              # Garage settings
│   └── nginx-ratelimit.conf     # Rate limiter rules
├── scripts/
│   ├── generate-secrets.sh      # Token generation
│   ├── init-garage.sh           # Cluster initialization
│   ├── monitor-restarts.sh      # Restart loop detector
│   └── garage-entrypoint.sh     # Custom entrypoint
├── data/                        # Storage (gitignored)
│   ├── garage-meta/             # Metadata
│   └── garage-data/             # Object data
├── tests/                       # Automated tests
│   ├── test-connectivity.sh
│   ├── test-health.sh
│   └── test-rate-limiter.sh
└── docs/                        # Complete documentation
    ├── INDEX.md
    ├── INSTALLATION.md
    ├── OPERATIONS.md
    ├── BUCKET_ACCESS.md
    ├── MONITORING.md
    ├── PROMETHEUS.md
    ├── SECURITY.md
    ├── TROUBLESHOOTING.md
    └── METRICS_REFERENCE.md
```

## Key Concepts

### Rate Limiting
Per-IP request limits prevent overload:
- **Default**: 100 requests/second per IP
- **Burst**: 200 requests allowed
- **Status Code**: 429 Too Many Requests (when limit exceeded)
- **Configurable**: Edit `RATE_LIMIT_RPS` in `.env`

### Health Checks
Automatic monitoring prevents downtime:
- **Garage**: Health check every 30 seconds
- **Rate Limiter**: Health check every 10 seconds
- **Auto-restart**: On failure with safeguards

### Access Control
Granular permissions per service:
- Each service gets unique credentials
- Read-only, read+write, or no access
- Multiple services can share buckets with different permissions

### Storage
Flexible storage configuration:
- **Metadata**: 10GB-100GB (SSD recommended)
- **Data**: Unlimited (HDD acceptable)
- **Both bind-mounted**: Easy backup and migration

## Performance

**Expected performance** (single node):
- **RAM**: 200-400MB
- **CPU**: <5% at idle
- **S3 latency**: <50ms
- **Throughput**: >100 RPS per IP
- **Storage**: Scales to multiple TB

## Troubleshooting

**Having issues?** Check in order:

1. **Quick diagnostics**: `./tests/test-health.sh`
2. **View logs**: `docker compose logs s3 | tail -50`
3. **Check guide**: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
4. **Run tests**: `./tests/test-connectivity.sh`

## Examples

### Access from Python

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='https://s3.example.com',
    aws_access_key_id='GKxxxxxx',
    aws_secret_access_key='xxxxxx',
    region_name='garage'
)

# Upload
s3.put_object(Bucket='my-bucket', Key='file.txt', Body=b'content')

# Download
obj = s3.get_object(Bucket='my-bucket', Key='file.txt')
```

### Access via AWS CLI

```bash
aws configure set aws_access_key_id GKxxxxxx
aws configure set aws_secret_access_key xxxxxx
aws configure set region garage

aws s3 ls s3://my-bucket --endpoint-url https://s3.example.com
aws s3 cp file.txt s3://my-bucket --endpoint-url https://s3.example.com
```

### Access from JavaScript

```javascript
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
    endpoint: 'https://s3.example.com',
    accessKeyId: 'GKxxxxxx',
    secretAccessKey: 'xxxxxx',
    region: 'garage'
});

// Upload
s3.upload({Bucket: 'my-bucket', Key: 'file.txt', Body: data}, (err) => {
    if (!err) console.log('Uploaded!');
});
```

## Prerequisites

- Docker & Docker Compose
- 20GB+ disk space
- External HTTPS reverse proxy (for production)
- Domain name (or localhost for testing)

## License

Garage is licensed under AGPL-3.0. This setup is provided as-is.

## Support

- **Documentation**: See [docs/INDEX.md](docs/INDEX.md)
- **Garage Docs**: https://garagehq.deuxfleurs.fr/documentation/
- **Issues**: Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

**Last Updated**: 2026-01-18 | **Version**: 1.0.1
