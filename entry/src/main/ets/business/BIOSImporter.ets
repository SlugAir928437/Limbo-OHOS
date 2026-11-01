import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { FileUtils } from './FileUtils';

/** BIOS 导入结果。 */
export interface BiosImportResult {
  path: string;
  tooLarge: boolean;
}

const MAX_BIOS_SIZE: number = 100 * 1024 * 1024;

/**
 * BIOS 文件导入（迁移自 Android BIOSImporter）。
 * 选择文件后复制到应用私有目录，超过 100MB 的文件会被拒绝。
 */
export class BIOSImporter {
  static async importFromPicker(context: common.Context): Promise<BiosImportResult> {
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['.bin', '.fd', '.rom'];
      options.maxSelectNumber = 1;
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) {
        return { path: '', tooLarge: false };
      }

      const stat: fs.Stat = fs.statSync(uris[0]);
      if (stat.size > MAX_BIOS_SIZE) {
        return { path: '', tooLarge: true };
      }

      let name: string = FileUtils.getFilenameFromPath(uris[0]);
      try {
        name = decodeURIComponent(name);
      } catch (err) {
        // 保留原始文件名
      }
      name = name.replace(/"/g, '').replace(/\\/g, '_').replace(/\//g, '_');
      if (name.length === 0) {
        name = 'imported-bios.bin';
      }

      const dir: string = context.filesDir + '/bios';
      FileUtils.ensureDir(dir);
      const dest: string = dir + '/' + name;
      fs.copyFileSync(uris[0], dest);
      return { path: dest, tooLarge: false };
    } catch (err) {
      console.error(`import BIOS failed: ${JSON.stringify(err)}`);
      return { path: '', tooLarge: false };
    }
  }
}
