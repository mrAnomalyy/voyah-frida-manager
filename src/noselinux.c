/*
 * noselinux.c — Minimal LD_PRELOAD shim for Android (arm64-v8a)
 *
 * Suppresses frida-inject's unconditional SELinux policy reload
 * (frida_selinux_patch_policy -> /sys/fs/selinux/policy & /sys/fs/selinux/load)
 * when SELinux is already in Permissive mode. This prevents periodic kernel
 * selinuxfs node rebuilds that cause servicemanager "Unknown class" races and
 * system_server DeadSystemException soft reboots.
 *
 * Build command (Android NDK r28+ / API 30):
 *   $NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android30-clang \
 *     -shared -fPIC -O2 -Wall -Wextra -Werror \
 *     -Wl,--soname,libnoselinux.so \
 *     -o bin/libnoselinux.so src/noselinux.c -ldl
 */

#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

__attribute__((constructor))
static void noselinux_init(void) {
    /* Strip LD_PRELOAD before frida spawns helpers (e.g. 32-bit frida-helper-32) */
    unsetenv("LD_PRELOAD");
}

static int is_blocked_selinux_path(const char *path) {
    if (path == NULL) {
        return 0;
    }
    return strcmp(path, "/sys/fs/selinux/policy") == 0 ||
           strcmp(path, "/sys/fs/selinux/load") == 0;
}

int access(const char *pathname, int mode) {
    if (is_blocked_selinux_path(pathname)) {
        errno = ENOENT;
        return -1;
    }
    int (*real_access)(const char *, int) =
        (int (*)(const char *, int))dlsym(RTLD_NEXT, "access");
    if (real_access == NULL) {
        errno = ENOSYS;
        return -1;
    }
    return real_access(pathname, mode);
}

int faccessat(int dirfd, const char *pathname, int mode, int flags) {
    if (is_blocked_selinux_path(pathname)) {
        errno = ENOENT;
        return -1;
    }
    int (*real_faccessat)(int, const char *, int, int) =
        (int (*)(int, const char *, int, int))dlsym(RTLD_NEXT, "faccessat");
    if (real_faccessat == NULL) {
        errno = ENOSYS;
        return -1;
    }
    return real_faccessat(dirfd, pathname, mode, flags);
}

int open(const char *pathname, int flags, ...) {
    if (is_blocked_selinux_path(pathname)) {
        errno = ENOENT;
        return -1;
    }
    int (*real_open)(const char *, int, ...) =
        (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open");
    if (real_open == NULL) {
        errno = ENOSYS;
        return -1;
    }
    if ((flags & (O_CREAT | O_TMPFILE)) != 0) {
        va_list ap;
        va_start(ap, flags);
        mode_t mode = (mode_t)va_arg(ap, int);
        va_end(ap);
        return real_open(pathname, flags, mode);
    }
    return real_open(pathname, flags);
}

int openat(int dirfd, const char *pathname, int flags, ...) {
    if (is_blocked_selinux_path(pathname)) {
        errno = ENOENT;
        return -1;
    }
    int (*real_openat)(int, const char *, int, ...) =
        (int (*)(int, const char *, int, ...))dlsym(RTLD_NEXT, "openat");
    if (real_openat == NULL) {
        errno = ENOSYS;
        return -1;
    }
    if ((flags & (O_CREAT | O_TMPFILE)) != 0) {
        va_list ap;
        va_start(ap, flags);
        mode_t mode = (mode_t)va_arg(ap, int);
        va_end(ap);
        return real_openat(dirfd, pathname, flags, mode);
    }
    return real_openat(dirfd, pathname, flags);
}
