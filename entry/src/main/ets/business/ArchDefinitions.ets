import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { LimboConfig } from './LimboConfig';

/**
 * 架构相关的可选项（迁移自 Android ArchDefinitions）。
 * 选项来自 rawfile 中的 txt 列表，架构固定为 x86_64。
 */
export class ArchDefinitions {
  private static cpuValues: string[] = [];
  private static machineTypeValues: string[] = [];
  private static nicValues: string[] = [];
  private static soundValues: string[] = [];
  private static ready: Promise<void> | null = null;

  static ensureReady(context: common.Context): Promise<void> {
    if (ready !== null) {
      return ArchDefinitions.ready;
    }
    ArchDefinitions.ready = ArchDefinitions.load(context);
    return ArchDefinitions.ready;
  }

  private static async load(context: common.Context): Promise<void> {
    ArchDefinitions.cpuValues = await ArchDefinitions.readRawLines(context, 'x86_cpu.txt');
    ArchDefinitions.machineTypeValues = await ArchDefinitions.readRawLines(context, 'x86_machine_types.txt');
    ArchDefinitions.nicValues = await ArchDefinitions.readRawLines(context, 'common_nic_cards.txt');
    ArchDefinitions.soundValues = await ArchDefinitions.readRawLines(context, 'common_soundcards.txt');
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
    return ['std', 'ati', 'qxl', 'cirrus', 'vmware', 'virtio-gpu-pci', 'virtio-gpu-gl-pci', 'nographic'];
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
    return values;
  }

  static getUsbControllerValues(): string[] {
    return ['None', 'qemu-xhci', 'nec-usb-xhci', 'ich9-usb-ehci1', 'piix3-usb-uhci'];
  }

  static getBootDevices(): string[] {
    const values: string[] = ['Default', 'CDROM', 'Hard Disk'];
    if (LimboConfig.ENABLE_EMULATED_FLOPPY) {
      values.push('Floppy');
    }
    return values;
  }

  static getBiosFirmwareValues(): string[] {
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
