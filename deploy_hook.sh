#!/usr/bin/env bash
set -e

ADB_SERIAL="${ADB_SERIAL:-aaeb4f94}"
SCRIPT_PATH="$1"
TARGET_PKG="${2:-com.voyah.car}"

if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    echo "Usage: ./deploy_hook.sh <path/to/script.js> [target_package_name]"
    echo "Example: ./deploy_hook.sh my_hook.js com.voyah.car"
    exit 1
fi

HOOK_NAME=$(basename "$SCRIPT_PATH" .js)

echo "[*] Deploying hook: $HOOK_NAME -> Target: $TARGET_PKG"

# Push script
adb -s "$ADB_SERIAL" push "$SCRIPT_PATH" "/data/local/voyahmods/hooks.d/$HOOK_NAME.js"
adb -s "$ADB_SERIAL" shell "chmod 644 /data/local/voyahmods/hooks.d/$HOOK_NAME.js"

# Set target
adb -s "$ADB_SERIAL" shell "echo '$TARGET_PKG' > /data/local/voyahmods/hooks.d/$HOOK_NAME.target"

# Clear any previous tripped or disabled marker
adb -s "$ADB_SERIAL" shell "rm -f /data/local/voyahmods/hooks.d/$HOOK_NAME.disabled /data/local/tmp/voyahmods_state/$HOOK_NAME.tripped /data/local/tmp/voyahmods_state/$HOOK_NAME.crashes"

echo "[+] Hook $HOOK_NAME deployed successfully!"
echo "    The supervisor will detect and inject it within 5 seconds."
echo "    Monitor logs: adb shell cat /data/local/tmp/voyahmods_state/$HOOK_NAME.log"
