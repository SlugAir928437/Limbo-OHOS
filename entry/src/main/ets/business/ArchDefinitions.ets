import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { ArchDefinition, ArchManager } from './ArchManager';
import { LimboConfig } from './LimboConfig';

/**
 * 架构相关的可选项（迁移自 Android ArchDefinitions）。
 * 选项来自 rawfile 中的 txt 列表，按当前架构（x86_64 / arm64）加载。
 */
export class ArchDefinitions {
  private static cpuValues: string[] = [];
  private static machineTypeValues: string[] = [];
  private static nicValues: string[] = [];
  private static soundValues: string[] = [];
  private static armNicValues: string[] = [];
  private static loadedArch: string = '';
  private static ready: Promise<void> | null = null;

  static ensureReady(context: common.Context): Promise<void> {
    const arch: string = LimboConfig.ARCH;
    const existing: Promise<void> | null = ArchDefinitions.ready;
    if (existing !== null && ArchDefinitions.loadedArch === arch) {
      return existing;
    }
    ArchDefinitions.loadedArch = arch;
    const started: Promise<void> = ArchDefinitions.load(context);
    ArchDefinitions.ready = started;
    return started;
  }

  private static async load(context: common.Context): Promise<void> {
    const definition: ArchDefinition = ArchManager.getCurrent();
    ArchDefinitions.cpuValues = await ArchDefinitions.readRawLines(context, definition.cpuFile);
    ArchDefinitions.machineTypeValues = await ArchDefinitions.readRawLines(context, definition.machineFile);
    ArchDefinitions.nicValues = await ArchDefinitions.readRawLines(context, 'common_nic_cards.txt');
    ArchDefinitions.soundValues = await ArchDefinitions.readRawLines(context, 'common_soundcards.txt');
    ArchDefinitions.armNicValues = definition.armNic
      ? await ArchDefinitions.readRawLines(context, 'arm_nic_cards.txt') : [];
  }

  private static async readRawLines(context: common.Context, fileName: string): Promise<string[]> {
    try {
      const content: Uint8Array = await context.resourceManager.getRawFileContent(fileName);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(content);
      const lines: string[] = text.split('\n');
      const values: string[] = [];
      for (let i = 0; i < lines.length; i++) {
        const line: string = lines[i].trim();
        if (line.length > 0) {
          values.push(line);
        }
      }
      return values;
    } catch (err) {
      console.error(`read raw ${fileName} failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  static getMachineValues(): string[] {
    return ['None', 'New'];
  }

  static getCpuValues(): string[] {
    const values: string[] = ['Default'];
    for (let i = 0; i < ArchDefinitions.cpuValues.length; i++) {
      values.push(ArchDefinitions.cpuValues[i]);
    }
    values.push('host');
    return values;
  }

  static getMachineTypeValues(): string[] {
    if (ArchManager.isArm64()) {
      return ArchDefinitions.machineTypeValues.slice();
    }
    const values: string[] = ['Default'];
    for (let i = 0; i < ArchDefinitions.machineTypeValues.length; i++) {
      values.push(ArchDefinitions.machineTypeValues[i]);
    }
    return values;
  }

  static getUIValues(): string[] {
    // HarmonyOS 版本只做 SDL 原生显示；GTK 不参与构建
    return ['VNC', 'SPICE', 'SDL'];
  }

  static getKeyboardValues(): string[] {
    return ['en-us'];
  }

  static getMouseValues(): string[] {
    return ['ps2', 'usb-mouse', 'usb-tablet（修复鼠标）', 'virtio-tablet-pci', 'virtio-multitouch-pci'];
  }

  static getVGAValues(): string[] {
    const values: string[] = ['std', 'ati'];
    // QXL 只在内核为 i386 的 QEMU 中默认编入；aarch64 构建不保证可用
    if (!ArchManager.isArm64()) {
      values.push('qxl');
    }
    values.push('cirrus', 'vmware', 'virtio-gpu-pci', 'virtio-gpu-gl-pci', 'nographic');
    return values;
  }

  static getSoundcards(): string[] {
    const values: string[] = ['None'];
    for (let i = 0; i < ArchDefinitions.soundValues.length; i++) {
      values.push(ArchDefinitions.soundValues[i]);
    }
    return values;
  }

  static getNetworkDevices(): string[] {
    const values: string[] = ['Default'];
    for (let i = 0; i < ArchDefinitions.nicValues.length; i++) {
      values.push(ArchDefinitions.nicValues[i]);
    }
    for (let i = 0; i < ArchDefinitions.armNicValues.length; i++) {
      values.push(ArchDefinitions.armNicValues[i]);
    }
    return values;
  }

  static getUsbControllerValues(): string[] {
    if (ArchManager.isArm64()) {
      // ich9/piix3 是 x86 芯片组内置的 USB 控制器
      return ['None', 'qemu-xhci', 'nec-usb-xhci'];
    }
    return ['None', 'qemu-xhci', 'nec-usb-xhci', 'ich9-usb-ehci1', 'piix3-usb-uhci'];
  }

  static getBootDevices(): string[] {
    const values: string[] = ['Default', 'CDROM', 'Hard Disk'];
    if (LimboConfig.ENABLE_EMULATED_FLOPPY && !ArchManager.isArm64()) {
      values.push('Floppy');
    }
    return values;
  }

  static getBiosFirmwareValues(): string[] {
    if (ArchManager.isArm64()) {
      return ['ast27x0_bootrom.bin', 'edk2-aarch64-code.fd'];
    }
    return ['bios-256k.bin', 'bios.bin', 'bios-microvm.bin', 'edk2-x86_64-code.fd'];
  }

  static getAccelLabels(): string[] {
    // HMOS 版本不提供 KVM / Gunyah / GZVM，只有 TCG
    return ['TCG'];
  }

  static getAccelValues(): string[] {
    return ['tcg'];
  }

  static getDiskOptions(): string[] {
    return ['None', '打开'];
  }

  static getNvramOptions(): string[] {
    return ['默认', '新建', '打开'];
  }

  static getSizeUnitOptions(): string[] {
    return ['GB', 'MB', 'TB'];
  }
}
