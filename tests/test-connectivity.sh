#!/bin/bash
# Test S3 Garage connectivity
# Verifies that all components are properly connected

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "           Connectivity Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Docker services running
echo "TEST 1: Docker Services Status"
echo "───────────────────────────────────────────────────────────────"
if ! command -v docker &> /dev/null; then
    echo "✗ Docker is not installed"
    exit 1
fi

echo "✓ Docker is installed"

if ! docker compose ps &> /dev/null; then
    echo "✗ Docker compose is not working"
    exit 1
fi

echo "✓ Docker compose is working"
echo ""

# Test 2: Services running
echo "TEST 2: Service Status"
echo "───────────────────────────────────────────────────────────────"
GARAGE_RUNNING=$(docker compose ps garage | grep -c "Up" || echo "0")
RATE_LIMITER_RUNNING=$(docker compose ps rate-limiter | grep -c "Up" || echo "0")

if [ "$GARAGE_RUNNING" -gt 0 ]; then
    echo "✓ Garage service is running"
else
    echo "✗ Garage service is not running"
fi

if [ "$RATE_LIMITER_RUNNING" -gt 0 ]; then
    echo "✓ Rate limiter service is running"
else
    echo "✗ Rate limiter service is not running"
fi
echo ""

# Test 3: Port availability
echo "TEST 3: Port Availability"
echo "───────────────────────────────────────────────────────────────"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3900/health &> /dev/null; then
    echo "✓ Port 3900 (Rate limiter) is accessible"
else
    echo "✗ Port 3900 (Rate limiter) is not accessible"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:3901/ &> /dev/null; then
    echo "✓ Port 3901 (Garage) is accessible"
else
    echo "✗ Port 3901 (Garage) is not accessible"
fi
echo ""

# Test 4: Network connectivity
echo "TEST 4: Inter-service Communication"
echo "───────────────────────────────────────────────────────────────"
RATE_LIMITER_TO_GARAGE=$(docker compose exec -T rate-limiter curl -s -o /dev/null -w "%{http_code}" http://garage:3901/ 2>/dev/null || echo "000")

if [ "$RATE_LIMITER_TO_GARAGE" != "000" ]; then
    echo "✓ Rate limiter can reach Garage (Status: $RATE_LIMITER_TO_GARAGE)"
else
    echo "✗ Rate limiter cannot reach Garage"
fi
echo ""

# Test 5: Configuration
echo "TEST 5: Configuration Files"
echo "───────────────────────────────────────────────────────────────"
if [ -f "docker-compose.yml" ]; then
    echo "✓ docker-compose.yml exists"
else
    echo "✗ docker-compose.yml not found"
fi

if [ -f ".env" ]; then
    echo "✓ .env file exists"
else
    echo "✗ .env file not found"
    echo "  Run: ./scripts/generate-secrets.sh"
fi

if [ -f "config/garage.toml" ]; then
    echo "✓ config/garage.toml exists"
else
    echo "✗ config/garage.toml not found"
fi

if [ -f "config/nginx-ratelimit.conf" ]; then
    echo "✓ config/nginx-ratelimit.conf exists"
else
    echo "✗ config/nginx-ratelimit.conf not found"
fi
echo ""

# Test 6: Environment variables
echo "TEST 6: Environment Variables"
echo "───────────────────────────────────────────────────────────────"
if [ -f ".env" ]; then
    DOMAIN=$(grep "^DOMAIN=" .env | cut -d= -f2)
    RPC_SECRET=$(grep "^RPC_SECRET=" .env | cut -d= -f2)
    ADMIN_TOKEN=$(grep "^ADMIN_TOKEN=" .env | cut -d= -f2)

    echo "✓ DOMAIN: $DOMAIN"
    if [ -n "$RPC_SECRET" ]; then
        echo "✓ RPC_SECRET: Set (${RPC_SECRET:0:16}...)"
    else
        echo "✗ RPC_SECRET: Not set"
    fi

    if [ -n "$ADMIN_TOKEN" ]; then
        echo "✓ ADMIN_TOKEN: Set (${ADMIN_TOKEN:0:16}...)"
    else
        echo "✗ ADMIN_TOKEN: Not set"
    fi
else
    echo "⚠ .env file not found"
fi
echo ""

# Test 7: Data directories
echo "TEST 7: Data Directories"
echo "───────────────────────────────────────────────────────────────"
if [ -d "data/garage-meta" ]; then
    echo "✓ data/garage-meta directory exists"
    META_SIZE=$(du -sh data/garage-meta | cut -f1)
    echo "  Size: $META_SIZE"
else
    echo "✗ data/garage-meta directory not found"
fi

if [ -d "data/garage-data" ]; then
    echo "✓ data/garage-data directory exists"
    DATA_SIZE=$(du -sh data/garage-data | cut -f1)
    echo "  Size: $DATA_SIZE"
else
    echo "✗ data/garage-data directory not found"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "                  Connectivity Test Complete"
echo "═══════════════════════════════════════════════════════════════"
