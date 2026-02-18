#!/bin/sh

# OTA Update Script for A/B Partitions
# Usage: ./ota_update.sh <url_to_new_rootfs>

set -e  # Exit on any error

NEW_ROOTFS_URL="$1"
DOWNLOAD_PATH="/data/rootfs_new.ext4"
CURRENT_ROOT=$(grep -o 'root=/dev/[^ ]*' /proc/cmdline | cut -d= -f2)

echo "════════════════════════════════════════"
echo "  OTA Update System - A/B Partitions"
echo "════════════════════════════════════════"
echo "Current root: $CURRENT_ROOT"

# Determine target partition (opposite of current)
if [ "$CURRENT_ROOT" = "/dev/mmcblk0p2" ]; then
    TARGET_PARTITION="/dev/mmcblk0p3"
    TARGET_NAME="rootfs-b"
    NEW_CMDLINE_ROOT="/dev/mmcblk0p3"
elif [ "$CURRENT_ROOT" = "/dev/mmcblk0p3" ]; then
    TARGET_PARTITION="/dev/mmcblk0p2"
    TARGET_NAME="rootfs-a"
    NEW_CMDLINE_ROOT="/dev/mmcblk0p2"
else
    echo "❌ ERROR: Unknown root partition: $CURRENT_ROOT"
    exit 1
fi

echo "Target partition: $TARGET_PARTITION ($TARGET_NAME)"
echo ""

# Step 1: Download new rootfs
if [ -n "$NEW_ROOTFS_URL" ]; then
    echo "📥 Step 1/4: Downloading new rootfs..."
    echo "URL: $NEW_ROOTFS_URL"
    
    # Remove old download if exists
    rm -f "$DOWNLOAD_PATH"
    
    # Download with wget
    if ! wget -O "$DOWNLOAD_PATH" "$NEW_ROOTFS_URL"; then
        echo "❌ Download failed!"
        exit 1
    fi
    
    echo "✅ Download complete: $(du -h $DOWNLOAD_PATH | cut -f1)"
else
    if [ ! -f "$DOWNLOAD_PATH" ]; then
        echo "❌ ERROR: No URL provided and no existing image at $DOWNLOAD_PATH"
        exit 1
    fi
    echo "📦 Using existing image: $DOWNLOAD_PATH"
fi

echo ""

# Step 2: Write to standby partition
echo "💾 Step 2/4: Writing image to $TARGET_PARTITION..."
echo "This will take ~2 minutes..."

if ! dd if="$DOWNLOAD_PATH" of="$TARGET_PARTITION" bs=4M; then
    echo "❌ Write failed!"
    exit 1
fi

sync
echo "✅ Write complete!"
echo ""

# Step 3: Update cmdline.txt
echo "⚙️  Step 3/4: Updating boot configuration..."

# Mount boot partition
mkdir -p /tmp/boot
mount /dev/mmcblk0p1 /tmp/boot

# Backup current cmdline
cp /tmp/boot/cmdline.txt /tmp/boot/cmdline.txt.backup

# Read current cmdline
CURRENT_CMDLINE=$(cat /tmp/boot/cmdline.txt)

# Replace root= parameter
NEW_CMDLINE=$(echo "$CURRENT_CMDLINE" | sed "s|root=/dev/mmcblk0p[0-9]|root=$NEW_CMDLINE_ROOT|")

# Write new cmdline
echo "$NEW_CMDLINE" > /tmp/boot/cmdline.txt

echo "Old: $CURRENT_CMDLINE"
echo "New: $NEW_CMDLINE"

# Verify change
if grep -q "$NEW_CMDLINE_ROOT" /tmp/boot/cmdline.txt; then
    echo "✅ Boot configuration updated!"
else
    echo "❌ Failed to update cmdline.txt"
    cp /tmp/boot/cmdline.txt.backup /tmp/boot/cmdline.txt
    umount /tmp/boot
    exit 1
fi

sync
umount /tmp/boot
echo ""

# Step 4: Reboot
echo "🔄 Step 4/4: Rebooting into new system..."
echo ""
echo "════════════════════════════════════════"
echo "System will reboot in 5 seconds..."
echo "New partition: $TARGET_NAME"
echo "════════════════════════════════════════"

sleep 5
reboot
