import { LimboFont } from '../theme/LimboTheme';

/** 可滚动的长文本对话框（更新日志 / 许可证 / 日志查看复用）。 */
@CustomDialog
export struct TextViewerDialog {
  controller?: CustomDialogController;
  titleProvider: () => ResourceStr = () => '';
  contentProvider: () => string = () => '';
  emptyProvider: () => string = () => '暂无内容';

  build() {
    Column() {
      Text(this.titleProvider())
        .fontSize(LimboFont.title4)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .width('100%')

      Scroll() {
        Text(this.contentProvider().length > 0 ? this.contentProvider() : this.emptyProvider())
          .fontSize(LimboFont.body - 1)
          .fontColor($r('app.color.limbo_text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .margin({ top: 12 })
      .scrollBar(BarState.Auto)

      Button('关闭')
        .width('100%')
        .height(40)
        .fontSize(LimboFont.body)
        .fontColor($r('app.color.limbo_text_primary'))
        .backgroundColor($r('app.color.limbo_secondary_container'))
        .margin({ top: 16 })
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('100%')
    .height(440)
    .padding(20)
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(16)
  }
}
