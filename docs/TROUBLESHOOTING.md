# Troubleshooting Guide

## WiFi Issues

### Symptom: No wlan0 interface

**Diagnosis:**
```bash
# Check if interface exists
ip addr show wlan0

# Check kernel driver loading
dmesg | grep brcm
lsmod | grep brcm

# Check firmware files
ls -la /lib/firmware/brcm/
```

**Solutions:**

1. **Driver not loaded:**
```bash
   # Verify firmware package installed in Buildroot
   # Target packages → Hardware handling → Firmware
   #   → brcmfmac-sdio-firmware-rpi-wifi
```

2. **mdev not configured:**
```bash
   # System configuration → /dev management
   #   → Dynamic using mdev (NOT static)
```

3. **Manual driver load:**
```bash
   modprobe brcmfmac
```

### Symptom: wlan0 exists but no connection

**Check wpa_supplicant:**
```bash
ps | grep wpa_supplicant
wpa_cli status
```

**Manual connection test:**
```bash
# Stop existing instances
killall wpa_supplicant

# Start in foreground with debug
wpa_supplicant -i wlan0 -c /data/wpa_supplicant.conf -d

# In another terminal, get IP
dhcpcd wlan0
```

**Check credentials:**
```bash
cat /data/wpa_supplicant.conf
# Verify SSID and password are correct
```

### Symptom: Connection drops frequently

**Check signal strength:**
```bash
iwconfig wlan0
# Look for Signal level
```

**Power management issues:**
```bash
# Disable power management
iwconfig wlan0 power off
```

## SSH Issues

### Symptom: Connection refused

**Check SSH daemon:**
```bash
ps | grep sshd
netstat -tuln | grep :22
```

**Start SSH manually:**
```bash
/usr/sbin/sshd -D  # Foreground with debug
```

**Check configuration:**
```bash
/usr/sbin/sshd -T | grep permitroot
/usr/sbin/sshd -T | grep passwordauth
```

### Symptom: Permission denied (publickey)

**Check authorized_keys:**
```bash
ls -la /root/.ssh/
cat /root/.ssh/authorized_keys
```

**Fix permissions:**
```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

**Check symlink:**
```bash
ls -la /root/.ssh/authorized_keys
# Should point to /data/.ssh/authorized_keys
```

**Verify SSH key on client:**
```bash
# On your PC
ssh-add -l
cat ~/.ssh/id_ed25519.pub
```

### Symptom: Host key verification failed

**On client PC:**
```bash
ssh-keygen -R <raspberry-pi-ip>
```

## MQTT Issues

### Symptom: Mosquitto not running

**Check process:**
```bash
ps | grep mosquitto
```

**Start manually:**
```bash
mosquitto -d -c /data/mosquitto.conf
```

**Check logs:**
```bash
tail -f /var/log/messages | grep mosquitto
```

### Symptom: ESP32 can't connect (rc=-2)

**Check broker is listening on network:**
```bash
netstat -tuln | grep 1883
```

**Should show:**
```
tcp        0      0 0.0.0.0:1883            0.0.0.0:*               LISTEN
```

**NOT:**
```
tcp        0      0 127.0.0.1:1883          0.0.0.0:*               LISTEN
```

**Fix:**
```bash
# Check /data/mosquitto.conf contains:
cat /data/mosquitto.conf
# Should have:
# listener 1883 0.0.0.0
# allow_anonymous true

# Restart mosquitto
killall mosquitto
mosquitto -d -c /data/mosquitto.conf
```

### Symptom: MQTT publisher not running

**Check process:**
```bash
ps | grep mqtt_publisher
```

**Run in foreground for debugging:**
```bash
/data/mqtt_publisher
# Watch for error messages
```

**Test broker manually:**
```bash
mosquitto_pub -h localhost -t test -m "hello"
mosquitto_sub -h localhost -t test -v
```

### Symptom: No sensor data

**Subscribe to all topics:**
```bash
mosquitto_sub -h localhost -t "#" -v
```

**Check publisher topics:**
```bash
mosquitto_sub -h localhost -t "rpi/#" -v
```

## OTA Update Issues

### Symptom: OTA download fails

**Check network connectivity:**
```bash
ping <server-ip>
wget http://<server-ip>:8080/rootfs.ext4
```

**Check available space:**
```bash
df -h /data
# Need at least 250 MB free
```

**Manual download:**
```bash
cd /data
wget http://<server-ip>:8080/rootfs_v1.1.ext4
```

### Symptom: OTA write fails

**Check partition:**
```bash
cat /proc/partitions
# Verify mmcblk0p2 and mmcblk0p3 exist
```

**Check current partition:**
```bash
cat /proc/cmdline | grep root=
```

**Manual write test:**
```bash
# Write to standby partition
dd if=/data/rootfs_new.ext4 of=/dev/mmcblk0p3 bs=4M
sync
```

### Symptom: System won't boot after OTA

**Emergency recovery via HDMI console:**

1. Boot with HDMI and keyboard connected
2. Login as root
3. Check current partition:
```bash
   cat /proc/cmdline
```
4. Switch back to old partition:
```bash
   mount /dev/mmcblk0p1 /boot
   sed -i 's/mmcblk0p3/mmcblk0p2/' /boot/cmdline.txt
   sync
   reboot
```

### Symptom: Health check fails immediately

**Run health check manually:**
```bash
/data/health_check.sh
cat /data/health_check.log
```

**Common causes:**
- WiFi not configured in new partition
- SSH keys missing
- Mosquitto config missing

**Solution:** Ensure Buildroot overlay includes all configs

### Symptom: Automatic rollback loop

**Check boot counter:**
```bash
cat /data/boot_count
```

**Reset counter:**
```bash
echo "0" > /data/boot_count
```

**Check rollback log:**
```bash
cat /data/rollback.log
```

## ESP32 Issues

### Symptom: ESP32 won't connect to WiFi

**Check serial monitor:**
```
WiFi.status() returns 6 (WL_DISCONNECTED)
```

**Solutions:**
1. Verify SSID and password in firmware
2. Check 2.4 GHz WiFi (ESP32 doesn't support 5 GHz)
3. Check router MAC filtering

### Symptom: ESP32 MQTT connection failed

**Check serial output:**
```
MQTT rc=-2 → Network connection failed
MQTT rc=-4 → Timeout waiting for response
```

**Solutions:**
1. Verify broker IP address in firmware
2. Check broker is listening (see MQTT section above)
3. Test with mosquitto_sub on PC:
```bash
   mosquitto_sub -h <rpi-ip> -t "test" -v
```

### Symptom: DHT11 readings are NaN

**Check wiring:**
- VCC → 3.3V (NOT 5V)
- DATA → GPIO4
- GND → GND

**Check sensor:**
```cpp
Serial.println(dht.readTemperature());
Serial.println(dht.readHumidity());
```

**Add delay:**
```cpp
delay(2000);  // DHT11 needs time between reads
```

## System Issues

### Symptom: Can't write to filesystem

**Root is read-only by design.**

**Temporary write access:**
```bash
mount -o remount,rw /
# Make changes
mount -o remount,ro /
```

**Persistent changes go in /data:**
```bash
echo "config" > /data/myfile.conf
```

### Symptom: Services don't auto-start

**Check init script:**
```bash
ls -la /etc/init.d/S99custom
cat /etc/init.d/S99custom
```

**Test manually:**
```bash
/etc/init.d/S99custom start
```

**Check /data scripts exist:**
```bash
ls -la /data/startup.sh
ls -la /data/mqtt_service.sh
```

### Symptom: Out of memory

**Check current usage:**
```bash
free -m
top
```

**Kill memory-hungry processes:**
```bash
killall <process-name>
```

**Restart services:**
```bash
/etc/init.d/S99custom stop
/etc/init.d/S99custom start
```

### Symptom: SD card corruption

**Check filesystem:**
```bash
# On development PC
sudo fsck /dev/sdX2
sudo fsck /dev/sdX3
sudo fsck /dev/sdX4
```

**Prevention:**
- Use quality SD card (Class 10 or better)
- Proper shutdown: `poweroff` command
- Read-only root filesystem (already implemented)

## Debugging Techniques

### View Kernel Messages
```bash
dmesg | tail -50
dmesg | grep -i error
```

### Monitor System Logs
```bash
tail -f /var/log/messages
```

### Process Debugging
```bash
# List all processes
ps aux

# Find specific process
ps | grep <name>

# Kill process
killall <name>
```

### Network Debugging
```bash
# Show all network interfaces
ip addr show

# Show routes
ip route show

# Test connectivity
ping -c 4 8.8.8.8

# DNS lookup
nslookup google.com
```

### MQTT Debugging
```bash
# Subscribe to all topics
mosquitto_sub -h localhost -t "#" -v

# Publish test message
mosquitto_pub -h localhost -t "test" -m "hello"

# Check broker stats
mosquitto_sub -h localhost -t '$SYS/#' -v
```

### System Call Tracing
```bash
strace -f /data/mqtt_publisher
```

## Performance Issues

### Symptom: Slow boot time

**Measure boot stages:**
```bash
systemd-analyze  # If using systemd
dmesg | grep -i time
```

**Common delays:**
- Network timeout (dhcpcd)
- Service startup (mosquitto)

### Symptom: High CPU usage

**Find culprit:**
```bash
top
# Press 'P' to sort by CPU
```

**Check MQTT publisher:**
```bash
# Should use <5% CPU
top -p $(pidof mqtt_publisher)
```

## Getting Help

**Gather diagnostic info:**
```bash
# System info
uname -a
cat /proc/cpuinfo
free -m

# Network
ip addr show
ip route show

# Processes
ps aux

# Kernel messages
dmesg | tail -50
```

**Check logs:**
```bash
cat /data/health_check.log
cat /data/rollback.log
cat /data/logs/esp32_data.log
```

**GitHub Issues:**
https://github.com/AbhishekRevoor1/embedded-linux-mqtt-gateway/issues

Include:
- Symptom description
- Steps to reproduce
- Diagnostic output
- Build configuration (defconfig)
