import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LimboConfig } from './LimboConfig';

/**
 * 应用设置（迁移自 Android LimboSettingsManager）。
 * 使用 Preferences 持久化，key 语义与 Android SharedPreferences 保持一致。
 */
export class LimboSettingsManager {
  private static prefs: preferences.Preferences | null = null;
  private static defaultImagesDir: string = '';
  private static defaultExportDir: string = '';
  private static defaultSharedDir: string = '';
  private static qemuDataDir: string = '';

  static async ensureReady(context: common.Context): Promise<void> {
    if (LimboSettingsManager.prefs !== null) {
      return;
    }
    const options: preferences.Options = { name: 'limbo_settings' };
    LimboSettingsManager.prefs = await preferences.getPreferences(context, options);
    LimboSettingsManager.defaultImagesDir = context.filesDir + '/images';
    LimboSettingsManager.defaultExportDir = context.filesDir + '/export';
    LimboSettingsManager.defaultSharedDir = context.filesDir + '/shared';
    LimboSettingsManager.qemuDataDir = context.filesDir + '/qemu/pc-bios';
  }

  /** QEMU 固件数据目录（-L 参数指向这里，由 QemuFirmware 从 rawfile 解出）。 */
  static getQemuDataDir(): string {
    return LimboSettingsManager.qemuDataDir;
  }

  static getString(key: string, defaultValue: string): string {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return defaultValue;
    }
    const value: preferences.ValueType = prefs.getSync(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  static setString(key: string, value: string): void {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return;
    }
    prefs.putSync(key, value);
    prefs.flush().catch((err: Error) => {
      console.error(`flush settings failed: ${err.message}`);
    });
  }

  static getBoolean(key: string, defaultValue: boolean): boolean {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return defaultValue;
    }
    const value: preferences.ValueType = prefs.getSync(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  static setBoolean(key: string, value: boolean): void {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return;
    }
    prefs.putSync(key, value);
    prefs.flush().catch((err: Error) => {
      console.error(`flush settings failed: ${err.message}`);
    });
  }

  static getNumber(key: string, defaultValue: number): number {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return defaultValue;
    }
    const value: preferences.ValueType = prefs.getSync(key, defaultValue);
    return typeof value === 'number' ? value : defaultValue;
  }

  static setNumber(key: string, value: number): void {
    const prefs: preferences.Preferences | null = LimboSettingsManager.prefs;
    if (prefs === null) {
      return;
    }
    prefs.putSync(key, value);
    prefs.flush().catch((err: Error) => {
      console.error(`flush settings failed: ${err.message}`);
    });
  }

  // ============================================================
  // DNS / 目录
  // ============================================================

  /** DNS 服务器（与 Android 同名 key）。 */
  static getDnsServer(): string {
    return LimboSettingsManager.getString('DNSServer', LimboConfig.DEFAULT_DNS_SERVER);
  }

  static setDnsServer(value: string): void {
    LimboSettingsManager.setString('DNSServer', value);
  }

  /** 新建磁盘镜像的保存目录。 */
  static getImagesDir(): string {
    return LimboSettingsManager.getString('imagesDir', LimboSettingsManager.defaultImagesDir);
  }

  static setImagesDir(value: string): void {
    LimboSettingsManager.setString('imagesDir', value);
  }

  static getExportDir(): string {
    return LimboSettingsManager.getString('exportDir', LimboSettingsManager.defaultExportDir);
  }

  static setExportDir(value: string): void {
    LimboSettingsManager.setString('exportDir', value);
  }

  static getSharedDir(): string {
    return LimboSettingsManager.getString('sharedDir', LimboSettingsManager.defaultSharedDir);
  }

  static setSharedDir(value: string): void {
    LimboSettingsManager.setString('sharedDir', value);
  }

  static getLastDir(): string {
    return LimboSettingsManager.getString('lastDir', '');
  }

  static setLastDir(value: string): void {
    LimboSettingsManager.setString('lastDir', value);
  }

  // ============================================================
  // 屏幕
  // ============================================================

  /** 0=自动 1=横屏 2=反向横屏 3=竖屏 4=反向竖屏。 */
  static getOrientationSetting(): number {
    return LimboSettingsManager.getNumber('orientationPref', 0);
  }

  static setOrientationSetting(value: number): void {
    LimboSettingsManager.setNumber('orientationPref', value);
  }

  static getAlwaysShowMenuToolbar(): boolean {
    return LimboSettingsManager.getBoolean('AlwaysShowMenuToolbar', false);
  }

  static setAlwaysShowMenuToolbar(value: boolean): void {
    LimboSettingsManager.setBoolean('AlwaysShowMenuToolbar', value);
  }

  static getFullscreen(): boolean {
    return LimboSettingsManager.getBoolean('ShowFullscreen', true);
  }

  static setFullscreen(value: boolean): void {
    LimboSettingsManager.setBoolean('ShowFullscreen', value);
  }

  static getKeyMapperSize(): number {
    return LimboSettingsManager.getNumber('keyMapperSize', 3);
  }

  static setKeyMapperSize(value: number): void {
    LimboSettingsManager.setNumber('keyMapperSize', value);
  }

  static getPreventMouseOutOfBounds(): boolean {
    return LimboSettingsManager.getBoolean('preventMouseOutOfBounds', false);
  }

  static setPreventMouseOutOfBounds(value: boolean): void {
    LimboSettingsManager.setBoolean('preventMouseOutOfBounds', value);
  }

  static getKeyPressDelay(): number {
    return LimboSettingsManager.getNumber('keyPressDelay', 100);
  }

  static setKeyPressDelay(value: number): void {
    LimboSettingsManager.setNumber('keyPressDelay', value);
  }

  static getMouseButtonDelay(): number {
    return LimboSettingsManager.getNumber('mousePressDelay', 100);
  }

  static setMouseButtonDelay(value: number): void {
    LimboSettingsManager.setNumber('mousePressDelay', value);
  }

  // ============================================================
  // 高级 / 文件
  // ============================================================

  static getPrio(): boolean {
    return LimboSettingsManager.getBoolean('HighPrio', false);
  }

  static setPrio(value: boolean): void {
    LimboSettingsManager.setBoolean('HighPrio', value);
  }

  static getEnableLegacyFileManager(): boolean {
    return LimboSettingsManager.getBoolean('EnableLegacyFileManager', false);
  }

  static setEnableLegacyFileManager(value: boolean): void {
    LimboSettingsManager.setBoolean('EnableLegacyFileManager', value);
  }

  // ============================================================
  // QMP
  // ============================================================

  static getEnableQmp(): boolean {
    return LimboSettingsManager.getBoolean('enableQMP', true);
  }

  static setEnableQmp(value: boolean): void {
    LimboSettingsManager.setBoolean('enableQMP', value);
  }

  static getEnableExternalQmp(): boolean {
    return LimboSettingsManager.getBoolean('enableExternalQMP', false);
  }

  static setEnableExternalQmp(value: boolean): void {
    LimboSettingsManager.setBoolean('enableExternalQMP', value);
  }

  // ============================================================
  // VNC / SPICE
  // ============================================================

  static getVNCEnablePassword(): boolean {
    return LimboSettingsManager.getBoolean('enableVNCPassword', false);
  }

  static setVNCEnablePassword(value: boolean): void {
    LimboSettingsManager.setBoolean('enableVNCPassword', value);
  }

  static getVNCPass(): string {
    return LimboSettingsManager.getString('vncPass', '');
  }

  static setVNCPass(value: string): void {
    LimboSettingsManager.setString('vncPass', value);
  }

  static getEnableExternalVNC(): boolean {
    return LimboSettingsManager.getBoolean('enableExternalVNC', false);
  }

  static setEnableExternalVNC(value: boolean): void {
    LimboSettingsManager.setBoolean('enableExternalVNC', value);
  }

  static getSPICEEnablePassword(): boolean {
    return LimboSettingsManager.getBoolean('enableSPICEPassword', false);
  }

  static setSPICEEnablePassword(value: boolean): void {
    LimboSettingsManager.setBoolean('enableSPICEPassword', value);
  }

  static getSPICEPass(): string {
    return LimboSettingsManager.getString('spicePass', '');
  }

  static setSPICEPass(value: string): void {
    LimboSettingsManager.setString('spicePass', value);
  }

  static getEnableExternalSPICE(): boolean {
    return LimboSettingsManager.getBoolean('enableExternalSPICE', false);
  }

  static setEnableExternalSPICE(value: boolean): void {
    LimboSettingsManager.setBoolean('enableExternalSPICE', value);
  }

  // ============================================================
  // SDL 显示 / 磁盘缓存 / 音频
  // ============================================================

  /** 0=拉伸 1=等比 2=1:1。 */
  static getSDLScaleMode(): number {
    return LimboSettingsManager.getNumber('sdlScaleMode', 1);
  }

  static setSDLScaleMode(value: number): void {
    LimboSettingsManager.setNumber('sdlScaleMode', value);
  }

  /** 0=关闭 -1=跟随屏幕 >0=目标频率(Hz)。 */
  static getSDLRefreshRate(): number {
    return LimboSettingsManager.getNumber('sdlRefreshRate', 0);
  }

  static setSDLRefreshRate(value: number): void {
    LimboSettingsManager.setNumber('sdlRefreshRate', value);
  }

  static getDiskCache(): string {
    return LimboSettingsManager.getString('diskCachePref', 'default');
  }

  static setDiskCache(value: string): void {
    LimboSettingsManager.setString('diskCachePref', value);
  }

  static getEnableAaudio(): boolean {
    return LimboSettingsManager.getBoolean('enableAaudio', false);
  }

  static setEnableAaudio(value: boolean): void {
    LimboSettingsManager.setBoolean('enableAaudio', value);
  }
}
