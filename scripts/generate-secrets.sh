#!/bin/bash
# Generate secure tokens for Garage configuration

set -e

# Check if .env already exists
if [ -f .env ]; then
    echo "Error: .env file already exists"
    echo "Remove it first if you want to regenerate secrets, or edit it manually"
    exit 1
fi

# Check if .env.example exists
if [ ! -f .env.example ]; then
    echo "Error: .env.example not found"
    exit 1
fi

echo "Generating secure tokens for Garage..."
echo ""

# Generate secrets
RPC_SECRET=$(openssl rand -hex 32)
ADMIN_TOKEN=$(openssl rand -base64 32)
METRICS_TOKEN=$(openssl rand -base64 32)

echo "Generated secrets:"
echo "  RPC_SECRET: ${RPC_SECRET:0:16}..."
echo "  ADMIN_TOKEN: ${ADMIN_TOKEN:0:16}..."
echo "  METRICS_TOKEN: ${METRICS_TOKEN:0:16}..."
echo ""

# Copy template
cp .env.example .env

# Update .env with generated secrets
if command -v sed >/dev/null 2>&1; then
    # Use different sed syntax for macOS vs Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^RPC_SECRET=.*|RPC_SECRET=${RPC_SECRET}|" .env
        sed -i '' "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=${ADMIN_TOKEN}|" .env
        sed -i '' "s|^METRICS_TOKEN=.*|METRICS_TOKEN=${METRICS_TOKEN}|" .env
    else
        # Linux
        sed -i "s|^RPC_SECRET=.*|RPC_SECRET=${RPC_SECRET}|" .env
        sed -i "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=${ADMIN_TOKEN}|" .env
        sed -i "s|^METRICS_TOKEN=.*|METRICS_TOKEN=${METRICS_TOKEN}|" .env
    fi
else
    echo "Warning: sed not found, .env created but secrets not populated"
    echo "Please add these values manually to .env:"
    echo "  RPC_SECRET=${RPC_SECRET}"
    echo "  ADMIN_TOKEN=${ADMIN_TOKEN}"
    echo "  METRICS_TOKEN=${METRICS_TOKEN}"
fi

echo "✓ Created .env file with generated secrets"
echo ""
echo "Next steps:"
echo "  1. Edit .env and set your DOMAIN (e.g., example.com)"
echo "  2. Review and adjust storage paths if needed"
echo "  3. Run: docker compose up -d"
echo "  4. Run: ./scripts/init-garage.sh"
echo ""
