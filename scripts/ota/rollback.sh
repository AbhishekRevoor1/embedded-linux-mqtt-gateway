#!/bin/sh

# Rollback Script
# Switches boot partition back to the previous one

ROLLBACK_LOG="/data/rollback.log"
CURRENT_ROOT=$(grep -o 'root=/dev/[^ ]*' /proc/cmdline | cut -d= -f2)

echo "════════════════════════════════════════" | tee -a $ROLLBACK_LOG
echo "ROLLBACK TRIGGERED - $(date)" | tee -a $ROLLBACK_LOG
echo "════════════════════════════════════════" | tee -a $ROLLBACK_LOG
echo "Current partition: $CURRENT_ROOT" | tee -a $ROLLBACK_LOG

# Determine rollback partition
if [ "$CURRENT_ROOT" = "/dev/mmcblk0p2" ]; then
    ROLLBACK_PARTITION="mmcblk0p3"
    echo "Rolling back to: /dev/mmcblk0p3" | tee -a $ROLLBACK_LOG
elif [ "$CURRENT_ROOT" = "/dev/mmcblk0p3" ]; then
    ROLLBACK_PARTITION="mmcblk0p2"
    echo "Rolling back to: /dev/mmcblk0p2" | tee -a $ROLLBACK_LOG
else
    echo "❌ ERROR: Unknown partition" | tee -a $ROLLBACK_LOG
    exit 1
fi

# Mount boot and update cmdline
mkdir -p /tmp/boot
mount /dev/mmcblk0p1 /tmp/boot

# Backup
cp /tmp/boot/cmdline.txt /tmp/boot/cmdline.txt.rollback

# Read current
CURRENT_CMDLINE=$(cat /tmp/boot/cmdline.txt)

# Replace partition
NEW_CMDLINE=$(echo "$CURRENT_CMDLINE" | sed "s|root=/dev/mmcblk0p[0-9]|root=/dev/$ROLLBACK_PARTITION|")

# Write new cmdline
echo "$NEW_CMDLINE" > /tmp/boot/cmdline.txt

echo "Old cmdline: $CURRENT_CMDLINE" | tee -a $ROLLBACK_LOG
echo "New cmdline: $NEW_CMDLINE" | tee -a $ROLLBACK_LOG

sync
umount /tmp/boot

# Reset boot counter
echo "0" > /data/boot_count

echo "✅ Rollback complete - Rebooting..." | tee -a $ROLLBACK_LOG
sleep 3
reboot
