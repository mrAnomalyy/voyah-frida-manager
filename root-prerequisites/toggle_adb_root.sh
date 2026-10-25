#!/system/bin/sh
# ==============================================================================
# VOYAH H53 - ADB Root Toggle Script
# Switches between native root (uid=0) and safe unprivileged shell (uid=2000)
# ==============================================================================

MODDIR=/data/local/voyahmods
FLAG=$MODDIR/enable_adb_root
CMD=/data/local/tmp/.cmd

ROOT_ON='printf "\x31" | dd of=/dev/__properties__/u:object_r:exported2_default_prop:s0 bs=1 seek=6896 count=1 conv=notrunc 2>/dev/null; printf "\x30" | dd of=/dev/__properties__/u:object_r:exported_secure_prop:s0 bs=1 seek=460 count=1 conv=notrunc 2>/dev/null; setprop service.adb.root 1; setprop ctl.restart adbd'

ROOT_OFF='printf "\x30" | dd of=/dev/__properties__/u:object_r:exported2_default_prop:s0 bs=1 seek=6896 count=1 conv=notrunc 2>/dev/null; printf "\x31" | dd of=/dev/__properties__/u:object_r:exported_secure_prop:s0 bs=1 seek=460 count=1 conv=notrunc 2>/dev/null; setprop service.adb.root 0; setprop ctl.restart adbd'

execute_root() {
    exec_cmd="$1"
    if [ "$(id -u)" = "0" ]; then
        eval "$exec_cmd"
    elif [ -f /data/local/tmp/rootshell.pid ]; then
        echo "$exec_cmd" > "$CMD"
        # Wait up to 2 seconds for command completion
        i=0
        while [ $i -lt 10 ]; do
            [ ! -f "$CMD" ] && break
            sleep 0.2
            i=$((i + 1))
        done
    elif command -v su >/dev/null 2>&1; then
        su 0,shell sh -p -c "$exec_cmd"
    else
        echo "Error: No root access available to execute command."
        return 1
    fi
}

case "$1" in
    on)
        mkdir -p "$MODDIR" 2>/dev/null
        touch "$FLAG" 2>/dev/null
        execute_root "$ROOT_ON"
        echo "ADB Root ENABLED. (adbd daemon restarting with root privileges)"
        ;;
    off)
        rm -f "$FLAG" 2>/dev/null
        execute_root "$ROOT_OFF"
        echo "ADB Root DISABLED. (adbd daemon restarting in unprivileged mode)"
        ;;
    status)
        echo "Current ADB user: $(id)"
        if [ -f "$FLAG" ]; then
            echo "Persistent ADB Root flag: ENABLED (/data/local/voyahmods/enable_adb_root)"
        else
            echo "Persistent ADB Root flag: DISABLED"
        fi
        ;;
    *)
        echo "Usage: sh toggle_adb_root.sh [on|off|status]"
        exit 1
        ;;
esac
