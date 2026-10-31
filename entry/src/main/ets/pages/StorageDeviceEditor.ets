import { promptAction, router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import {
  IMAGE_NEW,
  IMAGE_OPEN,
  StorageDeviceUiState,
  STORAGE_FORMAT_LABELS,
  STORAGE_IF_LABELS
} from '../model/LimboUiState';
import { findDevice, StorageEditorParams } from '../model/LimboStore';
import { LimboFont, LimboSize } from '../theme/LimboTheme';
import { LimboDropdown } from '../components/LimboDropdown';
import { LabeledTextFieldRow } from '../components/LimboRows';
import { MachineController } from '../business/MachineController';
import { StorageDevices } from '../business/StorageDevices';

/**
 * 单个存储设备编辑页（迁移自 Android StorageDeviceEditorActivity）。
 *
 * 类型 / 接口 / 格式 / 缓存 / 容量 / 镜像 / 保存 / 移除，
 * 取消返回时丢弃改动，确定返回时写回主页对应的设备行。
 */
@Entry
@Component
struct StorageDeviceEditor {
  @State device: StorageDeviceUiState = new StorageDeviceUiState();
  @State isNew: boolean = true;

  aboutToAppear(): void {
    const params: StorageEditorParams = router.getParams() as StorageEditorParams;
    if (params !== undefined && params !== null) {
      this.isNew = params.isNew;
      const original: StorageDeviceUiState | undefined = findDevice(params.tag);
      if (original !== undefined) {
        this.device = original.clone();
        this.mergeRecentImages();
      }
    }
  }

  /** 把该设备类型最近使用的镜像合并进下拉列表。 */
  private mergeRecentImages(): void {
    const recent: string[] = StorageDevices.recentPathsFor(this.device);
    const options: string[] = this.device.imageOptions.slice();
    for (let i = 0; i < recent.length; i++) {
      if (options.indexOf(recent[i]) < 0) {
        options.push(recent[i]);
      }
    }
    this.device.imageOptions = options;
  }

  build() {
    Column() {
      this.TopBar()

      Scroll() {
        Column() {
          Column() {
            LimboDropdown({
              title: $r('app.string.label_storage_type'),
              options: this.device.typeOptions,
              selectedIndex: this.device.typeSel,
              onSelected: (index: number) => {
                this.onTypeSelected(index);
              }
            })

            if (this.device.canIf) {
              LimboDropdown({
                title: $r('app.string.label_storage_interface'),
                options: STORAGE_IF_LABELS,
                selectedIndex: this.device.ifSel,
                onSelected: (index: number) => {
                  this.device.ifSel = index;
                }
              })
              LimboDropdown({
                title: $r('app.string.label_storage_format'),
                options: STORAGE_FORMAT_LABELS,
                selectedIndex: this.device.formatSel,
                onSelected: (index: number) => {
                  this.device.formatSel = index;
                }
              })
            }

            if (this.device.canCache) {
              LabeledTextFieldRow({
                label: $r('app.string.label_storage_cache'),
                value: this.device.cacheValue,
                placeholder: '留空则使用默认',
                onValueChange: (value: string) => {
                  this.device.cacheValue = value;
                }
              })
            }

            if (this.showNewImageFields()) {
              LabeledTextFieldRow({
                label: $r('app.string.label_storage_size'),
                value: this.device.sizeValue,
                numeric: true,
                onValueChange: (value: string) => {
                  this.device.sizeValue = this.digitsOnly(value, 6);
                }
              })
              LimboDropdown({
                title: $r('app.string.label_storage_size_unit'),
                options: this.device.sizeUnitOptions,
                selectedIndex: this.device.sizeUnitSel,
                onSelected: (index: number) => {
                  this.device.sizeUnitSel = index;
                }
              })
              LabeledTextFieldRow({
                label: $r('app.string.label_new_image_name'),
                value: this.device.newImageName,
                onValueChange: (value: string) => {
                  this.device.newImageName = value;
                }
              })
            }

            LimboDropdown({
              title: $r('app.string.label_storage_image'),
              options: this.device.imageOptions,
              selectedIndex: this.device.imageSel,
              onSelected: (index: number) => {
                this.onImageSelected(index);
              }
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.limbo_card'))
          .borderRadius(LimboSize.cardRadius)
          .clip(true)
          .margin({ top: 12 })

          if (!this.isNew) {
            Button($r('app.string.remove_storage_device'))
              .width('100%')
              .height(44)
              .fontSize(LimboFont.body)
              .fontColor($r('app.color.limbo_error'))
              .backgroundColor(Color.Transparent)
              .margin({ top: 16 })
              .onClick(() => {
                this.onRemove();
              })
          }

          Button($r('app.string.ok'))
            .width('100%')
            .height(44)
            .fontSize(LimboFont.body)
            .fontColor($r('app.color.limbo_on_primary'))
            .backgroundColor($r('app.color.limbo_primary'))
            .margin({ top: 8 })
            .onClick(() => {
              this.onSave();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.limbo_window_background'))
  }

  @Builder
  TopBar() {
    Row() {
      Text($r('app.string.cancel'))
        .fontSize(LimboFont.body)
        .fontColor($r('app.color.limbo_primary'))
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          router.back();
        })

      Text($r('app.string.title_storage_device_editor'))
        .fontSize(LimboFont.title3)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('')
        .width(60)
    }
    .width('100%')
    .height(LimboSize.topBarHeight)
  }

  /** 只有“创建新镜像”时才显示容量、单位与镜像名称。 */
  private showNewImageFields(): boolean {
    return this.device.createImage && this.device.selectedImageOption() === IMAGE_NEW;
  }

  private onTypeSelected(index: number): void {
    if (index === this.device.typeSel) {
      return;
    }
    this.device.applyType(index);
    this.device.newImageName = '';
  }

  private onImageSelected(index: number): void {
    this.device.imageSel = index;
    const option: string = this.device.selectedImageOption();
    if (option === IMAGE_OPEN) {
      this.browseImage();
    } else if (option !== IMAGE_NEW) {
      this.device.newImageName = '';
    }
  }

  /** 选择镜像文件（HarmonyOS 系统文件选择器）。 */
  private async browseImage(): Promise<void> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(getContext(this));
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const uris: string[] = await documentPicker.select(options);
      if (uris.length > 0) {
        const selected: string = uris[0];
        if (this.device.imageOptions.indexOf(selected) < 0) {
          this.device.imageOptions = this.device.imageOptions.concat([selected]);
        }
        this.device.imageSel = this.device.imageOptions.indexOf(selected);
      } else {
        this.device.imageSel = 0;
      }
    } catch (err) {
      console.error(`browseImage failed: ${JSON.stringify(err)}`);
      this.device.imageSel = 0;
    }
  }

  private async onSave(): Promise<void> {
    if (MachineController.getInstance().getMachine() === null) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }
    if (this.showNewImageFields() && this.device.newImageName.trim().length === 0) {
      promptAction.showToast({ message: $r('app.string.image_filename_cannot_be_empty') });
      return;
    }
    const applied: boolean = await StorageDevices.apply(this.device);
    if (!applied) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }
    router.back();
  }

  private async onRemove(): Promise<void> {
    await StorageDevices.remove(this.device);
    router.back();
  }

  private digitsOnly(value: string, maxLength: number): string {
    const digits: string = value.replace(/[^0-9]/g, '');
    return digits.length > maxLength ? digits.substring(0, maxLength) : digits;
  }
}
