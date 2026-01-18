#!/bin/bash
# Initialize Garage cluster layout
# Run this script after starting Garage for the first time

set -e

echo "Initializing Garage cluster..."
echo ""

# Wait for Garage to be healthy
echo "Waiting for Garage to start..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker compose exec -T garage /garage status >/dev/null 2>&1; then
        echo "✓ Garage is running"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Error: Garage did not start within expected time"
    echo "Check logs with: docker compose logs garage"
    exit 1
fi

echo ""

# Get node ID
echo "Getting node ID..."
NODE_ID=$(docker compose exec -T garage /garage node id -q 2>/dev/null | tr -d '\r')

if [ -z "$NODE_ID" ]; then
    echo "Error: Could not get node ID"
    exit 1
fi

echo "✓ Node ID: $NODE_ID"
echo ""

# Function to convert human-readable sizes to bytes
parse_size() {
    local size=$1
    local bytes=0

    # Remove spaces
    size=$(echo "$size" | tr -d ' ')

    # Convert to lowercase for case-insensitive matching
    size_lower=$(echo "$size" | tr '[:upper:]' '[:lower:]')

    # Extract number and unit
    if [[ $size_lower =~ ^([0-9.]+)([kmgt])?b?$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            k) bytes=$(echo "$num * 1024" | bc) ;;
            m) bytes=$(echo "$num * 1024 * 1024" | bc) ;;
            g) bytes=$(echo "$num * 1024 * 1024 * 1024" | bc) ;;
            t) bytes=$(echo "$num * 1024 * 1024 * 1024 * 1024" | bc) ;;
            *)
                # No unit, assume bytes
                bytes=$(echo "$num" | bc)
                ;;
        esac
    else
        echo "Error: Invalid size format: $size"
        echo "Examples: 100G, 0.5T, 1.5TB, 500GB, 1024M"
        exit 1
    fi

    # Convert to integer (bc returns decimal)
    echo "${bytes%.*}"
}

# Set capacity (default 100GB, can be overridden with first argument)
CAPACITY_INPUT=${1:-100G}
CAPACITY=$(parse_size "$CAPACITY_INPUT")

# Calculate for display
if [ "$CAPACITY" -ge 1099511627776 ]; then
    CAPACITY_DISPLAY=$((CAPACITY / 1099511627776))
    CAPACITY_UNIT="TB"
elif [ "$CAPACITY" -ge 1073741824 ]; then
    CAPACITY_DISPLAY=$((CAPACITY / 1073741824))
    CAPACITY_UNIT="GB"
elif [ "$CAPACITY" -ge 1048576 ]; then
    CAPACITY_DISPLAY=$((CAPACITY / 1048576))
    CAPACITY_UNIT="MB"
else
    CAPACITY_DISPLAY=$CAPACITY
    CAPACITY_UNIT="B"
fi

echo "Configuring layout with ${CAPACITY_DISPLAY}${CAPACITY_UNIT} capacity..."
echo ""

# Assign node to zone
docker compose exec -T garage /garage layout assign -z dc1 -c "$CAPACITY" "$NODE_ID"

echo ""
echo "Current layout:"
docker compose exec -T garage /garage layout show

echo ""
echo "Applying layout (version 1)..."
docker compose exec -T garage /garage layout apply --version 1

echo ""
echo "✓ Garage cluster initialized successfully!"
echo ""
echo "Next steps - Create your first bucket and access key:"
echo ""
echo "  # Create a bucket"
echo "  docker compose exec garage /garage bucket create my-bucket"
echo ""
echo "  # Create an access key"
echo "  docker compose exec garage /garage key create my-key"
echo ""
echo "  # Grant permissions"
echo "  docker compose exec garage /garage bucket allow --read --write my-bucket --key my-key"
echo ""
echo "  # View the access key credentials"
echo "  docker compose exec garage /garage key info my-key"
echo ""
echo "You can now use the S3 API at: https://s3.${DOMAIN:-your-domain.com}"
echo "And buckets at: https://bucket-name.s3.${DOMAIN:-your-domain.com}"
echo ""
