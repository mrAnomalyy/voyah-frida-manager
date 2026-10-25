# VOYAH H53 — Root Prerequisites Package

This folder contains the self-contained root tools required by Android 11 to allow memory-inspection and runtime hook tools (such as Frida) to interact with vehicle applications.

---

## Why is Root Needed for ISLC Activation?

1. **Production Android Build (`ro.debuggable=0`):** The head unit is a production user build. Standard `adb root` commands are denied by Android.
2. **SELinux Isolation:** Android 11 enforces SELinux rules that prevent normal `uid=2000(shell)` from inspecting memory or using `ptrace` on system apps like `com.xiaoma.appstore`.
3. **Hardware SOME/IP Communication:** Sending vehicle signal `1677721855` requires invoking `MegaCarPropHelper` inside an authorized system process.

---

## Files in this Directory

| File | Purpose |
|---|---|
| `toggle_adb_root.sh` | On-device script to switch ADB daemon between `root` (`uid=0`) and safe `shell` (`uid=2000`) |
| `VoyahBootPolicy_ROOT.tar.gz` | Persistent root policy deployed to the `xdja_idps` security service on `/mnt/vendor/persist` |
| `setup_root.sh` | 1-click installer to configure root on a stock vehicle |

---

## Usage

If the car is completely stock and has never had root or `toggle_adb_root.sh` installed, simply run:

```bash
./setup_root.sh
```

This will:
1. Push `toggle_adb_root.sh` to `/data/local/voyahmods/toggle_adb_root.sh`.
2. Deploy the root policy to the persist partition.
3. Restart the IDPS service.
4. Verify root access over USB ADB.
