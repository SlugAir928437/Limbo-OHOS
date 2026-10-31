import {
  DEVICE_TYPES,
  DeviceTypeDef,
  IMAGE_NEW,
  IMAGE_NONE,
  IMAGE_OPEN,
  StorageDeviceUiState
} from '../model/LimboUiState';
import { FileUtils } from './FileUtils';
import { Machine } from './Machine';
import { MachineController } from './MachineController';
import { MachineFilePaths } from './MachineFilePaths';
import { MachineProperty } from './MachineProperty';
import { LimboSettingsManager } from './LimboSettingsManager';

const HARDDISK_PATH_PROPS: MachineProperty[] = [
  MachineProperty.HDA, MachineProperty.HDB, MachineProperty.HDC, MachineProperty.HDD
];
const HARDDISK_IF_PROPS: MachineProperty[] = [
  MachineProperty.HDA_INTERFACE, MachineProperty.HDB_INTERFACE,
  MachineProperty.HDC_INTERFACE, MachineProperty.HDD_INTERFACE
];
const HARDDISK_FORMAT_PROPS: MachineProperty[] = [
  MachineProperty.HDA_FORMAT, MachineProperty.HDB_FORMAT,
  MachineProperty.HDC_FORMAT, MachineProperty.HDD_FORMAT
];
const HARDDISK_CACHE_PROPS: MachineProperty[] = [
  MachineProperty.HDA_CACHE, MachineProperty.HDB_CACHE,
  MachineProperty.HDC_CACHE, MachineProperty.HDD_CACHE
];
const HARDDISK_FILE_TYPES: string[] = ['HDA', 'HDB', 'HDC', 'HDD'];
const IF_VALUES: string[] = ['', 'ide', 'scsi', 'virtio', 'sata', 'nvme'];
const FORMAT_VALUES: string[] = ['', 'raw', 'qcow2', 'qcow', 'vmdk', 'vhdx', 'vdi', 'vpc', 'parallels'];

/**
 * 存储设备 <-> Machine 字段的桥接层。
 * 负责把 Machine 里的 HDA..HDD / CDROM / FDA / FDB / SD / SHARED_FOLDER 字段
 * 转换成编辑页使用的 StorageDeviceUiState，以及把编辑结果写回 Machine 与数据库。
 */
export class StorageDevices {
  static rebuild(machine: Machine | null): StorageDeviceUiState[] {
    const devices: StorageDeviceUiState[] = [];
    if (machine === null) {
      return devices;
    }
    let tag: number = 0;
    const paths: Array<string | null> = [machine.hdaPath, machine.hdbPath, machine.hdcPath, machine.hddPath];
    const interfaces: string[] = [machine.hdaInterface, machine.hdbInterface, machine.hdcInterface, machine.hddInterface];
    const formats: Array<string | null> = [machine.hdaFormat, machine.hdbFormat, machine.hdcFormat, machine.hddFormat];
    const caches: Array<string | null> = [machine.hdaCache, machine.hdbCache, machine.hdcCache, machine.hddCache];
    for (let slot = 0; slot < 4; slot++) {
      if (FileUtils.isUsablePath(paths[slot])) {
        devices.push(StorageDevices.createDevice('HARD_DISK', slot, paths[slot],
          interfaces[slot], formats[slot], caches[slot], tag));
        tag++;
      }
    }
    if (FileUtils.isUsablePath(machine.cdImagePath)) {
      devices.push(StorageDevices.createDevice('CDROM', -1, machine.cdImagePath,
        machine.cdInterface, machine.cdFormat, null, tag));
      tag++;
    }
    if (FileUtils.isUsablePath(machine.fdaImagePath)) {
      devices.push(StorageDevices.createDevice('FDA', -1, machine.fdaImagePath, '', null, null, tag));
      tag++;
    }
    if (FileUtils.isUsablePath(machine.fdbImagePath)) {
      devices.push(StorageDevices.createDevice('FDB', -1, machine.fdbImagePath, '', null, null, tag));
      tag++;
    }
    if (FileUtils.isUsablePath(machine.sdImagePath)) {
      devices.push(StorageDevices.createDevice('SD', -1, machine.sdImagePath, '', null, null, tag));
      tag++;
    }
    if (FileUtils.isUsablePath(machine.sharedFolderPath)) {
      devices.push(StorageDevices.createDevice('SHARED_DIR', -1, machine.sharedFolderPath, '', null, null, tag));
    }
    return devices;
  }

  private static createDevice(typeKey: string, slot: number, path: string | null,
                              ifValue: string, format: string | null, cache: string | null,
                              tag: number): StorageDeviceUiState {
    const device: StorageDeviceUiState = new StorageDeviceUiState();
    device.tag = tag;
    device.applyType(StorageDevices.typeIndex(typeKey));
    device.originalTypeKey = typeKey;
    device.hardDiskSlot = slot;
    if (path !== null) {
      const options: string[] = device.imageOptions.slice();
      options.push(path);
      device.imageOptions = options;
      device.imageSel = options.length - 1;
    }
    device.ifSel = StorageDevices.indexOfValue(IF_VALUES, ifValue);
    const formatValue: string = format === null ? '' : format;
    device.formatSel = StorageDevices.indexOfValue(FORMAT_VALUES, formatValue);
    device.cacheValue = cache === null ? '' : cache;
    return device;
  }

  /** 编辑页点“确定”：写入 Machine 字段并落库；返回是否成功。 */
  static async apply(device: StorageDeviceUiState): Promise<boolean> {
    const controller: MachineController = MachineController.getInstance();
    const machine: Machine | null = controller.getMachine();
    if (machine === null) {
      return false;
    }

    // 编辑页切换了设备类型：先清理旧类型对应的字段
    if (device.originalTypeKey.length > 0 && device.originalTypeKey !== device.typeKey) {
      await StorageDevices.clearDevice(device.originalTypeKey, device.hardDiskSlot);
    }

    const option: string = device.selectedImageOption();
    let image: string = '';
    if (option === IMAGE_NEW) {
      const name: string = device.newImageName.trim();
      if (name.length === 0) {
        return false;
      }
      image = await FileUtils.createDiskImage(LimboSettingsManager.getImagesDir(), name,
        StorageDevices.sizeBytes(device));
    } else if (option !== IMAGE_NONE && option !== IMAGE_OPEN) {
      image = option;
    }

    const iface: string = StorageDevices.valueAt(IF_VALUES, device.ifSel);
    const format: string = StorageDevices.valueAt(FORMAT_VALUES, device.formatSel);
    const cache: string = device.cacheValue.trim();

    if (device.typeKey === 'HARD_DISK') {
      const slot: number = device.hardDiskSlot >= 0 ? device.hardDiskSlot
        : StorageDevices.firstFreeHardDiskSlot(machine);
      await controller.updateFieldNow(HARDDISK_PATH_PROPS[slot], image);
      await controller.updateFieldNow(HARDDISK_IF_PROPS[slot], iface);
      await controller.updateFieldNow(HARDDISK_FORMAT_PROPS[slot], format);
      await controller.updateFieldNow(HARDDISK_CACHE_PROPS[slot], cache);
      MachineFilePaths.insertRecentFilePath(HARDDISK_FILE_TYPES[slot], image);
      return true;
    }
    if (device.typeKey === 'CDROM') {
      await controller.updateFieldNow(MachineProperty.CDROM, image);
      await controller.updateFieldNow(MachineProperty.CDROM_INTERFACE, iface);
      await controller.updateFieldNow(MachineProperty.CDROM_FORMAT, format);
      MachineFilePaths.insertRecentFilePath('CDROM', image);
      return true;
    }
    if (device.typeKey === 'FDA') {
      await controller.updateFieldNow(MachineProperty.FDA, image);
      MachineFilePaths.insertRecentFilePath('FDA', image);
      return true;
    }
    if (device.typeKey === 'FDB') {
      await controller.updateFieldNow(MachineProperty.FDB, image);
      MachineFilePaths.insertRecentFilePath('FDB', image);
      return true;
    }
    if (device.typeKey === 'SD') {
      await controller.updateFieldNow(MachineProperty.SD, image);
      MachineFilePaths.insertRecentFilePath('SD', image);
      return true;
    }
    if (device.typeKey === 'SHARED_DIR') {
      await controller.updateFieldNow(MachineProperty.SHARED_FOLDER, image);
      MachineFilePaths.insertRecentFilePath('SHARED_DIR', image);
      return true;
    }
    return false;
  }

  /** 编辑页点“移除设备”：清空对应字段，硬盘槽位会自动向前压缩。 */
  static async remove(device: StorageDeviceUiState): Promise<void> {
    await StorageDevices.clearDevice(device.typeKey, device.hardDiskSlot);
  }

  private static async clearDevice(typeKey: string, slot: number): Promise<void> {
    const controller: MachineController = MachineController.getInstance();
    const machine: Machine | null = controller.getMachine();
    if (machine === null) {
      return;
    }
    if (typeKey === 'HARD_DISK') {
      const paths: Array<string | null> = [machine.hdaPath, machine.hdbPath, machine.hdcPath, machine.hddPath];
      const removedSlot: number = slot >= 0 && slot < 4 ? slot : 0;
      const remaining: string[] = [];
      for (let i = 0; i < 4; i++) {
        if (i !== removedSlot && FileUtils.isUsablePath(paths[i]) && paths[i] !== null) {
          remaining.push(paths[i] as string);
        }
      }
      for (let i = 0; i < 4; i++) {
        const value: string = i < remaining.length ? remaining[i] : '';
        await controller.updateFieldNow(HARDDISK_PATH_PROPS[i], value);
        await controller.updateFieldNow(HARDDISK_IF_PROPS[i], 'ide');
        await controller.updateFieldNow(HARDDISK_FORMAT_PROPS[i], '');
        await controller.updateFieldNow(HARDDISK_CACHE_PROPS[i], '');
      }
      return;
    }
    if (typeKey === 'CDROM') {
      await controller.updateFieldNow(MachineProperty.CDROM, '');
      await controller.updateFieldNow(MachineProperty.CDROM_INTERFACE, 'ide');
      await controller.updateFieldNow(MachineProperty.CDROM_FORMAT, '');
      return;
    }
    if (typeKey === 'FDA') {
      await controller.updateFieldNow(MachineProperty.FDA, '');
      return;
    }
    if (typeKey === 'FDB') {
      await controller.updateFieldNow(MachineProperty.FDB, '');
      return;
    }
    if (typeKey === 'SD') {
      await controller.updateFieldNow(MachineProperty.SD, '');
      return;
    }
    if (typeKey === 'SHARED_DIR') {
      await controller.updateFieldNow(MachineProperty.SHARED_FOLDER, '');
    }
  }

  /** 最近使用的镜像，按设备类型返回（用于编辑页镜像下拉）。 */
  static recentPathsFor(device: StorageDeviceUiState): string[] {
    if (device.typeKey === 'HARD_DISK') {
      return MachineFilePaths.getRecentFilePaths('HDA');
    }
    return MachineFilePaths.getRecentFilePaths(device.typeKey);
  }

  private static firstFreeHardDiskSlot(machine: Machine): number {
    const paths: Array<string | null> = [machine.hdaPath, machine.hdbPath, machine.hdcPath, machine.hddPath];
    for (let i = 0; i < 4; i++) {
      if (!FileUtils.isUsablePath(paths[i])) {
        return i;
      }
    }
    return 0;
  }

  private static typeIndex(typeKey: string): number {
    for (let i = 0; i < DEVICE_TYPES.length; i++) {
      const def: DeviceTypeDef = DEVICE_TYPES[i];
      if (def.key === typeKey) {
        return i;
      }
    }
    return 0;
  }

  private static indexOfValue(values: string[], value: string): number {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) {
        return i;
      }
    }
    return 0;
  }

  private static valueAt(values: string[], index: number): string {
    return index >= 0 && index < values.length ? values[index] : '';
  }

  private static sizeBytes(device: StorageDeviceUiState): number {
    let value: number = 1;
    const parsed: number = parseInt(device.sizeValue, 10);
    if (!Number.isNaN(parsed) && parsed > 0) {
      value = parsed;
    }
    const unit: string = StorageDevices.valueAt(device.sizeUnitOptions, device.sizeUnitSel);
    if (unit === 'MB') {
      return value * 1024 * 1024;
    }
    if (unit === 'TB') {
      return value * 1024 * 1024 * 1024 * 1024;
    }
    return value * 1024 * 1024 * 1024;
  }
}
