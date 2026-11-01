import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { FileUtils } from './FileUtils';

/** 随 HAP 打包的 QEMU 固件（workflow 生成的 rawfile 目录）。 */
const RAW_DIR: string = 'qemu/pc-bios';
const DEST_SUBDIR: string = '/qemu/pc-bios';
const MANIFEST_NAME: string = 'manifest.txt';
const MARKER_NAME: string = '.manifest';

/**
 * 把 HAP rawfile 中的 QEMU 固件（pc-bios）复制到应用私有目录，
 * 供 QEMU 通过 -L <dir> 读取 BIOS / VGA ROM / option ROM / keymaps。
 *
 * manifest.txt 的第一行携带 QEMU 提交号；它与已复制目录中的标记不一致时
 * 会重新复制，保证 HAP 升级后固件同步更新。
 */
export class QemuFirmware {
  private static ready: Promise<void> | null = null;

  static ensureReady(context: common.Context): Promise<void> {
    const existing: Promise<void> | null = QemuFirmware.ready;
    if (existing !== null) {
      return existing;
    }
    const started: Promise<void> = QemuFirmware.copyAll(context).catch((err: Error) => {
      console.error(`prepare QEMU firmware failed: ${err.message}`);
    });
    QemuFirmware.ready = started;
    return started;
  }

  private static async copyAll(context: common.Context): Promise<void> {
    const destDir: string = context.filesDir + DEST_SUBDIR;
    let manifest: string = '';
    try {
      const manifestBytes: Uint8Array =
        await context.resourceManager.getRawFileContent(RAW_DIR + '/' + MANIFEST_NAME);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      manifest = decoder.decodeToString(manifestBytes);
    } catch (err) {
      // 本地开发未经过 CI 打包时没有固件，交给 QEMU 自己的数据目录
      console.warn(`QEMU firmware manifest not packaged: ${JSON.stringify(err)}`);
      return;
    }

    const markerPath: string = destDir + '/' + MARKER_NAME;
    if (FileUtils.exists(markerPath)) {
      try {
        if (fs.readTextSync(markerPath) === manifest) {
          return;
        }
      } catch (err) {
        console.error(`read firmware marker failed: ${JSON.stringify(err)}`);
      }
    }

    FileUtils.ensureDir(destDir);
    const lines: string[] = manifest.split(/\r?\n/);
    let allCopied: boolean = true;
    for (let i = 0; i < lines.length; i++) {
      const relative: string = lines[i].trim();
      if (relative.length === 0 || relative.startsWith('#')) {
        continue;
      }
      const slash: number = relative.lastIndexOf('/');
      if (slash > 0) {
        FileUtils.ensureDir(destDir + '/' + relative.substring(0, slash));
      }
      const rawPath: string = RAW_DIR + '/' + relative;
      const destPath: string = destDir + '/' + relative;
      try {
        const content: Uint8Array = await context.resourceManager.getRawFileContent(rawPath);
        // fs.writeSync 接受 ArrayBuffer，这里把 rawfile 内容拷进独立缓冲区
        const buffer: ArrayBuffer = new ArrayBuffer(content.byteLength);
        const view: Uint8Array = new Uint8Array(buffer);
        view.set(content);
        const file: fs.File = fs.openSync(destPath,
          fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        try {
          fs.writeSync(file.fd, buffer);
        } finally {
          fs.closeSync(file);
        }
      } catch (err) {
        allCopied = false;
        console.error(`copy QEMU firmware ${relative} failed: ${JSON.stringify(err)}`);
      }
    }

    // 只有全部文件复制成功才写标记，避免下次启动跳过修复
    if (!allCopied) {
      return;
    }
    const marker: fs.File = fs.openSync(markerPath,
      fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(marker.fd, manifest);
    } finally {
      fs.closeSync(marker);
    }
  }
}
