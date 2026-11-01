import { LimboFont } from '../theme/LimboTheme';

/** 通用确认对话框（删除虚拟机、丢弃状态等复用）。 */
@CustomDialog
export struct ConfirmDialog {
  controller?: CustomDialogController;
  titleProvider: () => ResourceStr = () => '';
  messageProvider: () => string = () => '';
  onConfirm: () => void = () => {
  };

  build() {
    Column() {
      Text(this.titleProvider())
        .fontSize(LimboFont.title4)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .width('100%')

      Text(this.messageProvider())
        .fontSize(LimboFont.body - 1)
        .fontColor($r('app.color.limbo_text_secondary'))
        .width('100%')
        .margin({ top: 10 })

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
          .backgroundColor($r('app.color.limbo_error'))
          .onClick(() => {
            this.onConfirm();
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
