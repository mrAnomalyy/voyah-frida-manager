#!/usr/bin/env bash
set -e

ADB_SERIAL="${ADB_SERIAL:-aaeb4f94}"

echo "=========================================================="
echo "  Voyah Frida Manager — Uninstallation"
echo "  Target Device: $ADB_SERIAL"
echo "=========================================================="

# 1. Verify ADB connection
if ! adb -s "$ADB_SERIAL" get-state >/dev/null 2>&1; then
    echo "[-] Error: Device $ADB_SERIAL is not connected."
    exit 1
fi

# 2. Check & Enable root access if required
UID_OUT=$(adb -s "$ADB_SERIAL" shell id -u 2>/dev/null | tr -d '\r\n')
if [ "$UID_OUT" != "0" ]; then
    echo "[*] Enabling root over USB..."
    adb -s "$ADB_SERIAL" shell "su 0,shell sh /data/local/voyahmods/toggle_adb_root.sh on"
    sleep 1
fi

# 3. Engage killswitch (graceful termination of supervisor loop)
echo "[*] Engaging emergency killswitch..."
adb -s "$ADB_SERIAL" shell "touch /data/local/tmp/voyahmods.disable"
sleep 2

# 4. Stop any lingering frida-inject-15 processes
echo "[*] Terminating active frida-inject processes..."
adb -s "$ADB_SERIAL" shell "killall frida-inject-15 2>/dev/null || true"

# 5. Stop supervisor process
echo "[*] Terminating supervisor daemon..."
adb -s "$ADB_SERIAL" shell "pkill -f 'supervisor.sh' 2>/dev/null || true"
sleep 1

# 6. Remove boot hook (prevents auto-start on boot)
echo "[*] Removing boot hook /data/local/tmp/boot-hooks.d/60-voyahmods.sh..."
adb -s "$ADB_SERIAL" shell "rm -f /data/local/tmp/boot-hooks.d/60-voyahmods.sh"

# 7. Remove supervisor script
echo "[*] Removing /data/local/voyahmods/supervisor.sh..."
adb -s "$ADB_SERIAL" shell "rm -f /data/local/voyahmods/supervisor.sh"

# 8. Clean up state directory
echo "[*] Removing state directory /data/local/tmp/voyahmods_state/..."
adb -s "$ADB_SERIAL" shell "rm -rf /data/local/tmp/voyahmods_state"

# 9. Clean up killswitch files
echo "[*] Resetting killswitch files..."
adb -s "$ADB_SERIAL" shell "rm -f /data/local/tmp/voyahmods.disable /data/local/voyahmods/disable"

# 10. Check target app status
echo "[*] Verifying vehicle system services..."
CAR_PID=$(adb -s "$ADB_SERIAL" shell "pidof com.voyah.car" 2>/dev/null | tr -d '\r\n')
if [ -n "$CAR_PID" ] && [ "$CAR_PID" -gt 0 ]; then
    echo "[+] com.voyah.car is running stably (PID $CAR_PID)."
fi

# 11. Safe mode hygiene
echo "[*] Returning ADB to unprivileged safe mode (off)..."
adb -s "$ADB_SERIAL" shell "sh /data/local/voyahmods/toggle_adb_root.sh off" >/dev/null 2>&1 || true

echo "=========================================================="
echo "  Uninstallation Complete!"
echo "  Note: User scripts in /data/local/voyahmods/hooks.d/ were"
echo "  preserved. Remove them manually if no longer needed."
echo "=========================================================="
