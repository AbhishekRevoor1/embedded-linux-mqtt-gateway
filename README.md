# Custom Embedded Linux MQTT Gateway

A production-ready embedded Linux system built from scratch using Buildroot, implementing an MQTT-based IoT gateway on Raspberry Pi 3. This project demonstrates expertise in embedded Linux development, system architecture design, and IoT protocols.

[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%203-red)](https://www.raspberrypi.org/)
[![Buildroot](https://img.shields.io/badge/Buildroot-2024.02.9-blue)](https://buildroot.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 🎯 Project Overview

This project creates a minimal, reliable embedded Linux distribution optimized for IoT applications. The system features:

- **Minimal Footprint**: 107MB root filesystem with only essential components
- **High Reliability**: Read-only root filesystem preventing system corruption
- **Auto-Start Services**: WiFi, SSH, MQTT broker, and data publisher configured for automatic startup
- **Real-time Telemetry**: C application publishing system metrics via MQTT every 5 seconds
- **Production Ready**: Persistent configuration, secure SSH access, and robust error handling

## 🏗️ System Architecture

```
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
│  - /dev/mmcblk0p3: Data (ext4, 28.9GB, read-write)      │
└─────────────────────────────────────────────────────────┘
          │                           │
          │ WiFi (WPA2)              │ MQTT (1883)
          ▼                           ▼
    Internet/Router           IoT Clients/ESP32
```

## ✨ Key Features

### System Design
- **Read-only Root Filesystem**: Prevents corruption and ensures system integrity
- **Persistent Data Partition**: 28.9GB separate partition for logs, configurations, and user data
- **Minimal Attack Surface**: Only essential services enabled, reducing security vulnerabilities
- **Automatic Service Management**: Custom init scripts for reliable startup sequence

### Networking
- **WiFi Connectivity**: Automatic WPA2 authentication on boot (Ab TPLink network)
- **SSH Access**: Key-based authentication with persistent host keys
- **DHCP Client**: Automatic IP address assignment via dhcpcd
- **Network Resilience**: WiFi reconnection on network failures

### MQTT Data Publisher
- **Real-time Metrics**: CPU temperature, memory usage, system uptime
- **Efficient Protocol**: MQTT QoS 0 for lightweight communication
- **Custom C Implementation**: Using libmosquitto for direct broker integration
- **Configurable Interval**: 5-second publish cycle (easily adjustable)

## 🛠️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Build System** | Buildroot 2024.02.9 |
| **Target Platform** | Raspberry Pi 3 Model B (BCM2837) |
| **Processor** | ARM Cortex-A53 (quad-core, 1.2GHz) |
| **Kernel** | Linux 6.1.61-v7 |
| **Init System** | BusyBox init |
| **Device Management** | mdev (dynamic /dev) |
| **WiFi Driver** | brcmfmac (BCM43438 chipset) |
| **Network Auth** | wpa_supplicant 2.10 with nl80211 |
| **DHCP Client** | dhcpcd 10.0.8 |
| **SSH Server** | OpenSSH 9.7 |
| **MQTT Broker** | Mosquitto 2.0.19 |
| **Programming** | C (application), Shell (scripts) |
| **Toolchain** | ARM Buildroot GNU/Linux GCC |

## 📋 Prerequisites

### Hardware
- Raspberry Pi 3 Model B (or B+)
- MicroSD card (minimum 4GB, recommended 8GB+)
- SD card reader
- WiFi network with WPA2 authentication
- Power supply (5V, 2.5A recommended)

### Software (Development Machine)
- Linux system (Ubuntu 22.04 LTS recommended)
- Required packages:
  ```bash
  sudo apt-get install -y \
      build-essential \
      git \
      libncurses5-dev \
      rsync \
      bc \
      cpio \
      python3 \
      unzip \
      wget \
      file
  ```

## 🚀 Build Instructions

### Step 1: Download Buildroot

```bash
# Create project directory
mkdir -p ~/embedded-linux-projects
cd ~/embedded-linux-projects

# Download Buildroot 2024.02.9
wget https://buildroot.org/downloads/buildroot-2024.02.9.tar.gz
tar -xzf buildroot-2024.02.9.tar.gz
cd buildroot-2024.02.9
```

### Step 2: Configure Buildroot

```bash
# Start with Raspberry Pi 3 defconfig
make raspberrypi3_defconfig

# Enter menuconfig for customization
make menuconfig
```

### Step 3: Key Configuration Settings

Navigate through menuconfig and configure:

#### **Target Options**
- Target Architecture: ARM (little endian)
- Target Architecture Variant: cortex-A53
- Target ABI: EABIhf
- Floating point strategy: VFPv4-D16

#### **Build Options**
- Enable compiler cache: Yes
- Number of jobs: `$(nproc)`

#### **Toolchain**
- Toolchain type: Buildroot toolchain
- Kernel Headers: Linux 6.1.x
- C library: glibc

#### **System Configuration**
- System hostname: `rpi3-mqtt-gateway`
- Root password: Set your password
- /dev management: Dynamic using devtmpfs + mdev (**CRITICAL for WiFi**)
- Root filesystem overlay directories: (leave empty, we'll use post-build)
- Init system: BusyBox
- remount root filesystem read-write during boot: **DISABLE** (for read-only root)

#### **Kernel**
- Kernel version: Latest version (6.1.x)
- Kernel configuration: Using an in-tree defconfig
- Defconfig name: bcm2709

#### **Target Packages → Hardware Handling → Firmware**
- [*] brcmfmac-sdio-firmware-rpi
  - [*] brcmfmac-sdio-firmware-rpi-wifi (**ESSENTIAL for WiFi**)

#### **Target Packages → Networking Applications**
- [*] dhcpcd (DHCP client)
- [*] iw (wireless configuration)
- [*] mosquitto
  - [*] Install the mosquitto broker
- [*] openssh
  - [*] client
  - [*] server
  - [*] key utilities
- [*] wget
- [*] wireless-tools (iwconfig, iwlist)
- [*] wpa_supplicant (**ESSENTIAL**)
  - [*] Enable nl80211 support (**CRITICAL**)
  - [*] Install wpa_cli binary
  - [*] Install wpa_passphrase binary

#### **Target Packages → Libraries → JSON/XML**
- [*] cJSON

#### **Filesystem Images**
- [*] ext2/3/4 root filesystem
  - ext2/3/4 variant: ext4
  - exact size: 250M
- [*] tar the root filesystem

### Step 4: Build the System

```bash
# Start build (takes 30-90 minutes on first build)
make -j$(nproc)
```

**Note**: If `mosquitto` build fails with patch errors, run:
```bash
rm package/mosquitto/0001-Revert-Fix-NetBSD-build.patch
make mosquitto-dirclean
make -j$(nproc)
```

### Step 5: Verify Build Output

```bash
ls -lh output/images/

# You should see:
# - bcm2710-rpi-3-b.dtb (device tree)
# - boot.vfat (boot partition)
# - rootfs.ext4 (root filesystem)
# - sdcard.img (complete SD card image)
# - zImage (kernel)
```

## 💾 Flash to SD Card

### Step 1: Identify SD Card

```bash
# Insert SD card and identify device
lsblk

# Look for your SD card (typically /dev/sdb or /dev/mmcblk0)
# ⚠️ WARNING: Choose carefully! Wrong device = data loss!
```

### Step 2: Unmount Partitions

```bash
# Unmount any mounted partitions
sudo umount /dev/sdX*

# Replace /dev/sdX with your actual device (e.g., /dev/sdb)
```

### Step 3: Flash the Image

```bash
cd output/images/

# Flash image to SD card (replace /dev/sdX with your device)
sudo dd if=sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync

# Ensure all writes complete
sync
```

### Step 4: Add Data Partition

```bash
# Use parted to add 3rd partition
sudo parted /dev/sdX

# In parted:
print                                    # View current partitions
mkpart primary ext4 152MiB 100%         # Create partition
quit

# Format the data partition
sudo mkfs.ext4 -L data /dev/sdX3

# Verify
lsblk /dev/sdX
```

Expected result:
```
sdX      
├─sdX1    32M  boot (FAT16)
├─sdX2   120M  rootfs (ext4)
└─sdX3   ~GB  data (ext4)
```

## ⚙️ Initial Configuration

### Step 1: First Boot

Insert SD card into Raspberry Pi and power on. Connect via:
- **Serial console** (UART on GPIO pins), OR
- **HDMI monitor + USB keyboard**, OR
- **SSH over Ethernet** (find IP from router)

Login: `root` / `<your-password>`

### Step 2: Configure WiFi

```bash
# Create persistent WiFi configuration
cat > /data/wpa_supplicant.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
network={
    ssid="YourWiFiSSID"
    psk="YourWiFiPassword"
}
EOF

# Link to system location
mount -o remount,rw /
cp /data/wpa_supplicant.conf /etc/wpa_supplicant.conf
mount -o remount,ro /

# Start WiFi
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
dhcpcd wlan0

# Verify connection
ip addr show wlan0
```

### Step 3: Configure SSH

```bash
# Generate SSH host keys (if not already done)
mkdir -p /data/ssh
ssh-keygen -t rsa -f /data/ssh/ssh_host_rsa_key -N ""
ssh-keygen -t ecdsa -f /data/ssh/ssh_host_ecdsa_key -N ""
ssh-keygen -t ed25519 -f /data/ssh/ssh_host_ed25519_key -N ""

# Link host keys
mount -o remount,rw /
ln -sf /data/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
ln -sf /data/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
ln -sf /data/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
ln -sf /data/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
ln -sf /data/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
ln -sf /data/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
mount -o remount,ro /

# Add your SSH public key for password-less login
mkdir -p /data/.ssh
chmod 700 /data/.ssh
echo "ssh-ed25519 YOUR_PUBLIC_KEY_HERE user@host" > /data/.ssh/authorized_keys
chmod 600 /data/.ssh/authorized_keys

# Link to root home
mount -o remount,rw /
ln -sf /data/.ssh /root/.ssh
mount -o remount,ro /

# Start SSH server
/usr/sbin/sshd
```

### Step 4: Create Startup Script

```bash
# Create comprehensive startup script
cat > /data/startup.sh << 'EOF'
#!/bin/sh

# Mount root as read-write temporarily
mount -o remount,rw /

# Link SSH keys
mkdir -p /root
ln -sf /data/.ssh /root/.ssh
ln -sf /data/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
ln -sf /data/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
ln -sf /data/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
ln -sf /data/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
ln -sf /data/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
ln -sf /data/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub

# Copy WiFi config
cp /data/wpa_supplicant.conf /etc/wpa_supplicant.conf

# Remount as read-only
mount -o remount,ro /

# Start WiFi
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
sleep 5
dhcpcd wlan0

# Start SSH server
/usr/sbin/sshd

echo "Startup complete!"
EOF

chmod +x /data/startup.sh
```

### Step 5: Create MQTT Service

```bash
# Create MQTT service script
cat > /data/mqtt_service.sh << 'EOF'
#!/bin/sh
# Wait for network
sleep 10

# Start MQTT broker
mosquitto -d

# Wait for broker
sleep 2

# Start MQTT publisher
/data/mqtt_publisher &
EOF

chmod +x /data/mqtt_service.sh
```

### Step 6: Configure Auto-Start

```bash
# Create init script for auto-start
mount -o remount,rw /

cat > /etc/init.d/S99custom << 'EOF'
#!/bin/sh

case "$1" in
  start)
    echo "Starting custom services..."
    /data/startup.sh
    
    # Start MQTT service
    /data/mqtt_service.sh &
    ;;
  stop)
    echo "Stopping custom services..."
    killall mqtt_publisher
    killall mosquitto
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
esac

exit 0
EOF

chmod +x /etc/init.d/S99custom
mount -o remount,ro /
```

## 📝 Building the MQTT Publisher Application

### Step 1: Create Source Code

On Raspberry Pi, create `/data/mqtt_publisher.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mosquitto.h>

#define MQTT_HOST "localhost"
#define MQTT_PORT 1883
#define SLEEP_INTERVAL 5

void read_cpu_temp(char *buffer) {
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (fp) {
        fscanf(fp, "%s", buffer);
        fclose(fp);
    }
}

void read_memory(char *buffer) {
    FILE *fp = popen("free -m | grep Mem | awk '{print $3}'", "r");
    if (fp) {
        fgets(buffer, 32, fp);
        buffer[strcspn(buffer, "\n")] = 0;
        pclose(fp);
    }
}

void read_uptime(char *buffer) {
    FILE *fp = popen("uptime", "r");
    if (fp) {
        fgets(buffer, 128, fp);
        buffer[strcspn(buffer, "\n")] = 0;
        pclose(fp);
    }
}

int main() {
    struct mosquitto *mosq;
    char cpu_temp[32], memory[32], uptime[128];
    
    mosquitto_lib_init();
    mosq = mosquitto_new("rpi_publisher", true, NULL);
    
    if (!mosq) {
        fprintf(stderr, "Error: Out of memory.\n");
        return 1;
    }
    
    if (mosquitto_connect(mosq, MQTT_HOST, MQTT_PORT, 60) != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "Unable to connect to MQTT broker.\n");
        return 1;
    }
    
    printf("Connected to MQTT broker. Publishing data every %d seconds...\n", SLEEP_INTERVAL);
    
    while (1) {
        read_cpu_temp(cpu_temp);
        read_memory(memory);
        read_uptime(uptime);
        
        mosquitto_publish(mosq, NULL, "sensor/cpu_temp", strlen(cpu_temp), cpu_temp, 0, false);
        mosquitto_publish(mosq, NULL, "sensor/memory", strlen(memory), memory, 0, false);
        mosquitto_publish(mosq, NULL, "sensor/uptime", strlen(uptime), uptime, 0, false);
        
        printf("Published: temp=%s, mem=%s MB\n", cpu_temp, memory);
        
        sleep(SLEEP_INTERVAL);
    }
    
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 0;
}
```

### Step 2: Cross-Compile

On your development machine (Ubuntu):

```bash
cd ~/embedded-linux-projects/buildroot-2024.02.9

# Copy source from RPi
scp root@<RPI_IP>:/data/mqtt_publisher.c ./

# Cross-compile
./output/host/bin/arm-buildroot-linux-gnueabihf-gcc \
  -o mqtt_publisher \
  mqtt_publisher.c \
  -I./output/staging/usr/include \
  -L./output/staging/usr/lib \
  -lmosquitto -lpthread

# Copy binary back to RPi
scp mqtt_publisher root@<RPI_IP>:/data/
```

## 🧪 Testing

### Test MQTT Communication

**Terminal 1 - Subscribe:**
```bash
mosquitto_sub -h localhost -t sensor/# -v
```

**Terminal 2 - Run Publisher:**
```bash
cd /data
./mqtt_publisher
```

Expected output in Terminal 1:
```
sensor/cpu_temp 47236
sensor/memory 29
sensor/uptime  00:45:20 up 45 min,  load average: 0.00, 0.00, 0.00
```

### Test Auto-Start

```bash
# Reboot system
reboot

# After ~45 seconds, SSH back in and check
ps | grep mqtt_publisher
mosquitto_sub -h localhost -t sensor/# -v
```

## 📊 System Specifications

| Metric | Value |
|--------|-------|
| **Root Filesystem Size** | 107 MB |
| **Boot Time** | ~30-45 seconds |
| **Memory Usage (Idle)** | ~28-30 MB |
| **CPU Temperature (Idle)** | ~47-49°C |
| **WiFi Connection Time** | ~5-8 seconds |
| **MQTT Publish Interval** | 5 seconds |
| **Power Consumption** | ~1.5-2W (WiFi active) |

## 🔧 Troubleshooting

### WiFi Not Connecting

```bash
# Check WiFi interface status
ip addr show wlan0

# Check wpa_supplicant
ps | grep wpa_supplicant

# Check kernel messages
dmesg | grep brcm

# Manually start WiFi
wpa_supplicant -B -i wlan0 -c /data/wpa_supplicant.conf
dhcpcd wlan0
```

### SSH Not Working

```bash
# Check if SSH is running
ps | grep sshd

# Check SSH configuration
/usr/sbin/sshd -T | grep -i permitroot
/usr/sbin/sshd -T | grep -i passwordauth

# Start SSH manually
/usr/sbin/sshd

# Check logs
tail -f /var/log/messages
```

### MQTT Publisher Not Starting

```bash
# Check if broker is running
ps | grep mosquitto

# Start broker manually
mosquitto -d

# Check publisher
/data/mqtt_publisher

# View logs
tail -f /var/log/messages
```

### Read-Only Filesystem Issues

```bash
# Remount as read-write temporarily
mount -o remount,rw /

# Make changes...

# Remount as read-only
mount -o remount,ro /

# Verify
mount | grep "on / "
```

## 📚 Key Learnings & Challenges Solved

### 1. WiFi Driver Integration
**Challenge**: WiFi not working after boot  
**Solution**: 
- Enabled `brcmfmac-sdio-firmware-rpi-wifi` package in Buildroot
- Configured mdev (dynamic /dev management) for automatic driver loading
- Enabled nl80211 support in wpa_supplicant

### 2. Read-Only Root Filesystem
**Challenge**: SSH host keys and configuration cannot be written  
**Solution**:
- Created `/data` partition for persistent storage
- Used symlinks to link SSH keys from `/data/ssh` to `/etc/ssh`
- Stored all persistent configs in `/data`

### 3. SSH Authentication
**Challenge**: Password authentication failing  
**Solution**:
- Discovered corrupted password hash with invalid characters
- Changed `PermitRootLogin` from `without-password` to `yes`
- Disabled UsePAM to simplify authentication

### 4. Auto-Start Services
**Challenge**: Services not starting on boot  
**Solution**:
- Created comprehensive init script in `/etc/init.d/S99custom`
- Implemented startup sequence: WiFi → SSH → MQTT
- Added proper delays for network initialization

## 🚀 Future Enhancements

- [ ] ESP32 subscriber client for displaying sensor data
- [ ] Web dashboard for real-time monitoring
- [ ] OTA (Over-The-Air) firmware updates with A/B partition scheme
- [ ] SSL/TLS encryption for MQTT communication
- [ ] Multiple WiFi network failover
- [ ] Watchdog timer for automatic recovery
- [ ] System metrics logging to SD card
- [ ] Remote configuration via MQTT commands

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Abhishek Abhishek**
- Email: work.abhishek964@gmail.com
- LinkedIn: [https://www.linkedin.com/in/abhishek-revoor/]
- GitHub: [https://github.com/AbhishekRevoor1]

## 🙏 Acknowledgments

- Buildroot community for excellent documentation
- Raspberry Pi Foundation for hardware specifications
- Eclipse Mosquitto project for MQTT broker
- OpenSSH project for secure remote access

---

**Built with ❤️ using Buildroot and embedded Linux**
