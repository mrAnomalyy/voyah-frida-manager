#!/usr/bin/env bash
set -e

ADB_SERIAL="${ADB_SERIAL:-aaeb4f94}"

echo "=========================================================="
echo "  Voyah Frida Manager — System & Hook Status"
echo "  Target Device: $ADB_SERIAL"
echo "=========================================================="

echo "--- [1] Supervisor Daemon ---"
adb -s "$ADB_SERIAL" shell "ps -A -o PID,PPID,USER,ARGS | grep '[s]upervisor.sh' || echo 'Supervisor is NOT running!'"

echo ""
echo "--- [2] Active Frida Injectors ---"
adb -s "$ADB_SERIAL" shell "ps -A -o PID,PPID,USER,ARGS | grep '[f]rida-inject-15' || echo 'No active injectors.'"

echo ""
echo "--- [3] Deployed Hooks (/data/local/voyahmods/hooks.d/) ---"
adb -s "$ADB_SERIAL" shell "ls -la /data/local/voyahmods/hooks.d/ 2>/dev/null || echo 'Hooks directory not found.'"

echo ""
echo "--- [4] Circuit Breaker & Hook State ---"
adb -s "$ADB_SERIAL" shell "ls -la /data/local/tmp/voyahmods_state/ 2>/dev/null || echo 'State directory empty.'"

echo ""
echo "--- [5] Supervisor Master Log (Last 15 lines) ---"
adb -s "$ADB_SERIAL" shell "tail -n 15 /data/local/tmp/voyahmods_state/supervisor.log 2>/dev/null || echo 'No supervisor log.'"
echo "=========================================================="
