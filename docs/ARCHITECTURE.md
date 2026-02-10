# System Architecture

## Overview
This document describes the architecture of the embedded Linux MQTT gateway system.

## Block Diagram
┌─────────────────────────────────────────────────────────┐
│                  Raspberry Pi 3 Model B                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │         Buildroot Custom Linux (107MB)             │ │
│  │  ┌──────────────┐      ┌───────────────────────┐  │ │
│  │  │   Kernel     │      │   User Space          │  │ │
│  │  │  6.1.61-v7   │      │  - BusyBox init       │  │ │
│  │  │              │      │  - wpa_supplicant     │  │ │
│  │  │  Drivers:    │      │  - dhcpcd             │  │ │
│  │  │  - brcmfmac  │      │  - OpenSSH server     │  │ │
│  │  │  - mdev      │      │  - Mosquitto broker   │  │ │
│  │  └──────────────┘      │  - Custom MQTT app    │  │ │
│  │                        └───────────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Storage Layout:                                         │
│  - /dev/mmcblk0p1: Boot (FAT16, 32MB)                   │
│  - /dev/mmcblk0p2: Root (ext4, 120MB, read-only)        │
│  - /dev/mmcblk0p3: Data (ext4, ~30GB, read-write)       │
└─────────────────────────────────────────────────────────┘
## Boot Sequence

1. **GPU Bootloader** (ROM) → Loads bootcode.bin
2. **start.elf** (GPU firmware) → Reads config.txt, loads kernel
3. **Linux Kernel** → Initializes hardware, mounts rootfs
4. **BusyBox Init** → Runs /etc/init.d/rcS
5. **S99custom** → Executes /data/startup.sh
6. **startup.sh** → Configures WiFi, SSH, starts services
7. **mqtt_service.sh** → Starts Mosquitto broker and publisher

## Component Details

### Kernel (6.1.61-v7)
- Configured with bcm2709 defconfig
- Includes brcmfmac WiFi driver
- Device tree: bcm2710-rpi-3-b.dtb

### Networking
- **wpa_supplicant**: WPA2 authentication with nl80211 driver
- **dhcpcd**: DHCP client for IP assignment
- **OpenSSH**: Remote access (key-based auth only)

### MQTT Stack
- **Mosquitto Broker**: Runs on localhost:1883
- **mqtt_publisher**: Custom C app publishing to sensor/* topics

### Persistence Strategy
- All configuration in /data partition
- Symlinks from read-only locations to /data
- startup.sh manages symlink creation at boot

## Data Flow
## Security Model

- Root filesystem is read-only (prevents tampering)
- SSH password auth disabled (keys only)
- MQTT currently unencrypted (localhost only)
- No firewall (trusted network assumption)

## Future Architecture Changes

- Add TLS/SSL to MQTT for remote access
- Implement A/B partition scheme for OTA updates
- Add systemd for better service management
- Implement watchdog timer for automatic recovery
