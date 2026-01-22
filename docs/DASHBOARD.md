# S3 Garage Dashboard

A local, lightweight web dashboard to monitor your Garage S3 cluster, browse buckets, and inspect objects.

## Access

*   **URL**: [http://localhost:8501](http://localhost:8501)
*   **Port**: 8501

## Setup & Login

The dashboard requires S3 credentials to list buckets and Admin credentials (token) to show cluster health.

### 1. Create Dashboard Credentials

Run this command to create a read-only or read/write key specifically for the dashboard:

```bash
docker compose exec s3 /usr/local/bin/garage key create dashboard
```

*Example Output:*
```
Key ID: GKxxxxxxxxxxxxxxxxxxxxxxxx
Secret key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2. Login

You have two options:

**Option A: Manual Login (UI)**
1.  Open the dashboard.
2.  In the left sidebar, paste your **Access Key ID** and **Secret Access Key**.
3.  The Admin Token is pre-filled from your `.env` configuration.

**Option B: Auto-Login (.env)**
To auto-login on startup, add the credentials to your `.env` file:

```bash
echo "AWS_ACCESS_KEY_ID=GKxxxxxxxx" >> .env
echo "AWS_SECRET_ACCESS_KEY=xxxxxxxx" >> .env
docker compose up -d
```

## Features

### 📊 Cluster Status
Shows real-time health of the S3 service and Admin API.
*   **Service Health**: Reachability of the Garage node.
*   **Nodes Online**: Number of nodes in the cluster.
*   **Storage Used**: Total raw storage used by the cluster (from metrics).

### 📦 Buckets Browser
Lists all buckets available to your credentials.
*   **Name**: Bucket name.
*   **Created**: Creation timestamp.

### 📂 Object Explorer
Select a bucket to view its contents.
*   **Key**: File path/name.
*   **Size**: File size in KB.
*   **Last Modified**: Upload timestamp.

## Security

By default, the dashboard interface is accessible to anyone who can reach port 8501. While S3 data access requires keys, exposing the dashboard publicly is not recommended.

### 1. Bind to Localhost (Recommended)
If running on a VPS or public server, prevent public access by binding the port only to localhost.

Edit `docker-compose.yml`:
```yaml
ports:
  - "127.0.0.1:8501:8501"
```

You can then access it securely via SSH tunneling:
```bash
ssh -L 8501:localhost:8501 user@your-server.com
```

### 2. Password Protection
To expose the dashboard publicly, you **must** use a reverse proxy with authentication (Basic Auth or OAuth).

**Caddy Example (Basic Auth):**
```caddyfile
dashboard.example.com {
    reverse_proxy localhost:8501
    basicauth {
        # Username "admin", generate hash with `caddy hash-password`
        admin $2a$14$....
    }
}
```

## Troubleshooting

### "No buckets found"
*   Ensure your Access Key/Secret Key are correct.
*   Ensure the key has permission to see buckets.
    *   To grant access: `docker compose exec s3 /usr/local/bin/garage bucket allow --read my-bucket --key dashboard`

### "Service Health: Unreachable"
*   Ensure the `s3` container is running (`docker compose ps`).
*   Check if `ADMIN_TOKEN` is correctly set in `.env` and passed to the container.

### "Connection Refused" (localhost:8501)
*   Ensure the dashboard container is running.
*   Check logs: `docker compose logs dashboard`
