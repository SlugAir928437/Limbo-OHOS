import { ArchManager } from './ArchManager';
import { LimboConfig } from './LimboConfig';
import { LimboSettingsManager } from './LimboSettingsManager';
import { Machine } from './Machine';
import { MachineDatabase } from './MachineDatabase';
import { MachineProperty } from './MachineProperty';
import { QemuArgs } from './QemuArgs';
import { VmExecutor } from './VmExecutor';

/** 运行状态（对应 Android MachineController.MachineStatus）。 */
export enum MachineStatus {
  Ready,
  Stopped,
  Saving,
  Paused,
  SaveCompleted,
  SaveFailed,
  Unknown,
  Running
}

/** 控制器事件（对应 Android MachineController.Event）。 */
export enum MachineEvent {
  MachineCreated,
  MachineCreateFailed,
  MachineLoaded,
  MachinesChanged
}

type StatusListener = (machine: Machine | null, status: MachineStatus) => void;
type EventListener = (event: MachineEvent, detail: string) => void;

/**
 * 虚拟机控制器（迁移自 Android MachineController）。
 *
 * HarmonyOS 端暂时没有 QEMU 执行体，因此 start/pause/stop/restart 只维护
 * 业务状态与数据库中的 PAUSED 字段；将来接入原生引擎时替换这四个方法即可。
 */
export class MachineController {
  private static readonly instance: MachineController = new MachineController();
  private machine: Machine | null = null;
  private status: MachineStatus = MachineStatus.Stopped;
  private statusListeners: StatusListener[] = [];
  private eventListeners: EventListener[] = [];
  private pendingUpdates: Map<string, number> = new Map();
  private lastError: string = '';

  static getInstance(): MachineController {
    return MachineController.instance;
  }

  getMachine(): Machine | null {
    return this.machine;
  }

  getStatus(): MachineStatus {
    return this.status;
  }

  isRunning(): boolean {
    return this.status === MachineStatus.Running;
  }

  isPaused(): boolean {
    return this.machine !== null && this.machine.paused === 1;
  }

  /** 最近一次原生启动/暂停失败的原因。 */
  getLastError(): string {
    return this.lastError;
  }

  addStatusListener(listener: StatusListener): void {
    this.statusListeners.push(listener);
  }

  removeStatusListener(listener: StatusListener): void {
    const rest: StatusListener[] = [];
    for (let i = 0; i < this.statusListeners.length; i++) {
      if (this.statusListeners[i] !== listener) {
        rest.push(this.statusListeners[i]);
      }
    }
    this.statusListeners = rest;
  }

  addEventListener(listener: EventListener): void {
    this.eventListeners.push(listener);
  }

  getStoredMachines(): Promise<string[]> {
    return MachineDatabase.getInstance().getMachineNames();
  }

  /** 按名字从数据库加载虚拟机；找不到时清空当前虚拟机。 */
  async loadMachine(name: string): Promise<Machine | null> {
    const loaded: Machine | null = await MachineDatabase.getInstance().getMachine(name);
    this.setMachine(loaded);
    if (loaded !== null) {
      this.updateStatus(loaded.paused === 1 ? MachineStatus.Paused : MachineStatus.Ready);
      this.notifyEvent(MachineEvent.MachineLoaded, loaded.name);
    } else {
      this.updateStatus(MachineStatus.Stopped);
    }
    return loaded;
  }

  clearMachine(): void {
    this.setMachine(null);
    this.updateStatus(MachineStatus.Stopped);
  }

  /** 创建虚拟机（重名时返回 null；写入失败时可通过 getLastError() 获取原因）。 */
  async createMachine(name: string): Promise<Machine | null> {
    this.lastError = '';
    const existing: Machine | null = await MachineDatabase.getInstance().getMachine(name);
    if (existing !== null) {
      this.notifyEvent(MachineEvent.MachineCreateFailed, name);
      return null;
    }
    const machine: Machine = new Machine(name, true);
    // 确保落库架构与当前架构完全一致（列表按 ARCH 过滤）
    machine.arch = ArchManager.getCurrent().key;
    const rowId: number = await MachineDatabase.getInstance().insertMachine(machine);
    if (rowId < 0) {
      this.lastError = '数据库写入失败';
      this.notifyEvent(MachineEvent.MachineCreateFailed, name);
      return null;
    }
    this.setMachine(machine);
    this.updateStatus(MachineStatus.Ready);
    this.notifyEvent(MachineEvent.MachineCreated, name);
    this.notifyEvent(MachineEvent.MachinesChanged, name);
    return machine;
  }

  async deleteMachine(): Promise<boolean> {
    const current: Machine | null = this.machine;
    if (current === null) {
      return false;
    }
    const deleted: boolean = await MachineDatabase.getInstance().deleteMachine(current.name);
    if (deleted) {
      this.setMachine(null);
      this.updateStatus(MachineStatus.Stopped);
      this.notifyEvent(MachineEvent.MachinesChanged, current.name);
    }
    return deleted;
  }

  // ============================================================
  // 运行状态：有 QEMU 引擎时走原生执行体，否则退化为状态机演示
  // ============================================================

  async start(): Promise<void> {
    if (this.machine === null) {
      return;
    }
    const executor: VmExecutor = VmExecutor.getInstance();

    if (executor.isAvailable()) {
      if (this.status === MachineStatus.Paused) {
        if (!executor.resumeVm()) {
          this.lastError = executor.getLastError();
          return;
        }
      } else if (executor.getState() === 0) {
        const args: string[] = QemuArgs.build(this.machine, LimboSettingsManager.getDnsServer());
        // 显示缩放方式与可变刷新率来自设置页
        if (!executor.startVm(args, LimboSettingsManager.getSDLScaleMode(),
          LimboSettingsManager.getSDLRefreshRate())) {
          this.lastError = executor.getLastError();
          this.updateStatus(MachineStatus.Ready);
          return;
        }
      }
    }

    this.machine.paused = 0;
    await MachineDatabase.getInstance().updateField(this.machine.name, MachineProperty.PAUSED, '0');
    this.updateStatus(MachineStatus.Running);
  }

  async pause(): Promise<void> {
    if (this.machine === null) {
      return;
    }
    const executor: VmExecutor = VmExecutor.getInstance();
    if (executor.isAvailable() && executor.getState() !== 0) {
      if (!executor.pauseVm()) {
        this.lastError = executor.getLastError();
        return;
      }
    }
    this.machine.paused = 1;
    await MachineDatabase.getInstance().updateField(this.machine.name, MachineProperty.PAUSED, '1');
    this.updateStatus(MachineStatus.Paused);
  }

  async stop(): Promise<void> {
    if (this.machine === null) {
      return;
    }
    const executor: VmExecutor = VmExecutor.getInstance();
    if (executor.isAvailable() && executor.getState() !== 0) {
      executor.stopVm(false);
    }
    this.machine.paused = 0;
    await MachineDatabase.getInstance().updateField(this.machine.name, MachineProperty.PAUSED, '0');
    this.updateStatus(MachineStatus.Stopped);
  }

  async restart(): Promise<void> {
    if (this.machine === null) {
      return;
    }
    const executor: VmExecutor = VmExecutor.getInstance();
    if (executor.isAvailable() && executor.getState() !== 0) {
      if (!executor.stopVm(true)) {
        this.lastError = executor.getLastError();
      }
      this.machine.paused = 0;
      await MachineDatabase.getInstance().updateField(this.machine.name, MachineProperty.PAUSED, '0');
      this.updateStatus(MachineStatus.Running);
      return;
    }
    await this.start();
  }

  // ============================================================
  // 字段更新（对应 Android Machine 的 Observer -> 数据库）
  // ============================================================

  /** 更新字段并延迟落库，避免输入框每敲一个字符都写数据库。 */
  updateField(property: MachineProperty, value: string): void {
    const current: Machine | null = this.machine;
    if (current === null) {
      return;
    }
    current.setProperty(property, value);
    const key: string = property;
    const existing: number | undefined = this.pendingUpdates.get(key);
    if (existing !== undefined) {
      clearTimeout(existing);
    }
    const machineName: string = current.name;
    const timer: number = setTimeout(() => {
      this.pendingUpdates.delete(key);
      MachineDatabase.getInstance().updateField(machineName, property, value)
        .catch((err: Error) => {
          console.error(`persist ${key} failed: ${err.message}`);
        });
    }, LimboConfig.DB_UPDATE_DELAY_MS);
    this.pendingUpdates.set(key, timer);
  }

  /** 立即更新字段并落库（下拉选择/开关等离散操作使用）。 */
  async updateFieldNow(property: MachineProperty, value: string): Promise<void> {
    const current: Machine | null = this.machine;
    if (current === null) {
      return;
    }
    current.setProperty(property, value);
    await MachineDatabase.getInstance().updateField(current.name, property, value);
  }

  private setMachine(machine: Machine | null): void {
    this.machine = machine;
  }

  private updateStatus(status: MachineStatus): void {
    this.status = status;
    for (let i = 0; i < this.statusListeners.length; i++) {
      this.statusListeners[i](this.machine, status);
    }
  }

  private notifyEvent(event: MachineEvent, detail: string): void {
    for (let i = 0; i < this.eventListeners.length; i++) {
      this.eventListeners[i](event, detail);
    }
  }
}
