#!/bin/bash
# Flash SD card with built image
# Usage: ./flash_sd_card.sh /dev/sdX

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 /dev/sdX"
    echo "Example: $0 /dev/sdb"
    exit 1
fi

DEVICE=$1
IMAGE_PATH="../buildroot-projects/buildroot-2024.02.9/output/images/sdcard.img"

if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image not found at $IMAGE_PATH"
    echo "Please build the image first: cd buildroot && make"
    exit 1
fi

echo "⚠️  WARNING: This will erase all data on $DEVICE"
echo "Image: $IMAGE_PATH"
lsblk $DEVICE
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo "Unmounting partitions..."
sudo umount ${DEVICE}* 2>/dev/null || true

echo "Flashing image..."
sudo dd if=$IMAGE_PATH of=$DEVICE bs=4M status=progress conv=fsync

echo "Creating data partition..."
sudo parted $DEVICE mkpart primary ext4 152MiB 100% || true

sync
sleep 2

echo "Formatting data partition..."
sudo mkfs.ext4 -L data ${DEVICE}3

echo "✅ Done! SD card is ready to boot."
echo "Insert into Raspberry Pi and power on."
