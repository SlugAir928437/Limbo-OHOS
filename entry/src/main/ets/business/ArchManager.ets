import { common } from '@kit.AbilityKit';
import { LimboConfig } from './LimboConfig';
import { LimboSettingsManager } from './LimboSettingsManager';

/** 一个可模拟的客户机架构。 */
export interface ArchDefinition {
  key: string;
  label: string;
  qemuBinary: string;
  cpuFile: string;
  machineFile: string;
  armNic: boolean;
}

/** 当前构建实际包含引擎的两个架构（workflow 构建 x86_64 + aarch64 softmmu）。 */
export const SUPPORTED_ARCHS: ArchDefinition[] = [
  {
    key: 'x86_64',
    label: 'x86_64 (amd64)',
    qemuBinary: 'qemu-system-x86_64',
    cpuFile: 'x86_cpu.txt',
    machineFile: 'x86_machine_types.txt',
    armNic: false
  },
  {
    key: 'arm64',
    label: 'arm64 (aarch64)',
    qemuBinary: 'qemu-system-aarch64',
    cpuFile: 'arm_cpu.txt',
    machineFile: 'arm_machine_types.txt',
    armNic: true
  }
];

/**
 * 模拟架构管理（迁移自 Android ArchManager）。
 *
 * 与 Android 的差异：HarmonyOS 版本只内置 x86_64 / aarch64 两套引擎，
 * 因此可切换列表只有这两个；切换后不重启应用，而是清空当前选择并按
 * 新架构重新加载虚拟机列表。
 */
export class ArchManager {
  /** 与 Android 同名的持久化 key。 */
  static readonly SETTINGS_KEY: string = 'emulatedArch';

  /** 读取已保存架构并写入 LimboConfig；应在任何数据库查询前调用。 */
  static async initialize(context: common.Context): Promise<void> {
    await LimboSettingsManager.ensureReady(context);
    const saved: string = LimboSettingsManager.getString(ArchManager.SETTINGS_KEY, LimboConfig.DEFAULT_ARCH);
    const definition: ArchDefinition | null = ArchManager.find(saved);
    const target: ArchDefinition = definition === null ? SUPPORTED_ARCHS[0] : definition;
    LimboConfig.setArch(target.key, target.label);
  }

  static find(key: string): ArchDefinition | null {
    for (let i = 0; i < SUPPORTED_ARCHS.length; i++) {
      if (SUPPORTED_ARCHS[i].key === key) {
        return SUPPORTED_ARCHS[i];
      }
    }
    return null;
  }

  static getCurrent(): ArchDefinition {
    const definition: ArchDefinition | null = ArchManager.find(LimboConfig.ARCH);
    return definition === null ? SUPPORTED_ARCHS[0] : definition;
  }

  static getSelectableArchs(): ArchDefinition[] {
    return SUPPORTED_ARCHS;
  }

  /** 另一个可切换架构；只有一个时返回 null。 */
  static getOther(): ArchDefinition | null {
    for (let i = 0; i < SUPPORTED_ARCHS.length; i++) {
      if (SUPPORTED_ARCHS[i].key !== LimboConfig.ARCH) {
        return SUPPORTED_ARCHS[i];
      }
    }
    return null;
  }

  static isArm64(): boolean {
    return LimboConfig.ARCH === 'arm64';
  }

  static qemuBinary(): string {
    return ArchManager.getCurrent().qemuBinary;
  }

  /** 保存并应用新架构；调用方随后需要刷新 ArchDefinitions 与虚拟机列表。 */
  static async switchTo(context: common.Context, key: string): Promise<boolean> {
    const definition: ArchDefinition | null = ArchManager.find(key);
    if (definition === null) {
      return false;
    }
    await LimboSettingsManager.ensureReady(context);
    LimboConfig.setArch(definition.key, definition.label);
    LimboSettingsManager.setString(ArchManager.SETTINGS_KEY, definition.key);
    return true;
  }

  /** 架构默认的硬盘/光驱接口（空接口值由 QemuArgs 使用）。 */
  static defaultDriveInterface(cdrom: boolean): string {
    if (ArchManager.isArm64()) {
      return cdrom ? 'scsi' : 'virtio';
    }
    return 'ide';
  }
}
