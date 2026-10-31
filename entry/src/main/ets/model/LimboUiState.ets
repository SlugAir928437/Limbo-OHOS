/**
 * Limbo 主配置页的 UI 状态模型。
 *
 * 1:1 对应 Android 端 com.limbo.emu.ui.LimboUiState / StorageDeviceUiState，
 * 只是把 Compose 的 mutableStateOf 换成 ArkUI 的 @Observed 可观察对象。
 * 本层只负责“界面状态”，不包含任何 QEMU 业务逻辑。
 */

/** 存储设备镜像下拉里的固定项（与 Android StorageDeviceEditorActivity 保持一致）。 */
export const IMAGE_NONE: string = 'None';
export const IMAGE_NEW: string = '新建';
export const IMAGE_OPEN: string = '打开';

/** 单个存储设备的类型定义（对应 Android LimboActivity.DeviceType）。 */
export class DeviceTypeDef {
  key: string;
  label: string;
  removable: boolean;
  createImage: boolean;
  sharedFolder: boolean;
  maxCount: number;
  canIf: boolean;
  canCache: boolean;

  constructor(key: string, label: string, removable: boolean, createImage: boolean,
              sharedFolder: boolean, maxCount: number, canIf: boolean, canCache: boolean) {
    this.key = key;
    this.label = label;
    this.removable = removable;
    this.createImage = createImage;
    this.sharedFolder = sharedFolder;
    this.maxCount = maxCount;
    this.canIf = canIf;
    this.canCache = canCache;
  }
}

/** 可选设备类型，顺序与 Android 端一致。 */
export const DEVICE_TYPES: DeviceTypeDef[] = [
  new DeviceTypeDef('HARD_DISK', '硬盘', false, true, false, 4, true, true),
  new DeviceTypeDef('CDROM', '光驱', true, false, false, 1, true, false),
  new DeviceTypeDef('FDA', '软盘 A', true, false, false, 1, false, false),
  new DeviceTypeDef('FDB', '软盘 B', true, false, false, 1, false, false),
  new DeviceTypeDef('SD', 'SD 卡', true, false, false, 1, false, false),
  new DeviceTypeDef('SHARED_DIR', '共享文件夹', false, false, true, 1, false, false)
];

/** 存储设备接口选项（-drive if=）。 */
export const STORAGE_IF_LABELS: string[] = ['默认', 'IDE', 'SCSI', 'VirtIO', 'SATA', 'NVMe'];
/** 存储设备格式选项（-drive format=）。 */
export const STORAGE_FORMAT_LABELS: string[] = ['自动', 'RAW', 'QCOW2', 'QCOW', 'VMDK', 'VHDX', 'VDI', 'VPC', 'Parallels'];

/** 各下拉框的默认选项，取自 Android ArchDefinitions / LimboActivity（x86_64 默认值）。 */
export const UI_OPTIONS: string[] = ['VNC', 'SPICE', 'SDL'];
export const KEYBOARD_OPTIONS: string[] = ['en-us'];
export const MOUSE_OPTIONS: string[] = ['ps2', 'usb-mouse', 'usb-tablet（修复鼠标）',
  'virtio-tablet-pci', 'virtio-multitouch-pci'];
export const MACHINE_TYPE_OPTIONS: string[] = ['Default', 'pc', 'q35', 'microvm', 'virt'];
export const CPU_OPTIONS: string[] = ['Default', '486', 'athlon', 'base', 'Broadwell', 'Conroe',
  'core2duo', 'coreduo', 'Haswell', 'kvm64', 'max', 'Nehalem', 'Penryn', 'pentium', 'qemu32',
  'qemu64', 'SandyBridge', 'Westmere'];
export const ACCEL_OPTIONS: string[] = ['TCG', 'KVM'];
export const NVRAM_OPTIONS: string[] = ['默认', '新建', '打开'];
export const BOOT_OPTIONS: string[] = ['Default', 'CDROM', 'Hard Disk', 'Floppy'];
export const BIOS_OPTIONS: string[] = ['默认', 'bios-256k.bin', 'bios.bin'];
export const DISK_OPTIONS: string[] = [IMAGE_NONE, IMAGE_OPEN];
export const VGA_OPTIONS: string[] = ['std', 'ati', 'qxl', 'cirrus', 'vmware',
  'virtio-gpu-pci', 'virtio-gpu-gl-pci', 'nographic'];
export const SOUND_OPTIONS: string[] = [IMAGE_NONE, 'sb16', 'ac97', 'adlib', 'cs4231a', 'gus',
  'es1370', 'hda', 'pcspk', 'virtio-sound-pci'];
export const NET_OPTIONS: string[] = [IMAGE_NONE, 'User', 'TAP'];
export const NIC_OPTIONS: string[] = ['Default', 'e1000', 'pcnet', 'rtl8139', 'ne2k_pci',
  'i82551', 'i82557b', 'i82559er', 'virtio', 'virtio-net-pci'];
export const USB_OPTIONS: string[] = [IMAGE_NONE, 'qemu-xhci', 'nec-usb-xhci',
  'ich9-usb-ehci1', 'piix3-usb-uhci'];

/** 可折叠分区标识（对应 Android ui.LimboUiState.Section）。 */
export enum Section {
  UI,
  BOARD,
  STORAGE,
  BOOT,
  GRAPHICS,
  AUDIO,
  NETWORK,
  ADVANCED
}

/**
 * 单个存储设备行的界面状态（对应 Android ui.StorageDeviceUiState）。
 * 额外保存了编辑页需要的接口/格式/缓存等字段，便于在编辑页与主页面之间共享。
 */
@Observed
export class StorageDeviceUiState {
  tag: number = 0;
  typeKey: string = 'HARD_DISK';
  /** 从 Machine 重建时的原始类型，用于编辑页切换类型后清理旧字段。 */
  originalTypeKey: string = '';
  typeOptions: string[] = [];
  typeSel: number = 0;

  sizeValue: string = '4';
  sizeUnitOptions: string[] = ['GB', 'MB', 'TB'];
  sizeUnitSel: number = 0;

  imageOptions: string[] = [IMAGE_NONE];
  imageSel: number = 0;
  newImageName: string = '';

  ifSel: number = 0;
  formatSel: number = 0;
  cacheValue: string = '';

  enabled: boolean = true;
  removable: boolean = false;
  createImage: boolean = false;
  sharedFolder: boolean = false;
  canIf: boolean = false;
  canCache: boolean = false;
  hardDiskSlot: number = -1;

  constructor() {
    this.typeOptions = DEVICE_TYPES.map((type: DeviceTypeDef) => type.label);
    this.applyType(0);
  }

  /** 切换设备类型，并同步该类型的标志位与镜像选项。 */
  applyType(index: number): void {
    if (index < 0 || index >= DEVICE_TYPES.length) {
      return;
    }
    const def: DeviceTypeDef = DEVICE_TYPES[index];
    this.typeSel = index;
    this.typeKey = def.key;
    this.removable = def.removable;
    this.createImage = def.createImage;
    this.sharedFolder = def.sharedFolder;
    this.canIf = def.canIf;
    this.canCache = def.canCache;
    this.imageOptions = this.buildImageOptions();
    this.imageSel = 0;
  }

  /** 镜像选项：None / [新建] / 打开 / 最近使用的文件。 */
  buildImageOptions(): string[] {
    const options: string[] = [IMAGE_NONE];
    if (this.createImage) {
      options.push(IMAGE_NEW);
    }
    options.push(IMAGE_OPEN);
    return options;
  }

  typeLabel(): string {
    if (this.typeSel >= 0 && this.typeSel < this.typeOptions.length) {
      return this.typeOptions[this.typeSel];
    }
    return '?';
  }

  selectedImageOption(): string {
    if (this.imageSel >= 0 && this.imageSel < this.imageOptions.length) {
      return this.imageOptions[this.imageSel];
    }
    return IMAGE_NONE;
  }

  /** 主页存储行第二行显示的内容：新建镜像时显示名称，其余情况显示镜像路径。 */
  imageDisplay(): string {
    const option: string = this.selectedImageOption();
    if (option === IMAGE_NEW) {
      return this.newImageName;
    }
    if (option === IMAGE_OPEN || option === IMAGE_NONE) {
      return '';
    }
    return option;
  }

  clone(): StorageDeviceUiState {
    const copy: StorageDeviceUiState = new StorageDeviceUiState();
    copy.tag = this.tag;
    copy.typeKey = this.typeKey;
    copy.originalTypeKey = this.originalTypeKey;
    copy.typeOptions = this.typeOptions.slice();
    copy.typeSel = this.typeSel;
    copy.sizeValue = this.sizeValue;
    copy.sizeUnitOptions = this.sizeUnitOptions.slice();
    copy.sizeUnitSel = this.sizeUnitSel;
    copy.imageOptions = this.imageOptions.slice();
    copy.imageSel = this.imageSel;
    copy.newImageName = this.newImageName;
    copy.ifSel = this.ifSel;
    copy.formatSel = this.formatSel;
    copy.cacheValue = this.cacheValue;
    copy.enabled = this.enabled;
    copy.removable = this.removable;
    copy.createImage = this.createImage;
    copy.sharedFolder = this.sharedFolder;
    copy.canIf = this.canIf;
    copy.canCache = this.canCache;
    copy.hardDiskSlot = this.hardDiskSlot;
    return copy;
  }
}

/**
 * 主配置页的集中可观察状态（对应 Android ui.LimboUiState）。
 * 只保留界面需要的字段；业务写库动作在 Android 端由 Activity 完成，
 * HarmonyOS 端暂以本地状态演示 UI 行为。
 */
@Observed
export class LimboUiState {
  // 虚拟机
  machines: string[] = [];
  machineSel: number = 0;
  machineEnabled: boolean = true;
  archLabel: string = '';

  // 运行状态：0 停止 / 1 运行 / 2 暂停 / 3 保存中
  statusRunning: boolean = false;
  statusKind: number = 0;

  // 用户界面
  uiOptions: string[] = UI_OPTIONS;
  uiSel: number = 2;
  uiEnabled: boolean = true;
  keyboardOptions: string[] = KEYBOARD_OPTIONS;
  keyboardSel: number = 0;
  keyboardEnabled: boolean = true;
  mouseOptions: string[] = MOUSE_OPTIONS;
  mouseSel: number = 3;
  mouseEnabled: boolean = true;

  // 主板
  machineTypeOptions: string[] = MACHINE_TYPE_OPTIONS;
  machineTypeSel: number = 1;
  machineTypeEnabled: boolean = true;
  cpuOptions: string[] = CPU_OPTIONS;
  cpuSel: number = 15;
  cpuEnabled: boolean = true;
  cpuNumValue: string = '1';
  cpuNumEnabled: boolean = true;
  ramValue: string = '512';
  ramEnabled: boolean = true;
  accelOptions: string[] = ACCEL_OPTIONS;
  accelSel: number = 0;
  accelEnabled: boolean = true;
  disableI8042: boolean = true;
  disableI8042Enabled: boolean = false;
  enableNvram: boolean = true;
  enableNvramEnabled: boolean = false;
  nvramOptions: string[] = NVRAM_OPTIONS;
  nvramSel: number = 0;
  nvramEnabled: boolean = false;
  enableMTTCG: boolean = false;
  enableMTTCGEnabled: boolean = true;
  showMTTCGSwitch: boolean = true;
  disableACPI: boolean = false;
  disableACPIEnabled: boolean = true;
  disableHPET: boolean = false;
  disableHPETEnabled: boolean = true;
  disableTSC: boolean = false;
  disableTSCEnabled: boolean = true;

  // 存储设备
  storageDevices: StorageDeviceUiState[] = [];
  addDeviceEnabled: boolean = true;

  // 启动
  bootOptions: string[] = BOOT_OPTIONS;
  bootSel: number = 0;
  bootEnabled: boolean = true;
  biosOptions: string[] = BIOS_OPTIONS;
  biosSel: number = 0;
  biosEnabled: boolean = true;
  kernelOptions: string[] = DISK_OPTIONS;
  kernelSel: number = 0;
  kernelEnabled: boolean = true;
  initrdOptions: string[] = DISK_OPTIONS;
  initrdSel: number = 0;
  initrdEnabled: boolean = true;
  append: string = '';
  appendEnabled: boolean = true;

  // 图形
  vgaOptions: string[] = VGA_OPTIONS;
  vgaSel: number = 0;
  vgaEnabled: boolean = true;

  // 音频
  soundOptions: string[] = SOUND_OPTIONS;
  soundSel: number = 0;
  soundEnabled: boolean = true;

  // 网络
  netOptions: string[] = NET_OPTIONS;
  netSel: number = 0;
  netEnabled: boolean = true;
  nicOptions: string[] = NIC_OPTIONS;
  nicSel: number = 0;
  nicEnabled: boolean = false;
  dns: string = '';
  dnsEnabled: boolean = false;
  hostFwd: string = '';
  hostFwdEnabled: boolean = false;

  // 高级
  extraParams: string = '';
  extraParamsEnabled: boolean = true;
  usbControllerOptions: string[] = USB_OPTIONS;
  usbControllerSel: number = 0;
  usbControllerEnabled: boolean = true;

  // 分区折叠状态：图形默认展开，其余默认折叠（与 Android 一致）
  uiCollapsed: boolean = true;
  boardCollapsed: boolean = true;
  storageCollapsed: boolean = true;
  bootCollapsed: boolean = true;
  graphicsCollapsed: boolean = false;
  audioCollapsed: boolean = true;
  networkCollapsed: boolean = true;
  advancedCollapsed: boolean = true;

  constructor() {
    // 初始为空，真实数据由 MachineDatabase / MachineController 在页面初始化时注入
    this.machines = ['未选择虚拟机', '新建虚拟机…'];
    this.machineSel = 0;
    // 虚拟机下拉必须始终可点，否则无法选择/新建虚拟机（与 Android 一致）
    this.machineEnabled = true;
    this.addDeviceEnabled = false;
    this.archLabel = 'x86_64 (amd64)';
    this.setMachineLoaded(false);
  }

  /** 切换分区折叠状态。 */
  toggleSection(section: Section): void {
    switch (section) {
      case Section.UI:
        this.uiCollapsed = !this.uiCollapsed;
        break;
      case Section.BOARD:
        this.boardCollapsed = !this.boardCollapsed;
        break;
      case Section.STORAGE:
        this.storageCollapsed = !this.storageCollapsed;
        break;
      case Section.BOOT:
        this.bootCollapsed = !this.bootCollapsed;
        break;
      case Section.GRAPHICS:
        this.graphicsCollapsed = !this.graphicsCollapsed;
        break;
      case Section.AUDIO:
        this.audioCollapsed = !this.audioCollapsed;
        break;
      case Section.NETWORK:
        this.networkCollapsed = !this.networkCollapsed;
        break;
      case Section.ADVANCED:
        this.advancedCollapsed = !this.advancedCollapsed;
        break;
      default:
        break;
    }
  }

  /**
   * 是否已加载虚拟机。未加载时所有配置项禁用，
   * 对应 Android LimboActivity#enableNonRemovableDeviceOptions。
   */
  setMachineLoaded(loaded: boolean): void {
    this.uiEnabled = loaded;
    this.keyboardEnabled = loaded;
    this.mouseEnabled = loaded;
    this.machineTypeEnabled = loaded;
    this.cpuEnabled = loaded;
    this.cpuNumEnabled = loaded;
    this.ramEnabled = loaded;
    this.accelEnabled = loaded;
    this.enableMTTCGEnabled = loaded && this.showMTTCGSwitch;
    // i8042 / NVRAM 只在 IA-64 架构下可配置
    this.disableI8042Enabled = false;
    this.enableNvramEnabled = false;
    this.nvramEnabled = false;
    this.bootEnabled = loaded;
    this.biosEnabled = loaded;
    this.kernelEnabled = loaded;
    this.initrdEnabled = loaded;
    this.appendEnabled = loaded;
    this.vgaEnabled = loaded;
    this.soundEnabled = loaded;
    this.netEnabled = loaded;
    this.nicEnabled = loaded && this.netSel > 0;
    this.dnsEnabled = loaded && this.netSel > 0;
    this.hostFwdEnabled = loaded && this.netSel > 0;
    this.disableACPIEnabled = loaded;
    this.disableHPETEnabled = loaded;
    this.disableTSCEnabled = loaded;
    this.extraParamsEnabled = loaded;
    this.usbControllerEnabled = loaded;
    this.addDeviceEnabled = loaded;
  }
}
