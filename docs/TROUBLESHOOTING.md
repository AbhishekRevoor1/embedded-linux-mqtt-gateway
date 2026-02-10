# Troubleshooting Guide

## WiFi Issues

### Symptom: No wlan0 interface

**Check WiFi driver:**
```bash
dmesg | grep brcm
lsmod | grep brcm
```

**If driver not loaded:**
- Verify firmware package is installed
- Check mdev is configured (not static /dev)
- Rebuild with brcmfmac-sdio-firmware-rpi-wifi enabled

### Symptom: wlan0 exists but no connection

**Check wpa_supplicant:**
```bash
ps | grep wpa_supplicant
wpa_cli status
```

**Manual connection:**
```bash
wpa_supplicant -B -i wlan0 -c /data/wpa_supplicant.conf -d
dhcpcd wlan0
```

## SSH Issues

### Symptom: Connection refused

**Check SSH is running:**
```bash
ps | grep sshd
netstat -tuln | grep :22
```

**Start manually:**
```bash
/usr/sbin/sshd
```

### Symptom: Permission denied

**Check configuration:**
```bash
/usr/sbin/sshd -T | grep permitroot
/usr/sbin/sshd -T | grep passwordauth
```

**Check keys:**
```bash
ls -la /root/.ssh/
cat /root/.ssh/authorized_keys
```

## MQTT Issues

### Symptom: Publisher not connecting

**Check broker:**
```bash
ps | grep mosquitto
netstat -tuln | grep :1883
```

**Test manually:**
```bash
mosquitto_pub -h localhost -t test -m "hello"
mosquitto_sub -h localhost -t test
```

### Symptom: No data publishing

**Check application:**
```bash
ps | grep mqtt_publisher
/data/mqtt_publisher  # Run in foreground to see errors
```

## System Issues

### Symptom: Can't write files

**Remount as read-write:**
```bash
mount -o remount,rw /
# Make changes
mount -o remount,ro /
```

### Symptom: Services not auto-starting

**Check init script:**
```bash
ls -la /etc/init.d/S99custom
cat /etc/init.d/S99custom
```

**Test manually:**
```bash
/etc/init.d/S99custom start
```

## Getting Help

1. Check kernel messages: `dmesg`
2. Check system logs: `tail -f /var/log/messages`
3. Run services in foreground with -d/-v flags
4. Use strace for system call debugging
5. Check GitHub issues or open a new one
