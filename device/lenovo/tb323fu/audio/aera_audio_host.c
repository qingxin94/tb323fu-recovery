/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * TB323FU recovery AGM/PAL host.
 *
 * The stock vendor libraries export registerService().  We deliberately do
 * NOT link libbinder_ndk at build time: the stock AGM/PAL libraries already
 * NEED libbinder_ndk.so, and loading the vendor libbinder.so first makes the
 * whole process use /dev/vndbinder (the vendor domain).  The host then shares
 * exactly one binder copy with the stock AGM/PAL runtime.
 */
#include <android/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static const char kTag[] = "AERA_AudioHost";
static const char kAgmLibrary[] = "libagmipcservice.so";
static const char kPalLibrary[] = "libpalipcservice.so";
static const char kBinderNdk[] = "libbinder_ndk.so";

typedef void* AIBinder;

struct BinderApi {
    bool (*set_thread_pool_max)(int);
    void (*start_thread_pool)(void);
    void (*join_thread_pool)(void);
    AIBinder* (*check_service)(const char*);
    void (*dec_strong)(AIBinder*);
};

static struct BinderApi g_binder;

static void log_line(int priority, const char* text) {
    __android_log_write(priority, kTag, text);
    fprintf(stderr, "AERA audio host: %s\n", text);
}

static int file_readable(const char* path) {
    return access(path, R_OK) == 0;
}

static bool load_binder_api(void* library) {
    g_binder.set_thread_pool_max = (bool (*)(int))dlsym(
        library, "ABinderProcess_setThreadPoolMaxThreadCount");
    g_binder.start_thread_pool = (void (*)(void))dlsym(
        library, "ABinderProcess_startThreadPool");
    g_binder.join_thread_pool = (void (*)(void))dlsym(
        library, "ABinderProcess_joinThreadPool");
    g_binder.check_service = (AIBinder* (*)(const char*))dlsym(
        library, "AServiceManager_checkService");
    g_binder.dec_strong = (void (*)(AIBinder*))dlsym(
        library, "AIBinder_decStrong");
    return g_binder.set_thread_pool_max && g_binder.start_thread_pool &&
           g_binder.join_thread_pool && g_binder.check_service &&
           g_binder.dec_strong;
}

/* Preload the vendor libbinder.so.  libbinder_ndk.so will then reuse this
 * already-loaded copy, so ProcessState defaults to /dev/vndbinder instead of
 * the recovery system /dev/binder. */
static void preload_vendor_binder(const char* vendor_root) {
    char path[512];
    snprintf(path, sizeof(path), "%s/lib64/libbinder.so", vendor_root);
    if (!file_readable(path))
        snprintf(path, sizeof(path), "/vendor/lib64/libbinder.so");
    if (!file_readable(path)) {
        log_line(ANDROID_LOG_WARN, "vendor libbinder.so is unavailable");
        return;
    }
    void* library = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (library == NULL) {
        char message[640];
        snprintf(message, sizeof(message), "vendor libbinder preload failed: %s",
                 dlerror());
        log_line(ANDROID_LOG_WARN, message);
        return;
    }
    char message[640];
    snprintf(message, sizeof(message), "vendor libbinder preloaded: %s", path);
    log_line(ANDROID_LOG_INFO, message);
}

static void* register_service_library(const char* vendor_root,
                                      const char* library_name,
                                      const char* instance,
                                      const char* label,
                                      bool* confirmed) {
    *confirmed = false;
    char path[512];
    snprintf(path, sizeof(path), "%s/lib64/%s", vendor_root, library_name);
    if (!file_readable(path)) {
        char message[640];
        snprintf(message, sizeof(message), "%s missing at %s", label, path);
        log_line(ANDROID_LOG_ERROR, message);
        return NULL;
    }

    void* library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        char message[640];
        snprintf(message, sizeof(message), "%s dlopen failed: %s", label,
                 dlerror());
        log_line(ANDROID_LOG_ERROR, message);
        return NULL;
    }

    dlerror();
    void (*register_service)(void) = NULL;
    *(void**)(&register_service) = dlsym(library, "registerService");
    const char* symbol_error = dlerror();
    if (register_service == NULL || symbol_error != NULL) {
        char message[640];
        snprintf(message, sizeof(message), "%s registerService missing: %s",
                 label, symbol_error ? symbol_error : "not exported");
        log_line(ANDROID_LOG_ERROR, message);
        dlclose(library);
        return NULL;
    }

    register_service();
    AIBinder* service = g_binder.check_service(instance);
    if (service == NULL) {
        char message[640];
        snprintf(message, sizeof(message),
                 "%s registration not confirmed for %s", label, instance);
        log_line(ANDROID_LOG_ERROR, message);
        dlclose(library);
        return NULL;
    }
    g_binder.dec_strong(service);
    *confirmed = true;

    char message[640];
    snprintf(message, sizeof(message), "%s registered from %s", label, path);
    log_line(ANDROID_LOG_INFO, message);
    return library;
}

int main(int argc, char** argv) {
    const char* vendor_root = "/mnt/aera-stock/vendor";
    if (argc > 1 && argv[1][0] != '\0')
        vendor_root = argv[1];

    char agm_path[512];
    snprintf(agm_path, sizeof(agm_path), "%s/lib64/%s", vendor_root,
             kAgmLibrary);
    if (!file_readable(agm_path) &&
        file_readable("/vendor/lib64/libagmipcservice.so"))
        vendor_root = "/vendor";

    if (getuid() != 0) {
        log_line(ANDROID_LOG_ERROR, "must run as root");
        return 64;
    }

    preload_vendor_binder(vendor_root);

    void* binder_library = dlopen(kBinderNdk, RTLD_NOW | RTLD_LOCAL);
    if (binder_library == NULL || !load_binder_api(binder_library)) {
        char message[640];
        snprintf(message, sizeof(message), "libbinder_ndk load failed: %s",
                 dlerror() ? dlerror() : "missing symbols");
        log_line(ANDROID_LOG_ERROR, message);
        return 67;
    }

    g_binder.set_thread_pool_max(8);
    g_binder.start_thread_pool();

    bool agm_confirmed = false;
    void* agm = register_service_library(
        vendor_root, kAgmLibrary, "vendor.qti.hardware.agm.IAGM/default",
        "AGM", &agm_confirmed);

    bool pal_confirmed = false;
    void* pal = register_service_library(
        vendor_root, kPalLibrary, "vendor.qti.hardware.pal.IPAL/default",
        "PAL", &pal_confirmed);

    if (!agm_confirmed && !pal_confirmed) {
        log_line(ANDROID_LOG_ERROR,
                 "no AGM/PAL service could be registered; audio host unavailable");
        if (pal) dlclose(pal);
        if (agm) dlclose(agm);
        return 70;
    }

    char message[640];
    snprintf(message, sizeof(message),
             "AGM/PAL binder services ready (AGM=%d PAL=%d)", agm_confirmed,
             pal_confirmed);
    log_line(ANDROID_LOG_INFO, message);

    g_binder.join_thread_pool();
    log_line(ANDROID_LOG_ERROR, "binder thread pool exited unexpectedly");
    if (pal) dlclose(pal);
    if (agm) dlclose(agm);
    return 70;
}
