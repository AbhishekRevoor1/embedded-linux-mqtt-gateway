#!/bin/sh

# Health Check Script
# Runs after boot to verify system is healthy
# If fails, triggers rollback to previous partition

HEALTH_LOG="/data/health_check.log"
MAX_BOOT_ATTEMPTS=3
BOOT_COUNT_FILE="/data/boot_count"

echo "════════════════════════════════════════" | tee -a $HEALTH_LOG
echo "Health Check - $(date)" | tee -a $HEALTH_LOG
echo "════════════════════════════════════════" | tee -a $HEALTH_LOG

# Initialize boot counter
if [ ! -f "$BOOT_COUNT_FILE" ]; then
    echo "0" > $BOOT_COUNT_FILE
fi

BOOT_COUNT=$(cat $BOOT_COUNT_FILE)
BOOT_COUNT=$((BOOT_COUNT + 1))
echo $BOOT_COUNT > $BOOT_COUNT_FILE

echo "Boot attempt: $BOOT_COUNT/$MAX_BOOT_ATTEMPTS" | tee -a $HEALTH_LOG

# Check 1: WiFi connectivity
echo -n "Checking WiFi... " | tee -a $HEALTH_LOG
if ip addr show wlan0 | grep -q "inet "; then
    echo "✅ PASS" | tee -a $HEALTH_LOG
    WIFI_OK=1
else
    echo "❌ FAIL" | tee -a $HEALTH_LOG
    WIFI_OK=0
fi

# Check 2: SSH server
echo -n "Checking SSH... " | tee -a $HEALTH_LOG
if ps | grep -q "[s]shd"; then
    echo "✅ PASS" | tee -a $HEALTH_LOG
    SSH_OK=1
else
    echo "❌ FAIL" | tee -a $HEALTH_LOG
    SSH_OK=0
fi

# Check 3: MQTT broker
echo -n "Checking MQTT... " | tee -a $HEALTH_LOG
if ps | grep -q "[m]osquitto"; then
    echo "✅ PASS" | tee -a $HEALTH_LOG
    MQTT_OK=1
else
    echo "❌ FAIL" | tee -a $HEALTH_LOG
    MQTT_OK=0
fi

# Overall health
if [ $WIFI_OK -eq 1 ] && [ $SSH_OK -eq 1 ] && [ $MQTT_OK -eq 1 ]; then
    echo "" | tee -a $HEALTH_LOG
    echo "✅ SYSTEM HEALTHY - Marking as good" | tee -a $HEALTH_LOG
    echo "0" > $BOOT_COUNT_FILE  # Reset counter
    exit 0
else
    echo "" | tee -a $HEALTH_LOG
    echo "❌ SYSTEM UNHEALTHY" | tee -a $HEALTH_LOG
    
    if [ $BOOT_COUNT -ge $MAX_BOOT_ATTEMPTS ]; then
        echo "⚠️  Max boot attempts reached - TRIGGERING ROLLBACK" | tee -a $HEALTH_LOG
        /data/rollback.sh
    else
        echo "Retrying... (Attempt $BOOT_COUNT/$MAX_BOOT_ATTEMPTS)" | tee -a $HEALTH_LOG
        echo "Rebooting in 10 seconds..." | tee -a $HEALTH_LOG
        sleep 10
        reboot
    fi
fi
