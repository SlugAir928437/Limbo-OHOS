import { router } from '@kit.ArkUI';
import { LimboDropdown } from '../components/LimboDropdown';
import { SwitchRow } from '../components/LimboRows';
import { TextInputDialog } from '../components/TextInputDialog';
import { LimboSettingsManager } from '../business/LimboSettingsManager';
import { LimboFont, LimboSize } from '../theme/LimboTheme';

const ORIENTATION_LABELS: string[] = ['自动', '横屏', '反向横屏', '竖屏', '反向竖屏'];
const KEY_MAPPER_LABELS: string[] = ['3 × 6', '4 × 8', '5 × 10'];
const KEY_MAPPER_VALUES: number[] = [3, 4, 5];
const DELAY_LABELS: string[] = ['20 ms', '30 ms', '40 ms', '50 ms', '60 ms', '70 ms', '80 ms', '90 ms', '100 ms'];
const DELAY_VALUES: number[] = [20, 30, 40, 50, 60, 70, 80, 90, 100];
const DISK_CACHE_LABELS: string[] = ['default', 'none', 'writethrough', 'writeback', 'directsync', 'unsafe'];

function indexOfNumber(values: number[], value: number): number {
  for (let i = 0; i < values.length; i++) {
    if (values[i] === value) {
      return i;
    }
  }
  return 0;
}

/**
 * 设置页（迁移自 Android PreferenceActivity + res/xml/settings.xml）。
 * 分组：文件 / 屏幕 / 高级 / QMP / VNC / SPICE / 磁盘。
 */
@Entry
@Component
struct Settings {
  @State orientationSel: number = 0;
  @State alwaysToolbar: boolean = false;
  @State fullscreen: boolean = true;
  @State keyMapperSel: number = 0;
  @State preventMouseOut: boolean = false;
  @State keyDelaySel: number = 8;
  @State mouseDelaySel: number = 8;
  @State highPrio: boolean = false;
  @State legacyFileManager: boolean = false;

  @State enableQmp: boolean = true;
  @State externalQmp: boolean = false;

  @State vncPassEnabled: boolean = false;
  @State vncPass: string = '';
  @State externalVnc: boolean = false;

  @State spicePassEnabled: boolean = false;
  @State spicePass: string = '';
  @State externalSpice: boolean = false;

  @State diskCacheSel: number = 0;

  @State inputTitle: string = '';
  @State inputInitial: string = '';
  @State inputPlaceholder: string = '';
  @State inputPassword: boolean = false;
  private passwordTarget: number = 0;

  private inputDialog: CustomDialogController = new CustomDialogController({
    builder: TextInputDialog({
      titleProvider: (): ResourceStr => this.inputTitle,
      initialProvider: (): string => this.inputInitial,
      placeholderProvider: (): string => this.inputPlaceholder,
      passwordProvider: (): boolean => this.inputPassword,
      onConfirm: (value: string) => {
        this.onPasswordConfirm(value);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    this.orientationSel = LimboSettingsManager.getOrientationSetting();
    this.alwaysToolbar = LimboSettingsManager.getAlwaysShowMenuToolbar();
    this.fullscreen = LimboSettingsManager.getFullscreen();
    this.keyMapperSel = indexOfNumber(KEY_MAPPER_VALUES, LimboSettingsManager.getKeyMapperSize());
    this.preventMouseOut = LimboSettingsManager.getPreventMouseOutOfBounds();
    this.keyDelaySel = indexOfNumber(DELAY_VALUES, LimboSettingsManager.getKeyPressDelay());
    this.mouseDelaySel = indexOfNumber(DELAY_VALUES, LimboSettingsManager.getMouseButtonDelay());
    this.highPrio = LimboSettingsManager.getPrio();
    this.legacyFileManager = LimboSettingsManager.getEnableLegacyFileManager();

    this.enableQmp = LimboSettingsManager.getEnableQmp();
    this.externalQmp = LimboSettingsManager.getEnableExternalQmp();

    this.vncPassEnabled = LimboSettingsManager.getVNCEnablePassword();
    this.vncPass = LimboSettingsManager.getVNCPass();
    this.externalVnc = LimboSettingsManager.getEnableExternalVNC();

    this.spicePassEnabled = LimboSettingsManager.getSPICEEnablePassword();
    this.spicePass = LimboSettingsManager.getSPICEPass();
    this.externalSpice = LimboSettingsManager.getEnableExternalSPICE();

    const cache: string = LimboSettingsManager.getDiskCache();
    for (let i = 0; i < DISK_CACHE_LABELS.length; i++) {
      if (DISK_CACHE_LABELS[i] === cache) {
        this.diskCacheSel = i;
      }
    }
  }

  build() {
    Column() {
      this.TopBar()

      Scroll() {
        Column({ space: 8 }) {
          this.SectionTitle('文件')
          SettingsCard() {
            SwitchRow({
              label: '使用旧版文件管理器',
              checked: this.legacyFileManager,
              onCheckedChange: (checked: boolean) => {
                this.legacyFileManager = checked;
                LimboSettingsManager.setEnableLegacyFileManager(checked);
              }
            })
          }

          this.SectionTitle('屏幕')
          SettingsCard() {
            LimboDropdown({
              title: '屏幕方向',
              options: ORIENTATION_LABELS,
              selectedIndex: this.orientationSel,
              onSelected: (index: number) => {
                this.orientationSel = index;
                LimboSettingsManager.setOrientationSetting(index);
              }
            })
            SwitchRow({
              label: '始终显示菜单工具栏',
              checked: this.alwaysToolbar,
              onCheckedChange: (checked: boolean) => {
                this.alwaysToolbar = checked;
                LimboSettingsManager.setAlwaysShowMenuToolbar(checked);
              }
            })
            SwitchRow({
              label: '全屏显示',
              checked: this.fullscreen,
              onCheckedChange: (checked: boolean) => {
                this.fullscreen = checked;
                LimboSettingsManager.setFullscreen(checked);
              }
            })
            LimboDropdown({
              title: '按键映射布局',
              options: KEY_MAPPER_LABELS,
              selectedIndex: this.keyMapperSel,
              onSelected: (index: number) => {
                this.keyMapperSel = index;
                LimboSettingsManager.setKeyMapperSize(KEY_MAPPER_VALUES[index]);
              }
            })
            SwitchRow({
              label: '防止鼠标移出边界',
              checked: this.preventMouseOut,
              onCheckedChange: (checked: boolean) => {
                this.preventMouseOut = checked;
                LimboSettingsManager.setPreventMouseOutOfBounds(checked);
              }
            })
            LimboDropdown({
              title: '按键延迟',
              options: DELAY_LABELS,
              selectedIndex: this.keyDelaySel,
              onSelected: (index: number) => {
                this.keyDelaySel = index;
                LimboSettingsManager.setKeyPressDelay(DELAY_VALUES[index]);
              }
            })
            LimboDropdown({
              title: '鼠标按键延迟',
              options: DELAY_LABELS,
              selectedIndex: this.mouseDelaySel,
              onSelected: (index: number) => {
                this.mouseDelaySel = index;
                LimboSettingsManager.setMouseButtonDelay(DELAY_VALUES[index]);
              }
            })
          }

          this.SectionTitle('高级')
          SettingsCard() {
            SwitchRow({
              label: '高优先级运行虚拟机线程',
              checked: this.highPrio,
              onCheckedChange: (checked: boolean) => {
                this.highPrio = checked;
                LimboSettingsManager.setPrio(checked);
              }
            })
          }

          this.SectionTitle('QMP')
          SettingsCard() {
            SwitchRow({
              label: '启用 QMP 服务器',
              checked: this.enableQmp,
              onCheckedChange: (checked: boolean) => {
                this.enableQmp = checked;
                LimboSettingsManager.setEnableQmp(checked);
              }
            })
            SwitchRow({
              label: '允许外部 QMP 连接',
              checked: this.externalQmp,
              isEnabled: this.enableQmp,
              onCheckedChange: (checked: boolean) => {
                this.externalQmp = checked;
                LimboSettingsManager.setEnableExternalQmp(checked);
              }
            })
          }

          this.SectionTitle('VNC')
          SettingsCard() {
            SwitchRow({
              label: '启用 VNC 密码',
              checked: this.vncPassEnabled,
              onCheckedChange: (checked: boolean) => {
                this.vncPassEnabled = checked;
                LimboSettingsManager.setVNCEnablePassword(checked);
                if (checked && this.vncPass.length === 0) {
                  this.openPasswordDialog(1);
                }
              }
            })
            ActionRow({
              label: '设置 VNC 密码',
              summary: this.vncPass.length > 0 ? '已设置' : '未设置',
              isEnabled: this.vncPassEnabled,
              onTap: () => {
                this.openPasswordDialog(1);
              }
            })
            SwitchRow({
              label: '允许外部 VNC 连接',
              checked: this.externalVnc,
              isEnabled: this.enableQmp,
              onCheckedChange: (checked: boolean) => {
                this.externalVnc = checked;
                LimboSettingsManager.setEnableExternalVNC(checked);
              }
            })
          }

          this.SectionTitle('SPICE')
          SettingsCard() {
            SwitchRow({
              label: '启用 SPICE 密码',
              checked: this.spicePassEnabled,
              onCheckedChange: (checked: boolean) => {
                this.spicePassEnabled = checked;
                LimboSettingsManager.setSPICEEnablePassword(checked);
                if (checked && this.spicePass.length === 0) {
                  this.openPasswordDialog(2);
                }
              }
            })
            ActionRow({
              label: '设置 SPICE 密码',
              summary: this.spicePass.length > 0 ? '已设置' : '未设置',
              isEnabled: this.spicePassEnabled,
              onTap: () => {
                this.openPasswordDialog(2);
              }
            })
            SwitchRow({
              label: '允许外部 SPICE 连接',
              checked: this.externalSpice,
              onCheckedChange: (checked: boolean) => {
                this.externalSpice = checked;
                LimboSettingsManager.setEnableExternalSPICE(checked);
              }
            })
          }

          this.SectionTitle('磁盘')
          SettingsCard() {
            LimboDropdown({
              title: '默认磁盘缓存',
              options: DISK_CACHE_LABELS,
              selectedIndex: this.diskCacheSel,
              onSelected: (index: number) => {
                this.diskCacheSel = index;
                LimboSettingsManager.setDiskCache(DISK_CACHE_LABELS[index]);
              }
            })
          }
        }
        .width('100%')
        .padding({
          left: LimboSize.pageHorizontal,
          right: LimboSize.pageHorizontal,
          top: 8,
          bottom: 24
        })
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
      Button({ type: ButtonType.Circle }) {
        Text('‹')
          .fontSize(26)
          .fontColor($r('app.color.limbo_text_primary'))
      }
      .width(40)
      .height(40)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })

      Text('设置')
        .fontSize(LimboFont.title3)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .margin({ left: 4 })
    }
    .width('100%')
    .height(LimboSize.topBarHeight)
    .padding({ left: 8, right: 16 })
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(LimboFont.footnote)
      .fontColor($r('app.color.limbo_text_secondary'))
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 2 })
  }

  private openPasswordDialog(target: number): void {
    this.passwordTarget = target;
    this.inputTitle = target === 1 ? 'VNC 密码' : 'SPICE 密码';
    this.inputInitial = target === 1 ? this.vncPass : this.spicePass;
    this.inputPlaceholder = '请输入密码';
    this.inputPassword = true;
    this.inputDialog.open();
  }

  private onPasswordConfirm(value: string): void {
    if (this.passwordTarget === 1) {
      this.vncPass = value;
      LimboSettingsManager.setVNCPass(value);
    } else if (this.passwordTarget === 2) {
      this.spicePass = value;
      LimboSettingsManager.setSPICEPass(value);
    }
  }
}

/** 设置页的统一卡片容器。 */
@Component
struct SettingsCard {
  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(LimboSize.cardRadius)
    .clip(true)
  }
}

/** 右侧带摘要与箭头的可点击设置行（用于密码设置等）。 */
@Component
struct ActionRow {
  label: string = '';
  @Prop summary: string = '';
  @Prop isEnabled: boolean = true;
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(LimboFont.main)
        .fontColor($r('app.color.limbo_text_primary'))
        .layoutWeight(1)

      Text(this.summary)
        .fontSize(LimboFont.body - 1)
        .fontColor($r('app.color.limbo_text_secondary'))
        .margin({ left: 8 })

      Text('›')
        .fontSize(LimboFont.title4)
        .fontColor($r('app.color.limbo_text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({
      left: LimboSize.rowHorizontal,
      right: LimboSize.rowHorizontal,
      top: LimboSize.fieldVertical,
      bottom: LimboSize.fieldVertical
    })
    .opacity(this.isEnabled ? 1 : 0.4)
    .enabled(this.isEnabled)
    .onClick(() => {
      this.onTap();
    })
  }
}
