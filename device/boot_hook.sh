#!/system/bin/sh
# /data/local/tmp/boot-hooks.d/60-voyahmods.sh
# Auto-start VoyahMods Persistent Hook Supervisor on vehicle boot
[ -f /data/local/voyahmods/supervisor.sh ] && exec sh -p /data/local/voyahmods/supervisor.sh
