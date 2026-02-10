#!/bin/sh
# Wait for network to be ready
sleep 10

# Start MQTT broker
mosquitto -d

# Wait for broker to start
sleep 2

# Start MQTT publisher
/data/mqtt_publisher &
