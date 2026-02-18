# Embedded Linux MQTT Gateway with A/B OTA Updates

A production-ready embedded Linux system for Raspberry Pi 3 featuring over-the-air (OTA) firmware updates with A/B partition scheme, MQTT-based IoT communication, and ESP32 integration.

![System Status](https://img.shields.io/badge/Status-Production%20Ready-green)
![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%203-red)

## 🎯 Project Overview

Industrial-grade embedded Linux system with:
- **A/B Partition OTA Updates** - Safe firmware updates with automatic rollback
- **Read-Only Root Filesystem** - Enhanced reliability
- **MQTT Gateway** - Bidirectional IoT communication with ESP32
- **Health Check System** - Automatic validation and recovery
- **Minimal Footprint** - 107 MB root filesystem, 42s boot time

## 📁 Repository Structure
```
embedded-linux-mqtt-gateway/
├── docs/                    # Documentation + Technical Report (PDF)
├── esp32/                   # ESP32 Arduino firmware
├── overlays/rootfs_overlay/ # Buildroot filesystem overlay
├── scripts/                 # System & deployment scripts
│   └── ota/                # OTA update, health check, rollback
├── src/                     # MQTT publisher C source
└── README.md               # This file
```

## 🚀 Quick Start

See [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) for complete build instructions.

## 📊 Key Metrics

- Boot Time: 42s | Footprint: 107 MB | Memory: 28 MB idle
- OTA Speed: 4-5 MB/s | Write: ~105s for 120 MB

## 📚 Documentation

- [Technical Report](docs/Embedded_Linux_OTA_Technical_Report.pdf) - 40+ page academic documentation
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - System architecture
- [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) - Build instructions
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

## 👤 Author

**Abhishek Revoor**  
M.Sc. Electrical Engineering and Embedded Systems  
Hochschule Ravensburg-Weingarten, Germany

---
⭐ Star this repository if you find it useful!
