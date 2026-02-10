#!/bin/sh

# Mount root as read-write temporarily
mount -o remount,rw /

# Link SSH keys from /data to /root
mkdir -p /root
ln -sf /data/.ssh /root/.ssh

# Link SSH host keys
ln -sf /data/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
ln -sf /data/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
ln -sf /data/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
ln -sf /data/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
ln -sf /data/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
ln -sf /data/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub

# Copy WiFi config from /data
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
