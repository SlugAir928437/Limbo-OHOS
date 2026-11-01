import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LimboConfig } from './LimboConfig';
import { Machine } from './Machine';
import { MachineProperty } from './MachineProperty';

/**
 * 虚拟机持久化层（迁移自 Android MachineOpenHelper）。
 * 使用 HarmonyOS RelationalStore，表结构与 Android 的 machines 表保持一致。
 */
export class MachineDatabase {
  private static readonly instance: MachineDatabase = new MachineDatabase();
  private store: relationalStore.RdbStore | null = null;
  private initPromise: Promise<void> | null = null;

  static getInstance(): MachineDatabase {
    return MachineDatabase.instance;
  }

  private static tableSql(): string {
    return 'CREATE TABLE IF NOT EXISTS ' + LimboConfig.MACHINE_TABLE + ' ('
      + MachineProperty.MACHINE_NAME + ' TEXT, '
      + MachineProperty.SNAPSHOT_NAME + ' TEXT, '
      + MachineProperty.CPU + ' TEXT, '
      + MachineProperty.ARCH + ' TEXT, '
      + MachineProperty.MEMORY + ' TEXT, '
      + MachineProperty.FDA + ' TEXT, '
      + MachineProperty.FDB + ' TEXT, '
      + MachineProperty.CDROM + ' TEXT, '
      + MachineProperty.HDA + ' TEXT, '
      + MachineProperty.HDB + ' TEXT, '
      + MachineProperty.HDC + ' TEXT, '
      + MachineProperty.HDD + ' TEXT, '
      + MachineProperty.BOOT_CONFIG + ' TEXT, '
      + MachineProperty.NETCONFIG + ' TEXT, '
      + MachineProperty.NICCONFIG + ' TEXT, '
      + MachineProperty.VGA + ' TEXT, '
      + MachineProperty.SOUNDCARD + ' TEXT, '
      + MachineProperty.HDCONFIG + ' TEXT, '
      + MachineProperty.DISABLE_ACPI + ' INTEGER, '
      + MachineProperty.DISABLE_HPET + ' INTEGER, '
      + MachineProperty.ENABLE_USBMOUSE + ' INTEGER, '
      + MachineProperty.STATUS + ' TEXT, '
      + MachineProperty.LAST_UPDATED + ' TEXT, '
      + MachineProperty.KERNEL + ' TEXT, '
      + MachineProperty.INITRD + ' TEXT, '
      + MachineProperty.APPEND + ' TEXT, '
      + MachineProperty.CPUNUM + ' INTEGER, '
      + MachineProperty.MACHINETYPE + ' TEXT, '
      + MachineProperty.DISABLE_FD_BOOT_CHK + ' INTEGER, '
      + MachineProperty.SD + ' TEXT, '
      + MachineProperty.PAUSED + ' INTEGER, '
      + MachineProperty.SHARED_FOLDER + ' TEXT, '
      + MachineProperty.SHARED_FOLDER_MODE + ' INTEGER, '
      + MachineProperty.EXTRA_PARAMS + ' TEXT, '
      + MachineProperty.HOSTFWD + ' TEXT, '
      + MachineProperty.GUESTFWD + ' TEXT, '
      + MachineProperty.UI + ' TEXT, '
      + MachineProperty.DISABLE_TSC + ' INTEGER, '
      + MachineProperty.MOUSE + ' TEXT, '
      + MachineProperty.KEYBOARD + ' TEXT, '
      + MachineProperty.ENABLE_MTTCG + ' INTEGER, '
      + MachineProperty.ENABLE_KVM + ' INTEGER, '
      + MachineProperty.HDA_INTERFACE + ' TEXT, '
      + MachineProperty.HDB_INTERFACE + ' TEXT, '
      + MachineProperty.HDC_INTERFACE + ' TEXT, '
      + MachineProperty.HDD_INTERFACE + ' TEXT, '
      + MachineProperty.CDROM_INTERFACE + ' TEXT, '
      + MachineProperty.BIOS + ' TEXT, '
      + MachineProperty.DISABLE_I8042 + ' INTEGER, '
      + MachineProperty.ENABLE_NVRAM + ' INTEGER DEFAULT 1, '
      + MachineProperty.NVRAM_PATH + ' TEXT, '
      + MachineProperty.HDA_FORMAT + ' TEXT, '
      + MachineProperty.HDB_FORMAT + ' TEXT, '
      + MachineProperty.HDC_FORMAT + ' TEXT, '
      + MachineProperty.HDD_FORMAT + ' TEXT, '
      + MachineProperty.CDROM_FORMAT + ' TEXT, '
      + MachineProperty.HDA_CACHE + ' TEXT, '
      + MachineProperty.HDB_CACHE + ' TEXT, '
      + MachineProperty.HDC_CACHE + ' TEXT, '
      + MachineProperty.HDD_CACHE + ' TEXT, '
      + MachineProperty.ACCEL_MODE + ' TEXT, '
      + MachineProperty.USB_CONTROLLER + ' TEXT'
      + ');';
  }

  /** 幂等初始化；可在 EntryAbility 与页面中重复调用。 */
  ensureReady(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return Promise.resolve();
    }
    if (this.initPromise !== null) {
      return this.initPromise;
    }
    this.initPromise = this.init(context);
    return this.initPromise;
  }

  private async init(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: LimboConfig.DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await store.executeSql(MachineDatabase.tableSql());
    if (store.version === 0) {
      store.version = LimboConfig.DATABASE_VERSION;
    }
    this.store = store;
  }

  private requireStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('MachineDatabase is not initialized');
    }
    return this.store;
  }

  private static now(): string {
    const date: Date = new Date();
    const pad = (value: number): string => value < 10 ? '0' + value : '' + value;
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate())
      + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes()) + ':' + pad(date.getSeconds());
  }

  /** 当前架构；极端情况下回退到默认架构，避免查询参数为空导致列表为空。 */
  private static currentArch(): string {
    const value: string = LimboConfig.ARCH;
    return value.length > 0 ? value : LimboConfig.DEFAULT_ARCH;
  }

  async insertMachine(machine: Machine): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'MACHINE_NAME': machine.name,
      'CPU': machine.cpu,
      'CPUNUM': machine.cpuNum,
      'MEMORY': machine.memory,
      'HDA': machine.hdaPath ?? '',
      'HDA_INTERFACE': machine.hdaInterface,
      'HDA_FORMAT': machine.hdaFormat ?? '',
      'HDA_CACHE': machine.hdaCache ?? '',
      'HDB': machine.hdbPath ?? '',
      'HDB_INTERFACE': machine.hdbInterface,
      'HDB_FORMAT': machine.hdbFormat ?? '',
      'HDB_CACHE': machine.hdbCache ?? '',
      'HDC': machine.hdcPath ?? '',
      'HDC_INTERFACE': machine.hdcInterface,
      'HDC_FORMAT': machine.hdcFormat ?? '',
      'HDC_CACHE': machine.hdcCache ?? '',
      'HDD': machine.hddPath ?? '',
      'HDD_INTERFACE': machine.hddInterface,
      'HDD_FORMAT': machine.hddFormat ?? '',
      'HDD_CACHE': machine.hddCache ?? '',
      'CDROM': machine.cdImagePath ?? '',
      'CDROM_INTERFACE': machine.cdInterface,
      'CDROM_FORMAT': machine.cdFormat ?? '',
      'FDA': machine.fdaImagePath ?? '',
      'FDB': machine.fdbImagePath ?? '',
      'SD': machine.sdImagePath ?? '',
      'SHARED_FOLDER': machine.sharedFolderPath ?? '',
      'SHARED_FOLDER_MODE': machine.sharedFolderMode,
      'BOOT_CONFIG': machine.bootDevice,
      'NETCONFIG': machine.network ?? '',
      'NICCONFIG': machine.networkCard,
      'VGA': machine.vga,
      'SOUNDCARD': machine.soundCard ?? '',
      'DISABLE_ACPI': machine.disableACPI,
      'DISABLE_HPET': machine.disableHPET,
      'DISABLE_TSC': machine.disableTSC,
      'DISABLE_FD_BOOT_CHK': machine.disableFdBootChk,
      'KERNEL': machine.kernel ?? '',
      'INITRD': machine.initRd ?? '',
      'APPEND': machine.append ?? '',
      'BIOS': machine.bios ?? '',
      'MACHINETYPE': machine.machineType,
      'ARCH': machine.arch.length > 0 ? machine.arch : MachineDatabase.currentArch(),
      'EXTRA_PARAMS': machine.extraParams ?? '',
      'HOSTFWD': machine.hostFwd ?? '',
      'GUESTFWD': machine.guestFwd ?? '',
      'UI': machine.getUI(),
      'MOUSE': machine.mouse,
      'KEYBOARD': machine.keyboard,
      'ENABLE_MTTCG': machine.enableMTTCG,
      'ENABLE_KVM': machine.enableKVM,
      'ACCEL_MODE': machine.accelMode,
      'DISABLE_I8042': machine.disableI8042,
      'ENABLE_NVRAM': machine.enableNvram,
      'NVRAM_PATH': machine.nvramPath ?? '',
      'USB_CONTROLLER': machine.usbController,
      'PAUSED': machine.paused,
      'LAST_UPDATED': MachineDatabase.now(),
      'STATUS': LimboConfig.STATUS_CREATED.toString()
    };
    try {
      return await this.requireStore().insert(LimboConfig.MACHINE_TABLE, bucket);
    } catch (err) {
      console.error(`insertMachine failed: ${JSON.stringify(err)}`);
      return -1;
    }
  }

  /** 按 Android 的列名 + 当前架构更新单个字段。 */
  async updateField(machineName: string, property: MachineProperty, value: string): Promise<void> {
    const sql: string = 'UPDATE ' + LimboConfig.MACHINE_TABLE + ' SET ' + property
      + '=? WHERE ' + MachineProperty.MACHINE_NAME + '=? AND ' + MachineProperty.ARCH + '=?';
    try {
      await this.requireStore().executeSql(sql, [value, machineName, MachineDatabase.currentArch()]);
    } catch (err) {
      console.error(`updateField failed: ${JSON.stringify(err)}`);
    }
  }

  /** 当前架构的全部虚拟机（导出 CSV 使用）。 */
  async getAllMachines(): Promise<Machine[]> {
    const machines: Machine[] = [];
    const sql: string = 'SELECT * FROM ' + LimboConfig.MACHINE_TABLE
      + ' WHERE ' + MachineProperty.ARCH + '=? ORDER BY ' + MachineProperty.MACHINE_NAME;
    try {
      const resultSet: relationalStore.ResultSet =
        await this.requireStore().querySql(sql, [MachineDatabase.currentArch()]);
      if (resultSet.goToFirstRow()) {
        do {
          machines.push(this.readMachine(resultSet));
        } while (resultSet.goToNextRow());
      }
      resultSet.close();
    } catch (err) {
      console.error(`getAllMachines failed: ${JSON.stringify(err)}`);
    }
    return machines;
  }

  async getMachine(machineName: string): Promise<Machine | null> {
    const sql: string = 'SELECT * FROM ' + LimboConfig.MACHINE_TABLE
      + ' WHERE ' + MachineProperty.MACHINE_NAME + '=? AND '
      + MachineProperty.ARCH + '=?';
    try {
      const resultSet: relationalStore.ResultSet =
        await this.requireStore().querySql(sql, [machineName, MachineDatabase.currentArch()]);
      let machine: Machine | null = null;
      if (resultSet.goToFirstRow()) {
        machine = this.readMachine(resultSet);
      }
      resultSet.close();
      return machine;
    } catch (err) {
      console.error(`getMachine failed: ${JSON.stringify(err)}`);
      return null;
    }
  }

  async getMachineNames(): Promise<string[]> {
    const names: string[] = [];
    const sql: string = 'SELECT ' + MachineProperty.MACHINE_NAME + ' FROM ' + LimboConfig.MACHINE_TABLE
      + ' WHERE ' + MachineProperty.ARCH + '=? ORDER BY 1';
    try {
      const resultSet: relationalStore.ResultSet =
        await this.requireStore().querySql(sql, [MachineDatabase.currentArch()]);
      if (resultSet.goToFirstRow()) {
        do {
          names.push(resultSet.getString(0));
        } while (resultSet.goToNextRow());
      }
      resultSet.close();
    } catch (err) {
      console.error(`getMachineNames failed: ${JSON.stringify(err)}`);
    }
    return names;
  }

  async deleteMachine(machineName: string): Promise<boolean> {
    const sql: string = 'DELETE FROM ' + LimboConfig.MACHINE_TABLE + ' WHERE '
      + MachineProperty.MACHINE_NAME + '=? AND ' + MachineProperty.ARCH + '=?';
    try {
      await this.requireStore().executeSql(sql, [machineName, MachineDatabase.currentArch()]);
      return true;
    } catch (err) {
      console.error(`deleteMachine failed: ${JSON.stringify(err)}`);
      return false;
    }
  }

  private readMachine(resultSet: relationalStore.ResultSet): Machine {
    const machine: Machine = new Machine(this.readString(resultSet, MachineProperty.MACHINE_NAME) ?? '', false);
    machine.cpu = this.readString(resultSet, MachineProperty.CPU) ?? 'Default';
    machine.cpuNum = this.readInt(resultSet, MachineProperty.CPUNUM, 1);
    machine.memory = this.readInt(resultSet, MachineProperty.MEMORY, 128);
    machine.arch = this.readString(resultSet, MachineProperty.ARCH) ?? MachineDatabase.currentArch();
    machine.machineType = this.readString(resultSet, MachineProperty.MACHINETYPE) ?? 'pc';
    machine.ui = this.readString(resultSet, MachineProperty.UI) ?? 'SDL';
    machine.mouse = this.readString(resultSet, MachineProperty.MOUSE) ?? 'ps2';
    machine.keyboard = this.readString(resultSet, MachineProperty.KEYBOARD) ?? LimboConfig.DEFAULT_KEYBOARD_LAYOUT;
    machine.accelMode = this.readString(resultSet, MachineProperty.ACCEL_MODE) ?? Machine.ACCEL_TCG;
    machine.enableMTTCG = this.readInt(resultSet, MachineProperty.ENABLE_MTTCG, 0);
    machine.enableKVM = this.readInt(resultSet, MachineProperty.ENABLE_KVM, 0);
    machine.disableI8042 = this.readInt(resultSet, MachineProperty.DISABLE_I8042, 1);
    machine.enableNvram = this.readInt(resultSet, MachineProperty.ENABLE_NVRAM, 1);
    machine.nvramPath = this.readString(resultSet, MachineProperty.NVRAM_PATH);
    machine.disableACPI = this.readInt(resultSet, MachineProperty.DISABLE_ACPI, 0);
    machine.disableHPET = this.readInt(resultSet, MachineProperty.DISABLE_HPET, 0);
    machine.disableTSC = this.readInt(resultSet, MachineProperty.DISABLE_TSC, 1);
    machine.disableFdBootChk = this.readInt(resultSet, MachineProperty.DISABLE_FD_BOOT_CHK, 0);
    machine.hdaPath = this.readString(resultSet, MachineProperty.HDA);
    machine.hdbPath = this.readString(resultSet, MachineProperty.HDB);
    machine.hdcPath = this.readString(resultSet, MachineProperty.HDC);
    machine.hddPath = this.readString(resultSet, MachineProperty.HDD);
    machine.hdaInterface = this.readString(resultSet, MachineProperty.HDA_INTERFACE) ?? 'ide';
    machine.hdbInterface = this.readString(resultSet, MachineProperty.HDB_INTERFACE) ?? 'ide';
    machine.hdcInterface = this.readString(resultSet, MachineProperty.HDC_INTERFACE) ?? 'ide';
    machine.hddInterface = this.readString(resultSet, MachineProperty.HDD_INTERFACE) ?? 'ide';
    machine.hdaFormat = this.readString(resultSet, MachineProperty.HDA_FORMAT);
    machine.hdbFormat = this.readString(resultSet, MachineProperty.HDB_FORMAT);
    machine.hdcFormat = this.readString(resultSet, MachineProperty.HDC_FORMAT);
    machine.hddFormat = this.readString(resultSet, MachineProperty.HDD_FORMAT);
    machine.hdaCache = this.readString(resultSet, MachineProperty.HDA_CACHE);
    machine.hdbCache = this.readString(resultSet, MachineProperty.HDB_CACHE);
    machine.hdcCache = this.readString(resultSet, MachineProperty.HDC_CACHE);
    machine.hddCache = this.readString(resultSet, MachineProperty.HDD_CACHE);
    machine.cdImagePath = this.readString(resultSet, MachineProperty.CDROM);
    machine.cdInterface = this.readString(resultSet, MachineProperty.CDROM_INTERFACE) ?? 'ide';
    machine.cdFormat = this.readString(resultSet, MachineProperty.CDROM_FORMAT);
    machine.fdaImagePath = this.readString(resultSet, MachineProperty.FDA);
    machine.fdbImagePath = this.readString(resultSet, MachineProperty.FDB);
    machine.sdImagePath = this.readString(resultSet, MachineProperty.SD);
    machine.sharedFolderPath = this.readString(resultSet, MachineProperty.SHARED_FOLDER);
    machine.sharedFolderMode = this.readInt(resultSet, MachineProperty.SHARED_FOLDER_MODE, 1);
    machine.bootDevice = this.readString(resultSet, MachineProperty.BOOT_CONFIG) ?? 'Default';
    machine.kernel = this.readString(resultSet, MachineProperty.KERNEL);
    machine.initRd = this.readString(resultSet, MachineProperty.INITRD);
    machine.append = this.readString(resultSet, MachineProperty.APPEND);
    machine.bios = this.readString(resultSet, MachineProperty.BIOS);
    machine.network = this.readString(resultSet, MachineProperty.NETCONFIG);
    machine.networkCard = this.readString(resultSet, MachineProperty.NICCONFIG) ?? 'Default';
    machine.guestFwd = this.readString(resultSet, MachineProperty.GUESTFWD);
    machine.hostFwd = this.readString(resultSet, MachineProperty.HOSTFWD);
    machine.vga = this.readString(resultSet, MachineProperty.VGA) ?? 'std';
    machine.soundCard = this.readString(resultSet, MachineProperty.SOUNDCARD);
    machine.extraParams = this.readString(resultSet, MachineProperty.EXTRA_PARAMS);
    machine.usbController = this.readString(resultSet, MachineProperty.USB_CONTROLLER) ?? Machine.USB_CONTROLLER_NONE;
    machine.paused = this.readInt(resultSet, MachineProperty.PAUSED, 0);
    return machine;
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | null {
    const index: number = resultSet.getColumnIndex(column);
    if (index < 0 || resultSet.isColumnNull(index)) {
      return null;
    }
    return resultSet.getString(index);
  }

  private readInt(resultSet: relationalStore.ResultSet, column: string, defaultValue: number): number {
    const index: number = resultSet.getColumnIndex(column);
    if (index < 0 || resultSet.isColumnNull(index)) {
      return defaultValue;
    }
    return resultSet.getLong(index);
  }
}
