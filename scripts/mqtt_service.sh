#!/bin/sh
# Wait for network
sleep 10

# Start MQTT broker with config file
mosquitto -d -c /etc/mosquitto/mosquitto.conf

# Wait for broker
sleep 2

# Start MQTT publisher
/data/mqtt_publisher &
