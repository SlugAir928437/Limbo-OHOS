import { fileIo as fs } from '@kit.CoreFileKit';

/** 文件工具（迁移自 Android FileUtils 中业务层需要的基础能力）。 */
export class FileUtils {
  static isUsablePath(value: string | null): boolean {
    return value !== null && value.length > 0 && value !== 'None';
  }

  static getFilenameFromPath(path: string | null): string {
    if (path === null || path.length === 0) {
      return '';
    }
    let index: number = path.lastIndexOf('/');
    const winIndex: number = path.lastIndexOf('\\');
    if (winIndex > index) {
      index = winIndex;
    }
    return index >= 0 ? path.substring(index + 1) : path;
  }

  static exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (err) {
      return false;
    }
  }

  static ensureDir(dir: string): void {
    if (dir.length === 0 || FileUtils.exists(dir)) {
      return;
    }
    try {
      fs.mkdirSync(dir, true);
    } catch (err) {
      console.error(`mkdir ${dir} failed: ${JSON.stringify(err)}`);
    }
  }

  /** 新建磁盘镜像文件并按容量做稀疏扩展，返回最终路径。 */
  static async createDiskImage(dir: string, name: string, sizeBytes: number): Promise<string> {
    FileUtils.ensureDir(dir);
    const path: string = FileUtils.uniquePath(dir, name);
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        if (sizeBytes > 0) {
          fs.truncateSync(path, sizeBytes);
        }
      } catch (err) {
        console.error(`truncate ${path} failed: ${JSON.stringify(err)}`);
      } finally {
        fs.closeSync(file);
      }
    } catch (err) {
      console.error(`create ${path} failed: ${JSON.stringify(err)}`);
    }
    return path;
  }

  private static uniquePath(dir: string, name: string): string {
    const base: string = dir.length > 0 ? dir + '/' + name : name;
    if (!FileUtils.exists(base)) {
      return base;
    }
    const dot: number = name.lastIndexOf('.');
    const stem: string = dot > 0 ? name.substring(0, dot) : name;
    const ext: string = dot > 0 ? name.substring(dot) : '';
    let seq: number = 1;
    let candidate: string = base;
    while (FileUtils.exists(candidate)) {
      candidate = dir.length > 0 ? dir + '/' + stem + '-' + seq + ext : stem + '-' + seq + ext;
      seq++;
    }
    return candidate;
  }
}
