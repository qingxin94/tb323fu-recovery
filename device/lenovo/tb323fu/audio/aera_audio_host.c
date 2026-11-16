/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * TB323FU recovery AGM/PAL service host.
 *
 * The stock vendor image contains libagmipcservice.so and libpalipcservice.so.
 * Each library exports a registerService() entry point.  AERA does not run the
 * full Android audio HAL; this process only registers IAGM and IPAL with the
 * recovery binder service manager so a narrow player can use the stock
 * AudioReach runtime.  The libraries are loaded from the installed vendor
 * partition, not from the recovery ramdisk.
 */
#include <android/binder_ibinder.h>
#include <android/binder_process.h>
#include <android/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static const char kTag[] = "AERA_AudioHost";

static void log_line(int priority, const char* text) {
    __android_log_write(priority, kTag, text);
    fprintf(stderr, "AERA audio host: %s\n", text);
}

static int file_readable(const char* path) {
    return access(path, R_OK) == 0;
}

/* binder_manager.h exposes C++-only spellings in this branch; the exported
 * NDK entry point itself has a C ABI. */
AIBinder* AServiceManager_checkService(const char* instance);

static void* load_service(const char* directory, const char* library_name,
                          const char* instance, const char* label) {
    char path[512];
    snprintf(path, sizeof(path), "%s/lib64/%s", directory, library_name);
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
    AIBinder* service = AServiceManager_checkService(instance);
    if (service == NULL) {
        char message[640];
        snprintf(message, sizeof(message), "%s registration missing for %s",
                 label, instance);
        log_line(ANDROID_LOG_ERROR, message);
        dlclose(library);
        return NULL;
    }
    AIBinder_decStrong(service);

    char message[640];
    snprintf(message, sizeof(message), "%s registered from %s", label, path);
    log_line(ANDROID_LOG_INFO, message);
    return library;
}

int main(int argc, char** argv) {
    const char* vendor_root = "/mnt/aera-stock/vendor";
    if (argc > 1 && argv[1][0] != '\0')
        vendor_root = argv[1];

    /* Prefer the partition mounted by aera-audio-bootstrap; fall back to the
     * normal recovery /vendor view if the stock partition is already there. */
    char agm_path[512];
    snprintf(agm_path, sizeof(agm_path), "%s/lib64/libagmipcservice.so",
             vendor_root);
    if (!file_readable(agm_path) &&
        file_readable("/vendor/lib64/libagmipcservice.so"))
        vendor_root = "/vendor";

    if (getuid() != 0) {
        log_line(ANDROID_LOG_ERROR, "must run as root");
        return 64;
    }

    ABinderProcess_setThreadPoolMaxThreadCount(6);
    ABinderProcess_startThreadPool();

    void* agm = load_service(vendor_root, "libagmipcservice.so",
                             "vendor.qti.hardware.agm.IAGM/default", "AGM");
    if (agm == NULL)
        return 70;

    void* pal = load_service(vendor_root, "libpalipcservice.so",
                             "vendor.qti.hardware.pal.IPAL/default", "PAL");
    if (pal == NULL) {
        dlclose(agm);
        return 70;
    }

    log_line(ANDROID_LOG_INFO, "AGM/PAL binder services ready");
    ABinderProcess_joinThreadPool();

    log_line(ANDROID_LOG_ERROR, "binder thread pool exited");
    dlclose(pal);
    dlclose(agm);
    return 70;
}
