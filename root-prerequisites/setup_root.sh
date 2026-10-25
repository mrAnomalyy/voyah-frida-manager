#!/usr/bin/env bash
# ==============================================================================
# VOYAH H53 - Root Prerequisites Installer
# Sets up persistent root capability and toggle_adb_root.sh on the head unit
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " VOYAH H53: Root Prerequisites Setup"
echo "=========================================================="

# Check ADB
if ! command -v adb &> /dev/null; then
    echo "[!] Error: adb not found. Please install Android platform-tools."
    exit 1
fi

DEVICE=$(adb devices | grep -v "List" | grep "device" | head -n 1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
    echo "[!] Error: No device found via ADB. Connect USB cable to head unit."
    exit 1
fi

echo "[*] Target device: $DEVICE"

# 1. Create target directory
echo "[1/4] Preparing directories on device..."
adb shell "mkdir -p /data/local/tmp /data/local/voyahmods" 2>/dev/null || true

# 2. Push scripts and policy
echo "[2/4] Uploading root files to head unit..."
adb push "$DIR/toggle_adb_root.sh" /data/local/voyahmods/toggle_adb_root.sh
adb shell "chmod 755 /data/local/voyahmods/toggle_adb_root.sh"

adb push "$DIR/VoyahBootPolicy_ROOT.tar.gz" /data/local/voyahmods/VoyahBootPolicy_ROOT.tar.gz
adb push "$DIR/VoyahBootPolicy_ROOT.tar.gz" /data/local/tmp/new_policy.tar.gz

# 3. Deploy to persist partition
echo "[3/4] Installing policy into XDJA IDPS security daemon..."
# Try deployment via su 0,shell or direct copy
DEPLOY_CMD="cp /data/local/tmp/new_policy.tar.gz /mnt/vendor/persist/xdja_idps/data/update/policy/new_policy && chmod 0644 /mnt/vendor/persist/xdja_idps/data/update/policy/new_policy && setprop ctl.restart xdja_idps"

if adb shell "id -u" 2>/dev/null | grep -q "^0"; then
    adb shell "$DEPLOY_CMD"
elif adb shell "command -v su" 2>/dev/null | grep -q "su"; then
    adb shell "su 0,shell sh -p -c '$DEPLOY_CMD'"
else
    # Fallback to direct shell execution if permission allows
    adb shell "$DEPLOY_CMD" || true
fi

echo "[*] Waiting 3 seconds for IDPS daemon restart..."
sleep 3

# 4. Verification & Testing ADB Root
echo "[4/4] Activating ADB Root via toggle_adb_root.sh..."
adb shell "sh /data/local/voyahmods/toggle_adb_root.sh on" || true
sleep 3

CURRENT_ID=$(adb shell id 2>/dev/null || echo "failed")
echo "[*] Verification result: $CURRENT_ID"

if echo "$CURRENT_ID" | grep -q "uid=0(root)"; then
    echo ""
    echo "=========================================================="
    echo " SUCCESS: Root access is configured and working!"
    echo " USB ADB is currently running as root."
    echo "=========================================================="
else
    echo ""
    echo "[!] Note: Could not immediately confirm root. Please check connection."
fi
