/**
 * Limbo 业务层常量（迁移自 Android com.limbo.emu.main.Config）。
 * HarmonyOS 端固定模拟 x86_64，其它架构的选项表暂不打包。
 */
export class LimboConfig {
  /** 当前模拟架构，与 Android Config.Arch.x86_64 对应。 */
  static readonly ARCH: string = 'x86_64';
  static readonly ARCH_LABEL: string = 'x86_64 (amd64)';

  static readonly APP_NAME: string = 'Limbo Emulator';

  // 数据库（与 Android 同名同版本，便于理解数据模型）
  static readonly DATABASE_NAME: string = 'LIMBO.db';
  static readonly DATABASE_VERSION: number = 26;
  static readonly MACHINE_TABLE: string = 'machines';
  static readonly STATUS_CREATED: number = 1000;
  static readonly STATUS_PAUSED: number = 1001;

  // 默认值
  static readonly DEFAULT_DNS_SERVER: string = '8.8.8.8';
  static readonly DEFAULT_KEYBOARD_LAYOUT: string = 'en-us';
  static readonly DEFAULT_VNC_PORT: number = 1;
  static readonly DEFAULT_SPICE_PORT: number = 5930;

  // 功能开关（与 Android 默认一致）
  static readonly ENABLE_SDL: boolean = true;
  static readonly ENABLE_EMULATED_FLOPPY: boolean = true;
  static readonly ENABLE_EMULATED_SDCARD: boolean = false;
  static readonly ENABLE_SHARED_FOLDER: boolean = false;
  static readonly ENABLE_KEYBOARD_LAYOUT_OPTION: boolean = true;
  static readonly ENABLE_MOUSE_OPTION: boolean = true;
  static readonly ENABLE_MTTCG: boolean = true;

  // 文本落库防抖
  static readonly DB_UPDATE_DELAY_MS: number = 500;
  /** 最近使用文件最多保存条数。 */
  static readonly RECENT_FILE_LIMIT: number = 10;
}
