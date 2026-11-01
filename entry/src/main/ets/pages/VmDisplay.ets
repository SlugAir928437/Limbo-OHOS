import { display, promptAction, router, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { KeyCode } from '@kit.InputKit';
import sdl from 'libSDL2.so';
import { TextInputDialog } from '../components/TextInputDialog';
import { LimboSettingsManager } from '../business/LimboSettingsManager';
import { MachineController, MachineStatus } from '../business/MachineController';
import { QemuFirmware } from '../business/QemuFirmware';
import { VmExecutor } from '../business/VmExecutor';

/**
 * SDL 显示宿主页（对应 Android LimboSDLActivity）。
 *
 * 原生 SDL 窗口由 ohos_sdl2 的 XComponent NODE 承载；页面先创建 SDL 原生节点，
 * 再启动进程内 QEMU（-display sdl）。运行时菜单提供暂停/重启/停止、显示方式、
 * 刷新率，以及通过 QMP 注入的键盘/鼠标/文本输入。
 */
@Entry
@Component
struct VmDisplay {
  @State statusText: string = '正在启动虚拟机…';
  @State paused: boolean = false;
  @State scaleMode: number = 1;
  @State refreshRate: number = 0;

  // 输入注入
  @State keyboardEnabled: boolean = true;
  @State mouseMode: number = 0; // 0=触控板（相对） 1=触摸屏（绝对）
  @State showKeyMapper: boolean = false;
  @State viewWidth: number = 1;
  @State viewHeight: number = 1;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;

  @State inputTitle: string = '发送文本';
  @State inputInitial: string = '';
  @State inputPlaceholder: string = '输入要发送到客户机的文本';
  private inputDialog: CustomDialogController = new CustomDialogController({
    builder: TextInputDialog({
      titleProvider: (): ResourceStr => this.inputTitle,
      initialProvider: (): string => this.inputInitial,
      placeholderProvider: (): string => this.inputPlaceholder,
      onConfirm: (value: string) => {
        this.onTextConfirm(value);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      XComponent({
        id: 'limbo_sdl',
        type: XComponentType.NODE,
        libraryname: 'SDL2'
      })
        .width('100%')
        .height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const width: number = Number(newValue.width);
          const height: number = Number(newValue.height);
          if (!Number.isNaN(width) && width > 0) {
            this.viewWidth = width;
          }
          if (!Number.isNaN(height) && height > 0) {
            this.viewHeight = height;
          }
        })
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event);
        })
        .onAppear(() => {
          this.prepare();
        })

      if (this.showKeyMapper) {
        Column() {
          Blank()
          this.KeyMapperPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.None)
      }

      Row({ space: 8 }) {
        Text(this.statusText)
          .fontSize(13)
          .fontColor(Color.White)
          .opacity(0.8)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Circle }) {
          Text('⋮')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(38)
        .height(38)
        .padding(0)
        .backgroundColor('#66000000')
        .bindMenu(this.runtimeMenu())

        Button('断开')
          .height(38)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#66000000')
          .onClick(() => {
            this.stopAndExit();
          })
      }
      .padding({ left: 12, right: 12, top: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      this.handleKey(event);
    })
  }

  onBackPress(): boolean {
    this.stopAndExit();
    return true;
  }

  private async prepare(): Promise<void> {
    this.scaleMode = LimboSettingsManager.getSDLScaleMode();
    this.refreshRate = LimboSettingsManager.getSDLRefreshRate();

    try {
      const info = display.getDefaultDisplaySync();
      sdl.setScaledDensity(info.scaledDensity);
      sdl.createNativeNode('limbo_sdl', info.width, info.height, 0, 0);
    } catch (err) {
      console.error(`SDL createNativeNode failed: ${JSON.stringify(err)}`);
    }

    await this.applyOrientation();
    await this.applyFullscreen();

    const context: common.Context = getContext(this) as common.Context;
    await QemuFirmware.ensureReady(context);

    const controller: MachineController = MachineController.getInstance();
    await controller.start();
    if (controller.getStatus() !== MachineStatus.Running) {
      const error: string = VmExecutor.getInstance().getLastError();
      this.statusText = error.length > 0 ? error : '虚拟机启动失败';
      promptAction.showToast({ message: this.statusText });
      await this.restoreWindow();
      router.back();
      return;
    }
    this.statusText = '';
  }

  private runtimeMenu(): MenuElement[] {
    const controller: MachineController = MachineController.getInstance();
    const isPaused: boolean = controller.getStatus() === MachineStatus.Paused;
    const items: MenuElement[] = [
      {
        value: isPaused ? '恢复运行' : '暂停',
        action: () => {
          this.togglePause();
        }
      },
      {
        value: '重启',
        action: () => {
          this.restartVm();
        }
      },
      {
        value: '停止并断开',
        action: () => {
          this.stopAndExit();
        }
      },
      {
        value: '发送文本…',
        action: () => {
          this.promptSendText();
        }
      },
      {
        value: 'Ctrl+Alt+Del',
        action: () => {
          this.sendKeys('ctrl,alt,delete', 150);
        }
      },
      {
        value: this.mouseMode === 0 ? '鼠标模式：触控板' : '鼠标模式：触摸屏',
        action: () => {
          this.toggleMouseMode();
        }
      },
      {
        value: this.keyboardEnabled ? '键盘：开' : '键盘：关',
        action: () => {
          this.toggleKeyboard();
        }
      },
      {
        value: this.showKeyMapper ? '按键映射：开' : '按键映射：关',
        action: () => {
          this.toggleKeyMapper();
        }
      },
      {
        value: '显示方式：拉伸',
        action: () => {
          this.setScaleMode(0);
        }
      },
      {
        value: '显示方式：等比',
        action: () => {
          this.setScaleMode(1);
        }
      },
      {
        value: '显示方式：1:1',
        action: () => {
          this.setScaleMode(2);
        }
      },
      {
        value: '刷新率：关闭',
        action: () => {
          this.setRefreshRate(0);
        }
      },
      {
        value: '刷新率：跟随屏幕',
        action: () => {
          this.setRefreshRate(-1);
        }
      },
      {
        value: '刷新率：60 Hz',
        action: () => {
          this.setRefreshRate(60);
        }
      },
      {
        value: '刷新率：90 Hz',
        action: () => {
          this.setRefreshRate(90);
        }
      },
      {
        value: '刷新率：120 Hz',
        action: () => {
          this.setRefreshRate(120);
        }
      }
    ];
    return items;
  }

  private async togglePause(): Promise<void> {
    const controller: MachineController = MachineController.getInstance();
    if (controller.getStatus() === MachineStatus.Running) {
      await controller.pause();
    } else if (controller.getStatus() === MachineStatus.Paused) {
      await controller.start();
    }
    this.paused = controller.getStatus() === MachineStatus.Paused;
    this.statusText = this.paused ? '已暂停' : '';
  }

  private async restartVm(): Promise<void> {
    await MachineController.getInstance().restart();
    this.paused = false;
    this.statusText = '';
  }

  private setScaleMode(mode: number): void {
    this.scaleMode = mode;
    LimboSettingsManager.setSDLScaleMode(mode);
    VmExecutor.getInstance().setDisplayScaleMode(mode);
  }

  private setRefreshRate(hz: number): void {
    this.refreshRate = hz;
    LimboSettingsManager.setSDLRefreshRate(hz);
    VmExecutor.getInstance().setDisplayRefreshRate(hz);
  }

  // ============================================================
  // 输入注入（QMP）：键盘、文本、鼠标
  // ============================================================

  private promptSendText(): void {
    this.inputTitle = '发送文本';
    this.inputInitial = '';
    this.inputPlaceholder = '输入要发送到客户机的文本（仅 ASCII）';
    this.inputDialog.open();
  }

  private onTextConfirm(value: string): void {
    if (!VmExecutor.getInstance().sendText(value, 0)) {
      promptAction.showToast({
        message: '发送文本失败：' + VmExecutor.getInstance().getLastError()
      });
    }
  }

  private sendKeys(keysCsv: string, holdMs: number): void {
    if (!VmExecutor.getInstance().sendKeyCombo(keysCsv, holdMs)) {
      promptAction.showToast({
        message: '发送按键失败：' + VmExecutor.getInstance().getLastError()
      });
    }
  }

  private toggleKeyboard(): void {
    this.keyboardEnabled = !this.keyboardEnabled;
    promptAction.showToast({
      message: this.keyboardEnabled ? '键盘输入已启用' : '键盘输入已停用'
    });
  }

  private toggleMouseMode(): void {
    this.mouseMode = this.mouseMode === 0 ? 1 : 0;
    promptAction.showToast({
      message: this.mouseMode === 0 ? '鼠标模式：触控板' : '鼠标模式：触摸屏（需 usb-tablet/virtio-tablet）'
    });
  }

  private toggleKeyMapper(): void {
    this.showKeyMapper = !this.showKeyMapper;
  }

  private handleKey(event: KeyEvent): void {
    if (!this.keyboardEnabled) {
      return;
    }
    const qcode: string = this.keyCodeToQcode(event.keyCode);
    if (qcode.length > 0) {
      VmExecutor.getInstance().sendKeyEvent(qcode, event.type === KeyType.Down);
      return;
    }
    if (event.type === KeyType.Down && event.keyText.length === 1
      && event.keyText !== '\r' && event.keyText !== '\n') {
      VmExecutor.getInstance().sendText(event.keyText, 0);
    }
  }

  private keyCodeToQcode(keyCode: number): string {
    switch (keyCode) {
      case KeyCode.KEYCODE_ENTER:
        return 'ret';
      case KeyCode.KEYCODE_ESCAPE:
        return 'esc';
      case KeyCode.KEYCODE_DEL:
        return 'backspace';
      case KeyCode.KEYCODE_FORWARD_DEL:
        return 'delete';
      case KeyCode.KEYCODE_TAB:
        return 'tab';
      case KeyCode.KEYCODE_SPACE:
        return 'spc';
      case KeyCode.KEYCODE_DPAD_UP:
        return 'up';
      case KeyCode.KEYCODE_DPAD_DOWN:
        return 'down';
      case KeyCode.KEYCODE_DPAD_LEFT:
        return 'left';
      case KeyCode.KEYCODE_DPAD_RIGHT:
        return 'right';
      case KeyCode.KEYCODE_MOVE_HOME:
        return 'home';
      case KeyCode.KEYCODE_MOVE_END:
        return 'end';
      case KeyCode.KEYCODE_PAGE_UP:
        return 'pgup';
      case KeyCode.KEYCODE_PAGE_DOWN:
        return 'pgdn';
      case KeyCode.KEYCODE_INSERT:
        return 'insert';
      case KeyCode.KEYCODE_F1:
        return 'f1';
      case KeyCode.KEYCODE_F2:
        return 'f2';
      case KeyCode.KEYCODE_F3:
        return 'f3';
      case KeyCode.KEYCODE_F4:
        return 'f4';
      case KeyCode.KEYCODE_F5:
        return 'f5';
      case KeyCode.KEYCODE_F6:
        return 'f6';
      case KeyCode.KEYCODE_F7:
        return 'f7';
      case KeyCode.KEYCODE_F8:
        return 'f8';
      case KeyCode.KEYCODE_F9:
        return 'f9';
      case KeyCode.KEYCODE_F10:
        return 'f10';
      case KeyCode.KEYCODE_F11:
        return 'f11';
      case KeyCode.KEYCODE_F12:
        return 'f12';
      default:
        return '';
    }
  }

  private handleTouch(event: TouchEvent): void {
    const executor: VmExecutor = VmExecutor.getInstance();
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      executor.sendMouseButton('left', false);
      return;
    }
    if (event.touches.length === 0) {
      return;
    }
    const touch: TouchObject = event.touches[0];
    if (event.type === TouchType.Down) {
      this.lastTouchX = touch.x;
      this.lastTouchY = touch.y;
      if (this.mouseMode === 1) {
        executor.sendMouseMove(false, this.toAbsX(touch.x), this.toAbsY(touch.y));
      }
      executor.sendMouseButton('left', true);
      return;
    }
    if (event.type === TouchType.Move) {
      if (this.mouseMode === 1) {
        executor.sendMouseMove(false, this.toAbsX(touch.x), this.toAbsY(touch.y));
      } else {
        const dx: number = Math.round((touch.x - this.lastTouchX) * 1.5);
        const dy: number = Math.round((touch.y - this.lastTouchY) * 1.5);
        if (dx !== 0 || dy !== 0) {
          executor.sendMouseMove(true, dx, dy);
        }
      }
      this.lastTouchX = touch.x;
      this.lastTouchY = touch.y;
    }
  }

  private toAbsX(x: number): number {
    if (this.viewWidth <= 1) {
      return 0;
    }
    return Math.max(0, Math.min(32767, Math.round(x / this.viewWidth * 32767)));
  }

  private toAbsY(y: number): number {
    if (this.viewHeight <= 1) {
      return 0;
    }
    return Math.max(0, Math.min(32767, Math.round(y / this.viewHeight * 32767)));
  }

  @Builder
  KeyMapperPanel() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        this.KeyButton('Esc', 'esc')
        this.KeyButton('Tab', 'tab')
        this.KeyButton('Enter', 'ret')
        this.KeyButton('BkSp', 'backspace')
        this.KeyButton('Del', 'delete')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.KeyButton('F1', 'f1')
        this.KeyButton('F2', 'f2')
        this.KeyButton('F3', 'f3')
        this.KeyButton('F4', 'f4')
        this.KeyButton('F5', 'f5')
        this.KeyButton('F6', 'f6')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.KeyButton('F7', 'f7')
        this.KeyButton('F8', 'f8')
        this.KeyButton('F9', 'f9')
        this.KeyButton('F10', 'f10')
        this.KeyButton('F11', 'f11')
        this.KeyButton('F12', 'f12')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.KeyButton('↑', 'up')
        this.KeyButton('←', 'left')
        this.KeyButton('↓', 'down')
        this.KeyButton('→', 'right')
        this.KeyButton('Home', 'home')
        this.KeyButton('End', 'end')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.KeyButton('PgUp', 'pgup')
        this.KeyButton('PgDn', 'pgdn')
        this.KeyButton('Ins', 'insert')
        this.KeyButton('Alt+Tab', 'alt,tab')
        this.KeyButton('Alt+F4', 'alt,f4')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.KeyButton('Ctrl+C', 'ctrl,c')
        this.KeyButton('Ctrl+V', 'ctrl,v')
        this.KeyButton('Ctrl+X', 'ctrl,x')
        this.KeyButton('Ctrl+Z', 'ctrl,z')
        this.KeyButton('Ctrl+A', 'ctrl,a')
      }
      .width('100%')

      Row({ space: 4 }) {
        this.MouseButton('左键', 'left')
        this.MouseButton('中键', 'middle')
        this.MouseButton('右键', 'right')
        this.KeyButton('Ctrl+Alt+Del', 'ctrl,alt,delete')
      }
      .width('100%')
    }
    .width('100%')
    .padding(6)
    .backgroundColor('#CC000000')
  }

  @Builder
  KeyButton(label: string, keysCsv: string) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('#33FFFFFF')
      .enabled(this.keyboardEnabled)
      .onClick(() => {
        this.sendKeys(keysCsv, 90);
      })
  }

  @Builder
  MouseButton(label: string, button: string) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('#33FFFFFF')
      .onClick(() => {
        const executor: VmExecutor = VmExecutor.getInstance();
        executor.sendMouseButton(button, true);
        executor.sendMouseButton(button, false);
      })
  }

  private async applyOrientation(): Promise<void> {
    const setting: number = LimboSettingsManager.getOrientationSetting();
    const orientations: window.Orientation[] = [
      window.Orientation.AUTO_ROTATION,
      window.Orientation.LANDSCAPE,
      window.Orientation.LANDSCAPE_INVERTED,
      window.Orientation.PORTRAIT,
      window.Orientation.PORTRAIT_INVERTED
    ];
    const target: window.Orientation = setting >= 0 && setting < orientations.length
      ? orientations[setting] : window.Orientation.AUTO_ROTATION;
    try {
      const win: window.Window = await window.getLastWindow(getContext(this));
      await win.setPreferredOrientation(target);
    } catch (err) {
      console.error(`apply orientation failed: ${JSON.stringify(err)}`);
    }
  }

  private async applyFullscreen(): Promise<void> {
    if (!LimboSettingsManager.getFullscreen()) {
      return;
    }
    try {
      const win: window.Window = await window.getLastWindow(getContext(this));
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarEnable([]);
    } catch (err) {
      console.error(`apply fullscreen failed: ${JSON.stringify(err)}`);
    }
  }

  private async restoreWindow(): Promise<void> {
    try {
      const win: window.Window = await window.getLastWindow(getContext(this));
      await win.setWindowLayoutFullScreen(false);
      await win.setWindowSystemBarEnable(['status', 'navigation']);
      await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
    } catch (err) {
      console.error(`restore window failed: ${JSON.stringify(err)}`);
    }
  }

  private async stopAndExit(): Promise<void> {
    await MachineController.getInstance().stop();
    await this.restoreWindow();
    router.back();
  }
}
