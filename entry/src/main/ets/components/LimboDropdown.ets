import { LimboFont } from '../theme/LimboTheme';

/**
 * Miuix（HyperOS）风格的下拉选择行：左侧标题，右侧当前值，点击弹出覆盖层选项。
 * 对应 Android ui.components.LimboDropdown（OverlayDropdownPreference）。
 */
@Component
export struct LimboDropdown {
  title: ResourceStr = '';
  icon: Resource | null = null;
  summary: string = '';
  options: string[] = [];
  selectedIndex: number = 0;
  isEnabled: boolean = true;
  onSelected: (index: number) => void = () => {
  };

  private currentValue(): string {
    if (this.selectedIndex >= 0 && this.selectedIndex < this.options.length) {
      return this.options[this.selectedIndex];
    }
    return '';
  }

  private buildMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    for (let i = 0; i < this.options.length; i++) {
      const index: number = i;
      items.push({
        value: this.options[i],
        action: () => {
          this.onSelected(index);
        }
      });
    }
    return items;
  }

  private menuContent(): MenuElement[] {
    if (!this.isEnabled) {
      return [];
    }
    return this.buildMenuItems();
  }

  build() {
    Row() {
      if (this.icon !== null) {
        Image(this.icon as Resource)
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .margin({ right: 12 })
      }

      Column() {
        Text(this.title)
          .fontSize(LimboFont.main)
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

      Text(this.currentValue())
        .fontSize(LimboFont.body - 1)
        .fontColor($r('app.color.limbo_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '50%' })
        .margin({ left: 12 })

      Text('›')
        .fontSize(LimboFont.title4)
        .fontColor($r('app.color.limbo_text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .opacity(this.isEnabled ? 1 : 0.4)
    .enabled(this.isEnabled)
    .bindMenu(this.menuContent())
  }
}
