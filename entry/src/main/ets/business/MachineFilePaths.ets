import { LimboConfig } from './LimboConfig';
import { LimboSettingsManager } from './LimboSettingsManager';

/**
 * 最近使用的镜像/文件路径（迁移自 Android MachineFilePaths + FavOpenHelper）。
 * 使用 Preferences 以换行分隔保存，每个 FileType 一个 key。
 */
export class MachineFilePaths {
  private static key(fileType: string): string {
    return 'recent_' + fileType.toLowerCase();
  }

  static getRecentFilePaths(fileType: string): string[] {
    const raw: string = LimboSettingsManager.getString(MachineFilePaths.key(fileType), '');
    if (raw.length === 0) {
      return [];
    }
    const parts: string[] = raw.split('\n');
    const values: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const value: string = parts[i].trim();
      if (value.length > 0) {
        values.push(value);
      }
    }
    return values;
  }

  static insertRecentFilePath(fileType: string, filePath: string | null): void {
    if (filePath === null || filePath.length === 0) {
      return;
    }
    const values: string[] = MachineFilePaths.getRecentFilePaths(fileType);
    const merged: string[] = [filePath];
    for (let i = 0; i < values.length; i++) {
      if (values[i] !== filePath) {
        merged.push(values[i]);
      }
    }
    const limited: string[] = merged.length > LimboConfig.RECENT_FILE_LIMIT
      ? merged.slice(0, LimboConfig.RECENT_FILE_LIMIT) : merged;
    LimboSettingsManager.setString(MachineFilePaths.key(fileType), limited.join('\n'));
  }
}
