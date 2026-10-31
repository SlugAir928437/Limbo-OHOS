import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LimboConfig } from './LimboConfig';

/**
 * 应用设置（迁移自 Android LimboSettingsManager 中 UI/业务会用到的部分）。
 * 使用 Preferences 持久化，key 语义与 Android SharedPreferences 保持一致。
 */
export class LimboSettingsManager {
  private static prefs: preferences.Preferences | null = null;
  private static defaultImagesDir: string = '';

  static async ensureReady(context: common.Context): Promise<void> {
    if (LimboSettingsManager.prefs !== null) {
      return;
    }
    const options: preferences.Options = { name: 'limbo_settings' };
    LimboSettingsManager.prefs = await preferences.getPreferences(context, options);
    LimboSettingsManager.defaultImagesDir = context.filesDir + '/images';
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
}
