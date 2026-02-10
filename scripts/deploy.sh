#!/bin/bash
# Quick deployment script
# Usage: ./deploy.sh [IP_ADDRESS]

RPI_IP=${1:-192.168.0.114}

echo "Deploying MQTT publisher to $RPI_IP..."

# Build if needed
cd ../src
make BUILDROOT_PATH=../../buildroot-projects/buildroot-2024.02.9

# Deploy
scp mqtt_publisher root@$RPI_IP:/data/

# Restart service
ssh root@$RPI_IP "killall mqtt_publisher 2>/dev/null; sleep 1; /data/mqtt_service.sh &"

echo "✅ Deployed! Check logs:"
echo "   ssh root@$RPI_IP"
echo "   mosquitto_sub -h localhost -t sensor/# -v"
