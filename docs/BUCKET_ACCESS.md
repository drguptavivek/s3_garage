# Garage Bucket Access Control Guide

Complete guide to managing bucket permissions for multiple services and clients with different access levels.

## Scenario: Single Bucket with Multiple Access Tiers

```
Single Bucket: "media"

├── Service: Upload Handler (Write + Read)
├── Service: Image Processor (Read + Append)
├── Service: Analytics (Read Only)
├── Client: Web User (Read Only)
└── Client: Mobile App (Read Only)
```

---

## Setup Example: "media" Bucket

### Step 1: Create the Bucket

```bash
docker compose exec garage /garage bucket create media
```

### Step 2: Create Access Keys for Each Service/Client

```bash
# Service 1: Upload Handler (Internal Service)
# Needs: Read + Write (uploads files, reads for validation)
docker compose exec garage /garage key create --name "upload-handler" upload-handler

# Service 2: Image Processor (Internal Service)
# Needs: Read + Write (reads uploads, writes processed images)
docker compose exec garage /garage key create --name "image-processor" image-processor

# Service 3: Analytics (Internal Service)
# Needs: Read Only (reads metadata, counts)
docker compose exec garage /garage key create --name "analytics-reader" analytics-reader

# Client 1: Web User (External Client)
# Needs: Read Only (downloads images)
docker compose exec garage /garage key create --name "web-client" web-client

# Client 2: Mobile App (External Client)
# Needs: Read Only (downloads images)
docker compose exec garage /garage key create --name "mobile-app" mobile-app
```

### Step 3: Grant Permissions to "media" Bucket

```bash
# Service 1: Upload Handler - Full read+write
docker compose exec garage /garage bucket allow \
  --read --write media \
  --key upload-handler

# Service 2: Image Processor - Full read+write
docker compose exec garage /garage bucket allow \
  --read --write media \
  --key image-processor

# Service 3: Analytics - Read only
docker compose exec garage /garage bucket allow \
  --read media \
  --key analytics-reader

# Client 1: Web User - Read only
docker compose exec garage /garage bucket allow \
  --read media \
  --key web-client

# Client 2: Mobile App - Read only
docker compose exec garage /garage bucket allow \
  --read media \
  --key mobile-app
```

### Step 4: Verify Permissions

```bash
# See all keys with their permissions
docker compose exec garage /garage key list

# See detailed info for media bucket
docker compose exec garage /garage bucket info media

# See who has what access
docker compose exec garage /garage bucket allow --info media
```

**Output example:**

```
Key Name              Permissions              Buckets
upload-handler        read, write              media
image-processor       read, write              media
analytics-reader      read                     media
web-client            read                     media
mobile-app            read                     media
```

---

## Access Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  Upload Handler Service                      │
│ (Key: upload-handler | Access: read+write)                  │
└────────────────────────┬────────────────────────────────────┘
                         │ Uploads file to "media" bucket
                         ↓
         ┌───────────────────────────────┐
         │   Garage S3 "media" Bucket    │
         │  ┌─────────────────────────┐  │
         │  │ image1.jpg              │  │
         │  │ image2.png              │  │
         │  └─────────────────────────┘  │
         └────────┬────────────────────┬─┘
                  │                    │
        ┌─────────┴────┐      ┌────────┴──────┐
        │              │      │               │
        ↓              ↓      ↓               ↓
  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │   Image      │ │  Analytics   │ │ Web Client   │
  │  Processor   │ │   Service    │ │ (Read-Only)  │
  │ (read+write) │ │ (read-only)  │ │              │
  └──────────────┘ └──────────────┘ └──────────────┘
```

---

## Real-World Example: Photo Sharing App

### Services & Clients

**Internal Services (Docker Network):**
1. **Photo Upload API** - Upload Handler
2. **Image Resizer** - Generates thumbnails
3. **Usage Stats** - Analytics

**External Clients:**
4. **Web Browser** - Users download photos
5. **Mobile App** - Users download photos

### Complete Setup

#### 1. Create Bucket

```bash
docker compose exec garage /garage bucket create photos
```

#### 2. Create Access Keys

```bash
# Photo Upload API (service in same docker network)
docker compose exec garage /garage key create --name "upload-api" upload-api

# Image Resizer (service in same docker network)
docker compose exec garage /garage key create --name "image-resizer" image-resizer

# Usage Stats (service in same docker network)
docker compose exec garage /garage key create --name "stats-service" stats-service

# Web Browser (external client)
docker compose exec garage /garage key create --name "web-browser" web-browser

# Mobile App (external client)
docker compose exec garage /garage key create --name "mobile-client" mobile-client
```

#### 3. Grant Permissions

```bash
# Photo Upload API: upload + validate
docker compose exec garage /garage bucket allow \
  --read --write photos \
  --key upload-api

# Image Resizer: read originals, write thumbnails
docker compose exec garage /garage bucket allow \
  --read --write photos \
  --key image-resizer

# Usage Stats: read-only access to count/analyze
docker compose exec garage /garage bucket allow \
  --read photos \
  --key stats-service

# Web Browser: read-only for viewing
docker compose exec garage /garage bucket allow \
  --read photos \
  --key web-browser

# Mobile App: read-only for viewing
docker compose exec garage /garage bucket allow \
  --read photos \
  --key mobile-client
```

#### 4. Get Credentials

```bash
# Get credentials for each service/client
docker compose exec garage /garage key info upload-api
docker compose exec garage /garage key info image-resizer
docker compose exec garage /garage key info stats-service
docker compose exec garage /garage key info web-browser
docker compose exec garage /garage key info mobile-client
```

Each command outputs:
```
Key name: upload-api
Access key ID: GKxxxxx
Secret access key: xxxxxx
```

---

## How Each Service Uses the Credentials

### Service 1: Upload API (read+write)

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='https://s3.example.com',
    aws_access_key_id='GKxxxxx',      # upload-api key
    aws_secret_access_key='xxxxxx',
    region_name='garage'
)

# Can write (upload)
s3.put_object(
    Bucket='photos',
    Key='user-123/photo.jpg',
    Body=file_data
)

# Can read (verify)
response = s3.get_object(Bucket='photos', Key='user-123/photo.jpg')
```

### Service 2: Image Resizer (read+write)

```javascript
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
    endpoint: 'https://s3.example.com',
    accessKeyId: 'GKxxxxx',      // image-resizer key
    secretAccessKey: 'xxxxxx',
    region: 'garage'
});

// Can read (original photos)
s3.getObject({Bucket: 'photos', Key: 'original.jpg'}, (err, data) => {
    // Process image...

    // Can write (save thumbnail)
    s3.putObject({
        Bucket: 'photos',
        Key: 'thumbs/original-thumb.jpg',
        Body: processedImage
    });
});
```

### Service 3: Analytics (read-only)

```bash
#!/bin/bash

# Configure AWS CLI with analytics credentials
aws configure set aws_access_key_id GKxxxxx      # analytics-reader key
aws configure set aws_secret_access_key xxxxxx

# Can list and read
aws s3 ls s3://photos --endpoint-url https://s3.example.com --recursive

# Can download for analysis
aws s3 cp s3://photos/stats.json . --endpoint-url https://s3.example.com

# Cannot write (would fail)
aws s3 cp analysis.json s3://photos/ --endpoint-url https://s3.example.com
# Error: Access Denied
```

### Client 1: Web Browser (read-only)

```html
<html>
<head>
    <script src="https://sdk.amazonaws.com/js/aws-sdk-2.x.x.min.js"></script>
</head>
<body>
    <img src="" id="photo">

    <script>
    const s3 = new AWS.S3({
        endpoint: 'https://s3.example.com',
        accessKeyId: 'GKxxxxx',      // web-browser key
        secretAccessKey: 'xxxxxx',
        region: 'garage'
    });

    // Can read
    s3.getObject({Bucket: 'photos', Key: 'photo.jpg'}, (err, data) => {
        const url = URL.createObjectURL(new Blob([data.Body]));
        document.getElementById('photo').src = url;
    });

    // Cannot write (would fail)
    s3.putObject({
        Bucket: 'photos',
        Key: 'hack.jpg',
        Body: maliciousData
    }).catch(err => console.log('Access Denied'));
    </script>
</body>
</html>
```

### Client 2: Mobile App (read-only)

```swift
import AWSS3

class PhotoDownloader {
    let s3 = AWSS3(
        region: .USEast1,
        credentialsProvider: AWSStaticCredentialsProvider(
            accessKey: "GKxxxxx",      // mobile-client key
            secretKey: "xxxxxx"
        )
    )

    func downloadPhoto(key: String) {
        let expression = AWSS3TransferUtilityDownloadExpression()

        s3.transferUtility.downloadData(
            fromBucket: "photos",
            key: key,
            expression: expression
        ) { _, _, data in
            // Use downloaded photo
        }
    }

    // This would fail:
    func uploadPhoto(data: Data) {
        // s3.transferUtility.uploadData(...)
        // Error: Access Denied
    }
}
```

---

## Permission Matrix

Quick reference table:

| Service/Client | Key | Bucket | List | Read | Write | Delete |
|---|---|---|---|---|---|---|
| Upload API | upload-api | photos | ✅ | ✅ | ✅ | ❌ |
| Image Resizer | image-resizer | photos | ✅ | ✅ | ✅ | ❌ |
| Analytics | analytics-reader | photos | ✅ | ✅ | ❌ | ❌ |
| Web Browser | web-browser | photos | ✅ | ✅ | ❌ | ❌ |
| Mobile App | mobile-client | photos | ✅ | ✅ | ❌ | ❌ |

**Legend:**
- ✅ = Allowed
- ❌ = Denied (Access Denied error)

---

## Testing Access

### Test Each Key

```bash
# Export credentials for testing
export AWS_ACCESS_KEY_ID="GKxxxxx"
export AWS_SECRET_ACCESS_KEY="xxxxxx"
export AWS_S3_ENDPOINT="https://s3.example.com"

# Test: Can read from 'photos' bucket
aws s3 ls s3://photos --endpoint-url $AWS_S3_ENDPOINT
# Output: list of files ✅

# Test: Can write to 'photos' bucket (if key has write permission)
echo "test" > test.txt
aws s3 cp test.txt s3://photos/test.txt --endpoint-url $AWS_S3_ENDPOINT
# Output: upload successful ✅

# Test: Cannot write (if key is read-only)
aws s3 cp test.txt s3://photos/test.txt --endpoint-url $AWS_S3_ENDPOINT
# Output: An error occurred (AccessDenied) ❌
```

### Test Different Keys

```bash
#!/bin/bash

# Function to test a key
test_key() {
    local key_name=$1
    local access_key=$2
    local secret_key=$3

    echo "Testing key: $key_name"

    # Try to read
    AWS_ACCESS_KEY_ID=$access_key \
    AWS_SECRET_ACCESS_KEY=$secret_key \
    aws s3 ls s3://photos --endpoint-url https://s3.example.com

    if [ $? -eq 0 ]; then
        echo "  ✅ Read access: OK"
    else
        echo "  ❌ Read access: DENIED"
    fi

    # Try to write
    echo "test" | AWS_ACCESS_KEY_ID=$access_key \
    AWS_SECRET_ACCESS_KEY=$secret_key \
    aws s3 cp - s3://photos/test-$key_name.txt --endpoint-url https://s3.example.com

    if [ $? -eq 0 ]; then
        echo "  ✅ Write access: OK"
    else
        echo "  ❌ Write access: DENIED"
    fi

    echo ""
}

# Test each key
test_key "upload-api" "GK_upload_key" "upload_secret"
test_key "analytics-reader" "GK_analytics_key" "analytics_secret"
test_key "web-browser" "GK_web_key" "web_secret"
```

---

## Managing Permissions

### Add Write Permission to Read-Only Key

```bash
# analytics-reader currently has read-only
# Grant write permission
docker compose exec garage /garage bucket allow \
  --read --write photos \
  --key analytics-reader

# Verify
docker compose exec garage /garage bucket allow --info photos
```

### Remove Write Permission (Keep Read)

```bash
# Remove all permissions first
docker compose exec garage /garage bucket deny photos --key analytics-reader

# Re-add read-only
docker compose exec garage /garage bucket allow \
  --read photos \
  --key analytics-reader
```

### Remove All Access

```bash
# Deny all access to this key
docker compose exec garage /garage bucket deny photos --key web-browser

# Verify (key should not appear in list)
docker compose exec garage /garage bucket allow --info photos
```

### Delete a Key

```bash
# Remove the key entirely
docker compose exec garage /garage key delete web-browser

# All buckets using this key lose access
```

---

## Production Checklist

- [ ] Create bucket for each logical grouping (e.g., "photos", "videos", "documents")
- [ ] Create separate key for each service/client
- [ ] Grant only minimum permissions needed:
  - Services that write: `--read --write`
  - Services that read metadata: `--read`
  - Clients/external users: `--read`
- [ ] Document which key belongs to which service:
  ```
  upload-api      → Photo Upload Service (Docker) → internal
  image-resizer   → Image Processing (Docker) → internal
  analytics       → Analytics Dashboard (Docker) → internal
  web-browser     → End Users (Browser) → external
  mobile-app      → Mobile Users (App) → external
  ```
- [ ] Store credentials securely:
  - Services: Docker Compose `.env` or secrets manager
  - Clients: Environment variables or secure config
  - Never hardcode in code
- [ ] Rotate keys periodically
- [ ] Monitor access per key via Prometheus metrics
- [ ] Test each key before deploying

---

## Monitoring Access per Key

### Track Access by Service

Use Prometheus metrics to see which service accessed what:

```promql
# S3 requests per service (if you tag metrics by key/service)
rate(s3_request_counter{service="upload-api"}[5m])
rate(s3_request_counter{service="image-resizer"}[5m])
rate(s3_request_counter{service="analytics"}[5m])

# Errors per service
rate(s3_error_counter{service="web-browser"}[5m])
```

### Alert Rules

```yaml
groups:
  - name: bucket-access
    rules:
      # Alert if analytics service tries to write (should be read-only)
      - alert: AnalyticsWriteAttempt
        expr: increase(s3_error_counter{service="analytics",error="access_denied"}[5m]) > 0
        annotations:
          summary: "Analytics service attempted write (access denied)"

      # Alert if any client makes too many requests
      - alert: ClientHighAccessRate
        expr: rate(s3_request_counter{client="web-browser"}[5m]) > 1000
        annotations:
          summary: "High request rate from web-browser"
```

---

## Troubleshooting

### "Access Denied" When Should Have Permission

```bash
# Verify key actually has permission
docker compose exec garage /garage bucket allow --info photos

# Check which bucket is being accessed
# Service might be trying to access wrong bucket

# Verify endpoint URL includes bucket name correctly:
# Vhost style: mybucket.s3.example.com/path
# Path style: s3.example.com/mybucket/path
```

### Can't Find Credentials

```bash
# Get credentials for a key
docker compose exec garage /garage key info upload-api

# Output shows:
# Access key ID: GKxxxxx
# Secret access key: xxxxxx

# Use these in AWS SDK/CLI
```

### Key Not Working After Restart

```bash
# Keys persist in Garage's database
# They survive container restarts

# Verify key still exists
docker compose exec garage /garage key list

# Verify permissions still exist
docker compose exec garage /garage bucket allow --info photos

# If missing, re-create:
docker compose exec garage /garage key create --name "upload-api" upload-api
docker compose exec garage /garage bucket allow --read --write photos --key upload-api
```

---

## Quick Reference Commands

```bash
# List all keys
docker compose exec garage /garage key list

# List all buckets
docker compose exec garage /garage bucket list

# Create bucket
docker compose exec garage /garage bucket create photos

# Create key
docker compose exec garage /garage key create --name "my-service" my-service

# Grant read+write to bucket
docker compose exec garage /garage bucket allow --read --write photos --key my-service

# Grant read-only to bucket
docker compose exec garage /garage bucket allow --read photos --key my-service

# Revoke all access
docker compose exec garage /garage bucket deny photos --key my-service

# Get key credentials
docker compose exec garage /garage key info my-service

# Delete key
docker compose exec garage /garage key delete my-service

# See bucket details
docker compose exec garage /garage bucket info photos

# See all bucket permissions
docker compose exec garage /garage bucket allow --info photos
```

---

## References

- [Garage Key Management](https://garagehq.deuxfleurs.fr/documentation/reference-manual/admin-api/)
- [Garage Bucket Operations](https://garagehq.deuxfleurs.fr/documentation/reference-manual/admin-api/)
- [AWS S3 API Compatibility](https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/)
