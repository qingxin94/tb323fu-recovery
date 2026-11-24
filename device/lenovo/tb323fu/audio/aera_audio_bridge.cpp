/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * AERA browser PCM bridge for TB323FU.
 *
 * AERA's artillery/browser client opens the abstract Unix socket
 * "aera-browser-audio-v1", sends a 48 kHz / stereo / 16-bit hello, then streams
 * 20 ms PCM frames.  This bridge validates the peer UID, writes a WAV header to
 * a private FIFO, and asks the installed stock agmplay binary to consume that
 * FIFO through the AGM/PAL services registered by aera-audio-service.
 *
 * The bridge itself carries no vendor library and no kernel module.  It only
 * executes the stock agmplay from the mounted vendor partition.
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
constexpr int kAudioReadyTimeoutMs = 45000;
constexpr int kAudioReadyPollMs = 250;

volatile sig_atomic_t g_stop = 0;

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

bool AudioReady() {
  return Property("aera.audio.loaded", "") == "true" &&
         Property("aera.audio.ready", "") == "1" &&
         Property("init.svc.aera-agm-service", "") == "running";
}

bool EnsureAudioReady() {
  if (AudioReady()) return true;

  const bool modules_loaded = Property("aera.audio.loaded", "") == "true";
  bool bootstrap_kicked = modules_loaded;
  if (modules_loaded) {
    Log("audio modules loaded but AGM/PAL host is not running; "
        "starting bootstrap");
    __system_property_set("ctl.start", "aera-audio-bootstrap");
  } else {
    Log("audio group is not ready; triggering on-demand load");
    __system_property_set("sys.aera.audio.load", "1");
  }

  for (int elapsed = 0; elapsed < kAudioReadyTimeoutMs;
       elapsed += kAudioReadyPollMs) {
    if (AudioReady()) {
      Log("audio group ready");
      return true;
    }
    if (!bootstrap_kicked &&
        Property("aera.audio.loaded", "") == "true" &&
        Property("init.svc.aera-agm-service", "") != "running") {
      __system_property_set("ctl.start", "aera-audio-bootstrap");
      bootstrap_kicked = true;
      Log("audio modules loaded; starting bootstrap");
    }
    usleep(kAudioReadyPollMs * 1000);
  }
  Log("audio group did not become ready before timeout");
  return false;
}

bool WriteAll(int fd, const void* data, size_t size) {
  const auto* bytes = static_cast<const uint8_t*>(data);
  size_t done = 0;
  while (done < size) {
    const ssize_t count = write(fd, bytes + done, size - done);
    if (count < 0 && errno == EINTR) continue;
    if (count <= 0) return false;
    done += static_cast<size_t>(count);
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

std::string FindAgmPlay() {
  const std::string configured = Property("aera.audio.player", "");
  if (!configured.empty() && access(configured.c_str(), X_OK) == 0)
    return configured;
  const std::vector<std::string> candidates = {
      "/mnt/aera-stock/vendor/bin/agmplay",
      "/vendor/bin/agmplay",
  };
  for (const auto& candidate : candidates) {
    if (access(candidate.c_str(), X_OK) == 0) return candidate;
  }
  return std::string();
}

std::array<uint8_t, 44> WavHeader() {
  std::array<uint8_t, 44> header{};
  auto put16 = [&header](size_t offset, uint16_t value) {
    header[offset] = static_cast<uint8_t>(value);
    header[offset + 1] = static_cast<uint8_t>(value >> 8);
  };
  auto put32 = [&header](size_t offset, uint32_t value) {
    for (size_t i = 0; i < 4; ++i)
      header[offset + i] = static_cast<uint8_t>(value >> (8 * i));
  };
  memcpy(header.data(), "RIFF", 4);
  put32(4, 0x7ffff024U);
  memcpy(header.data() + 8, "WAVEfmt ", 8);
  put32(16, 16U);
  put16(20, 1U);
  put16(22, static_cast<uint16_t>(kChannels));
  put32(24, kRate);
  put32(28, kRate * kChannels * (kBits / 8));
  put16(32, static_cast<uint16_t>(kChannels * (kBits / 8)));
  put16(34, static_cast<uint16_t>(kBits));
  memcpy(header.data() + 36, "data", 4);
  put32(40, 0x7ffff000U);
  return header;
}

pid_t StartPlayer(const std::string& player, const std::string& fifo) {
  const std::string card = Property("aera.audio.card", "100");
  const std::string device = Property("aera.audio.device", "100");
  const std::string interface = Property("aera.audio.interface", "");
  /* TB323FU's stock agmplay usage is:
   *   agmplay file.wav [-D card] [-d device] [-num_intf N iface...]
   * It takes PCM format from the WAV header, so -c/-r/-b are not valid
   * options on this device and must not be passed. */
  std::vector<std::string> arguments = {
      player, fifo, "-D", card, "-d", device,
  };
  if (!interface.empty()) {
    arguments.push_back("-num_intf");
    arguments.push_back("1");
    arguments.push_back(interface);
  }

  const pid_t child = fork();
  if (child != 0) return child;
  prctl(PR_SET_PDEATHSIG, SIGTERM, 0, 0, 0);
  setenv("LD_LIBRARY_PATH",
         "/mnt/aera-stock/vendor/lib64:/vendor/lib64:/system/lib64", 1);
  setenv("ANDROID_ROOT", "/system", 1);
  setenv("ANDROID_DATA", "/data", 1);

  std::vector<char*> argv;
  argv.reserve(arguments.size() + 1);
  for (auto& argument : arguments) argv.push_back(argument.data());
  argv.push_back(nullptr);
  execv(player.c_str(), argv.data());
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

  if (!EnsureAudioReady()) {
    Log("audio output is not ready; closing stream");
    return;
  }

  const std::string player = FindAgmPlay();
  if (player.empty()) {
    Log("stock agmplay is not mounted; audio unavailable");
    return;
  }

  const std::string fifo =
      "/tmp/aera-browser-audio-" +
      std::to_string(static_cast<long long>(getpid()));
  unlink(fifo.c_str());
  if (mkfifo(fifo.c_str(), 0600) != 0) {
    Log("could not create audio FIFO");
    return;
  }
  const int output = open(fifo.c_str(), O_RDWR | O_CLOEXEC);
  if (output < 0) {
    unlink(fifo.c_str());
    Log("could not open audio FIFO");
    return;
  }

  const pid_t audio_player = StartPlayer(player, fifo);
  if (audio_player < 0) {
    close(output);
    unlink(fifo.c_str());
    Log("could not start agmplay");
    return;
  }

  const auto header = WavHeader();
  bool good = WriteAll(output, header.data(), header.size());
  int volume = ReadVolume();
  std::array<uint8_t, 8193> buffer{};
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
      sample = static_cast<int16_t>((static_cast<int32_t>(sample) * volume) /
                                    100);
      buffer[offset] = static_cast<uint8_t>(sample);
      buffer[offset + 1] = static_cast<uint8_t>(
          static_cast<uint16_t>(sample) >> 8);
    }
    good = WriteAll(output, buffer.data(), even);
    carry = total - even;
    if (carry) buffer[0] = buffer[even];
  }

  close(output);
  StopPlayer(audio_player);
  unlink(fifo.c_str());
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
  EnsureAudioReady();
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
  return 0;
}
