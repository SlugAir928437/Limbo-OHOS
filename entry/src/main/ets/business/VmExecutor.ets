import {
  getState,
  isEngineAvailable,
  pause,
  refreshScreen,
  resume,
  sendKeyCombo as nativeSendKeyCombo,
  sendKeyEvent as nativeSendKeyEvent,
  sendMouseButton as nativeSendMouseButton,
  sendMouseMove as nativeSendMouseMove,
  sendText as nativeSendText,
  setPaths,
  setRefreshRateHz,
  setScaleMode,
  start,
  stop
} from 'liblimbo.so';

/**
 * HarmonyOS 原生执行体封装（对应 Android 的 com.limbo.emu.jni.VMExecutor）。
 *
 * 实际工作由 entry/src/main/cpp 的 liblimbo.so 完成：
 * 进程内 dlopen libqemu-system-x86_64.so / libqemu-system-aarch64.so，TCG 执行，SDL 显示。
 * 不包含 KVM / Gunyah / GZVM 分支，也不包含 GTK 后端。
 */
export class VmExecutor {
  private static readonly instance: VmExecutor = new VmExecutor();

  private initialized: boolean = false;
  private engineAvailable: boolean = false;
  private lastError: string = '';

  static getInstance(): VmExecutor {
    return VmExecutor.instance;
  }

  /** 在 Ability 创建时调用一次：把目录信息交给原生层。 */
  init(storageDir: string, baseDir: string): void {
    try {
      setPaths(storageDir, baseDir);
      this.engineAvailable = isEngineAvailable();
      this.initialized = true;
    } catch (err) {
      this.engineAvailable = false;
      this.initialized = false;
      console.error(`VmExecutor.init failed: ${JSON.stringify(err)}`);
    }
  }

  /** 是否随包提供了 QEMU 引擎（x86_64 / aarch64 任一可用即视为可用）。 */
  isAvailable(): boolean {
    if (!this.initialized) {
      return false;
    }
    try {
      this.engineAvailable = isEngineAvailable();
    } catch (err) {
      this.engineAvailable = false;
    }
    return this.engineAvailable;
  }

  /** 0=空闲 1=启动中 2=运行中 3=停止中。 */
  getState(): number {
    try {
      return getState();
    } catch (err) {
      return 0;
    }
  }

  isRunning(): boolean {
    return this.getState() === 2;
  }

  getLastError(): string {
    return this.lastError;
  }

  /** 启动 QEMU，成功返回 true。 */
  startVm(args: string[], scaleMode: number, refreshRateHz: number): boolean {
    try {
      const error: string = start(args, scaleMode, refreshRateHz);
      if (error.length > 0) {
        this.lastError = error;
        console.error(`VmExecutor.start failed: ${error}`);
        return false;
      }
      this.lastError = '';
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      console.error(`VmExecutor.start exception: ${this.lastError}`);
      return false;
    }
  }

  /** restart=true 时请求重启，否则请求关机。 */
  stopVm(restart: boolean): boolean {
    try {
      const error: string = stop(restart);
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }

  /** QMP 暂停。 */
  pauseVm(): boolean {
    try {
      const error: string = pause();
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }

  /** QMP 恢复。 */
  resumeVm(): boolean {
    try {
      const error: string = resume();
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }

  /** 0=拉伸 1=等比 2=1:1。 */
  setDisplayScaleMode(mode: number): void {
    try {
      setScaleMode(mode);
    } catch (err) {
      console.error(`setScaleMode failed: ${JSON.stringify(err)}`);
    }
  }

  setDisplayRefreshRate(hz: number): void {
    try {
      setRefreshRateHz(hz);
    } catch (err) {
      console.error(`setRefreshRateHz failed: ${JSON.stringify(err)}`);
    }
  }

  refreshScreen(): void {
    try {
      refreshScreen(1);
    } catch (err) {
      console.error(`refreshScreen failed: ${JSON.stringify(err)}`);
    }
  }

  // ============================================================
  // 输入注入：通过 QMP 发送键鼠事件到客户机
  // ============================================================

  /** 键盘组合（逗号分隔的 QKeyCode 名称，如 "ctrl,alt,delete"）。 */
  sendKeyCombo(keysCsv: string, holdMs: number): boolean {
    try {
      const error: string = nativeSendKeyCombo(keysCsv, holdMs);
      if (error.length > 0) {
        this.lastError = error;
        console.error(`sendKeyCombo failed: ${error}`);
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      console.error(`sendKeyCombo exception: ${this.lastError}`);
      return false;
    }
  }

  /** 发送单个按键按下/抬起（物理键盘长按使用）。 */
  sendKeyEvent(key: string, down: boolean): boolean {
    try {
      const error: string = nativeSendKeyEvent(key, down);
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }

  /** 向客户机输入 ASCII 文本。 */
  sendText(text: string, delayMs: number): boolean {
    try {
      const error: string = nativeSendText(text, delayMs);
      if (error.length > 0) {
        this.lastError = error;
        console.error(`sendText failed: ${error}`);
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      console.error(`sendText exception: ${this.lastError}`);
      return false;
    }
  }

  /** 鼠标按键：left / middle / right。 */
  sendMouseButton(button: string, down: boolean): boolean {
    try {
      const error: string = nativeSendMouseButton(button, down);
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }

  /** 鼠标移动：relative=true 为相对位移，否则为 0..0x7fff 的绝对坐标。 */
  sendMouseMove(relative: boolean, x: number, y: number): boolean {
    try {
      const error: string = nativeSendMouseMove(relative, x, y);
      if (error.length > 0) {
        this.lastError = error;
        return false;
      }
      return true;
    } catch (err) {
      this.lastError = JSON.stringify(err);
      return false;
    }
  }
}
