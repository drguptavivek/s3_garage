# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a production-ready Docker Compose setup for Garage - a lightweight, self-hosted, S3-compatible object storage server. The setup is designed for single-node deployment with external reverse proxy handling TLS termination.

## Architecture

**Components:**
- **Garage Container**: S3-compatible object storage (port 3901 internal)
- **Rate Limiter**: Nginx-based rate limiting (port 3900 exposed)
- **External Reverse Proxy**: TLS termination and request routing (not included)
- **CLI Administration**: All management via `docker compose exec` commands

**Key Design Decisions:**
- Lightweight rate limiter (Nginx) included for DDoS/abuse protection
- Single Garage service (no Web UI for simplicity and security)
- Admin API (port 3903) is **NOT exposed** to host - only accessible internally
- Environment variable substitution via custom entrypoint script
- Bind-mounted data directories for easy backup and monitoring
- Vhost-style bucket access: `bucket.s3.domain.com`
- Rate limiting configurable per IP (100 RPS default, 200 burst)

**Data Storage:**
- Metadata: `./data/garage-meta/` (should be on SSD for performance)
- Object data: `./data/garage-data/` (can be on HDD)

## Commands

### Setup and Initialization

```bash
# Generate secure tokens
./scripts/generate-secrets.sh

# Edit .env file with your domain
nano .env

# Start Garage
docker compose up -d

# Initialize cluster layout (first time only, defaults to 100G)
./scripts/init-garage.sh

# Initialize with custom capacity (human-readable sizes)
./scripts/init-garage.sh 1T         # 1 Terabyte
./scripts/init-garage.sh 0.5T       # 500 Gigabytes
./scripts/init-garage.sh 500G       # 500 Gigabytes
./scripts/init-garage.sh 1.5TB      # 1.5 Terabytes
```

### Common Operations

```bash
# View Garage logs
docker compose logs -f garage

# View rate limiter logs
docker compose logs -f rate-limiter

# Check all services status
docker compose ps

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Update Garage version
docker compose pull && docker compose up -d
```

### Rate Limiter Configuration

```bash
# Edit .env to adjust rate limits
nano .env

# Adjust these values:
# RATE_LIMIT_RPS=100          # Requests per second per IP
# RATE_LIMIT_BURST=200        # Burst capacity

# Restart to apply changes
docker compose restart rate-limiter
```

### Garage CLI Commands

```bash
# Bucket management
docker compose exec garage /garage bucket create BUCKET_NAME
docker compose exec garage /garage bucket list
docker compose exec garage /garage bucket info BUCKET_NAME

# Key management
docker compose exec garage /garage key create KEY_NAME
docker compose exec garage /garage key info KEY_NAME
docker compose exec garage /garage key list

# Permissions
docker compose exec garage /garage bucket allow --read --write BUCKET_NAME --key KEY_NAME
docker compose exec garage /garage bucket deny --read --write BUCKET_NAME --key KEY_NAME

# Cluster status
docker compose exec garage /garage status
docker compose exec garage /garage layout show
docker compose exec garage /garage node id
```

### Testing S3 Access

```bash
# Using AWS CLI
aws --endpoint-url https://s3.YOUR_DOMAIN s3 ls
aws --endpoint-url https://s3.YOUR_DOMAIN s3 mb s3://test-bucket
aws --endpoint-url https://s3.YOUR_DOMAIN s3 cp file.txt s3://test-bucket/
```

## Development Workflow

### Initial Setup
1. Run `./scripts/generate-secrets.sh` to create `.env` file
2. Edit `.env` and set your `DOMAIN`
3. Ensure external reverse proxy is configured (see README.md)
4. Start services with `docker compose up -d`
5. Initialize cluster with `./scripts/init-garage.sh`

### Configuration Changes
- Edit `config/garage.toml` for Garage settings
- Edit `docker-compose.yml` for Docker settings
- Restart service: `docker compose restart garage`

### Backup Procedures
- **Critical**: Backup `data/garage-meta/` regularly (contains cluster state)
- **Optional**: Backup `data/garage-data/` (can be very large)
- Stop Garage before backing up metadata for consistency

### Troubleshooting
- Check logs: `docker compose logs garage`
- Verify config: `docker compose config`
- Check permissions: `ls -la data/`
- Test connectivity: `curl http://localhost:3900`

## Important Notes

- **Never commit** `.env` file (contains secrets)
- **Never expose** port 3903 (Admin API) externally
- **Always use** strong random tokens from `generate-secrets.sh`
- **DNS required**: Wildcard DNS for `*.s3.${DOMAIN}`
- **Reverse proxy required**: External TLS termination mandatory
- **Host header**: Must be preserved by reverse proxy for vhost-style buckets

## File Structure

```
s3_garage/
├── docker-compose.yml           # Garage + Rate Limiter services
├── .env                         # Environment variables (gitignored)
├── .env.example                 # Environment template with rate limit config
├── config/
│   ├── garage.toml              # Garage configuration with env vars
│   └── nginx-ratelimit.conf     # Nginx rate limiter configuration
├── scripts/
│   ├── garage-entrypoint.sh     # Envsubst wrapper for Garage
│   ├── generate-secrets.sh      # Token generation
│   └── init-garage.sh           # Cluster initialization
└── data/                        # Persistent storage (gitignored)
    ├── garage-meta/             # Metadata (SSD recommended)
    └── garage-data/             # Object storage
```
