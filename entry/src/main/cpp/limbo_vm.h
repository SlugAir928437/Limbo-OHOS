#ifndef LIMBO_VM_H
#define LIMBO_VM_H

#include <atomic>
#include <mutex>
#include <string>
#include <vector>

/**
 * 虚拟机运行状态（与 ArkTS 侧的 VmState 对应）。
 */
enum LimboVmState {
  LIMBO_VM_IDLE = 0,
  LIMBO_VM_STARTING = 1,
  LIMBO_VM_RUNNING = 2,
  LIMBO_VM_STOPPING = 3
};

/**
 * 进程内 QEMU 执行体（迁移自 Android 版 jni/limbo/vm-executor-jni.c）。
 *
 * 与 Android 版的差异：
 *  - 用 N-API 取代 JNI；
 *  - 只支持 TCG（不提供 KVM / Gunyah / GZVM 分支）；
 *  - 显示只走 SDL（不编译 GTK / AGL）；
 *  - 通过 QMP 实现暂停/恢复。
 *
 * QEMU 以 libqemu-system-x86_64.so 形式 dlopen，由 OHOS 构建脚本产出。
 */
class LimboVm {
public:
  static LimboVm &Instance();

  void SetPaths(const std::string &storageDir, const std::string &baseDir);

  /** 是否找到了可用的 QEMU 引擎库。 */
  bool IsEngineAvailable();

  /** 异步启动 QEMU；成功返回空字符串，失败返回错误信息。 */
  std::string Start(const std::vector<std::string> &args, int scaleMode, int refreshRateHz);

  /** 请求关机或重启；成功返回空字符串。 */
  std::string Stop(bool restart);

  /** QMP stop/cont，返回空字符串表示命令已送达。 */
  std::string Pause();
  std::string Resume();

  int GetState();

  void SetScaleMode(int mode);
  void SetRefreshRate(int hz);
  void RefreshScreen(int value);

  /** 发送键盘组合（逗号分隔的 QKeyCode 名称，如 "ctrl,alt,delete"）。 */
  std::string SendKeyCombo(const std::string &keysCsv, int holdMs);

  /** 发送单个按键的按下/抬起事件（用于物理键盘的长按）。 */
  std::string SendKeyEvent(const std::string &key, bool down);

  /** 向客户机输入 ASCII 文本；delayMs 为字符之间的间隔。 */
  std::string SendText(const std::string &text, int delayMs);

  /** 鼠标按键（left / middle / right）。 */
  std::string SendMouseButton(const std::string &button, bool down);

  /** 鼠标移动：relative=true 时为相对位移，否则为 0..0x7fff 的绝对坐标。 */
  std::string SendMouseMove(bool relative, int x, int y);

private:
  LimboVm() = default;
  ~LimboVm() = default;
  LimboVm(const LimboVm &) = delete;
  LimboVm &operator=(const LimboVm &) = delete;

  void RunQemu(const std::vector<std::string> &args, const std::string &libPath);
  std::string ResolveLibPath(const std::string &preferredName);
  bool ApplyIntVariable(const char *name, int value);
  bool QmpCommand(const char *command);
  /** 发送一条 QMP JSON 命令，返回原始响应（连接失败时为空）。 */
  std::string QmpExecute(const std::string &commandJson);

  std::mutex mutex_;
  std::mutex qmpMutex_;
  void *handle_ = nullptr;
  std::atomic<int> state_{LIMBO_VM_IDLE};
  int pendingScaleMode_ = -1;
  int pendingRefreshRate_ = -1;
  std::string storageDir_;
  std::string baseDir_;
};

#endif // LIMBO_VM_H
