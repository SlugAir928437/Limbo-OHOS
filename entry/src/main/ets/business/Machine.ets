import { LimboConfig } from './LimboConfig';
import { MachineProperty } from './MachineProperty';

/**
 * 虚拟机数据模型（迁移自 Android com.limbo.emu.machine.Machine）。
 * 字段名与数据库列一一对应，默认值沿用 Android x86_64 的 setDefaults()。
 */
export class Machine {
  static readonly ACCEL_TCG: string = 'tcg';
  static readonly ACCEL_KVM: string = 'kvm';
  static readonly ACCEL_GUNYAH: string = 'gunyah';
  static readonly ACCEL_GZVM: string = 'gzvm';
  static readonly USB_CONTROLLER_NONE: string = 'None';

  name: string;

  // 显示
  ui: string = 'SDL';
  keyboard: string = LimboConfig.DEFAULT_KEYBOARD_LAYOUT;
  mouse: string = 'ps2';
  arch: string = LimboConfig.ARCH;

  // 主板 / 加速
  machineType: string = 'pc';
  cpu: string = 'Default';
  cpuNum: number = 1;
  memory: number = 128;
  disableI8042: number = 1;
  enableNvram: number = 1;
  nvramPath: string | null = null;
  enableMTTCG: number = 0;
  enableKVM: number = 0;
  accelMode: string = Machine.ACCEL_TCG;
  disableACPI: number = 0;
  disableHPET: number = 0;
  disableTSC: number = 1;
  disableFdBootChk: number = 0;

  // 硬盘
  hdaPath: string | null = null;
  hdbPath: string | null = null;
  hdcPath: string | null = null;
  hddPath: string | null = null;
  hdaInterface: string = 'ide';
  hdbInterface: string = 'ide';
  hdcInterface: string = 'ide';
  hddInterface: string = 'ide';
  hdaFormat: string | null = null;
  hdbFormat: string | null = null;
  hdcFormat: string | null = null;
  hddFormat: string | null = null;
  hdaCache: string | null = null;
  hdbCache: string | null = null;
  hdcCache: string | null = null;
  hddCache: string | null = null;

  // 可移动设备
  cdImagePath: string | null = null;
  fdaImagePath: string | null = null;
  fdbImagePath: string | null = null;
  sdImagePath: string | null = null;
  cdInterface: string = 'ide';
  cdFormat: string | null = null;
  sharedFolderPath: string | null = null;
  sharedFolderMode: number = 1;

  // 启动
  bootDevice: string = 'Default';
  kernel: string | null = null;
  initRd: string | null = null;
  append: string | null = null;
  bios: string | null = null;

  // 网络
  network: string | null = null;
  networkCard: string = 'Default';
  guestFwd: string | null = null;
  hostFwd: string | null = null;

  // 显示 / 音频 / 高级
  vga: string = 'std';
  soundCard: string | null = null;
  extraParams: string | null = null;
  usbController: string = Machine.USB_CONTROLLER_NONE;

  // 运行状态
  paused: number = 0;

  constructor(name: string, loadDefaults: boolean) {
    this.name = name;
    if (loadDefaults) {
      this.loadDefaults();
    }
  }

  /** Android Machine#setDefaults 的 x86_64 分支。 */
  private loadDefaults(): void {
    this.arch = LimboConfig.ARCH;
    this.cpu = 'Default';
    this.machineType = 'pc';
    this.networkCard = 'Default';
    this.disableTSC = 1;
    this.usbController = Machine.USB_CONTROLLER_NONE;
  }

  getUI(): string {
    return this.ui.length > 0 ? this.ui : 'SDL';
  }

  isRemoteDisplay(): boolean {
    const ui: string = this.getUI();
    return ui === 'VNC' || ui === 'SPICE';
  }

  /** 通用属性写入（供 UI 回调与数据库同步使用）。 */
  setProperty(property: MachineProperty, value: string): void {
    switch (property) {
      case MachineProperty.UI:
        this.ui = value;
        break;
      case MachineProperty.MOUSE:
        this.mouse = value;
        break;
      case MachineProperty.KEYBOARD:
        this.keyboard = value;
        break;
      case MachineProperty.ARCH:
        this.arch = value;
        break;
      case MachineProperty.MACHINETYPE:
        this.machineType = value;
        break;
      case MachineProperty.CPU:
        this.cpu = value;
        break;
      case MachineProperty.CPUNUM:
        this.cpuNum = this.toInt(value);
        break;
      case MachineProperty.MEMORY:
        this.memory = this.toInt(value);
        break;
      case MachineProperty.DISABLE_I8042:
        this.disableI8042 = this.toInt(value);
        break;
      case MachineProperty.ENABLE_MTTCG:
        this.enableMTTCG = this.toInt(value);
        break;
      case MachineProperty.ENABLE_KVM:
        this.enableKVM = this.toInt(value);
        break;
      case MachineProperty.ACCEL_MODE:
        this.accelMode = value.length > 0 ? value : Machine.ACCEL_TCG;
        break;
      case MachineProperty.ENABLE_NVRAM:
        this.enableNvram = this.toInt(value);
        break;
      case MachineProperty.NVRAM_PATH:
        this.nvramPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.DISABLE_ACPI:
        this.disableACPI = this.toInt(value);
        break;
      case MachineProperty.DISABLE_HPET:
        this.disableHPET = this.toInt(value);
        break;
      case MachineProperty.DISABLE_TSC:
        this.disableTSC = this.toInt(value);
        break;
      case MachineProperty.DISABLE_FD_BOOT_CHK:
        this.disableFdBootChk = this.toInt(value);
        break;
      case MachineProperty.HDA:
        this.hdaPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDB:
        this.hdbPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDC:
        this.hdcPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDD:
        this.hddPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDA_INTERFACE:
        this.hdaInterface = value.length > 0 ? value : 'ide';
        break;
      case MachineProperty.HDB_INTERFACE:
        this.hdbInterface = value.length > 0 ? value : 'ide';
        break;
      case MachineProperty.HDC_INTERFACE:
        this.hdcInterface = value.length > 0 ? value : 'ide';
        break;
      case MachineProperty.HDD_INTERFACE:
        this.hddInterface = value.length > 0 ? value : 'ide';
        break;
      case MachineProperty.CDROM_INTERFACE:
        this.cdInterface = value.length > 0 ? value : 'ide';
        break;
      case MachineProperty.HDA_FORMAT:
        this.hdaFormat = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDB_FORMAT:
        this.hdbFormat = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDC_FORMAT:
        this.hdcFormat = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDD_FORMAT:
        this.hddFormat = this.nullIfEmpty(value);
        break;
      case MachineProperty.CDROM_FORMAT:
        this.cdFormat = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDA_CACHE:
        this.hdaCache = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDB_CACHE:
        this.hdbCache = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDC_CACHE:
        this.hdcCache = this.nullIfEmpty(value);
        break;
      case MachineProperty.HDD_CACHE:
        this.hddCache = this.nullIfEmpty(value);
        break;
      case MachineProperty.CDROM:
        this.cdImagePath = this.nullIfEmpty(value);
        break;
      case MachineProperty.FDA:
        this.fdaImagePath = this.nullIfEmpty(value);
        break;
      case MachineProperty.FDB:
        this.fdbImagePath = this.nullIfEmpty(value);
        break;
      case MachineProperty.SD:
        this.sdImagePath = this.nullIfEmpty(value);
        break;
      case MachineProperty.SHARED_FOLDER:
        this.sharedFolderPath = this.nullIfEmpty(value);
        break;
      case MachineProperty.SHARED_FOLDER_MODE:
        this.sharedFolderMode = this.toInt(value);
        break;
      case MachineProperty.BOOT_CONFIG:
        this.bootDevice = value;
        break;
      case MachineProperty.KERNEL:
        this.kernel = this.nullIfEmpty(value);
        break;
      case MachineProperty.INITRD:
        this.initRd = this.nullIfEmpty(value);
        break;
      case MachineProperty.APPEND:
        this.append = this.nullIfEmpty(value);
        break;
      case MachineProperty.BIOS:
        this.bios = this.nullIfEmpty(value);
        break;
      case MachineProperty.NETCONFIG:
        this.network = this.nullIfEmpty(value);
        break;
      case MachineProperty.NICCONFIG:
        this.networkCard = value;
        break;
      case MachineProperty.HOSTFWD:
        this.hostFwd = this.nullIfEmpty(value);
        break;
      case MachineProperty.GUESTFWD:
        this.guestFwd = this.nullIfEmpty(value);
        break;
      case MachineProperty.VGA:
        this.vga = value;
        break;
      case MachineProperty.SOUNDCARD:
        this.soundCard = this.nullIfEmpty(value);
        break;
      case MachineProperty.EXTRA_PARAMS:
        this.extraParams = this.nullIfEmpty(value);
        break;
      case MachineProperty.USB_CONTROLLER:
        this.usbController = value.length > 0 ? value : Machine.USB_CONTROLLER_NONE;
        break;
      case MachineProperty.PAUSED:
        this.paused = this.toInt(value);
        break;
      default:
        break;
    }
  }

  private toInt(value: string): number {
    const parsed: number = parseInt(value, 10);
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  private nullIfEmpty(value: string): string | null {
    return value.length > 0 ? value : null;
  }
}
