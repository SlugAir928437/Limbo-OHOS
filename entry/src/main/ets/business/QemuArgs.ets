import { ArchManager } from './ArchManager';
import { FileUtils } from './FileUtils';
import { LimboConfig } from './LimboConfig';
import { LimboSettingsManager } from './LimboSettingsManager';
import { Machine } from './Machine';

/**
 * QEMU 命令行构建（迁移自 Android VMExecutor#addDrives / addUIOptions 等）。
 *
 * HarmonyOS 版固定为 TCG：
 *  - 不生成 -enable-kvm / -accel kvm / gunyah / gzvm；
 *  - 不生成 GTK / AGL 显示参数，SDL 是唯一的本地显示后端；
 *  - 不包含 IA-64 相关参数（本版本只构建 x86_64 / aarch64 引擎）。
 */
export class QemuArgs {
  static readonly QMP_PORT: number = 4444;

  static build(machine: Machine, dns: string): string[] {
    const args: string[] = [ArchManager.qemuBinary()];

    // 固件（BIOS / VGA ROM / option ROM / keymaps）随 HAP 打包，
    // 运行时由 QemuFirmware 解到私有目录，QEMU 用 -L 指向该目录。
    const dataDir: string = LimboSettingsManager.getQemuDataDir();
    if (dataDir.length > 0 && FileUtils.exists(dataDir)) {
      args.push('-L', dataDir);
    }

    args.push('-name', machine.name);
    args.push('-accel', machine.enableMTTCG === 1 ? 'tcg,thread=multi' : 'tcg,thread=single');
    args.push('-m', machine.memory.toString());
    args.push('-smp', machine.cpuNum.toString());
    if (machine.machineType.length > 0 && machine.machineType !== 'Default') {
      args.push('-machine', machine.machineType);
    }
    if (machine.cpu.length > 0 && machine.cpu !== 'Default' && machine.cpu !== 'host') {
      args.push('-cpu', machine.cpu);
    }

    // 设置页配置的默认磁盘缓存（default 表示不追加 cache 参数）
    const defaultCache: string = LimboSettingsManager.getDiskCache();

    // aarch64 的 virt 机器没有 IDE/PS2；光驱使用 virtio-scsi
    if (ArchManager.isArm64()) {
      args.push('-device', 'virtio-scsi-pci,id=scsi0');
    }

    QemuArgs.addHardDisk(args, 'hd0', machine.hdaPath, machine.hdaInterface,
      machine.hdaFormat, machine.hdaCache, 0, defaultCache);
    QemuArgs.addHardDisk(args, 'hd1', machine.hdbPath, machine.hdbInterface,
      machine.hdbFormat, machine.hdbCache, 1, defaultCache);
    QemuArgs.addHardDisk(args, 'hd2', machine.hdcPath, machine.hdcInterface,
      machine.hdcFormat, machine.hdcCache, 2, defaultCache);
    QemuArgs.addHardDisk(args, 'hd3', machine.hddPath, machine.hddInterface,
      machine.hddFormat, machine.hddCache, 3, defaultCache);

    QemuArgs.addDrive(args, machine.cdImagePath, machine.cdInterface, 2,
      machine.cdFormat, defaultCache, true);
    // aarch64 virt 没有软驱/SD 控制器
    if (!ArchManager.isArm64()) {
      QemuArgs.addDrive(args, machine.fdaImagePath, 'floppy', 0, null, null, false, defaultCache);
      QemuArgs.addDrive(args, machine.fdbImagePath, 'floppy', 1, null, null, false, defaultCache);
      QemuArgs.addDrive(args, machine.sdImagePath, 'sd', 0, null, null, false, defaultCache);
    }

    if (QemuArgs.isUsable(machine.sharedFolderPath)) {
      args.push('-virtfs', 'local,path=' + machine.sharedFolderPath
        + ',mount_tag=host0,security_model=none,id=host0');
    }

    QemuArgs.addBootOptions(args, machine);
    QemuArgs.addDisplayOptions(args, machine);
    QemuArgs.addAudioOptions(args, machine);
    QemuArgs.addNetworkOptions(args, machine, dns);
    QemuArgs.addUsbOptions(args, machine);
    QemuArgs.addPeripheralOptions(args, machine);
    QemuArgs.addExtraParams(args, machine);

    // 暂停/恢复/快照都通过 QMP；stdin 监视器在 HarmonyOS 上没有意义
    if (LimboSettingsManager.getEnableQmp()) {
      const qmpAddress: string = LimboSettingsManager.getEnableExternalQmp() ? '0.0.0.0' : '127.0.0.1';
      args.push('-qmp', 'tcp:' + qmpAddress + ':' + QemuArgs.QMP_PORT + ',server=on,wait=off');
    }
    args.push('-monitor', 'none');
    return args;
  }

  private static isUsable(path: string | null): boolean {
    return path !== null && path.length > 0 && path !== 'None';
  }

  private static addDrive(args: string[], path: string | null, iface: string, index: number,
                          format: string | null, cache: string | null, cdrom: boolean,
                          fallbackCache: string): void {
    if (!QemuArgs.isUsable(path)) {
      return;
    }
    const ifValue: string = QemuArgs.effectiveInterface(iface, cdrom);
    let drive: string = 'file=' + path + ',if=' + ifValue + ',index=' + index;
    if (cdrom) {
      drive += ',media=cdrom,readonly=on';
    }
    if (format !== null && format.length > 0) {
      drive += ',format=' + format;
    }
    const effectiveCache: string = QemuArgs.effectiveCache(cache, fallbackCache);
    if (effectiveCache.length > 0) {
      drive += ',cache=' + effectiveCache;
    }
    args.push('-drive', drive);
  }

  /** NVMe 需要 -device 才能挂上，其余接口直接走 -drive if=。 */
  private static addHardDisk(args: string[], id: string, path: string | null, iface: string,
                             format: string | null, cache: string | null, index: number,
                             fallbackCache: string): void {
    if (!QemuArgs.isUsable(path)) {
      return;
    }
    const ifValue: string = QemuArgs.effectiveInterface(iface, false);
    if (ifValue === 'nvme') {
      let drive: string = 'file=' + path + ',if=none,id=' + id;
      if (format !== null && format.length > 0) {
        drive += ',format=' + format;
      }
      const effectiveCache: string = QemuArgs.effectiveCache(cache, fallbackCache);
      if (effectiveCache.length > 0) {
        drive += ',cache=' + effectiveCache;
      }
      args.push('-drive', drive);
      args.push('-device', 'nvme,drive=' + id + ',serial=limbo' + index);
      return;
    }
    QemuArgs.addDrive(args, path, ifValue, index, format, cache, false, fallbackCache);
  }

  /** 空接口按架构取默认；ARM 上 IDE/SATA 不可用，自动换成 virtio / scsi。 */
  private static effectiveInterface(iface: string, cdrom: boolean): string {
    if (ArchManager.isArm64() && (iface === 'ide' || iface === 'sata')) {
      return cdrom ? 'scsi' : 'virtio';
    }
    if (iface.length > 0) {
      return iface;
    }
    return ArchManager.defaultDriveInterface(cdrom);
  }

  /** 设备未单独设置缓存时使用设置页的默认值；default 表示沿用 QEMU 默认。 */
  private static effectiveCache(cache: string | null, fallbackCache: string): string {
    if (cache !== null && cache.length > 0) {
      return cache;
    }
    return fallbackCache.length > 0 && fallbackCache !== 'default' ? fallbackCache : '';
  }

  private static addBootOptions(args: string[], machine: Machine): void {
    if (QemuArgs.isUsable(machine.bios)) {
      args.push('-bios', machine.bios as string);
    }
    if (QemuArgs.isUsable(machine.kernel)) {
      args.push('-kernel', machine.kernel as string);
    }
    if (QemuArgs.isUsable(machine.initRd)) {
      args.push('-initrd', machine.initRd as string);
    }
    if (QemuArgs.isUsable(machine.append)) {
      args.push('-append', machine.append as string);
    }
    let order: string = '';
    if (machine.bootDevice === 'CDROM') {
      order = 'd';
    } else if (machine.bootDevice === 'Hard Disk') {
      order = 'c';
    } else if (machine.bootDevice === 'Floppy') {
      order = 'a';
    }
    if (order.length > 0) {
      args.push('-boot', 'order=' + order);
    }
  }

  private static addDisplayOptions(args: string[], machine: Machine): void {
    const ui: string = machine.getUI();
    if (ui === 'VNC') {
      const vncAddress: string = LimboSettingsManager.getEnableExternalVNC() ? '0.0.0.0' : '127.0.0.1';
      args.push('-vnc', vncAddress + ':' + LimboConfig.DEFAULT_VNC_PORT);
    } else if (ui === 'SPICE') {
      const spiceAddress: string = LimboSettingsManager.getEnableExternalSPICE() ? 'addr=0.0.0.0,' : '';
      args.push('-spice', spiceAddress + 'port=' + LimboConfig.DEFAULT_SPICE_PORT + ',disable-ticketing=on');
    } else {
      // GTK / AGL 在 HarmonyOS 版本中不提供，统一落到 SDL
      args.push('-display', 'sdl');
    }

    const vga: string = machine.vga;
    if (vga === 'nographic') {
      args.push('-nographic');
    } else if (vga.startsWith('virtio-gpu')) {
      args.push('-device', vga);
    } else if (vga.length > 0) {
      args.push('-vga', vga);
    }
  }

  private static addAudioOptions(args: string[], machine: Machine): void {
    const sound: string | null = machine.soundCard;
    if (sound === null || sound.length === 0 || sound === 'None') {
      return;
    }
    if (sound === 'hda') {
      args.push('-device', 'intel-hda');
      args.push('-device', 'hda-duplex');
      return;
    }
    args.push('-device', sound);
  }

  private static addNetworkOptions(args: string[], machine: Machine, dns: string): void {
    const network: string | null = machine.network;
    if (network === null || network.length === 0 || network === 'None') {
      return;
    }
    const tap: boolean = network === 'TAP';
    const nic: string = machine.networkCard;

    if (nic === 'Default') {
      let backend: string = 'user';
      if (!tap && dns.length > 0) {
        backend += ',dns=' + dns;
      }
      args.push('-nic', backend);
      return;
    }

    let netdev: string = tap ? 'tap,id=net0,ifname=tap0,script=no,downscript=no' : 'user,id=net0';
    if (!tap) {
      if (dns.length > 0) {
        netdev += ',dns=' + dns;
      }
      if (QemuArgs.isUsable(machine.hostFwd)) {
        netdev += ',hostfwd=' + (machine.hostFwd as string);
      }
    }
    args.push('-netdev', netdev);
    args.push('-device', nic + ',netdev=net0');
  }

  private static addUsbOptions(args: string[], machine: Machine): void {
    const usb: string = machine.usbController;
    if (usb.length > 0 && usb !== 'None') {
      args.push('-device', usb);
    }
  }

  /** 鼠标/键盘设备：x86 默认 PS/2；ARM virt 默认 USB 键鼠。 */
  private static addPeripheralOptions(args: string[], machine: Machine): void {
    const mouse: string = QemuArgs.mouseDevice(machine.mouse);
    const fallbackUsb: boolean = mouse.length === 0 && ArchManager.isArm64();
    if (ArchManager.isArm64() && (mouse.startsWith('usb-') || fallbackUsb)
      && (machine.usbController.length === 0 || machine.usbController === 'None')) {
      // ARM virt 默认没有 USB 控制器；USB 键鼠需要显式挂一个
      args.push('-device', 'qemu-xhci');
    }
    if (mouse.length > 0) {
      args.push('-device', mouse);
      if (mouse.startsWith('virtio-')) {
        args.push('-device', 'virtio-keyboard-pci');
      } else if (mouse.startsWith('usb-')) {
        args.push('-device', 'usb-kbd');
      }
    } else if (ArchManager.isArm64()) {
      args.push('-device', 'usb-kbd');
      args.push('-device', 'usb-mouse');
    }
    if (machine.keyboard.length > 0) {
      args.push('-k', machine.keyboard);
    }
  }

  private static mouseDevice(value: string): string {
    if (value.length === 0 || value === 'ps2') {
      return '';
    }
    if (value.startsWith('usb-tablet')) {
      return 'usb-tablet';
    }
    if (value === 'usb-mouse') {
      return 'usb-mouse';
    }
    if (value.startsWith('virtio-tablet-pci')) {
      return 'virtio-tablet-pci';
    }
    if (value.startsWith('virtio-multitouch-pci')) {
      return 'virtio-multitouch-pci';
    }
    return value;
  }

  private static addExtraParams(args: string[], machine: Machine): void {
    const extra: string | null = machine.extraParams;
    if (extra === null || extra.trim().length === 0) {
      return;
    }
    const parts: string[] = extra.trim().split(/\s+/);
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0) {
        args.push(parts[i]);
      }
    }
  }
}
