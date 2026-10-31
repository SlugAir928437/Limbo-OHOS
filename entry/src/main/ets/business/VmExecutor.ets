import {
  getState,
  isEngineAvailable,
  pause,
  refreshScreen,
  resume,
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
 * 进程内 dlopen libqemu-system-x86_64.so，TCG 执行，SDL 显示。
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

  /** 是否随包提供了 QEMU 引擎（libqemu-system-x86_64.so）。 */
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
}
