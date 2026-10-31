import { LimboFont, LimboSize } from '../theme/LimboTheme';

/**
 * 开关设置行：标题在左，HyperOS 风格开关在右。
 * 对应 Android ui.components.SwitchRow。
 */
@Component
export struct SwitchRow {
  label: ResourceStr = '';
  checked: boolean = false;
  enabled: boolean = true;
  onCheckedChange: (checked: boolean) => void = () => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(LimboFont.main)
        .fontColor($r('app.color.limbo_text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .selectedColor($r('app.color.limbo_primary'))
        .enabled(this.enabled)
        .onChange((isOn: boolean) => {
          this.onCheckedChange(isOn);
        })
    }
    .width('100%')
    .padding({ left: LimboSize.rowHorizontal, right: LimboSize.rowHorizontal, top: 6, bottom: 6 })
  }
}

/**
 * 左侧标签 + 右侧输入框的行。
 * 对应 Android ui.components.LabeledTextFieldRow。
 */
@Component
export struct LabeledTextFieldRow {
  label: ResourceStr = '';
  value: string = '';
  placeholder: string = '';
  numeric: boolean = false;
  enabled: boolean = true;
  onValueChange: (value: string) => void = () => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(LimboFont.main)
        .fontColor($r('app.color.limbo_text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('42%')
        .padding({ right: 8 })

      TextInput({ text: this.value, placeholder: this.placeholder })
        .type(this.numeric ? InputType.Number : InputType.Normal)
        .fontSize(LimboFont.body)
        .fontColor($r('app.color.limbo_text_primary'))
        .placeholderColor($r('app.color.limbo_text_secondary'))
        .height(LimboSize.inputHeight)
        .backgroundColor($r('app.color.limbo_field_background'))
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .enabled(this.enabled)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.onValueChange(value);
        })
    }
    .width('100%')
    .padding({
      left: LimboSize.rowHorizontal,
      right: LimboSize.rowHorizontal,
      top: LimboSize.fieldVertical,
      bottom: LimboSize.fieldVertical
    })
  }
}

/** 小圆点状态指示器（对应 Android ui.components.StatusDot）。 */
@Component
export struct StatusDot {
  dotColor: Resource = $r('app.color.status_stopped');
  dotSize: number = LimboSize.statusDot;

  build() {
    Circle()
      .width(this.dotSize)
      .height(this.dotSize)
      .fill(this.dotColor)
  }
}
