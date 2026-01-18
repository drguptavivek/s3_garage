# Operations Guide

Daily operations and command reference for managing Garage S3.

## Quick Reference

### Check Status
```bash
docker compose ps                              # Service status
docker compose exec garage /garage status      # Cluster status
./tests/test-health.sh                         # Health check
```

### Bucket Operations
```bash
docker compose exec garage /garage bucket create NAME
docker compose exec garage /garage bucket list
docker compose exec garage /garage bucket info NAME
docker compose exec garage /garage bucket delete --yes NAME
```

### Key (Access) Operations
```bash
docker compose exec garage /garage key create NAME
docker compose exec garage /garage key list
docker compose exec garage /garage key info NAME
docker compose exec garage /garage key delete --yes NAME
```

### Permission Operations
```bash
# Grant read+write
docker compose exec garage /garage bucket allow --read --write BUCKET --key KEY

# Grant read-only
docker compose exec garage /garage bucket allow --read BUCKET --key KEY

# Revoke all access
docker compose exec garage /garage bucket deny BUCKET --key KEY
```

---

## Complete Command Reference

### Service Management

#### View Service Status
```bash
# Quick status
docker compose ps

# Detailed Garage status
docker compose exec garage /garage status

# Detailed rate limiter status
docker compose logs rate-limiter | tail -20

# Watch service health in real-time
watch -n 1 'docker compose ps'
```

#### Start/Stop Services
```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart garage
docker compose restart rate-limiter

# View logs
docker compose logs -f garage         # Follow logs
docker compose logs garage | tail -50 # Last 50 lines
docker compose logs --since 5m garage # Last 5 minutes
```

---

### Bucket Management

#### Create Bucket

```bash
docker compose exec garage /garage bucket create my-bucket
```

**Output:**
```
Bucket my-bucket was created.
```

#### List All Buckets

```bash
docker compose exec garage /garage bucket list
```

**Output:**
```
List of buckets:
  my-bucket    d953c68892ba39ed0ed061577cbf0c2625be576dbe16b22a31c4af4d5876eb4c
  photos       a1b2c3d4e5f6...
  documents    x9y8z7w6v5u4...
```

#### Get Bucket Info

```bash
docker compose exec garage /garage bucket info my-bucket
```

**Output:**
```
Bucket: my-bucket
ID: d953c68892ba39ed0ed061577cbf0c2625be576dbe16b22a31c4af4d5876eb4c
Objects: 42
Size: 1.5 GB (1,610,612,736 B)
Unfinished uploads: 0
Website access: false

Authorized keys:
  RW   GK451cf0b9daf160b602c109fb  app-service
  R    GK123ef0b9daf160b602c109fb  analytics
```

#### Delete Bucket

```bash
# Bucket must be empty
docker compose exec garage /garage bucket delete --yes my-bucket
```

---

### Access Key Management

#### Create Access Key

```bash
docker compose exec garage /garage key create my-service
```

**Output:**
```
Key name: my-service
Access key ID: GK451cf0b9daf160b602c109fb
Secret key: 48968f95b8dddaf6e95071487c832c7460407b23db494245e464f80a0d9c99c4
Can create buckets: false
```

#### List All Keys

```bash
docker compose exec garage /garage key list
```

**Output:**
```
List of keys:
  GK451cf0b9daf160b602c109fb  my-service
  GK123ef0b9daf160b602c109fb  analytics-reader
  GK987cf0b9daf160b602c109fb  web-client
```

#### Get Key Info (Credentials)

```bash
docker compose exec garage /garage key info my-service
```

**Output:**
```
Key name: my-service
Access key ID: GK451cf0b9daf160b602c109fb
Secret key: 48968f95b8dddaf6e95071487c832c7460407b23db494245e464f80a0d9c99c4
Can create buckets: false

Key-specific bucket aliases:

Authorized buckets:
  RW   my-bucket
  RW   documents
  R    logs
```

#### Delete Key

```bash
docker compose exec garage /garage key delete --yes my-service
```

---

### Bucket Permissions

#### Grant Permissions

```bash
# Read + Write
docker compose exec garage /garage bucket allow --read --write my-bucket --key my-service

# Read Only
docker compose exec garage /garage bucket allow --read my-bucket --key my-service

# No permissions
docker compose exec garage /garage bucket allow my-bucket --key my-service
```

#### Check Permissions

```bash
# View who has access to a bucket
docker compose exec garage /garage bucket info my-bucket | grep -A5 "Authorized keys"

# View what a key can access
docker compose exec garage /garage key info my-service | grep -A5 "Authorized buckets"
```

#### Revoke Permissions

```bash
# Remove key from bucket
docker compose exec garage /garage bucket deny my-bucket --key my-service
```

#### Change Permissions

```bash
# Revoke existing
docker compose exec garage /garage bucket deny my-bucket --key my-service

# Grant new permissions
docker compose exec garage /garage bucket allow --read my-bucket --key my-service
```

---

## Common Workflows

### Setup: Service with Read+Write Access

**Scenario:** Create a photo upload service with full access to "photos" bucket

```bash
# 1. Create bucket
docker compose exec garage /garage bucket create photos

# 2. Create access key for service
docker compose exec garage /garage key create photo-uploader

# 3. Grant read+write permissions
docker compose exec garage /garage bucket allow \
  --read --write photos \
  --key photo-uploader

# 4. Get credentials for the service
docker compose exec garage /garage key info photo-uploader

# Output credentials to service:
# Access Key ID: GKxxxxxx
# Secret Key: xxxxxx
```

### Setup: Multiple Services with Different Permissions

**Scenario:** Photo app with uploader, processor, and viewer

```bash
# Create bucket
docker compose exec garage /garage bucket create images

# Upload service: read+write
docker compose exec garage /garage key create upload-service
docker compose exec garage /garage bucket allow --read --write images --key upload-service

# Processing service: read+write (reads originals, writes processed)
docker compose exec garage /garage key create image-processor
docker compose exec garage /garage bucket allow --read --write images --key image-processor

# Analytics: read-only
docker compose exec garage /garage key create analytics
docker compose exec garage /garage bucket allow --read images --key analytics

# Web users: read-only
docker compose exec garage /garage key create web-client
docker compose exec garage /garage bucket allow --read images --key web-client

# Verify setup
docker compose exec garage /garage bucket info images
```

### Update Permissions (Upgrade Read-Only to Read+Write)

```bash
# Current: key-name has read-only access to bucket
# Goal: Add write permission

# Revoke existing (removes all permissions)
docker compose exec garage /garage bucket deny bucket-name --key key-name

# Grant new permissions
docker compose exec garage /garage bucket allow --read --write bucket-name --key key-name

# Verify
docker compose exec garage /garage key info key-name
```

### Rotate Access Keys

```bash
# Step 1: Create new key
docker compose exec garage /garage key create old-service-new

# Step 2: Grant same permissions as old key
docker compose exec garage /garage bucket allow --read --write my-bucket --key old-service-new

# Step 3: Update service to use new credentials

# Step 4: Verify new key is working

# Step 5: Delete old key
docker compose exec garage /garage key delete --yes old-service
```

---

## Monitoring Operations

### Check Service Health

```bash
# One-time health check
./tests/test-health.sh

# Watch for restart loops
./scripts/monitor-restarts.sh

# Manual status check
docker compose ps garage
```

### View Metrics

```bash
# Via Prometheus (if configured)
curl -H "Authorization: Bearer $METRICS_TOKEN" http://localhost:3903/metrics

# Via Garage status command
docker compose exec garage /garage status
```

### Check Disk Usage

```bash
# Current data directory usage
du -sh data/garage-meta
du -sh data/garage-data

# Total usage
du -sh data/
```

---

## Data Export/Backup

### Backup Metadata

```bash
# Metadata is in SQLite database
# Backup the metadata directory
cp -r data/garage-meta backup-garage-meta-$(date +%Y%m%d)

# Or use tar for compression
tar -czf garage-meta-backup.tar.gz data/garage-meta/
```

### List Objects in Bucket

```bash
# Using aws-cli
aws s3 ls s3://my-bucket --endpoint-url https://s3.example.com --recursive
```

### Export Object Metadata

```bash
# Get size of each object
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --endpoint-url https://s3.example.com \
  --query 'Contents[].{Key:Key,Size:Size}' \
  --output table
```

---

## Troubleshooting Operations

### "Key already exists"

```bash
# Error when creating key with same name
Error: Key already exists

# Solution: Delete old key first, then create new
docker compose exec garage /garage key delete --yes my-service
docker compose exec garage /garage key create my-service
```

### "Bucket not empty"

```bash
# Error when trying to delete bucket with objects
Error: Bucket not empty

# Solution: Empty bucket first, then delete
# This requires deleting all objects via S3 API
# Or using aws-cli:
aws s3 rm s3://my-bucket --endpoint-url https://s3.example.com --recursive
docker compose exec garage /garage bucket delete --yes my-bucket
```

### "Access Denied" errors

```bash
# Service can't access bucket
Error: Access Denied

# Solutions:
# 1. Check permissions
docker compose exec garage /garage key info my-service | grep "my-bucket"

# 2. Check if key needs --read permission
docker compose exec garage /garage bucket allow --read my-bucket --key my-service

# 3. Check credentials are correct in service config
```

---

## Best Practices

1. **Principle of Least Privilege**
   - Each service gets only needed permissions
   - Read-only where possible
   - Separate keys per service

2. **Naming Convention**
   - Buckets: lowercase, descriptive (e.g., `user-uploads`, `media-cache`)
   - Keys: service-name-based (e.g., `upload-api`, `image-processor`)

3. **Regular Cleanup**
   - Delete unused keys
   - Delete empty buckets
   - Review permissions quarterly

4. **Credential Management**
   - Use `.env` files (not committed to git)
   - Rotate keys periodically
   - Keep backup keys for migration

5. **Monitoring**
   - Monitor failed access attempts
   - Track storage growth
   - Monitor request rates per key

---

## Advanced Operations

### Cluster Status and Rebalancing

```bash
# View cluster layout
docker compose exec garage /garage layout show

# View current rebalancing progress
docker compose exec garage /garage status | grep -i "rebalancing\|pending"
```

### Admin API Access

```bash
# Admin API is available at http://localhost:3903
# Requires ADMIN_TOKEN

curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:3903/health
```

### Configure Logging Level

```bash
# Change logging level (in .env)
RUST_LOG=debug  # More verbose

# Then restart Garage
docker compose restart garage

# View logs
docker compose logs -f garage
```

---

## Quick Recipes

### Create Production Setup
```bash
# 1. Create buckets for different purposes
docker compose exec garage /garage bucket create user-data
docker compose exec garage /garage bucket create cache
docker compose exec garage /garage bucket create backups

# 2. Create service keys
docker compose exec garage /garage key create app-service
docker compose exec garage /garage key create cache-worker
docker compose exec garage /garage key create backup-system

# 3. Grant specific permissions
docker compose exec garage /garage bucket allow --read --write user-data --key app-service
docker compose exec garage /garage bucket allow --read --write cache --key cache-worker
docker compose exec garage /garage bucket allow --read --write backups --key backup-system

# 4. Verify
docker compose exec garage /garage bucket list
docker compose exec garage /garage key list
```

### Reset Everything (Development Only)

```bash
# WARNING: Destroys all data!
docker compose down
rm -rf data/
docker compose up -d
./scripts/init-garage.sh
```

---

## References

- See **[BUCKET_ACCESS.md](./BUCKET_ACCESS.md)** for complex permission scenarios
- See **[OPERATIONS.md](./OPERATIONS.md)** (this file) for command reference
- See **[SECURITY.md](./SECURITY.md)** for securing operations
- See **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** for common issues
