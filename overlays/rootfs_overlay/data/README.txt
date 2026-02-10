This directory (/data) contains persistent storage for the system.

Contents:
- wpa_supplicant.conf: WiFi configuration
- startup.sh: System startup script
- mqtt_service.sh: MQTT service initialization
- mqtt_publisher: MQTT publisher application
- .ssh/: SSH authorized keys
- ssh/: SSH host keys

These files persist across reboots since /data is mounted read-write.
