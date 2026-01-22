#!/bin/bash
set -e

# Check required variables
if [ -z "$RPC_SECRET" ] || [ -z "$ADMIN_TOKEN" ] || [ -z "$METRICS_TOKEN" ]; then
    echo "Error: Required security tokens not set!"
    exit 1
fi

echo "Initializing S3 Garage Service..."

# 1. Generate Garage Configuration
echo "Generating Garage config..."
envsubst < /etc/garage.toml.template > /etc/garage.toml

# 2. Start Nginx (Rate Limiter)
echo "Starting Nginx..."
nginx

# 3. Start Garage
echo "Starting Garage..."
echo "S3 Region: ${S3_REGION}"
echo "Domain: ${DOMAIN}"

# Exec into garage to make it the main process
exec /usr/local/bin/garage -c /etc/garage.toml server
