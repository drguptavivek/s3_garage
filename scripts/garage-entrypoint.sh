#!/bin/sh
# Garage entrypoint script
# Substitutes environment variables in garage.toml template and starts Garage

set -e

# Check if required environment variables are set
if [ -z "$RPC_SECRET" ]; then
    echo "Error: RPC_SECRET environment variable is not set"
    exit 1
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Error: ADMIN_TOKEN environment variable is not set"
    exit 1
fi

if [ -z "$METRICS_TOKEN" ]; then
    echo "Error: METRICS_TOKEN environment variable is not set"
    exit 1
fi

# Substitute environment variables in template
echo "Substituting environment variables in configuration..."
envsubst < /etc/garage.toml.template > /tmp/garage.toml

# Verify configuration was created
if [ ! -f /tmp/garage.toml ]; then
    echo "Error: Failed to create garage.toml"
    exit 1
fi

echo "Starting Garage..."
echo "S3 Region: ${S3_REGION}"
echo "Domain: ${DOMAIN}"

# Start Garage with the generated configuration
exec /garage -c /tmp/garage.toml "$@"
