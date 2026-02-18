# System Architecture

## Overview
Production-ready embedded Linux system with A/B partition OTA updates, MQTT gateway, and ESP32 integration.

## System Block Diagram
```
┌─────────────────────────────────────────────────────────┐
│                  Raspberry Pi 3 Model B                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │      Buildroot Custom Linux (107MB footprint)      │ │
│  │  ┌──────────────┐      ┌───────────────────────┐  │ │
│  │  │   Kernel     │      │   User Space          │  │ │
│  │  │  6.1.61-v7   │      │  - BusyBox init       │  │ │
│  │  │              │      │  - wpa_supplicant     │  │ │
│  │  │  Drivers:    │      │  - dhcpcd             │  │ │
│  │  │  - brcmfmac  │      │  - OpenSSH server     │  │ │
│  │  │  - mdev      │      │  - Mosquitto broker   │  │ │
│  │  └──────────────┘      │  - MQTT publisher     │  │ │
│  │                        │  - OTA scripts        │  │ │
│  │                        └───────────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  A/B Partition Storage Layout:                          │
│  - /dev/mmcblk0p1: Boot (FAT16, 32MB)                   │
│  - /dev/mmcblk0p2: Root A (ext4, 120MB, ro) ← Active    │
│  - /dev/mmcblk0p3: Root B (ext4, 250MB, ro) ← Standby   │
│  - /dev/mmcblk0p4: Data (ext4, 29GB, rw)                │
└─────────────────────────────────────────────────────────┘

ESP32 Node:
┌─────────────────────┐
│  ESP32 Dev Module   │
│  - DHT11 sensor     │
│  - WiFi client      │
│  - MQTT pub/sub     │
└─────────────────────┘
```

## Boot Sequence

1. **GPU Bootloader** (ROM) → Loads bootcode.bin from p1
2. **start.elf** (GPU firmware) → Reads config.txt, cmdline.txt
3. **Kernel Boot** → cmdline.txt specifies root=/dev/mmcblk0pX (p2 or p3)
4. **Root Mount** → Mounts active partition read-only
5. **/etc/fstab** → Auto-mounts /data (p4)
6. **BusyBox Init** → Runs /etc/init.d/S* scripts
7. **S99custom** → Executes /data/startup.sh
8. **startup.sh** → WiFi, SSH keys, services
9. **mqtt_service.sh** → Mosquitto + publisher
10. **health_check.sh** (30s delay) → Validates system, triggers rollback if needed

## A/B Partition OTA System

### Update Flow
```
Current: Running from partition 2 (Root A)
   ↓
1. Download new rootfs.ext4 to /data/
   ↓
2. Write to partition 3 (Root B) with dd
   ↓
3. Modify cmdline.txt: root=/dev/mmcblk0p2 → root=/dev/mmcblk0p3
   ↓
4. Reboot
   ↓
5. Boot from partition 3 (new firmware)
   ↓
6. Health check validates services
   ├─ PASS → Reset boot counter, mark as good
   └─ FAIL → Increment counter, reboot (3 attempts max)
              ↓
              Rollback: Switch cmdline.txt back to p2, reboot
```

### Partition Switching Mechanism
The bootloader reads `cmdline.txt` which contains:
```
root=/dev/mmcblk0p2 rootwait console=tty1 ...
              ↑
         Active partition (2 or 3)
```

OTA script modifies this single parameter to switch between partitions atomically.

## Component Details

### Linux Kernel (6.1.61-v7)
- BCM2709 platform configuration
- brcmfmac WiFi driver (BCM43438 chipset)
- Device tree: bcm2710-rpi-3-b.dtb
- Read-only root filesystem support

### Networking Stack
- **wpa_supplicant 2.10**: WPA2 authentication, nl80211 driver
- **dhcpcd 10.0.8**: DHCP client for IP assignment
- **OpenSSH 9.7**: SSH server, key-based authentication only
- **WiFi firmware**: brcmfmac-sdio-firmware-rpi-wifi package

### MQTT Infrastructure
- **Mosquitto Broker 2.0.19**: Listens on 0.0.0.0:1883
- **mqtt_publisher**: Custom C application
  - Publishes RPi metrics (CPU temp, memory, uptime)
  - Subscribes to ESP32 topics
  - Logs ESP32 data to /data/logs/

### OTA Scripts (/data/)
- **ota_update.sh**: Downloads firmware, writes to standby partition
- **health_check.sh**: Validates WiFi/SSH/MQTT after boot
- **rollback.sh**: Reverts to previous partition on failure

### ESP32 Integration
- **Firmware**: Arduino-based MQTT client
- **Publishes**: esp32/sensor/temperature, esp32/sensor/humidity
- **Subscribes**: rpi/sensor/* (CPU, memory, uptime)
- **Connection**: WiFi → MQTT broker on RPi

## Data Persistence Strategy

### Read-Only Root
- Partitions p2 and p3 mount read-only
- Prevents corruption from power loss
- Temporary remount for configuration: `mount -o remount,rw /`

### Writable Data Partition (/data)
All persistent data stored here:
```
/data/
├── .ssh/authorized_keys    # SSH access keys
├── ssh/                    # SSH host keys
├── wpa_supplicant.conf     # WiFi credentials
├── mosquitto.conf          # MQTT broker config
├── logs/esp32_data.log     # ESP32 sensor logs
├── ota_update.sh           # OTA scripts
├── health_check.sh
├── rollback.sh
├── startup.sh              # Service initialization
├── mqtt_service.sh
└── mqtt_publisher          # Application binary
```

### Symbolic Links
Read-only locations → /data:
```
/etc/ssh/ssh_host_* → /data/ssh/ssh_host_*
/root/.ssh/authorized_keys → /data/.ssh/authorized_keys
```

## MQTT Topic Architecture

### Hierarchical Structure
```
rpi/                        # Raspberry Pi namespace
├── sensor/
│   ├── cpu_temp           # Millidegrees Celsius
│   ├── memory             # MB used
│   └── uptime             # Uptime string

esp32/                      # ESP32 namespace
├── sensor/
│   ├── temperature        # Degrees Celsius
│   └── humidity           # Percentage
└── status/
    └── online             # Heartbeat
```

### Data Flow
```
ESP32 → MQTT Broker (RPi) → RPi subscriber → /data/logs/esp32_data.log
RPi → MQTT Broker (RPi) → ESP32 subscriber → Serial monitor
```

## Security Model

### Current Implementation
- Root filesystem read-only (prevents tampering)
- SSH password authentication disabled (keys only)
- MQTT anonymous auth (network-accessible for ESP32)
- No firewall (local network deployment)

### Security Considerations
- MQTT unencrypted (suitable for trusted local networks)
- SSH keys stored in /data (survives firmware updates)
- WPA2 WiFi authentication
- Physical access = full control (SD card readable)

## System Recovery

### Boot Failure Scenarios
1. **New firmware broken** → Auto-rollback after 3 boot attempts
2. **Power loss during OTA write** → Old partition unaffected, retry update
3. **Corrupted /data** → System boots but services fail, manual recovery needed
4. **Corrupted active partition** → Manual cmdline.txt edit or SD card reflash

### Manual Recovery
```bash
# Boot from HDMI console
# Switch to other partition manually:
mount /dev/mmcblk0p1 /boot
sed -i 's/mmcblk0p3/mmcblk0p2/' /boot/cmdline.txt
reboot
```

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| Boot time | 42 seconds | Power-on to SSH accessible |
| WiFi connect | 8 seconds | From wpa_supplicant start |
| Root FS size | 107 MB | Compressed ext4 |
| Idle RAM | 28 MB | 972 MB available |
| OTA download | 4-5 MB/s | WiFi 802.11n |
| OTA write | ~105s (120MB) | SD card class 10 |
| MQTT latency | <100ms | Local network |
| CPU temp idle | 47-49°C | No heatsink |

## Future Architecture Enhancements

1. **TLS/SSL for MQTT** - Encrypted communication for production deployment
2. **Differential OTA** - Transmit only changed blocks to reduce bandwidth
3. **Watchdog Timer** - Auto-recovery from application hangs
4. **Multiple WiFi Networks** - Failover with priority selection
5. **Signed Firmware** - Cryptographic verification of updates
6. **Container Support** - Docker for application-level updates
7. **Web Dashboard** - Real-time monitoring and remote configuration
