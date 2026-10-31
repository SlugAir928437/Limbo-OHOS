import { LimboFont, LimboSize } from '../theme/LimboTheme';

/**
 * 可折叠的分区卡片（Miuix / HyperOS 风格）。
 * 头部：图标 + 标题 + 摘要 + 展开箭头；展开后渲染 @BuilderParam 内容。
 * 对应 Android ui.components.SectionCard。
 */
@Component
export struct SectionCard {
  title: ResourceStr = '';
  icon: Resource = $r('app.media.advanced');
  @Prop summary: string = '';
  @Prop collapsed: boolean = true;
  onToggle: () => void = () => {
  };

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Column() {
      Row() {
        Image(this.icon)
          .width(LimboSize.icon)
          .height(LimboSize.icon)
          .objectFit(ImageFit.Contain)

        Column() {
          Text(this.title)
            .fontSize(LimboFont.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.limbo_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          if (this.summary.length > 0) {
            Text(this.summary)
              .fontSize(LimboFont.footnote)
              .fontColor($r('app.color.limbo_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        Text(this.collapsed ? '⌄' : '⌃')
          .fontSize(LimboFont.subtitle)
          .fontColor($r('app.color.limbo_text_secondary'))
      }
      .width('100%')
      .padding({
        left: LimboSize.sectionHeaderHorizontal,
        right: LimboSize.sectionHeaderHorizontal,
        top: LimboSize.sectionHeaderVertical,
        bottom: LimboSize.sectionHeaderVertical
      })
      .onClick(() => {
        this.onToggle();
      })

      if (!this.collapsed) {
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.limbo_divider'))
          .margin({ left: LimboSize.sectionHeaderHorizontal, right: LimboSize.sectionHeaderHorizontal })

        Column() {
          this.content()
        }
        .width('100%')
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(LimboSize.cardRadius)
    .clip(true)
  }
}
