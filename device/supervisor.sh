#!/system/bin/sh
# /data/local/voyahmods/supervisor.sh
# Production Master Supervisor for VoyahMods Persistent Frida Hooks

TAG="voyahmods-supervisor"
HOOKS_DIR="/data/local/voyahmods/hooks.d"
STATE_DIR="/data/local/tmp/voyahmods_state"
KILLSWITCH="/data/local/tmp/voyahmods.disable"
GLOBAL_KILLSWITCH="/data/local/voyahmods/disable"
FRIDA_INJECT="/data/local/voyahmods/frida-inject-15"
MAX_CRASHES=3
SETTLE_SECONDS=20

mkdir -p "$HOOKS_DIR" "$STATE_DIR"

# 1. Global Killswitch Check
if [ -f "$KILLSWITCH" ] || [ -f "$GLOBAL_KILLSWITCH" ]; then
    echo "[$TAG] Killswitch file present. Supervisor aborted." >> "$STATE_DIR/supervisor.log"
    exit 0
fi

# 2. Boot Completion Gate
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 3
done
sleep "$SETTLE_SECONDS"

# 3. Ensure Environment
setenforce 0 2>/dev/null
export TMPDIR=/data/local/tmp

echo "[$TAG] Supervisor initialized at $(date)" >> "$STATE_DIR/supervisor.log"

# 4. Log Rotation (capped at 256KB)
trim_log() {
    _lf="$1"
    [ -f "$_lf" ] || return 0
    _sz=$(stat -c %s "$_lf" 2>/dev/null || echo 0)
    if [ "$_sz" -gt 262144 ]; then
        tail -c 65536 "$_lf" > "$_lf.trim" 2>/dev/null && mv "$_lf.trim" "$_lf"
    fi
}

# 5. Supervisor Loop
while true; do
    # Immediate exit if killswitch appears
    if [ -f "$KILLSWITCH" ] || [ -f "$GLOBAL_KILLSWITCH" ]; then
        echo "[$TAG] Killswitch engaged. Terminating all managed injectors." >> "$STATE_DIR/supervisor.log"
        killall frida-inject-15 2>/dev/null
        exit 0
    fi

    # Log rotation
    trim_log "$STATE_DIR/supervisor.log"

    # Clean up any injector whose script was deleted or muted (.disabled)
    for pid_file in "$STATE_DIR"/*.inj_pid; do
        [ -f "$pid_file" ] || continue
        h_name=$(basename "$pid_file" .inj_pid)

        if [ ! -f "$HOOKS_DIR/$h_name.js" ] || [ -f "$HOOKS_DIR/$h_name.disabled" ]; then
            inj_pid=$(cat "$pid_file" 2>/dev/null)
            if [ -n "$inj_pid" ] && [ -d "/proc/$inj_pid" ]; then
                comm=$(cat "/proc/$inj_pid/comm" 2>/dev/null)
                if [ "$comm" = "frida-inject-15" ]; then
                    echo "[$TAG] Stopping disabled/removed hook: $h_name (PID $inj_pid)" >> "$STATE_DIR/supervisor.log"
                    kill "$inj_pid" 2>/dev/null
                fi
            fi
            rm -f "$pid_file" "$STATE_DIR/$h_name.injected_pid" "$STATE_DIR/$h_name.inj_time"
        fi
    done

    # Scan drop-in directory
    for script_file in "$HOOKS_DIR"/*.js; do
        [ -f "$script_file" ] || continue
        hook_name=$(basename "$script_file" .js)

        # Check if hook is manually disabled
        if [ -f "$HOOKS_DIR/$hook_name.disabled" ]; then
            continue
        fi

        # Determine target process name (default: com.voyah.car)
        target_file="$HOOKS_DIR/$hook_name.target"
        if [ -f "$target_file" ]; then
            target_pkg=$(cat "$target_file" 2>/dev/null | tr -d '\r\n ')
        else
            target_pkg="com.voyah.car"
        fi
        [ -z "$target_pkg" ] && target_pkg="com.voyah.car"

        # Check Circuit Breaker
        tripped_file="$STATE_DIR/$hook_name.tripped"
        crash_file="$STATE_DIR/$hook_name.crashes"
        if [ -f "$tripped_file" ]; then
            continue
        fi

        # Resolve Target PID
        target_pid=$(pidof "$target_pkg" 2>/dev/null | cut -d" " -f1)
        if [ -z "$target_pid" ] || [ "$target_pid" -le 0 ]; then
            continue
        fi

        # Check if already running for this target PID
        pid_tracker="$STATE_DIR/$hook_name.injected_pid"
        last_pid=$(cat "$pid_tracker" 2>/dev/null || echo 0)

        inj_pid_file="$STATE_DIR/$hook_name.inj_pid"
        last_inj_pid=$(cat "$inj_pid_file" 2>/dev/null || echo 0)

        is_running=0
        if [ "$last_pid" = "$target_pid" ] && [ "$last_inj_pid" -gt 0 ]; then
            if kill -0 "$last_inj_pid" 2>/dev/null; then
                is_running=1
            fi
        fi

        # Re-inject if target restarted or injector dropped
        if [ "$is_running" = "0" ]; then
            crashes=$(cat "$crash_file" 2>/dev/null || echo 0)

            # Crash detection: did target die within 15 seconds of previous injection?
            last_inj_time_file="$STATE_DIR/$hook_name.inj_time"
            last_time=$(cat "$last_inj_time_file" 2>/dev/null || echo 0)
            now=$(date +%s)
            elapsed=$((now - last_time))

            if [ "$last_time" -gt 0 ] && [ "$elapsed" -lt 15 ]; then
                crashes=$((crashes + 1))
                echo "$crashes" > "$crash_file"
                echo "[$TAG] Warning: $hook_name target ($target_pkg) died in ${elapsed}s (crash $crashes/$MAX_CRASHES)" >> "$STATE_DIR/supervisor.log"

                if [ "$crashes" -ge "$MAX_CRASHES" ]; then
                    touch "$tripped_file"
                    echo "[$TAG] CRITICAL: Circuit breaker TRIPPED for $hook_name! Stopped auto-injection." >> "$STATE_DIR/supervisor.log"
                    continue
                fi
            else
                # Stable run (survived >15s) — reset crash counter
                if [ "$crashes" -gt 0 ]; then
                    echo 0 > "$crash_file"
                fi
            fi

            # Ensure SELinux is permissive before injection
            if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
                setenforce 0 2>/dev/null
            fi

            echo "[$TAG] Injecting $hook_name into $target_pkg (PID $target_pid)..." >> "$STATE_DIR/supervisor.log"
            echo "$target_pid" > "$pid_tracker"
            echo "$now" > "$last_inj_time_file"

            nohup env TMPDIR=/data/local/tmp "$FRIDA_INJECT" -p "$target_pid" -s "$script_file" </dev/null >> "$STATE_DIR/$hook_name.log" 2>&1 &
            inj_pid=$!
            echo "$inj_pid" > "$inj_pid_file"
        fi
    done

    sleep 5
done
