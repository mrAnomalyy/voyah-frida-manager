#!/usr/bin/env bash
set -e

ADB_SERIAL="${ADB_SERIAL:-aaeb4f94}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPERVISOR_SRC="$SCRIPT_DIR/device/supervisor.sh"
BOOT_HOOK_SRC="$SCRIPT_DIR/device/boot_hook.sh"

echo "=========================================================="
echo "  Voyah Frida Manager — Installation"
echo "  Target Device: $ADB_SERIAL"
echo "=========================================================="

# 1. Verify ADB connection
if ! adb -s "$ADB_SERIAL" get-state >/dev/null 2>&1; then
    echo "[-] Error: Device $ADB_SERIAL is not connected."
    exit 1
fi
echo "[+] Device $ADB_SERIAL connected."

# 2. Check & Enable root access if required
UID_OUT=$(adb -s "$ADB_SERIAL" shell id -u 2>/dev/null | tr -d '\r\n')
if [ "$UID_OUT" != "0" ]; then
    echo "[*] Enabling root over USB..."
    adb -s "$ADB_SERIAL" shell "su 0,shell sh /data/local/voyahmods/toggle_adb_root.sh on"
    sleep 1
fi
echo "[+] Root confirmed: $(adb -s "$ADB_SERIAL" shell id)"

# 3. Create required directories
echo "[*] Preparing target directories on device..."
adb -s "$ADB_SERIAL" shell "mkdir -p /data/local/voyahmods/hooks.d /data/local/tmp/boot-hooks.d /data/local/tmp/voyahmods_state"

# 4. Push supervisor script
echo "[*] Pushing supervisor script to /data/local/voyahmods/supervisor.sh..."
adb -s "$ADB_SERIAL" push "$SUPERVISOR_SRC" /data/local/voyahmods/supervisor.sh
adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/voyahmods/supervisor.sh"

# 5. Install boot-hook trigger
echo "[*] Registering boot trigger at /data/local/tmp/boot-hooks.d/60-voyahmods.sh..."
adb -s "$ADB_SERIAL" push "$BOOT_HOOK_SRC" /data/local/tmp/boot-hooks.d/60-voyahmods.sh
adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/tmp/boot-hooks.d/60-voyahmods.sh"

# 6. Start supervisor in background (detached under init PPID 1)
echo "[*] Checking live supervisor process..."
if ! adb -s "$ADB_SERIAL" shell "ps -A -o ARGS 2>/dev/null | grep -q '[s]upervisor.sh'"; then
    echo "[*] Starting supervisor in background..."
    adb -s "$ADB_SERIAL" shell "echo \$\$ > /acct/tasks 2>/dev/null; setsid sh -p /data/local/voyahmods/supervisor.sh </dev/null >/dev/null 2>&1 &"
    sleep 1
fi

# 7. Safe mode hygiene
echo "[*] Toggling ADB root back to safe mode (off)..."
adb -s "$ADB_SERIAL" shell "sh /data/local/voyahmods/toggle_adb_root.sh off" >/dev/null 2>&1 || true
sleep 1

echo "=========================================================="
echo "  Installation Complete!"
echo "  Drop-in hook directory: /data/local/voyahmods/hooks.d/"
echo "  Deploy new hook: ./deploy_hook.sh <script.js> [target_pkg]"
echo "=========================================================="
