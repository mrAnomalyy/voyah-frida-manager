#!/usr/bin/env bash
set -e

ADB_SERIAL="${ADB_SERIAL:-$(adb devices 2>/dev/null | grep -v 'List' | grep 'device' | head -n 1 | awk '{print $1}')}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPERVISOR_SRC="$SCRIPT_DIR/device/supervisor.sh"
BOOT_HOOK_SRC="$SCRIPT_DIR/device/boot_hook.sh"
TOGGLE_ROOT_SRC="$SCRIPT_DIR/device/toggle_adb_root.sh"
FRIDA_BIN_SRC="$SCRIPT_DIR/bin/frida-inject-15"

echo "=========================================================="
echo "  Voyah Frida Manager — Installation"
echo "  Target Device: ${ADB_SERIAL:-<auto-detect>}"
echo "=========================================================="

# 1. Verify ADB connection
if [ -z "$ADB_SERIAL" ] || ! adb -s "$ADB_SERIAL" get-state >/dev/null 2>&1; then
    echo "[-] Error: No ADB device connected."
    echo "    Please plug in the USB cable to the VOYAH head unit and verify 'adb devices'."
    exit 1
fi
echo "[+] Device $ADB_SERIAL connected."

# 2. Verify Root Prerequisites
echo "[*] Checking root capability..."
CURRENT_UID=$(adb -s "$ADB_SERIAL" shell id -u 2>/dev/null | tr -d '\r\n')

if [ "$CURRENT_UID" != "0" ]; then
    # Test if su 0,shell or toggle_adb_root works
    CAN_ROOT=0
    if adb -s "$ADB_SERIAL" shell "su 0,shell id -u" 2>/dev/null | grep -q "0"; then
        CAN_ROOT=1
    elif adb -s "$ADB_SERIAL" shell "sh /data/local/voyahmods/toggle_adb_root.sh on" 2>/dev/null; then
        sleep 1
        [ "$(adb -s "$ADB_SERIAL" shell id -u 2>/dev/null | tr -d '\r\n')" = "0" ] && CAN_ROOT=1
    fi

    if [ "$CAN_ROOT" = "0" ]; then
        echo "[-] Error: Persistent root is not active on this vehicle."
        echo "    For a clean or stock vehicle, please run the one-time root setup first:"
        echo "    cd root-prerequisites && ./setup_root.sh"
        exit 1
    fi

    echo "[*] Enabling root over USB..."
    adb -s "$ADB_SERIAL" shell "su 0,shell sh /data/local/voyahmods/toggle_adb_root.sh on" 2>/dev/null || true
    sleep 1
fi

ROOT_CHECK=$(adb -s "$ADB_SERIAL" shell id 2>/dev/null || echo "")
if ! echo "$ROOT_CHECK" | grep -q "uid=0(root)"; then
    echo "[-] Error: Failed to obtain root shell on device ($ROOT_CHECK)."
    exit 1
fi
echo "[+] Root confirmed: $ROOT_CHECK"

# 3. Create required directories
echo "[*] Preparing target directories on device..."
adb -s "$ADB_SERIAL" shell "mkdir -p /data/local/voyahmods/hooks.d /data/local/tmp/boot-hooks.d /data/local/tmp/voyahmods_state"

# 4. Push toggle_adb_root helper
if [ -f "$TOGGLE_ROOT_SRC" ]; then
    echo "[*] Pushing root toggle utility..."
    adb -s "$ADB_SERIAL" push "$TOGGLE_ROOT_SRC" /data/local/voyahmods/toggle_adb_root.sh >/dev/null
    adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/voyahmods/toggle_adb_root.sh"
fi

# 5. Push frida-inject binary if missing or update needed
echo "[*] Verifying frida-inject-15 binary on device..."
FRIDA_EXISTS=$(adb -s "$ADB_SERIAL" shell "[ -x /data/local/voyahmods/frida-inject-15 ] && echo 1 || echo 0" 2>/dev/null | tr -d '\r\n')
if [ "$FRIDA_EXISTS" != "1" ]; then
    if [ ! -f "$FRIDA_BIN_SRC" ]; then
        echo "[-] Error: Local binary $FRIDA_BIN_SRC is missing!"
        exit 1
    fi
    echo "[*] Deploying frida-inject-15 to /data/local/voyahmods/..."
    adb -s "$ADB_SERIAL" push "$FRIDA_BIN_SRC" /data/local/voyahmods/frida-inject-15
    adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/voyahmods/frida-inject-15"
fi

# 6. Push supervisor script
echo "[*] Pushing supervisor script to /data/local/voyahmods/supervisor.sh..."
adb -s "$ADB_SERIAL" push "$SUPERVISOR_SRC" /data/local/voyahmods/supervisor.sh
adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/voyahmods/supervisor.sh"

# 7. Install boot-hook trigger
echo "[*] Registering boot trigger at /data/local/tmp/boot-hooks.d/60-voyahmods.sh..."
adb -s "$ADB_SERIAL" push "$BOOT_HOOK_SRC" /data/local/tmp/boot-hooks.d/60-voyahmods.sh
adb -s "$ADB_SERIAL" shell "chmod 755 /data/local/tmp/boot-hooks.d/60-voyahmods.sh"

# 8. Start supervisor in background (detached under init PPID 1)
echo "[*] Checking live supervisor process..."
if ! adb -s "$ADB_SERIAL" shell "ps -A -o ARGS 2>/dev/null | grep -q '[s]upervisor.sh'"; then
    echo "[*] Starting supervisor in background..."
    adb -s "$ADB_SERIAL" shell "echo \$\$ > /acct/tasks 2>/dev/null; setsid sh -p /data/local/voyahmods/supervisor.sh </dev/null >/dev/null 2>&1 &"
    sleep 1
fi

# 9. Safe mode hygiene (turn ADB root OFF)
echo "[*] Toggling ADB root back to unprivileged safe mode (off)..."
adb -s "$ADB_SERIAL" shell "sh /data/local/voyahmods/toggle_adb_root.sh off" >/dev/null 2>&1 || true
sleep 1

echo "=========================================================="
echo "  Installation Complete!"
echo "  Drop-in hook directory: /data/local/voyahmods/hooks.d/"
echo "  Deploy new hook: ./deploy_hook.sh <script.js> [target_pkg]"
echo "=========================================================="
