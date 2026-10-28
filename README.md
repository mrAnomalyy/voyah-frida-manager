# Voyah Frida Manager

Production-grade, self-healing Frida hook persistence and supervision framework for the **VOYAH H53 (monza)** Android Automotive (AAOS 11) infotainment head unit.

---

## 🌟 Key Features

* **Multi-Hook Drop-In Directory**: Put any `.js` script into `/data/local/voyahmods/hooks.d/` along with a `.target` file, and it is automatically managed and injected.
* **Auto-Start on Boot**: Uses persistent root boot hook directory (`/data/local/tmp/boot-hooks.d/60-voyahmods.sh`). Survives car cold reboots, deep sleep, and STR cycles.
* **Self-Healing on App Restarts**: If the target system app (`com.voyah.car`, `com.voyah.os.carlauncher`, etc.) crashes, is killed, or restarts, the supervisor detects the new PID and re-injects within 5 seconds.
* **Automotive Bootloop Safety**:
  * **Boot Gate**: Waits for `sys.boot_completed == 1` + 20s settle delay to prevent early-boot race conditions.
  * **Process Health Guard**: Verifies target process state is `S` (sleep) or `R` (running) and uptime $\ge$ 8s before injecting, avoiding half-initialized states.
  * **OOM-Cleaner Avoidance**: Detects Voyah's background cleaner (`com.voyah.cleanoptimization`) alarm schedule via `dumpsys alarm` and postpones injection if a cleanup cycle is due in $<15$s.
  * **Circuit Breaker**: Detects rapid target app deaths ($<15$s). If a hook causes 3 consecutive crashes, it trips and halts auto-injection for that specific hook only (`.tripped`).
  * **Safe Memory Management**: Avoids pinning `-1000` OOM immunity on injectors, allowing the Linux LowMemoryKiller (LMK) to drop Frida scripts gracefully rather than killing critical car safety systems.
  * **Emergency Killswitch**: Touch `/data/local/tmp/voyahmods.disable` to immediately halt all persistent injection.
* **100% Self-Contained**: Bundles the precompiled `frida-inject-15` aarch64 binary and initial root setup scripts. Any individual can clone this repository and deploy it on a clean vehicle from scratch.

---

## 📁 Repository Structure

```
frida-manager/
├── install.sh                  # Host CLI to install supervisor & binaries onto car
├── uninstall.sh                # Host CLI to remove supervisor and all hooks
├── deploy_hook.sh              # Host CLI to deploy a new hook (.js + .target)
├── status.sh                   # Host CLI to check live daemon and hook states
├── bin/
│   └── frida-inject-15         # Precompiled arm64-v8a Frida injection binary
├── device/
│   ├── supervisor.sh           # Master supervisor running on head unit
│   ├── boot_hook.sh            # Boot trigger placed in boot-hooks.d
│   └── toggle_adb_root.sh      # Safe ADB root on/off toggle utility
├── examples/
│   ├── example_hook.js         # Safe Frida JS template with try/catch boundaries
│   └── example_hook.target     # Target process configuration
└── root-prerequisites/         # One-time setup package for clean/stock cars
    ├── README.md               # Explanation of root mechanism
    ├── README.ru.md            # Russian guide
    ├── setup_root.sh           # 1-click root exploit deployment
    ├── toggle_adb_root.sh      # Root toggle helper
    └── VoyahBootPolicy_ROOT.tar.gz  # Persistent XDJA IDPS policy
```

---

## ⚡ Quick Start

### 0. First-Time Setup on a Stock Vehicle (If Root is not yet installed)

If your vehicle is completely stock and does not have root access yet, run:

```bash
cd root-prerequisites
./setup_root.sh
cd ..
```

### 1. Installation

Connect your computer via USB to the vehicle's debugging port and run:

```bash
./install.sh
```

`install.sh` will automatically:
1. Verify root capability.
2. Push `bin/frida-inject-15` to `/data/local/voyahmods/frida-inject-15`.
3. Push `supervisor.sh` and register `/data/local/tmp/boot-hooks.d/60-voyahmods.sh`.
4. Start the supervisor in the background.
5. Return USB ADB to the unprivileged safe state (`toggle_adb_root.sh off`).

---

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
