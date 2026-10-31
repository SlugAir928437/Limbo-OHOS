import { Machine } from './Machine';

/**
 * QEMU 命令行构建（迁移自 Android VMExecutor#addDrives / addUIOptions 等）。
 *
 * HarmonyOS 版固定为 TCG：
 *  - 不生成 -enable-kvm / -accel kvm / gunyah / gzvm；
 *  - 不生成 GTK / AGL 显示参数，SDL 是唯一的本地显示后端；
 *  - 不包含 IA-64 相关参数（本版本只构建 qemu-system-x86_64）。
 */
export class QemuArgs {
  static readonly QMP_PORT: number = 4444;

  static build(machine: Machine, dns: string): string[] {
    const args: string[] = ['qemu-system-x86_64'];

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

    QemuArgs.addHardDisk(args, 'hd0', machine.hdaPath, machine.hdaInterface,
      machine.hdaFormat, machine.hdaCache, 0);
    QemuArgs.addHardDisk(args, 'hd1', machine.hdbPath, machine.hdbInterface,
      machine.hdbFormat, machine.hdbCache, 1);
    QemuArgs.addHardDisk(args, 'hd2', machine.hdcPath, machine.hdcInterface,
      machine.hdcFormat, machine.hdcCache, 2);
    QemuArgs.addHardDisk(args, 'hd3', machine.hddPath, machine.hddInterface,
      machine.hddFormat, machine.hddCache, 3);

    QemuArgs.addDrive(args, machine.cdImagePath, machine.cdInterface, 2,
      machine.cdFormat, null, true);
    QemuArgs.addDrive(args, machine.fdaImagePath, 'floppy', 0, null, null, false);
    QemuArgs.addDrive(args, machine.fdbImagePath, 'floppy', 1, null, null, false);
    QemuArgs.addDrive(args, machine.sdImagePath, 'sd', 0, null, null, false);

    if (QemuArgs.isUsable(machine.sharedFolderPath)) {
      args.push('-virtfs', 'local,path=' + machine.sharedFolderPath
        + ',mount_tag=host0,security_model=none,id=host0');
    }

    QemuArgs.addBootOptions(args, machine);
    QemuArgs.addDisplayOptions(args, machine);
    QemuArgs.addAudioOptions(args, machine);
    QemuArgs.addNetworkOptions(args, machine, dns);
    QemuArgs.addUsbOptions(args, machine);
    QemuArgs.addExtraParams(args, machine);

    // 暂停/恢复/快照都通过 QMP；stdin 监视器在 HarmonyOS 上没有意义
    args.push('-qmp', 'tcp:127.0.0.1:' + QemuArgs.QMP_PORT + ',server=on,wait=off');
    args.push('-monitor', 'none');
    return args;
  }

  private static isUsable(path: string | null): boolean {
    return path !== null && path.length > 0 && path !== 'None';
  }

  private static addDrive(args: string[], path: string | null, iface: string, index: number,
                          format: string | null, cache: string | null, cdrom: boolean): void {
    if (!QemuArgs.isUsable(path)) {
      return;
    }
    const ifValue: string = iface.length > 0 ? iface : 'ide';
    let drive: string = 'file=' + path + ',if=' + ifValue + ',index=' + index;
    if (cdrom) {
      drive += ',media=cdrom,readonly=on';
    }
    if (format !== null && format.length > 0) {
      drive += ',format=' + format;
    }
    if (cache !== null && cache.length > 0) {
      drive += ',cache=' + cache;
    }
    args.push('-drive', drive);
  }

  /** NVMe 需要 -device 才能挂上，其余接口直接走 -drive if=。 */
  private static addHardDisk(args: string[], id: string, path: string | null, iface: string,
                             format: string | null, cache: string | null, index: number): void {
    if (!QemuArgs.isUsable(path)) {
      return;
    }
    if (iface === 'nvme') {
      let drive: string = 'file=' + path + ',if=none,id=' + id;
      if (format !== null && format.length > 0) {
        drive += ',format=' + format;
      }
      if (cache !== null && cache.length > 0) {
        drive += ',cache=' + cache;
      }
      args.push('-drive', drive);
      args.push('-device', 'nvme,drive=' + id + ',serial=limbo' + index);
      return;
    }
    QemuArgs.addDrive(args, path, iface, index, format, cache, false);
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
      args.push('-vnc', '127.0.0.1:1');
    } else if (ui === 'SPICE') {
      args.push('-spice', 'port=5930,disable-ticketing=on');
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
