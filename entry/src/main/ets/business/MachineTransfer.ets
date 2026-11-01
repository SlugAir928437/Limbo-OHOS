import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { LimboConfig } from './LimboConfig';
import { Machine } from './Machine';
import { MachineDatabase } from './MachineDatabase';

/**
 * 虚拟机 CSV 导入导出（迁移自 Android MachineOpenHelper#exportMachines /
 * MachineImporter）。列顺序与 Android 导出的 CSV 完全一致，便于两边互导。
 */
const EXPORT_COLUMNS: string[] = [
  'MACHINE_NAME', 'CPU', 'MEMORY', 'CDROM', 'FDA', 'FDB', 'HDA', 'HDB', 'HDC', 'HDD',
  'NETCONFIG', 'NICCONFIG', 'VGA', 'SOUNDCARD', 'HDCONFIG', 'DISABLE_ACPI', 'DISABLE_HPET',
  'ENABLE_USBMOUSE', 'SNAPSHOT_NAME', 'BOOT_CONFIG', 'KERNEL', 'INITRD', 'APPEND', 'CPUNUM',
  'MACHINETYPE', 'DISABLE_FD_BOOT_CHK', 'ARCH', 'PAUSED', 'SD', 'SHARED_FOLDER',
  'SHARED_FOLDER_MODE', 'EXTRA_PARAMS', 'HOSTFWD', 'GUESTFWD', 'UI', 'DISABLE_TSC', 'MOUSE',
  'KEYBOARD', 'ENABLE_MTTCG', 'ENABLE_KVM', 'HDA_INTERFACE', 'HDB_INTERFACE', 'HDC_INTERFACE',
  'HDD_INTERFACE', 'CDROM_INTERFACE', 'BIOS', 'ACCEL_MODE', 'USB_CONTROLLER'
];

export class MachineTransfer {
  /** 弹出系统保存选择器，把当前架构的全部虚拟机写成 CSV；返回保存路径（失败为空）。 */
  static async exportToFile(context: common.Context, fileName: string): Promise<string> {
    try {
      const csv: string = await MachineTransfer.buildCsv();
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris: string[] = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        return '';
      }
      const file: fs.File = fs.openSync(uris[0],
        fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, csv);
      } finally {
        fs.closeSync(file);
      }
      return uris[0];
    } catch (err) {
      console.error(`export machines failed: ${JSON.stringify(err)}`);
      return '';
    }
  }

  /** 弹出系统文件选择器读取 CSV，导入后返回虚拟机名称列表。 */
  static async importFromPicker(context: common.Context): Promise<string[]> {
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['.csv'];
      options.maxSelectNumber = 1;
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) {
        return [];
      }
      const text: string = fs.readTextSync(uris[0]);
      return await MachineTransfer.importCsv(text);
    } catch (err) {
      console.error(`import machines failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  private static async buildCsv(): Promise<string> {
    const machines: Machine[] = await MachineDatabase.getInstance().getAllMachines();
    const lines: string[] = [];
    lines.push(MachineTransfer.joinRow(EXPORT_COLUMNS));
    for (let i = 0; i < machines.length; i++) {
      lines.push(MachineTransfer.joinRow(MachineTransfer.rowOf(machines[i])));
    }
    return lines.join('\n') + (lines.length > 0 ? '\n' : '');
  }

  private static rowOf(machine: Machine): Array<string | null> {
    return [
      machine.name,
      machine.cpu,
      machine.memory.toString(),
      machine.cdImagePath,
      machine.fdaImagePath,
      machine.fdbImagePath,
      machine.hdaPath,
      machine.hdbPath,
      machine.hdcPath,
      machine.hddPath,
      machine.network,
      machine.networkCard,
      machine.vga,
      machine.soundCard,
      null,
      machine.disableACPI.toString(),
      machine.disableHPET.toString(),
      '0',
      null,
      machine.bootDevice,
      machine.kernel,
      machine.initRd,
      machine.append,
      machine.cpuNum.toString(),
      machine.machineType,
      machine.disableFdBootChk.toString(),
      machine.arch,
      machine.paused.toString(),
      machine.sdImagePath,
      machine.sharedFolderPath,
      machine.sharedFolderMode.toString(),
      machine.extraParams,
      machine.hostFwd,
      machine.guestFwd,
      machine.getUI(),
      machine.disableTSC.toString(),
      machine.mouse,
      machine.keyboard,
      machine.enableMTTCG.toString(),
      machine.enableKVM.toString(),
      machine.hdaInterface,
      machine.hdbInterface,
      machine.hdcInterface,
      machine.hddInterface,
      machine.cdInterface,
      machine.bios,
      machine.accelMode,
      machine.usbController
    ];
  }

  private static joinRow(cells: Array<string | null>): string {
    const parts: string[] = [];
    for (let i = 0; i < cells.length; i++) {
      const value: string | null = cells[i];
      parts.push('"' + (value === null ? 'null' : value) + '"');
    }
    return parts.join(',');
  }

  private static parseLine(line: string): string[] {
    return line.split(/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/);
  }

  private static async importCsv(text: string): Promise<string[]> {
    const names: string[] = [];
    const lines: string[] = text.split(/\r?\n/);
    if (lines.length < 2) {
      return names;
    }
    const rawHeaders: string[] = MachineTransfer.parseLine(lines[0]);
    const headers: string[] = [];
    for (let i = 0; i < rawHeaders.length; i++) {
      headers.push(rawHeaders[i].replace(/"/g, '').trim());
    }
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].trim().length === 0) {
        continue;
      }
      const cells: string[] = MachineTransfer.parseLine(lines[i]);
      const machine: Machine = MachineTransfer.toMachine(headers, cells);
      if (machine.name.length === 0) {
        continue;
      }
      // 导入的虚拟机始终归属当前架构；重名时先删后插（与 Android 一致）
      machine.arch = LimboConfig.ARCH;
      await MachineDatabase.getInstance().deleteMachine(machine.name);
      await MachineDatabase.getInstance().insertMachine(machine);
      names.push(machine.name);
    }
    return names;
  }

  private static toMachine(headers: string[], cells: string[]): Machine {
    const name: string | null = MachineTransfer.cell(headers, cells, 'MACHINE_NAME');
    const machine: Machine = new Machine(name === null ? '' : name, false);

    const cpu: string | null = MachineTransfer.cell(headers, cells, 'CPU');
    if (cpu !== null) {
      machine.cpu = cpu;
    }
    const memory: string | null = MachineTransfer.cell(headers, cells, 'MEMORY');
    if (memory !== null) {
      machine.memory = MachineTransfer.toInt(memory, machine.memory);
    }
    const cpuNum: string | null = MachineTransfer.cell(headers, cells, 'CPUNUM');
    if (cpuNum !== null) {
      machine.cpuNum = MachineTransfer.toInt(cpuNum, machine.cpuNum);
    }
    const ui: string | null = MachineTransfer.cell(headers, cells, 'UI');
    if (ui !== null) {
      machine.ui = ui;
    }
    const mouse: string | null = MachineTransfer.cell(headers, cells, 'MOUSE');
    if (mouse !== null) {
      machine.mouse = mouse;
    }
    const keyboard: string | null = MachineTransfer.cell(headers, cells, 'KEYBOARD');
    if (keyboard !== null) {
      machine.keyboard = keyboard;
    }
    const machineType: string | null = MachineTransfer.cell(headers, cells, 'MACHINETYPE');
    if (machineType !== null) {
      machine.machineType = machineType;
    }
    const accelMode: string | null = MachineTransfer.cell(headers, cells, 'ACCEL_MODE');
    if (accelMode !== null) {
      machine.accelMode = accelMode;
    }
    const mttcg: string | null = MachineTransfer.cell(headers, cells, 'ENABLE_MTTCG');
    if (mttcg !== null) {
      machine.enableMTTCG = MachineTransfer.toInt(mttcg, 0);
    }
    const kvm: string | null = MachineTransfer.cell(headers, cells, 'ENABLE_KVM');
    if (kvm !== null) {
      machine.enableKVM = MachineTransfer.toInt(kvm, 0);
    }
    const acpi: string | null = MachineTransfer.cell(headers, cells, 'DISABLE_ACPI');
    if (acpi !== null) {
      machine.disableACPI = MachineTransfer.toInt(acpi, 0);
    }
    const hpet: string | null = MachineTransfer.cell(headers, cells, 'DISABLE_HPET');
    if (hpet !== null) {
      machine.disableHPET = MachineTransfer.toInt(hpet, 0);
    }
    const tsc: string | null = MachineTransfer.cell(headers, cells, 'DISABLE_TSC');
    if (tsc !== null) {
      machine.disableTSC = MachineTransfer.toInt(tsc, 0);
    }
    const fdChk: string | null = MachineTransfer.cell(headers, cells, 'DISABLE_FD_BOOT_CHK');
    if (fdChk !== null) {
      machine.disableFdBootChk = MachineTransfer.toInt(fdChk, 0);
    }
    const paused: string | null = MachineTransfer.cell(headers, cells, 'PAUSED');
    if (paused !== null) {
      machine.paused = MachineTransfer.toInt(paused, 0);
    }

    machine.hdaPath = MachineTransfer.cell(headers, cells, 'HDA');
    machine.hdbPath = MachineTransfer.cell(headers, cells, 'HDB');
    machine.hdcPath = MachineTransfer.cell(headers, cells, 'HDC');
    machine.hddPath = MachineTransfer.cell(headers, cells, 'HDD');
    machine.hdaInterface = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'HDA_INTERFACE'));
    machine.hdbInterface = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'HDB_INTERFACE'));
    machine.hdcInterface = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'HDC_INTERFACE'));
    machine.hddInterface = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'HDD_INTERFACE'));
    machine.cdImagePath = MachineTransfer.cell(headers, cells, 'CDROM');
    machine.cdInterface = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'CDROM_INTERFACE'));
    machine.fdaImagePath = MachineTransfer.cell(headers, cells, 'FDA');
    machine.fdbImagePath = MachineTransfer.cell(headers, cells, 'FDB');
    machine.sdImagePath = MachineTransfer.cell(headers, cells, 'SD');
    machine.sharedFolderPath = MachineTransfer.cell(headers, cells, 'SHARED_FOLDER');
    const sharedMode: string | null = MachineTransfer.cell(headers, cells, 'SHARED_FOLDER_MODE');
    if (sharedMode !== null) {
      machine.sharedFolderMode = MachineTransfer.toInt(sharedMode, machine.sharedFolderMode);
    }

    const boot: string | null = MachineTransfer.cell(headers, cells, 'BOOT_CONFIG');
    if (boot !== null) {
      machine.bootDevice = boot;
    }
    machine.kernel = MachineTransfer.cell(headers, cells, 'KERNEL');
    machine.initRd = MachineTransfer.cell(headers, cells, 'INITRD');
    machine.append = MachineTransfer.cell(headers, cells, 'APPEND');
    machine.bios = MachineTransfer.cell(headers, cells, 'BIOS');

    machine.network = MachineTransfer.cell(headers, cells, 'NETCONFIG');
    machine.networkCard = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'NICCONFIG'));
    machine.hostFwd = MachineTransfer.cell(headers, cells, 'HOSTFWD');
    machine.guestFwd = MachineTransfer.cell(headers, cells, 'GUESTFWD');
    machine.vga = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'VGA'));
    machine.soundCard = MachineTransfer.cell(headers, cells, 'SOUNDCARD');
    machine.extraParams = MachineTransfer.cell(headers, cells, 'EXTRA_PARAMS');
    machine.usbController = MachineTransfer.ifValue(MachineTransfer.cell(headers, cells, 'USB_CONTROLLER'));
    return machine;
  }

  private static cell(headers: string[], cells: string[], name: string): string | null {
    for (let i = 0; i < headers.length; i++) {
      if (headers[i] === name) {
        if (i >= cells.length) {
          return null;
        }
        const raw: string = cells[i];
        if (raw === '"null"' || raw === 'null') {
          return null;
        }
        return raw.replace(/"/g, '');
      }
    }
    return null;
  }

  private static ifValue(value: string | null): string {
    return value === null || value.length === 0 ? 'ide' : value;
  }

  private static toInt(value: string, defaultValue: number): number {
    const parsed: number = parseInt(value, 10);
    return Number.isNaN(parsed) ? defaultValue : parsed;
  }
}
