# External Reverse Proxy Configuration

To use virtual-host style bucket access (e.g., `https://my-bucket.s3.example.com`), you must configure your external reverse proxy (Nginx, Caddy, Traefik) to handle wildcard subdomains and forward traffic to the Garage container.

## DNS Setup

Create a wildcard DNS record for your domain:

```
Type: A (or CNAME)
Host: *.s3
Value: YOUR_SERVER_IP
```

This ensures requests for `anything.s3.example.com` reach your server.

## Garage Configuration

Your `garage.toml` must have the `root_domain` set (this is already handled by our setup script using the `DOMAIN` env var):

```toml
[s3_api]
root_domain = ".s3.example.com"
```

## Reverse Proxy Examples

These examples assume your Garage/OpenResty container is running on port `3900`.

### Nginx (External)

If you have an Nginx instance terminating TLS in front of Docker:

```nginx
server {
    listen 443 ssl;
    server_name s3.example.com *.s3.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Allow large uploads
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:3900;
        
        # Preserves the bucket.s3.example.com host header
        proxy_set_header Host $host;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Disable buffering for speed
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
```

### Caddy

Caddy handles certificates automatically.

```caddyfile
*.s3.example.com, s3.example.com {
    reverse_proxy localhost:3900 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

### Traefik

If using Traefik as a Docker label:

```yaml
services:
  s3:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.s3.rule=Host(`s3.example.com`) || HostRegexp(`{bucket:[a-z0-9-]+}.s3.example.com`)"
      - "traefik.http.routers.s3.entrypoints=websecure"
      - "traefik.http.routers.s3.tls.certresolver=myresolver"
      - "traefik.http.services.s3.loadbalancer.server.port=3900"
```

## Testing

Once configured, you should be able to access buckets via subdomains:

```bash
# Path style (Always works)
curl https://s3.example.com/my-bucket/file.txt

# Vhost style (Requires wildcard DNS + Proxy setup)
curl https://my-bucket.s3.example.com/file.txt
```
