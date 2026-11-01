import { promptAction } from '@kit.ArkUI';
import { LimboFont } from '../theme/LimboTheme';

/**
 * 通用文本输入对话框（创建虚拟机、导出文件名、VNC/SPICE 密码等复用）。
 * 通过 *Provider 回调读取调用方的最新值，避免为每次弹窗重建控制器。
 */
@CustomDialog
export struct TextInputDialog {
  controller?: CustomDialogController;
  titleProvider: () => ResourceStr = () => '';
  messageProvider: () => string = () => '';
  placeholderProvider: () => string = () => '';
  initialProvider: () => string = () => '';
  passwordProvider: () => boolean = () => false;
  @State value: string = '';

  onConfirm: (value: string) => void = () => {
  };

  aboutToAppear(): void {
    this.value = this.initialProvider();
  }

  build() {
    Column() {
      Text(this.titleProvider())
        .fontSize(LimboFont.title4)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .width('100%')

      if (this.messageProvider().length > 0) {
        Text(this.messageProvider())
          .fontSize(LimboFont.body - 1)
          .fontColor($r('app.color.limbo_text_secondary'))
          .width('100%')
          .margin({ top: 8 })
      }

      TextInput({ text: this.value, placeholder: this.placeholderProvider() })
        .type(this.passwordProvider() ? InputType.Password : InputType.Normal)
        .fontSize(LimboFont.body)
        .fontColor($r('app.color.limbo_text_primary'))
        .placeholderColor($r('app.color.limbo_text_secondary'))
        .height(44)
        .backgroundColor($r('app.color.limbo_field_background'))
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .margin({ top: 16 })
        .onChange((value: string) => {
          this.value = value;
        })

      Row({ space: 8 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(LimboFont.body)
          .fontColor($r('app.color.limbo_text_primary'))
          .backgroundColor($r('app.color.limbo_secondary_container'))
          .onClick(() => {
            this.controller?.close();
          })

        Button('确定')
          .layoutWeight(1)
          .height(40)
          .fontSize(LimboFont.body)
          .fontColor($r('app.color.limbo_on_primary'))
          .backgroundColor($r('app.color.limbo_primary'))
          .onClick(() => {
            const trimmed: string = this.value.trim();
            if (trimmed.length === 0) {
              promptAction.showToast({ message: '输入不能为空' });
              return;
            }
            this.onConfirm(trimmed);
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(16)
  }
}
