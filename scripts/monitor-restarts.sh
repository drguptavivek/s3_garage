#!/bin/bash
# Monitor for restart loops in Garage and Rate Limiter services
# Detects if containers are restarting continuously

set -e

INTERVAL=5  # Check every 5 seconds
HISTORY_FILE="/tmp/garage_restart_history.txt"

echo "═══════════════════════════════════════════════════════════════"
echo "           Restart Loop Monitor"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Monitoring for restart loops (Ctrl+C to stop)..."
echo "Updates every ${INTERVAL} seconds"
echo ""

# Initialize history
> "$HISTORY_FILE"

while true; do
    GARAGE_RESTARTS=$(docker inspect garage 2>/dev/null | jq -r '.RestartCount // 0' || echo "N/A")
    RATE_LIMITER_RESTARTS=$(docker inspect garage-rate-limiter 2>/dev/null | jq -r '.RestartCount // 0' || echo "N/A")

    GARAGE_HEALTH=$(docker inspect garage 2>/dev/null | jq -r '.State.Health.Status // "none"' || echo "unknown")
    RATE_LIMITER_HEALTH=$(docker inspect garage-rate-limiter 2>/dev/null | jq -r '.State.Health.Status // "none"' || echo "unknown")

    GARAGE_STATUS=$(docker inspect garage 2>/dev/null | jq -r '.State.Status // "unknown"' || echo "unknown")
    RATE_LIMITER_STATUS=$(docker inspect garage-rate-limiter 2>/dev/null | jq -r '.State.Status // "unknown"' || echo "unknown")

    TIMESTAMP=$(date '+%H:%M:%S')

    # Display current status
    clear
    echo "═══════════════════════════════════════════════════════════════"
    echo "           Restart Loop Monitor - $TIMESTAMP"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Garage status
    echo "GARAGE SERVICE:"
    echo "  Status: $GARAGE_STATUS"
    echo "  Health: $GARAGE_HEALTH"
    echo "  Restarts: $GARAGE_RESTARTS"

    # Check if restarting
    if [ "$GARAGE_STATUS" = "restarting" ]; then
        echo "  ⚠️  CURRENTLY RESTARTING"
    fi

    echo ""

    # Rate Limiter status
    echo "RATE LIMITER SERVICE:"
    echo "  Status: $RATE_LIMITER_STATUS"
    echo "  Health: $RATE_LIMITER_HEALTH"
    echo "  Restarts: $RATE_LIMITER_RESTARTS"

    # Check if restarting
    if [ "$RATE_LIMITER_STATUS" = "restarting" ]; then
        echo "  ⚠️  CURRENTLY RESTARTING"
    fi

    echo ""

    # Store in history and check for rapid increases
    echo "$TIMESTAMP|$GARAGE_RESTARTS|$RATE_LIMITER_RESTARTS" >> "$HISTORY_FILE"

    # Keep last 20 entries in history
    LAST_20=$(tail -20 "$HISTORY_FILE")
    echo "$LAST_20" > "$HISTORY_FILE"

    # Analyze restart pattern (if we have at least 3 data points)
    LINE_COUNT=$(wc -l < "$HISTORY_FILE")
    if [ "$LINE_COUNT" -ge 3 ]; then
        # Get restart counts from 15 seconds ago and now
        FIRST_LINE=$(head -1 "$HISTORY_FILE")
        LAST_LINE=$(tail -1 "$HISTORY_FILE")

        GARAGE_FIRST=$(echo "$FIRST_LINE" | cut -d'|' -f2)
        GARAGE_LAST=$(echo "$LAST_LINE" | cut -d'|' -f2)

        RATE_LIMITER_FIRST=$(echo "$FIRST_LINE" | cut -d'|' -f3)
        RATE_LIMITER_LAST=$(echo "$LAST_LINE" | cut -d'|' -f3)

        GARAGE_INCREASE=$((GARAGE_LAST - GARAGE_FIRST))
        RATE_LIMITER_INCREASE=$((RATE_LIMITER_LAST - RATE_LIMITER_FIRST))

        echo "RESTART TREND (Last 15+ seconds):"
        echo "  Garage restarts increase: +$GARAGE_INCREASE"
        echo "  Rate Limiter restarts increase: +$RATE_LIMITER_INCREASE"
        echo ""

        # Warn if increasing rapidly
        if [ "$GARAGE_INCREASE" -gt 2 ]; then
            echo "  ⚠️  WARNING: Garage appears to be in a restart loop!"
            echo "      Run: docker compose logs garage | tail -20"
        fi

        if [ "$RATE_LIMITER_INCREASE" -gt 2 ]; then
            echo "  ⚠️  WARNING: Rate Limiter appears to be in a restart loop!"
            echo "      Run: docker compose logs rate-limiter | tail -20"
        fi

        if [ "$GARAGE_INCREASE" -le 0 ] && [ "$RATE_LIMITER_INCREASE" -le 0 ]; then
            echo "  ✓ No restart loop detected"
        fi
    else
        echo "RESTART TREND: Collecting data... ($LINE_COUNT/3 samples)"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Wait before next check
    sleep "$INTERVAL"
done
