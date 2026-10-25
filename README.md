# Voyah Frida Manager

Production-grade, self-healing Frida hook persistence and supervision framework for the **VOYAH H53 (monza)** Android Automotive (AAOS 11) infotainment head unit.

---

## 🌟 Key Features

* **Multi-Hook Drop-In Directory**: Put any `.js` script into `/data/local/voyahmods/hooks.d/` along with a `.target` file, and it is automatically managed and injected.
* **Auto-Start on Boot**: Uses Passion-NG's persistent root boot hook directory (`/data/local/tmp/boot-hooks.d/60-voyahmods.sh`). Survives car reboots and sleep/wake cycles.
* **Self-Healing on App Restarts**: If the target system app (`com.voyah.car`, `com.voyah.os.carlauncher`, etc.) crashes, is killed, or restarts, the supervisor detects the new PID and re-injects within 5 seconds.
* **Automotive Bootloop Safety**:
  * **Boot Gate**: Waits for `sys.boot_completed == 1` + 20s settle delay to prevent early-boot race conditions.
  * **Circuit Breaker**: Detects rapid target app deaths ($<15$s). If a hook causes 3 consecutive crashes, it trips and halts auto-injection for that specific hook only.
  * **Safe Memory Management**: Avoids pinning `-1000` OOM immunity on injectors, allowing the Linux LowMemoryKiller (LMK) to drop Frida scripts gracefully rather than killing critical car safety systems.
  * **Emergency Killswitch**: Touch `/data/local/tmp/voyahmods.disable` to immediately halt all persistent injection.

---

## 📁 Repository Structure

```
frida-manager/
├── install.sh                  # Host CLI to install supervisor onto car
├── uninstall.sh                # Host CLI to remove supervisor and all hooks
├── deploy_hook.sh              # Host CLI to deploy a new hook (.js + .target)
├── status.sh                   # Host CLI to check live daemon and hook states
├── device/
│   ├── supervisor.sh           # Master supervisor running on head unit
│   └── boot_hook.sh            # Boot trigger placed in boot-hooks.d
└── examples/
    ├── example_hook.js         # Safe Frida JS template with try/catch boundaries
    └── example_hook.target     # Target process configuration
```

---

## ⚡ Quick Start

### 1. Installation (One-Time Setup)

Connect laptop via USB to the vehicle and run:
```bash
./install.sh
```

### 2. Deploying a Hook

To deploy any Frida script:
```bash
./deploy_hook.sh path/to/my_hook.js com.voyah.car
```
The supervisor detects it within 5 seconds and begins auto-injection.

### 3. Monitoring Status & Logs

```bash
./status.sh
```
Or directly on device:
```bash
# Supervisor master log:
adb shell "cat /data/local/tmp/voyahmods_state/supervisor.log"

# Individual hook output:
adb shell "cat /data/local/tmp/voyahmods_state/<hook_name>.log"
```

### 4. Muting or Removing a Hook

* **Temporary Mute**:
  ```bash
  adb shell "touch /data/local/voyahmods/hooks.d/<hook_name>.disabled"
  ```
  The supervisor automatically stops the injector within 5 seconds.
* **Permanent Removal**:
  ```bash
  adb shell "rm -f /data/local/voyahmods/hooks.d/<hook_name>.js /data/local/voyahmods/hooks.d/<hook_name>.target"
  ```

### 5. Full Uninstallation

To completely remove the supervisor and all boot persistence:
```bash
./uninstall.sh
```
