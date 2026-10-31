import { LimboUiState, StorageDeviceUiState } from './LimboUiState';

/** 打开存储设备编辑页时通过 router 传入的参数。 */
export interface StorageEditorParams {
  tag: number;
  isNew: boolean;
}

/**
 * 主界面与编辑页共享的 UI 状态单例。
 * HarmonyOS 端没有 QEMU 业务层，先用这个单例在两个页面间传递界面状态。
 */
export const limboState: LimboUiState = new LimboUiState();

export function findDevice(tag: number): StorageDeviceUiState | undefined {
  const devices: StorageDeviceUiState[] = limboState.storageDevices;
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].tag === tag) {
      return devices[i];
    }
  }
  return undefined;
}
