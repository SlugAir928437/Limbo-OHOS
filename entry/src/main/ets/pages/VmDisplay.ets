import { display, promptAction, router } from '@kit.ArkUI';
import sdl from 'libSDL2.so';
import { MachineController, MachineStatus } from '../business/MachineController';
import { VmExecutor } from '../business/VmExecutor';

/**
 * SDL 显示宿主页（对应 Android LimboSDLActivity 的显示部分）。
 *
 * 原生 SDL 窗口由 ohos_sdl2 的 XComponent NODE 承载；页面先创建 SDL 原生节点，
 * 再启动进程内 QEMU（-display sdl）。不做 GTK / AGL。
 */
@Entry
@Component
struct VmDisplay {
  @State statusText: string = '正在启动虚拟机…';

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      XComponent({
        id: 'limbo_sdl',
        type: XComponentType.NODE,
        libraryname: 'SDL2'
      })
        .width('100%')
        .height('100%')
        .onAppear(() => {
          this.prepare();
        })

      Row() {
        Text(this.statusText)
          .fontSize(13)
          .fontColor(Color.White)
          .opacity(0.8)
          .margin({ right: 12 })

        Button($r('app.string.button_stop'))
          .height(34)
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
  }

  onBackPress(): boolean {
    this.stopAndExit();
    return true;
  }

  private async prepare(): Promise<void> {
    try {
      const info = display.getDefaultDisplaySync();
      sdl.setScaledDensity(info.scaledDensity);
      sdl.createNativeNode('limbo_sdl', info.width, info.height, 0, 0);
    } catch (err) {
      console.error(`SDL createNativeNode failed: ${JSON.stringify(err)}`);
    }

    const controller: MachineController = MachineController.getInstance();
    await controller.start();
    if (controller.getStatus() !== MachineStatus.Running) {
      const error: string = VmExecutor.getInstance().getLastError();
      this.statusText = error.length > 0 ? error : '虚拟机启动失败';
      promptAction.showToast({ message: this.statusText });
      router.back();
      return;
    }
    this.statusText = '';
  }

  private async stopAndExit(): Promise<void> {
    await MachineController.getInstance().stop();
    router.back();
  }
}
