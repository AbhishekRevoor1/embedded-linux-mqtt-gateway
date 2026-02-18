# Build Guide

## Prerequisites

**Development Host:**
- Ubuntu 20.04+ (or similar Linux distribution)
- 50+ GB free disk space
- 4+ GB RAM
- Internet connection

**Hardware:**
- Raspberry Pi 3 Model B
- 32GB+ microSD card (Class 10 recommended)
- ESP32 Dev Module (optional, for IoT features)
- DHT11 sensor (optional)

## Quick Start
```bash
# 1. Clone repository
git clone https://github.com/AbhishekRevoor1/embedded-linux-mqtt-gateway.git
cd embedded-linux-mqtt-gateway

# 2. Download Buildroot
wget https://buildroot.org/downloads/buildroot-2024.02.9.tar.gz
tar xf buildroot-2024.02.9.tar.gz
cd buildroot-2024.02.9

# 3. Apply configuration
cp ../configs/rpi3_mqtt_defconfig configs/
make rpi3_mqtt_defconfig

# 4. Copy overlays and board files
cp -r ../overlays/rootfs_overlay board/raspberrypi3/overlay
cp ../board/raspberrypi3/genimage.cfg.in board/raspberrypi3/

# 5. Build (30-90 minutes)
make -j$(nproc)

# 6. Flash SD card
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync
sudo parted /dev/sdX mkpart primary ext4 532MiB 100%
sudo mkfs.ext4 -L data /dev/sdX4
```

Replace `/dev/sdX` with your actual SD card device (check with `lsblk`).

## Detailed Build Instructions

### Step 1: Buildroot Setup
```bash
# Download and extract
wget https://buildroot.org/downloads/buildroot-2024.02.9.tar.gz
tar xf buildroot-2024.02.9.tar.gz
cd buildroot-2024.02.9

# Load base configuration
make raspberrypi3_defconfig
```

### Step 2: Configure Buildroot
```bash
make menuconfig
```

**Required Settings:**

**Target options:**
- Target Architecture: ARM (little endian)
- Target Architecture Variant: cortex-A53
- Target ABI: EABIhf
- Floating point: VFPv4-D16

**System configuration:**
- Root filesystem overlay: `board/raspberrypi3/overlay`
- Root password: Set your password
- /dev management: Dynamic using mdev

**Kernel:**
- Linux Kernel: Custom version 6.1.61
- Kernel configuration: bcm2709_defconfig

**Target packages → Networking applications:**
- [x] dhcpcd
- [x] mosquitto
- [x] openssh
- [x] wpa_supplicant
  - Enable nl80211 support
  - Enable autoscan

**Target packages → Libraries → Networking:**
- [x] libmosquitto

**Filesystem images:**
- [x] ext2/3/4 root filesystem
  - ext4 variant
  - Size: 120M

### Step 3: Apply Custom Configuration
```bash
# Copy your defconfig
cp ../embedded-linux-mqtt-gateway/configs/rpi3_mqtt_defconfig configs/
make rpi3_mqtt_defconfig

# Copy overlays (contains fstab, init scripts, mosquitto config)
cp -r ../embedded-linux-mqtt-gateway/overlays/rootfs_overlay board/raspberrypi3/overlay

# Copy genimage config (defines A/B partition layout)
cp ../embedded-linux-mqtt-gateway/board/raspberrypi3/genimage.cfg.in board/raspberrypi3/
```

### Step 4: Build
```bash
# Full build
make -j$(nproc)
```

**Build time:** 30-90 minutes depending on CPU cores and internet speed.

**Output location:** `output/images/sdcard.img`

### Step 5: Flash SD Card

**Identify SD card device:**
```bash
lsblk
# Look for your SD card (e.g., /dev/sdb, /dev/mmcblk0)
```

**Flash image:**
```bash
# Unmount if auto-mounted
sudo umount /dev/sdX*

# Write image (DESTRUCTIVE - double-check device!)
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync

# Create data partition (p4)
sudo parted /dev/sdX mkpart primary ext4 532MiB 100%
sudo mkfs.ext4 -L data /dev/sdX4
```

**Verify partitions:**
```bash
sudo fdisk -l /dev/sdX
```

Expected output:
```
Device       Boot   Start      End  Sectors  Size Id Type
/dev/sdX1    *       8192    73727    65536   32M  c W95 FAT32 (LBA)
/dev/sdX2           73728   319487   245760  120M 83 Linux
/dev/sdX3          319488   831487   512000  250M 83 Linux
/dev/sdX4          831488 61046783 60215296 28.7G 83 Linux
```

### Step 6: Initial Setup

**Create data directory structure:**
```bash
# Mount data partition
sudo mkdir -p /mnt/data
sudo mount /dev/sdX4 /mnt/data

# Copy scripts from repository
sudo cp ../embedded-linux-mqtt-gateway/scripts/startup.sh /mnt/data/
sudo cp ../embedded-linux-mqtt-gateway/scripts/mqtt_service.sh /mnt/data/
sudo cp -r ../embedded-linux-mqtt-gateway/scripts/ota /mnt/data/
sudo chmod +x /mnt/data/*.sh /mnt/data/ota/*.sh

# Create WiFi configuration
sudo cat > /mnt/data/wpa_supplicant.conf << 'WPAEOF'
network={
    ssid="YOUR_WIFI_SSID"
    psk="YOUR_WIFI_PASSWORD"
}
WPAEOF

# Copy Mosquitto config
sudo cp ../embedded-linux-mqtt-gateway/overlays/rootfs_overlay/etc/mosquitto/mosquitto.conf /mnt/data/

# Create directories
sudo mkdir -p /mnt/data/{.ssh,ssh,logs}
sudo chmod 700 /mnt/data/.ssh

# Add your SSH public key
sudo cp ~/.ssh/id_ed25519.pub /mnt/data/.ssh/authorized_keys
sudo chmod 600 /mnt/data/.ssh/authorized_keys

# Unmount
sudo umount /mnt/data
```

### Step 7: First Boot

1. Insert SD card into Raspberry Pi
2. Connect power (wait ~45 seconds for boot)
3. Find IP address:
```bash
   # On your PC
   nmap -sn 192.168.0.0/24 | grep -B 2 "Raspberry Pi"
```
4. SSH into RPi:
```bash
   ssh root@<raspberry-pi-ip>
```

## Application Development

### Cross-Compile MQTT Publisher
```bash
cd embedded-linux-mqtt-gateway/src

# Compile using Buildroot toolchain
../../buildroot-2024.02.9/output/host/bin/arm-buildroot-linux-gnueabihf-gcc \
  -o mqtt_publisher mqtt_publisher.c \
  -I../../buildroot-2024.02.9/output/staging/usr/include \
  -L../../buildroot-2024.02.9/output/staging/usr/lib \
  -lmosquitto -lpthread

# Deploy to RPi
scp mqtt_publisher root@<rpi-ip>:/data/
```

### ESP32 Firmware Setup

**Install Arduino IDE:**
```bash
# Download from arduino.cc
wget https://downloads.arduino.cc/arduino-1.8.19-linux64.tar.xz
tar xf arduino-1.8.19-linux64.tar.xz
cd arduino-1.8.19
./install.sh
```

**Configure ESP32:**
1. Add board manager URL: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. Install ESP32 board support (version 3.3.7)
3. Install libraries:
   - PubSubClient
   - DHT sensor library
   - Adafruit Unified Sensor

**Update firmware:**
1. Open `embedded-linux-mqtt-gateway/esp32/esp32_mqtt_client.ino`
2. Update WiFi credentials and MQTT broker IP
3. Upload to ESP32

## Customizing the Build

### Modify Kernel Configuration
```bash
cd buildroot-2024.02.9
make linux-menuconfig
# Make changes
make linux-rebuild
make
```

### Add Packages
```bash
make menuconfig
# Navigate to Target packages
# Select desired packages
make savedefconfig BR2_DEFCONFIG=../embedded-linux-mqtt-gateway/configs/rpi3_mqtt_defconfig
make
```

### Update Overlay Files

Edit files in `overlays/rootfs_overlay/`, then rebuild:
```bash
make clean
make
```

## Incremental Builds

**Rebuild single package:**
```bash
make <package>-rebuild
make
```

**Clean and rebuild package:**
```bash
make <package>-dirclean
make
```

**Full clean:**
```bash
make clean
make
```

## Creating OTA Update Images

**After making changes:**
```bash
# Rebuild
make -j$(nproc)

# Extract just the rootfs
cp output/images/rootfs.ext4 rootfs_v1.1.ext4

# Add version marker
sudo mkdir -p /tmp/rootfs_mount
sudo mount -o loop rootfs_v1.1.ext4 /tmp/rootfs_mount
sudo sh -c 'echo "VERSION: 1.1" > /tmp/rootfs_mount/etc/version.txt'
sudo umount /tmp/rootfs_mount

# Host for OTA
python3 -m http.server 8080
```

**On Raspberry Pi:**
```bash
/data/ota_update.sh http://<your-pc-ip>:8080/rootfs_v1.1.ext4
```

## Troubleshooting Builds

### Build Fails with "No rule to make target"

**Clean and retry:**
```bash
make clean
make
```

### Mosquitto Package Fails
```bash
make mosquitto-dirclean
rm buildroot-2024.02.9/package/mosquitto/*.patch
make
```

### Out of Disk Space
```bash
# Clean download cache
rm -rf dl/

# Clean build output
rm -rf output/
make
```

### WiFi Driver Not Included

Verify in menuconfig:
```
Target packages → Hardware handling → Firmware
  → [x] brcmfmac-sdio-firmware-rpi-wifi
```

### Wrong Architecture

Check target settings:
- ARM (little endian)
- cortex-A53
- EABIhf
- VFPv4-D16 floating point

## Build Performance Tips

**Parallel builds:**
```bash
make -j$(nproc)  # Uses all CPU cores
```

**Use ccache:**
```bash
# Enable in menuconfig
Build options → Enable compiler cache
make
```

**Local source mirror:**
```bash
# Set download directory
BR2_DL_DIR=/path/to/downloads make
```

## Next Steps

- See [ARCHITECTURE.md](ARCHITECTURE.md) for system design details
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for runtime issues
- See [Technical Report](Embedded_Linux_OTA_Technical_Report.pdf) for comprehensive documentation
