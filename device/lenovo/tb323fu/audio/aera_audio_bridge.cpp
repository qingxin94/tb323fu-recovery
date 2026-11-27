/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * AERA browser PCM bridge for TB323FU.
 *
 * AERA's artillery/browser client opens the abstract Unix socket
 * "aera-browser-audio-v1", sends a 48 kHz / stereo / 16-bit hello, then streams
 * 20 ms PCM frames.  This bridge validates the peer UID and forwards raw PCM
 * to the dedicated stock-PAL player in a separate process.  It deliberately
 * does not gate playback on a "ready" property: a registration warning must
 * never stop the PCM path.
 *
 * The bridge itself carries no vendor library and no kernel module.  The PAL
 * player is the only process that loads libar-pal.so.
 */
#include <android/log.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <string>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/system_properties.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr uid_t kBrowserUid = 99090;
constexpr uid_t kMediaUid = 99092;
constexpr uint32_t kMagic = 0x41525041U;
constexpr uint32_t kRate = 48000U;
constexpr uint32_t kChannels = 2U;
constexpr uint32_t kBits = 16U;
constexpr char kSocketName[] = "aera-browser-audio-v1";
constexpr int kDefaultVolume = 60;
constexpr char kPalPlayer[] = "/system/bin/aera-palplayer";
constexpr char kPersistentFifo[] = "/tmp/aera-browser-audio.fifo";

volatile sig_atomic_t g_stop = 0;

/* AERA Media opens a new PCM client for every track.  PAL on TB323FU has a
 * small fixed number of low-latency streams and does not reliably reclaim a
 * client stream when aera-palplayer exits without pal_stream_stop().  Keeping
 * one player and one FIFO for the bridge lifetime means the stock PAL stream
 * is opened once per boot instead of once per video, so the fourth track does
 * not run out of PAL stream slots and stall the playbin clock. */
int g_output = -1;
pid_t g_player = -1;

void Stop(int) { g_stop = 1; }

void Log(const char* message) {
  __android_log_write(ANDROID_LOG_INFO, "AERA_AudioBridge", message);
  fprintf(stderr, "AERA audio bridge: %s\n", message);
}

std::string Property(const char* key, const char* fallback) {
  char value[PROP_VALUE_MAX] = {};
  if (__system_property_get(key, value) > 0 && value[0] != '\0')
    return std::string(value);
  return std::string(fallback);
}

/* Start the one-shot audio bring-up if it has not run.  This is deliberately
 * not a readiness gate: the client is never rejected for a missing property. */
void KickAudioHost() {
  if (Property("aera.audio.loaded", "") == "true") {
    __system_property_set("ctl.start", "aera-audio-bootstrap");
  } else {
    __system_property_set("sys.aera.audio.load", "1");
  }
}

bool WriteAll(int fd, int client, const void* data, size_t size) {
  const auto* bytes = static_cast<const uint8_t*>(data);
  size_t done = 0;
  unsigned stalled_polls = 0;
  while (done < size) {
    const ssize_t count = write(fd, bytes + done, size - done);
    if (count > 0) {
      done += static_cast<size_t>(count);
      stalled_polls = 0;
      continue;
    }
    if (count < 0 && errno == EINTR) continue;
    if (count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
      /* Wait for FIFO room, but also watch the client socket.  A media
       * session that exits mid-track must not leave the single-client
       * server stuck until the stall timeout: detect its HUP/EOF here and
       * release the PAL player immediately for the next session. */
      struct pollfd fds[2] = {
          {.fd = fd, .events = POLLOUT, .revents = 0},
          {.fd = client, .events = POLLIN, .revents = 0},
      };
      const int ready = poll(fds, 2, 50);
      if (ready > 0) {
        if (fds[1].revents & (POLLHUP | POLLERR | POLLNVAL)) return false;
        if (fds[1].revents & POLLIN) {
          char probe;
          const ssize_t peek = recv(client, &probe, 1, MSG_PEEK | MSG_DONTWAIT);
          if (peek == 0 || (peek < 0 && errno != EAGAIN && errno != EWOULDBLOCK))
            return false;
        }
        if (fds[0].revents & POLLOUT &&
            !(fds[0].revents & (POLLERR | POLLHUP | POLLNVAL))) {
          stalled_polls = 0;
          continue;
        }
        if (fds[0].revents & (POLLERR | POLLHUP | POLLNVAL)) return false;
      }
      if (++stalled_polls >= 100) return false;
      continue;
    }
    return false;
  }
  return true;
}

bool ReadAll(int fd, void* data, size_t size) {
  auto* bytes = static_cast<uint8_t*>(data);
  size_t done = 0;
  while (done < size) {
    const ssize_t count = read(fd, bytes + done, size - done);
    if (count < 0 && errno == EINTR) continue;
    if (count <= 0) return false;
    done += static_cast<size_t>(count);
  }
  return true;
}

int ReadVolume() {
  const int fd = open("/tmp/aera-audio-volume", O_RDONLY | O_CLOEXEC);
  if (fd < 0) return kDefaultVolume;
  char value[8] = {};
  const ssize_t count = read(fd, value, sizeof(value) - 1);
  close(fd);
  if (count <= 0) return kDefaultVolume;
  return std::clamp(atoi(value), 0, 100);
}

pid_t StartPlayer(const std::string& fifo) {
  const pid_t child = fork();
  if (child != 0) return child;
  prctl(PR_SET_PDEATHSIG, SIGTERM, 0, 0, 0);
  setenv("LD_LIBRARY_PATH",
         "/mnt/aera-stock/vendor/lib64:/tmp/aera-audio-abi:/vendor/lib64:/system/lib64", 1);
  setenv("ANDROID_ROOT", "/system", 1);
  setenv("ANDROID_DATA", "/data", 1);
  setenv("AERA_PAL_STREAM_TYPE", "1", 1);
  execl(kPalPlayer, "aera-palplayer", "--fifo", fifo.c_str(),
        "--stream-type", "1", nullptr);
  _exit(127);
}

void StopPlayer(pid_t child) {
  if (child <= 0) return;
  int status = 0;
  for (int attempt = 0; attempt < 20; ++attempt) {
    const pid_t result = waitpid(child, &status, WNOHANG);
    if (result == child || (result < 0 && errno == ECHILD)) return;
    usleep(25000);
  }
  kill(child, SIGTERM);
  for (int attempt = 0; attempt < 20; ++attempt) {
    const pid_t result = waitpid(child, &status, WNOHANG);
    if (result == child || (result < 0 && errno == ECHILD)) return;
    usleep(25000);
  }
  kill(child, SIGKILL);
  while (waitpid(child, &status, 0) < 0 && errno == EINTR) {
  }
}

void ServeClient(int client) {
  ucred credentials{};
  socklen_t credentials_size = sizeof(credentials);
  if (getsockopt(client, SOL_SOCKET, SO_PEERCRED, &credentials,
                 &credentials_size) != 0 ||
      credentials_size != sizeof(credentials) ||
      (credentials.uid != kBrowserUid && credentials.uid != kMediaUid)) {
    Log("rejected non-AERA audio client");
    return;
  }

  std::array<uint32_t, 4> hello{};
  if (!ReadAll(client, hello.data(), sizeof(hello)) || hello[0] != kMagic ||
      hello[1] != kRate || hello[2] != kChannels || hello[3] != kBits) {
    Log("rejected invalid PCM handshake");
    return;
  }

  KickAudioHost();

  /* Keep the FIFO and PAL player across client sessions.  The player blocks
   * in read() when no session is active; its PAL stream stays open. */
  if (g_player > 0) {
    int status = 0;
    if (waitpid(g_player, &status, WNOHANG) == g_player) {
      if (g_output >= 0) close(g_output);
      g_output = -1;
      g_player = -1;
      unlink(kPersistentFifo);
    }
  }
  if (g_output < 0) {
    if (g_player < 0) {
      unlink(kPersistentFifo);
      if (mkfifo(kPersistentFifo, 0600) != 0) {
        Log("could not create audio FIFO");
        return;
      }
      g_player = StartPlayer(kPersistentFifo);
      if (g_player < 0) {
        unlink(kPersistentFifo);
        Log("could not start aera-palplayer");
        return;
      }
    }
    /* Write-only non-blocking open fails with ENXIO until the reader exists. */
    for (int attempt = 0; attempt < 100 && g_output < 0; ++attempt) {
      g_output = open(kPersistentFifo, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
      if (g_output >= 0) break;
      if (errno != ENXIO && errno != EINTR) break;
      usleep(50000);
    }
    if (g_output < 0) {
      StopPlayer(g_player);
      g_player = -1;
      unlink(kPersistentFifo);
      Log("could not open audio FIFO");
      return;
    }
  }

  bool good = true;
  int volume = ReadVolume();
  std::array<uint8_t, 8195> buffer{};
  size_t carry = 0;
  unsigned volume_counter = 0;

  while (good && !g_stop) {
    const ssize_t count = read(client, buffer.data() + carry,
                               buffer.size() - carry);
    if (count < 0 && errno == EINTR) continue;
    if (count <= 0) break;
    const size_t total = carry + static_cast<size_t>(count);
    const size_t even = total & ~static_cast<size_t>(1);
    if ((volume_counter++ % 12U) == 0) volume = ReadVolume();
    for (size_t offset = 0; offset < even; offset += 2) {
      int16_t sample = static_cast<int16_t>(
          static_cast<uint16_t>(buffer[offset]) |
          (static_cast<uint16_t>(buffer[offset + 1]) << 8));
      sample = static_cast<int16_t>(
          (static_cast<int32_t>(sample) * volume * volume) / 10000);
      buffer[offset] = static_cast<uint8_t>(sample);
      buffer[offset + 1] = static_cast<uint8_t>(
          static_cast<uint16_t>(sample) >> 8);
    }
    good = WriteAll(g_output, client, buffer.data(), even);
    carry = total - even;
    if (carry) buffer[0] = buffer[even];
  }

  /* Do not close the writer or stop the PAL player here.  The next media
   * session reuses the same open PAL stream instead of allocating another. */
}
}  // namespace

int main(int argc, char** argv) {
  if (argc != 2 || strcmp(argv[1], "--browser-audio") != 0 || getuid() != 0) {
    fprintf(stderr,
            "Usage (root recovery only): aera-audio-bridge --browser-audio\n");
    return 64;
  }

  signal(SIGPIPE, SIG_IGN);
  signal(SIGTERM, Stop);
  signal(SIGINT, Stop);
  prctl(PR_SET_PDEATHSIG, SIGTERM, 0, 0, 0);

  const int server = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (server < 0) {
    Log("could not create audio socket");
    return 70;
  }

  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  memcpy(address.sun_path + 1, kSocketName, sizeof(kSocketName) - 1);
  const socklen_t address_size = static_cast<socklen_t>(
      offsetof(sockaddr_un, sun_path) + 1 + sizeof(kSocketName) - 1);
  if (bind(server, reinterpret_cast<const sockaddr*>(&address), address_size) !=
          0 ||
      listen(server, 1) != 0) {
    Log("could not bind AERA audio socket");
    close(server);
    return 70;
  }

  Log("browser PCM bridge ready");
  KickAudioHost();
  while (!g_stop) {
    const int client = accept4(server, nullptr, nullptr, SOCK_CLOEXEC);
    if (client < 0) {
      if (errno == EINTR) continue;
      break;
    }
    ServeClient(client);
    close(client);
  }
  close(server);
  if (g_output >= 0) close(g_output);
  g_output = -1;
  StopPlayer(g_player);
  g_player = -1;
  unlink(kPersistentFifo);
  return 0;
}
