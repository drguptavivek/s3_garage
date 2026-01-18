# Security Guide

Security best practices and hardening for production Garage deployments.

## Security Checklist

### Secrets & Credentials

- [ ] All tokens generated with strong randomness (32+ bytes)
- [ ] `.env` file is in `.gitignore` (never committed)
- [ ] Secrets stored securely (vault, secrets manager, encrypted files)
- [ ] No hardcoded credentials in code or configs
- [ ] Rotate keys every 90 days

### Network & TLS

- [ ] TLS 1.2+ enforced on reverse proxy
- [ ] Strong cipher suites configured
- [ ] HSTS header enabled (`Strict-Transport-Security`)
- [ ] All traffic goes through TLS reverse proxy
- [ ] Internal traffic on isolated Docker network

### Access Control

- [ ] Each service has separate access key (never shared)
- [ ] Minimum permissions granted (principle of least privilege)
- [ ] Periodic review of bucket permissions
- [ ] Unused keys deleted promptly
- [ ] Key rotation tested before production

### Admin API

- [ ] Port 3903 (admin API) NOT exposed to internet ✓ (default)
- [ ] Admin API only accessible via Docker CLI
- [ ] ADMIN_TOKEN changed from default
- [ ] Metrics endpoint authenticated (METRICS_TOKEN)

### Data Protection

- [ ] Metadata directory on SSD (better security)
- [ ] Data directory on properly configured storage
- [ ] Backups of metadata stored securely
- [ ] Encrypted storage at rest (if required)
- [ ] Regular backup testing

### Operational Security

- [ ] Container updates checked regularly
- [ ] Logs monitored for suspicious activity
- [ ] Rate limiting enabled
- [ ] Health checks and auto-restart enabled
- [ ] Restart loops prevented and monitored

## Token Management

### Generation

Use `generate-secrets.sh` for secure generation:

```bash
./scripts/generate-secrets.sh
```

Or manually:

```bash
# RPC_SECRET (32 bytes hex)
openssl rand -hex 32

# ADMIN_TOKEN (32 bytes base64)
openssl rand -base64 32

# METRICS_TOKEN (32 bytes base64)
openssl rand -base64 32
```

### Storage

Never expose tokens:

```bash
# ✗ Bad: Tokens in code
const ADMIN_TOKEN = "xxxx"

# ✗ Bad: Tokens in git
git add .env
git commit -m "Add tokens"

# ✓ Good: Tokens in .env (gitignored)
# .env contains: ADMIN_TOKEN=xxxx

# ✓ Good: Tokens in secrets manager
# Docker secrets, Kubernetes secrets, Vault, etc.
```

### Rotation

Rotate every 90 days:

```bash
# 1. Generate new token
NEW_TOKEN=$(openssl rand -base64 32)

# 2. Create new key in Garage
docker compose exec garage /garage key create service-v2

# 3. Grant same permissions as old key
docker compose exec garage /garage bucket allow --read --write BUCKET --key service-v2

# 4. Update service to use new key

# 5. Test new key works

# 6. Delete old key
docker compose exec garage /garage key delete --yes service
```

## Access Key Security

### Per-Service Keys

Each service gets unique credentials:

```bash
# ✓ Good: Separate keys
upload-service key: GK123456
processor key:      GK789abc
analytics key:      GKdef789

# ✗ Bad: Shared key
all-services key:   GK123456
```

Benefits:
- Can revoke compromised service independently
- Audit trail per service
- Easy rotation per service

### Minimum Permissions

Grant only what's needed:

```bash
# ✓ Good: Read-only for analytics
docker compose exec garage /garage bucket allow --read logs --key analytics

# ✗ Bad: Full access when only read needed
docker compose exec garage /garage bucket allow --read --write logs --key analytics
```

### Regular Audit

```bash
# List all keys with their permissions
docker compose exec garage /garage key list

# Check each key's access
docker compose exec garage /garage key info KEY_NAME

# Review bucket permissions
docker compose exec garage /garage bucket info BUCKET
```

## Network Security

### Port Exposure

Current safe defaults:

```yaml
garage:
  ports:
    # - "3901:3900"      # Exposed to host (rate limiter accesses)
    # - "3903:3903"      # NOT exposed - admin API internal only

rate-limiter:
  ports:
    - "3900:3900"        # Exposed to host for reverse proxy
```

### Firewall Rules

```bash
# Allow only reverse proxy to port 3900
sudo ufw allow from 192.168.1.100 to any port 3900

# Block direct access from internet
sudo ufw default deny incoming
```

### Reverse Proxy Configuration

```nginx
# Enforce TLS
server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;

    # Strong TLS settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;

    location / {
        proxy_pass http://garage-rate-limiter:3900;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

## Data Security

### At-Rest Encryption

For encrypted storage:

```bash
# Mount encrypted volume
docker volume create --driver local \
  --opt type=tmpfs \
  --opt device=tmpfs \
  encrypted-data

# Use in docker-compose.yml
volumes:
  - encrypted-data:/var/lib/garage/data
```

Or use filesystem-level encryption (dm-crypt, BitLocker).

### Backups

```bash
# Backup metadata regularly
tar -czf garage-meta-$(date +%Y%m%d).tar.gz \
  --encryption-key=xxx \
  data/garage-meta/

# Test restore process
tar -xzf garage-meta-20260118.tar.gz -C /tmp/test

# Store backups off-site
scp garage-meta-20260118.tar.gz backup-server:/backups/
```

### Audit Logs

Monitor access:

```bash
# View Prometheus metrics for access patterns
curl -H "Authorization: Bearer $METRICS_TOKEN" \
  http://localhost:3903/metrics | grep s3_request

# Monitor failed access attempts
docker compose logs garage | grep "Access\|Denied"

# Alert on unusual patterns
# (Configure in Prometheus alerting rules)
```

## DDoS Protection

### Rate Limiting

Current setup:

```yaml
# 100 requests/second per IP
RATE_LIMIT_RPS=100

# Burst to 200 requests
RATE_LIMIT_BURST=200
```

Adjust for your workload:

```bash
# Lower for protection (50 RPS)
RATE_LIMIT_RPS=50

# Higher for high-volume (500 RPS)
RATE_LIMIT_RPS=500

# Restart to apply
docker compose restart rate-limiter
```

### Firewall-Level Protection

```bash
# Limit connections per IP
sudo iptables -A INPUT -p tcp --dport 3900 -m limit \
  --limit 100/min --limit-burst 200 -j ACCEPT

# Drop excess traffic
sudo iptables -A INPUT -p tcp --dport 3900 -j DROP
```

## Monitoring Security

### Alert on Security Events

```promql
# Failed auth attempts
increase(s3_error_counter{error="access_denied"}[5m]) > 10

# Unusual traffic patterns
rate(s3_request_counter[1m]) > 10000

# Admin API access
rate(api_admin_request_counter[5m]) > 100
```

### Log Important Events

```bash
# Review admin API access
docker compose logs garage | grep "admin\|metrics"

# Check for failed access attempts
docker compose logs garage | grep -i "access\|denied\|forbidden"

# Monitor for errors
docker compose logs garage | grep -i "error\|panic"
```

## Compliance

### Data Residency

Store data in specific region:

```bash
# Set in docker-compose.yml
environment:
  - S3_REGION=eu-west-1  # EU data residency
```

### Audit Trail

Ensure audit capabilities:

```bash
# All commands logged via Prometheus metrics
# Monitor with: rate(s3_request_counter[5m])

# Maintain audit logs
docker compose logs garage > garage-audit.log

# Archive logs regularly
tar -czf garage-audit-$(date +%Y%m).tar.gz garage-audit.log
```

### Encryption Standards

- TLS 1.2+ minimum for all traffic
- AES-256 or equivalent for data at rest (if configured)
- Strong random tokens (256-bit entropy minimum)

## Incident Response

### Compromise Detection

```bash
# Unusual access patterns
docker compose logs garage | grep "s3_request_counter" | sort | uniq -c | sort -rn

# High error rate
docker compose logs garage | grep "error" | wc -l

# Restart loops
docker inspect garage | jq '.RestartCount'
```

### Recovery

1. **Identify** compromised key/bucket
2. **Isolate** - Remove access immediately
3. **Rotate** - Generate new credentials
4. **Notify** - Alert affected services
5. **Audit** - Review access logs
6. **Test** - Verify recovery

```bash
# Revoke compromised key
docker compose exec garage /garage key delete --yes compromised-key

# Rotate buckets if needed
docker compose exec garage /garage bucket delete --yes compromised-bucket
docker compose exec garage /garage bucket create compromised-bucket

# Create new keys
docker compose exec garage /garage key create new-key

# Grant permissions
docker compose exec garage /garage bucket allow --read --write bucket --key new-key
```

## Security Resources

- [OWASP S3 Security](https://owasp.org/www-community/attacks/S3_bucket_misconfiguration)
- [Garage Security Model](https://garagehq.deuxfleurs.fr/documentation/cookbook/security/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Nginx Security Headers](https://owasp.org/www-project-secure-headers/)

## See Also

- [OPERATIONS.md](./OPERATIONS.md) - Safe operational practices
- [MONITORING.md](./MONITORING.md) - Detecting security issues
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common problems
