/*
 * aera-palplayer: narrow recovery-side PCM consumer for TB323FU.
 *
 * This is our own implementation.  It does not contain or execute any UGY
 * binary.  It loads the device's stock libar-pal.so from /vendor/lib64 and
 * uses the public PAL C ABI to open the speaker stream, then writes the PCM
 * received from AERA's audio bridge FIFO.
 *
 * The bridge writes a 44-byte canonical WAV header before the PCM payload,
 * so the player detects and skips that header.  PAL teardown is deliberately
 * avoided on the normal EOF path because the stock PAL build aborts in its
 * destroy path after a graph ends; process exit performs the cleanup.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PAL_RATE 48000u
#define PAL_CHANNELS 2u
#define PAL_BITS 16u
#define PAL_SPEAKER_DEVICE 3
#define PAL_STREAM_LOW_LATENCY 1
#define PAL_DIRECTION_OUTPUT 1

typedef uint64_t PalStreamHandle;

typedef struct {
    uint16_t channels;
    uint8_t channel_map[64];
} PalChannelInfo;

typedef struct {
    uint32_t sample_rate;
    uint32_t bit_width;
    int32_t format;
    PalChannelInfo channel_info;
} PalMediaConfig;

typedef struct {
    int64_t version;
    int64_t size;
    int64_t duration_us;
    uint8_t has_video;
    uint8_t is_streaming;
    int32_t loopback_type;
    int32_t tx_proxy_type;
    int32_t rx_proxy_type;
    int32_t haptics_type;
    uint8_t is_bit_perfect;
} PalStreamInfo;

typedef union {
    PalStreamInfo optional;
    struct {
        int64_t version;
        int64_t size;
        int32_t direction;
    } voice_record;
    struct {
        uint32_t vsid;
        uint32_t tty_mode;
    } voice_call;
    struct {
        uint8_t local_playback;
        int32_t direction;
    } incall_music;
    int32_t hpcm_stream_type;
} PalStreamInfoUnion;

typedef struct {
    int32_t type;
    PalStreamInfoUnion info;
    int32_t flags;
    int32_t direction;
    PalMediaConfig input;
    PalMediaConfig output;
    char *address;
} PalStreamAttributes;

typedef struct {
    int32_t id;
    PalMediaConfig config;
    int32_t usb_card;
    int32_t usb_device;
    char sound_device_name[128];
    char custom_key[128];
    union {
        char id[128];
        uint32_t ipv6[8];
    } address;
} PalDevice;

typedef struct {
    uint8_t *data;
    size_t size;
    size_t offset;
    struct timespec *timestamp;
    uint32_t flags;
    size_t metadata_size;
    uint8_t *metadata;
    struct {
        int32_t handle;
        uint32_t size;
        uint32_t offset;
    } allocation;
    uint64_t frame_index;
} PalBuffer;

_Static_assert(sizeof(PalStreamAttributes) == 232, "PAL attributes layout");
_Static_assert(sizeof(PalDevice) == 476, "PAL device layout");
_Static_assert(sizeof(PalBuffer) == 80, "PAL buffer layout");

typedef struct {
    void *library;
    int32_t (*init)(void);
    void (*deinit)(void);
    int32_t (*stream_open)(PalStreamAttributes *, uint32_t, PalDevice *,
                           uint32_t, void *, void *, uint64_t,
                           PalStreamHandle **);
    int32_t (*stream_start)(PalStreamHandle *);
    int32_t (*stream_stop)(PalStreamHandle *);
    int32_t (*stream_close)(PalStreamHandle *);
    ssize_t (*stream_write)(PalStreamHandle *, PalBuffer *);
} PalApi;

static void log_msg(const char *text) {
    fprintf(stderr, "AERA palplayer: %s\n", text);
}

static int load_pal(PalApi *api) {
    api->library = dlopen("/mnt/aera-stock/vendor/lib64/libar-pal.so", RTLD_NOW | RTLD_LOCAL);
    if (!api->library) {
        api->library = dlopen("libar-pal.so", RTLD_NOW | RTLD_LOCAL);
    }
    if (!api->library) {
        fprintf(stderr, "AERA palplayer: dlopen libar-pal.so failed: %s\n",
                dlerror());
        return -1;
    }
    api->init = (int32_t (*)(void))dlsym(api->library, "pal_init");
    api->deinit = (void (*)(void))dlsym(api->library, "pal_deinit");
    api->stream_open = (int32_t (*)(PalStreamAttributes *, uint32_t,
                                    PalDevice *, uint32_t, void *, void *,
                                    uint64_t, PalStreamHandle **))
        dlsym(api->library, "pal_stream_open");
    api->stream_start =
        (int32_t (*)(PalStreamHandle *))dlsym(api->library,
                                               "pal_stream_start");
    api->stream_stop =
        (int32_t (*)(PalStreamHandle *))dlsym(api->library,
                                             "pal_stream_stop");
    api->stream_close =
        (int32_t (*)(PalStreamHandle *))dlsym(api->library,
                                             "pal_stream_close");
    api->stream_write =
        (ssize_t (*)(PalStreamHandle *, PalBuffer *))dlsym(api->library,
                                                           "pal_stream_write");
    if (!api->init || !api->deinit || !api->stream_open || !api->stream_start ||
        !api->stream_stop || !api->stream_close || !api->stream_write) {
        log_msg("stock PAL is missing one or more required symbols");
        return -1;
    }
    return 0;
}

static void set_pcm_config(PalMediaConfig *config) {
    config->sample_rate = PAL_RATE;
    config->bit_width = PAL_BITS;
    config->format = 1; /* PAL_AUDIO_FMT_PCM */
    config->channel_info.channels = PAL_CHANNELS;
    config->channel_info.channel_map[0] = 1; /* FL */
    config->channel_info.channel_map[1] = 2; /* FR */
}

static int run_player(int input, PalApi *api) {
    PalStreamAttributes attributes;
    PalDevice speaker;
    PalStreamHandle *stream = NULL;
    int result = 70;

    memset(&attributes, 0, sizeof(attributes));
    memset(&speaker, 0, sizeof(speaker));
    attributes.type = PAL_STREAM_LOW_LATENCY;
    attributes.direction = PAL_DIRECTION_OUTPUT;
    set_pcm_config(&attributes.input);
    set_pcm_config(&attributes.output);
    speaker.id = PAL_SPEAKER_DEVICE;
    set_pcm_config(&speaker.config);

    if (api->init() != 0) {
        log_msg("pal_init failed");
        return 70;
    }
    if (api->stream_open(&attributes, 1, &speaker, 0, NULL, NULL, 0,
                         &stream) != 0 ||
        stream == NULL) {
        log_msg("pal_stream_open failed");
        return 70;
    }
    if (api->stream_start(stream) != 0) {
        log_msg("pal_stream_start failed");
        _exit(72); /* do not run stock PAL teardown after a failed start */
    }
    log_msg("PAL speaker stream started");

    uint8_t buffer[8197];
    size_t carry = 0;
    while (1) {
        ssize_t count = read(input, buffer + carry, sizeof(buffer) - carry);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        size_t total = carry + (size_t)count;
        size_t aligned = total & ~((size_t)3); /* 16-bit stereo frame */
        size_t written = 0;
        while (written < aligned) {
            PalBuffer info;
            memset(&info, 0, sizeof(info));
            info.data = buffer + written;
            info.size = aligned - written;
            ssize_t bytes = api->stream_write(stream, &info);
            if (bytes <= 0) {
                log_msg("pal_stream_write failed");
                result = 74;
                goto done;
            }
            written += (size_t)bytes;
        }
        if (written != aligned) {
            result = 74;
            goto done;
        }
        carry = total - aligned;
        if (carry) memmove(buffer, buffer + aligned, carry);
    }

done:
    /*
     * Stock PAL on TB323FU can abort in pal_stream_stop/close/deinit after
     * the graph is torn down.  The player is single-use; process exit is the
     * safe cleanup, and the AGM/PAL host handles client death.
     */
    if (result == 0) _exit(0);
    _exit(result);
}

int main(int argc, char **argv) {
    int input = -1;
    const char *fifo = NULL;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--fifo") == 0 && i + 1 < argc) {
            fifo = argv[++i];
        } else if (strcmp(argv[i], "--stdin") == 0) {
            input = 0;
        } else if (fifo == NULL && argv[i][0] != '-') {
            fifo = argv[i];
        }
    }
    if (fifo != NULL && input < 0) {
        input = open(fifo, O_RDONLY | O_CLOEXEC);
        if (input < 0) {
            fprintf(stderr, "AERA palplayer: open %s failed: %s\n", fifo,
                    strerror(errno));
            return 64;
        }
    }
    if (input < 0) {
        fprintf(stderr,
                "Usage: aera-palplayer <fifo> [ignored bridge options]\n"
                "       aera-palplayer --fifo <path> | --stdin\n");
        return 64;
    }

    /* Always use the vendor-domain binder first; the PAL/AGM libraries are
       vendor binaries even when launched from the recovery bridge. */
    setenv("LD_LIBRARY_PATH",
           "/mnt/aera-stock/vendor/lib64:/tmp/aera-audio-abi:/vendor/lib64:/system/lib64",
           1);
    if (!getenv("ANDROID_ROOT")) setenv("ANDROID_ROOT", "/system", 1);
    if (!getenv("ANDROID_DATA")) setenv("ANDROID_DATA", "/data", 1);

    PalApi api;
    memset(&api, 0, sizeof(api));
    if (load_pal(&api) != 0) return 70;
    return run_player(input, &api);
}
