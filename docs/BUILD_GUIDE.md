# Build Guide

## Quick Start
```bash
# 1. Download and extract Buildroot
wget https://buildroot.org/downloads/buildroot-2024.02.9.tar.gz
tar -xzf buildroot-2024.02.9.tar.gz
cd buildroot-2024.02.9

# 2. Apply our configuration
cp ../embedded-linux-mqtt-gateway/configs/rpi3_mqtt_defconfig configs/
make rpi3_mqtt_defconfig

# 3. Build (30-90 minutes)
make -j$(nproc)

# 4. Flash to SD card
cd ../embedded-linux-mqtt-gateway/scripts
./flash_sd_card.sh /dev/sdX  # Replace with your SD card device
```

## Detailed Build Instructions

See [README.md](../README.md) for complete instructions including:
- Buildroot menuconfig options
- Package selection
- WiFi configuration
- SSH setup
- MQTT application compilation

## Customizing the Build

### Modify Buildroot Configuration
```bash
cd buildroot-2024.02.9
make menuconfig
# Make your changes
make savedefconfig BR2_DEFCONFIG=../embedded-linux-mqtt-gateway/configs/rpi3_mqtt_defconfig
```

### Add Packages
```bash
make menuconfig
# Navigate to Target packages and select what you need
make
```

### Rebuild After Changes
```bash
# Clean specific package
make <package>-dirclean

# Rebuild everything
make

# Or clean and rebuild
make clean
make
```

## Application Development Workflow
```bash
# 1. Edit source code
vim embedded-linux-mqtt-gateway/src/mqtt_publisher.c

# 2. Cross-compile
cd embedded-linux-mqtt-gateway/src
make BUILDROOT_PATH=../../buildroot-2024.02.9

# 3. Deploy to Raspberry Pi
make deploy

# 4. Test
mosquitto_sub -h 192.168.0.114 -t sensor/# -v
```

## Troubleshooting Builds

### mosquitto Patch Failure
```bash
rm buildroot-2024.02.9/package/mosquitto/*.patch
make mosquitto-dirclean
make
```

### Out of Disk Space
```bash
# Clean download cache
make clean
rm -rf dl/

# Clean build artifacts
rm -rf output/
```

### Wrong Architecture
Make sure you selected:
- Target Architecture: ARM (little endian)
- Target Architecture Variant: cortex-A53
- Target ABI: EABIhf
