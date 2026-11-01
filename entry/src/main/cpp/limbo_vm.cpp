#include "limbo_vm.h"

#include <arpa/inet.h>
#include <dlfcn.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <cerrno>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <thread>

#include "limbo_log.h"

namespace {
constexpr int kQmpPort = 4444;
// 首选 Limbo 构建脚本产出的名字；同时兼容 qemu-hmos 风格的 libqemu_full.so
constexpr const char *kQemuLibNames[] = {
  "libqemu-system-x86_64.so", "libqemu-system-aarch64.so", "libqemu_full.so"
};
constexpr const char *kQemuX86Lib = "libqemu-system-x86_64.so";
constexpr const char *kQemuAarch64Lib = "libqemu-system-aarch64.so";
constexpr int kShutdownCauseHostSignal = 3;
constexpr int kShutdownCauseGuestReset = 6;

/** 用于 dladdr 定位 liblimbo.so 所在目录的锚点（不能用成员函数指针）。 */
void LimboVmAnchor() {
}

std::string Trim(const std::string &value) {
  size_t begin = 0;
  while (begin < value.size() && std::isspace(static_cast<unsigned char>(value[begin])) != 0) {
    ++begin;
  }
  size_t end = value.size();
  while (end > begin && std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
    --end;
  }
  return value.substr(begin, end - begin);
}

std::string JsonEscape(const std::string &value) {
  std::string escaped;
  escaped.reserve(value.size());
  for (char raw : value) {
    switch (raw) {
      case '"':
        escaped += "\\\"";
        break;
      case '\\':
        escaped += "\\\\";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += raw;
        break;
    }
  }
  return escaped;
}

std::string QmpResultError(const std::string &response) {
  if (response.empty()) {
    return "QMP is not available";
  }
  if (response.find("\"error\"") != std::string::npos) {
    return response;
  }
  return "";
}

int ClampInt(int value, int minValue, int maxValue) {
  if (value < minValue) {
    return minValue;
  }
  if (value > maxValue) {
    return maxValue;
  }
  return value;
}

void SleepMs(int ms) {
  if (ms > 0) {
    usleep(static_cast<useconds_t>(ms) * 1000);
  }
}

/** ASCII 字符 -> QKeyCode 名称；需要 Shift 时置位。 */
bool ResolveChar(unsigned char c, std::string &key, bool &shift) {
  shift = false;
  if (c >= 'a' && c <= 'z') {
    key = std::string(1, static_cast<char>(c));
    return true;
  }
  if (c >= 'A' && c <= 'Z') {
    key = std::string(1, static_cast<char>(c - 'A' + 'a'));
    shift = true;
    return true;
  }
  if (c >= '0' && c <= '9') {
    key = std::string(1, static_cast<char>(c));
    return true;
  }
  switch (c) {
    case ' ': key = "spc"; return true;
    case '\n': key = "ret"; return true;
    case '\t': key = "tab"; return true;
    case 8: key = "backspace"; return true;
    case 27: key = "esc"; return true;
    case '!': key = "1"; shift = true; return true;
    case '@': key = "2"; shift = true; return true;
    case '#': key = "3"; shift = true; return true;
    case '$': key = "4"; shift = true; return true;
    case '%': key = "5"; shift = true; return true;
    case '^': key = "6"; shift = true; return true;
    case '&': key = "7"; shift = true; return true;
    case '*': key = "8"; shift = true; return true;
    case '(': key = "9"; shift = true; return true;
    case ')': key = "0"; shift = true; return true;
    case '-': key = "minus"; return true;
    case '_': key = "minus"; shift = true; return true;
    case '=': key = "equal"; return true;
    case '+': key = "equal"; shift = true; return true;
    case '[': key = "bracket_left"; return true;
    case '{': key = "bracket_left"; shift = true; return true;
    case ']': key = "bracket_right"; return true;
    case '}': key = "bracket_right"; shift = true; return true;
    case '\\': key = "backslash"; return true;
    case '|': key = "backslash"; shift = true; return true;
    case ';': key = "semicolon"; return true;
    case ':': key = "semicolon"; shift = true; return true;
    case '\'': key = "apostrophe"; return true;
    case '"': key = "apostrophe"; shift = true; return true;
    case ',': key = "comma"; return true;
    case '<': key = "comma"; shift = true; return true;
    case '.': key = "dot"; return true;
    case '>': key = "dot"; shift = true; return true;
    case '/': key = "slash"; return true;
    case '?': key = "slash"; shift = true; return true;
    case '`': key = "grave_accent"; return true;
    case '~': key = "grave_accent"; shift = true; return true;
    default:
      return false;
  }
}
} // namespace

LimboVm &LimboVm::Instance() {
  static LimboVm instance;
  return instance;
}

void LimboVm::SetPaths(const std::string &storageDir, const std::string &baseDir) {
  std::lock_guard<std::mutex> lock(mutex_);
  storageDir_ = storageDir;
  baseDir_ = baseDir;
}

std::string LimboVm::ResolveLibPath(const std::string &preferredName) {
  const char *envPath = std::getenv("LIMBO_QEMU_LIB");
  if (envPath != nullptr && envPath[0] != '\0' && access(envPath, R_OK) == 0) {
    return envPath;
  }

  // liblimbo.so 与 QEMU 引擎一起打包在 entry/libs/<abi> 下
  Dl_info info;
  if (dladdr(reinterpret_cast<void *>(&LimboVmAnchor), &info) != 0 &&
      info.dli_fname != nullptr) {
    std::string selfPath(info.dli_fname);
    const size_t slash = selfPath.find_last_of('/');
    if (slash != std::string::npos) {
      const std::string dir = selfPath.substr(0, slash + 1);
      const std::string candidate = dir + preferredName;
      if (access(candidate.c_str(), R_OK) == 0) {
        return candidate;
      }
      const std::string fallback = dir + "libqemu_full.so";
      if (access(fallback.c_str(), R_OK) == 0) {
        return fallback;
      }
    }
  }

  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!baseDir_.empty()) {
      const std::string candidate = baseDir_ + "/libs/" + preferredName;
      if (access(candidate.c_str(), R_OK) == 0) {
        return candidate;
      }
      const std::string fallback = baseDir_ + "/libs/libqemu_full.so";
      if (access(fallback.c_str(), R_OK) == 0) {
        return fallback;
      }
    }
  }
  return "";
}

bool LimboVm::IsEngineAvailable() {
  return !ResolveLibPath(kQemuX86Lib).empty();
}

std::string LimboVm::Start(const std::vector<std::string> &args, int scaleMode, int refreshRateHz) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (state_.load() != LIMBO_VM_IDLE) {
      return "VM is already running";
    }
    state_.store(LIMBO_VM_STARTING);
  }

  const std::string preferred = (!args.empty() && args[0].find("aarch64") != std::string::npos)
    ? std::string(kQemuAarch64Lib) : std::string(kQemuX86Lib);
  const std::string libPath = ResolveLibPath(preferred);
  if (libPath.empty()) {
    state_.store(LIMBO_VM_IDLE);
    return "QEMU engine not found (" + preferred + ")";
  }

  if (scaleMode >= 0) {
    SetScaleMode(scaleMode);
  }
  if (refreshRateHz >= 0) {
    SetRefreshRate(refreshRateHz);
  }

  // 触摸由 ArkTS 侧通过 QMP 注入（支持触控板/触摸屏两种模式），
  // 关闭 SDL 自带的 touch -> mouse 合成，避免重复的鼠标事件。
  setenv("SDL_TOUCH_MOUSE_EVENTS", "0", 1);

  std::thread worker(&LimboVm::RunQemu, this, args, libPath);
  worker.detach();
  return "";
}

void LimboVm::RunQemu(const std::vector<std::string> &args, const std::string &libPath) {
  void *handle = dlopen(libPath.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (handle == nullptr) {
    LOGW("dlopen(%s) failed: %s, try bundled names", libPath.c_str(), dlerror());
    for (const char *name : kQemuLibNames) {
      handle = dlopen(name, RTLD_NOW | RTLD_LOCAL);
      if (handle != nullptr) {
        break;
      }
    }
  }
  if (handle == nullptr) {
    LOGE("cannot load QEMU engine: %s", dlerror());
    state_.store(LIMBO_VM_IDLE);
    return;
  }

  {
    std::lock_guard<std::mutex> lock(mutex_);
    handle_ = handle;
  }
  if (pendingScaleMode_ >= 0) {
    ApplyIntVariable("limbo_sdl_scale_mode", pendingScaleMode_);
  }
  if (pendingRefreshRate_ >= 0) {
    ApplyIntVariable("limbo_sdl_refresh_rate", pendingRefreshRate_);
  }

  std::vector<std::string> argvStorage;
  argvStorage.reserve(args.size() + 1);
  if (args.empty()) {
    argvStorage.emplace_back("qemu-system-x86_64");
  } else {
    argvStorage = args;
  }
  std::vector<char *> argv;
  argv.reserve(argvStorage.size() + 1);
  for (std::string &item : argvStorage) {
    argv.push_back(const_cast<char *>(item.c_str()));
  }
  argv.push_back(nullptr);
  const int argc = static_cast<int>(argvStorage.size());

  typedef void (*QemuInitFn)(int argc, char **argv);
  typedef int (*QemuMainFn)(int argc, char **argv, char **envp);
  typedef void (*QemuLoopFn)(void);
  typedef void (*QemuCleanupFn)(void);

  dlerror();
  auto qemuInit = reinterpret_cast<QemuInitFn>(dlsym(handle, "qemu_init"));
  const char *symbolError = dlerror();
  if (qemuInit == nullptr || symbolError != nullptr) {
    auto qemuMain = reinterpret_cast<QemuMainFn>(dlsym(handle, "main"));
    if (qemuMain != nullptr) {
      state_.store(LIMBO_VM_RUNNING);
      qemuMain(argc, argv.data(), nullptr);
    } else {
      LOGE("QEMU engine has no qemu_init/main symbol: %s", dlerror());
    }
  } else {
    auto qemuLoop = reinterpret_cast<QemuLoopFn>(dlsym(handle, "qemu_main_loop"));
    auto qemuCleanup = reinterpret_cast<QemuCleanupFn>(dlsym(handle, "qemu_cleanup"));
    if (qemuLoop == nullptr || qemuCleanup == nullptr) {
      LOGE("QEMU engine is missing qemu_main_loop/qemu_cleanup");
    } else {
      state_.store(LIMBO_VM_RUNNING);
      qemuInit(argc, argv.data());
      qemuLoop();
      qemuCleanup();
    }
  }

  {
    std::lock_guard<std::mutex> lock(mutex_);
    handle_ = nullptr;
  }
  dlclose(handle);
  state_.store(LIMBO_VM_IDLE);
  LOGI("QEMU engine stopped");
}

std::string LimboVm::Stop(bool restart) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (handle_ == nullptr) {
    return "VM is not running";
  }
  typedef void (*RequestFn)(int cause);
  if (restart) {
    auto request = reinterpret_cast<RequestFn>(dlsym(handle_, "qemu_system_reset_request"));
    if (request == nullptr) {
      return "qemu_system_reset_request not found";
    }
    request(kShutdownCauseGuestReset);
    return "";
  }
  auto request = reinterpret_cast<RequestFn>(dlsym(handle_, "qemu_system_shutdown_request"));
  if (request == nullptr) {
    return "qemu_system_shutdown_request not found";
  }
  request(kShutdownCauseHostSignal);
  state_.store(LIMBO_VM_STOPPING);
  return "";
}

std::string LimboVm::Pause() {
  return QmpCommand("stop") ? "" : "QMP stop failed";
}

std::string LimboVm::Resume() {
  return QmpCommand("cont") ? "" : "QMP cont failed";
}

int LimboVm::GetState() {
  return state_.load();
}

void LimboVm::SetScaleMode(int mode) {
  std::lock_guard<std::mutex> lock(mutex_);
  pendingScaleMode_ = mode;
  if (handle_ != nullptr) {
    ApplyIntVariable("limbo_sdl_scale_mode", mode);
  }
}

void LimboVm::SetRefreshRate(int hz) {
  std::lock_guard<std::mutex> lock(mutex_);
  pendingRefreshRate_ = hz;
  if (handle_ != nullptr) {
    ApplyIntVariable("limbo_sdl_refresh_rate", hz);
  }
}

void LimboVm::RefreshScreen(int value) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (handle_ != nullptr) {
    ApplyIntVariable("limbo_vga_full_update", value);
  }
}

bool LimboVm::ApplyIntVariable(const char *name, int value) {
  if (handle_ == nullptr) {
    return false;
  }
  dlerror();
  void *symbol = dlsym(handle_, name);
  if (symbol == nullptr || dlerror() != nullptr) {
    return false;
  }
  *reinterpret_cast<int *>(symbol) = value;
  return true;
}

bool LimboVm::QmpCommand(const char *command) {
  const std::string response =
    QmpExecute(std::string("{\"execute\":\"") + command + "\"}");
  return response.find("\"return\"") != std::string::npos;
}

std::string LimboVm::QmpExecute(const std::string &commandJson) {
  std::lock_guard<std::mutex> lock(qmpMutex_);
  const int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return "";
  }

  timeval timeout{};
  timeout.tv_sec = 1;
  timeout.tv_usec = 0;
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(kQmpPort);
  inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);

  if (connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) != 0) {
    close(fd);
    LOGW("QMP connect failed: %s", strerror(errno));
    return "";
  }

  char buffer[2048];
  // QMP 欢迎信息
  recv(fd, buffer, sizeof(buffer) - 1, 0);

  const char *capabilities = "{\"execute\":\"qmp_capabilities\"}\r\n";
  if (send(fd, capabilities, strlen(capabilities), 0) < 0) {
    close(fd);
    return "";
  }
  recv(fd, buffer, sizeof(buffer) - 1, 0);

  const std::string payload = commandJson + "\r\n";
  if (send(fd, payload.c_str(), payload.size(), 0) < 0) {
    close(fd);
    return "";
  }
  const int received = recv(fd, buffer, sizeof(buffer) - 1, 0);
  close(fd);
  if (received <= 0) {
    return "";
  }
  return std::string(buffer, static_cast<size_t>(received));
}

std::string LimboVm::SendKeyCombo(const std::string &keysCsv, int holdMs) {
  std::vector<std::string> keys;
  size_t start = 0;
  while (start <= keysCsv.size()) {
    const size_t comma = keysCsv.find(',', start);
    const std::string item = Trim(keysCsv.substr(start, comma == std::string::npos
      ? std::string::npos : comma - start));
    if (!item.empty()) {
      keys.push_back(item);
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  if (keys.empty()) {
    return "no keys specified";
  }
  if (holdMs < 1) {
    holdMs = 1;
  } else if (holdMs > 1000) {
    holdMs = 1000;
  }

  std::string keysJson = "[";
  for (size_t i = 0; i < keys.size(); ++i) {
    if (i > 0) {
      keysJson += ",";
    }
    keysJson += "{\"type\":\"qcode\",\"data\":\"" + JsonEscape(keys[i]) + "\"}";
  }
  keysJson += "]";

  const std::string command = "{\"execute\":\"send-key\",\"arguments\":{\"keys\":"
    + keysJson + ",\"hold-time\":" + std::to_string(holdMs) + "}}";
  return QmpResultError(QmpExecute(command));
}

std::string LimboVm::SendKeyEvent(const std::string &key, bool down) {
  if (key.empty()) {
    return "no key specified";
  }
  const std::string command = "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":"
    "[{\"type\":\"key\",\"data\":{\"down\":" + std::string(down ? "true" : "false")
    + ",\"key\":{\"type\":\"qcode\",\"data\":\"" + JsonEscape(key) + "\"}}}]}}";
  return QmpResultError(QmpExecute(command));
}

std::string LimboVm::SendText(const std::string &text, int delayMs) {
  if (text.empty()) {
    return "";
  }
  if (delayMs < 0) {
    delayMs = 0;
  }
  for (size_t i = 0; i < text.size(); ++i) {
    std::string key;
    bool shift = false;
    if (!ResolveChar(static_cast<unsigned char>(text[i]), key, shift)) {
      continue;
    }

    // 一次命令内按下并释放；需要 Shift 时包在按键两侧。
    std::string events = "[";
    if (shift) {
      events += "{\"type\":\"key\",\"data\":{\"down\":true,\"key\":{\"type\":\"qcode\",\"data\":\"shift\"}}},";
    }
    events += "{\"type\":\"key\",\"data\":{\"down\":true,\"key\":{\"type\":\"qcode\",\"data\":\""
      + key + "\"}}},";
    events += "{\"type\":\"key\",\"data\":{\"down\":false,\"key\":{\"type\":\"qcode\",\"data\":\""
      + key + "\"}}}";
    if (shift) {
      events += ",{\"type\":\"key\",\"data\":{\"down\":false,\"key\":{\"type\":\"qcode\",\"data\":\"shift\"}}}";
    }
    events += "]";

    const std::string command =
      "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":" + events + "}}";
    const std::string error = QmpResultError(QmpExecute(command));
    if (!error.empty()) {
      return error;
    }
    if (i + 1 < text.size()) {
      SleepMs(delayMs);
    }
  }
  return "";
}

std::string LimboVm::SendMouseButton(const std::string &button, bool down) {
  const std::string command = "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":"
    "[{\"type\":\"btn\",\"data\":{\"down\":" + std::string(down ? "true" : "false")
    + ",\"button\":\"" + JsonEscape(button) + "\"}}]}}";
  return QmpResultError(QmpExecute(command));
}

std::string LimboVm::SendMouseMove(bool relative, int x, int y) {
  if (relative && x == 0 && y == 0) {
    return "";
  }
  const std::string kind = relative ? "rel" : "abs";
  int vx = x;
  int vy = y;
  if (!relative) {
    vx = ClampInt(vx, 0, 0x7fff);
    vy = ClampInt(vy, 0, 0x7fff);
  }
  const std::string events = "[{\"type\":\"" + kind + "\",\"data\":{\"axis\":\"x\",\"value\":"
    + std::to_string(vx) + "}},{\"type\":\"" + kind + "\",\"data\":{\"axis\":\"y\",\"value\":"
    + std::to_string(vy) + "}}]";
  const std::string command =
    "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":" + events + "}}";
  return QmpResultError(QmpExecute(command));
}
