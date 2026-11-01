import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import sdl from 'libsdl2.so';

/**
 * SDL 的 UI 回调（ohos_sdl2 通过线程安全函数切回 UI 线程调用）。
 *
 * 虚拟机画面由 QEMU 直接渲染，标题/全屏/软键盘等交互由 ArkTS 页面自己处理，
 * 因此这里只需要提供同名方法即可，具体行为留空。
 */
class SdlUiCallback {
  setTitle(title: string): void {
  }

  setWindowStyle(fullscreen: boolean): void {
  }

  setOrientation(width: number, height: number, resizable: number, hint: string): void {
  }

  setPointer(cursorID: number): void {
  }

  requestPermission(permission: string): void {
  }

  showTextInput(x: number, y: number, width: number, height: number): void {
  }

  showTextInput2(x: number, y: number, width: number, height: number): void {
  }

  hideTextInput(flag?: number): void {
  }

  shouldMinimizeOnFocusLoss(flag?: number): void {
  }

  nAPISetWindowResize(x: number, y: number, width: number, height: number): void {
  }

  setCustomCursorandCreate(pixelmap: object, focusX: number, focusY: number): void {
  }
}

/**
 * ohos_sdl2（ohos_sdl2_capi 分支）的 ArkTS 宿主。
 *
 * 工作流程：
 *  1. prepare()：建立页面互斥量、EGL 驱动环境变量，并告知 SDL 屏幕分辨率与缩放密度；
 *  2. attachRootNode()：把 XComponent(NODE, libraryname: 'sdl2') 的根节点交给 SDL，
 *     SDL 会在该根节点下自建一个用于渲染的 XComponent；
 *  3. 之后 QEMU 的 -display sdl 才能成功创建 SDL 窗口。
 *
 * 缺少第 2 步时 SDL_CreateWindow 会失败，QEMU 启动后立即退出，
 * 表现就是 SDL 页面黑屏、QEMU 未运行。
 */
export class SdlHost {
  /**
   * ohos_sdl2 只把 id 为 RootXC 的 XComponent 记录为 SDL 窗口的根节点，
   * 因此 XComponent 的 id 必须是这个常量。
   */
  static readonly ROOT_NODE_ID: string = 'RootXC';

  private static readonly callback: SdlUiCallback = new SdlUiCallback();
  private static environmentReady: boolean = false;

  /** 初始化 SDL 运行环境；应在 Ability 创建阶段调用一次，早于任何 XComponent 创建。 */
  static prepare(context: common.Context): boolean {
    if (SdlHost.environmentReady) {
      return true;
    }
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      // init 会创建页面互斥量与 EGL 环境变量，必须早于 nativeSetScreenResolution
      sdl.init(SdlHost.callback);
      sdl.setResourceManager(context.cacheDir, context.resourceManager);
      sdl.nativeSetScreenResolution(info.width, info.height, info.width, info.height,
        info.densityPixels, info.refreshRate, info.scaledDensity);
      sdl.setScaledDensity(info.scaledDensity);
      SdlHost.environmentReady = true;
      return true;
    } catch (err) {
      console.error(`SDL 环境初始化失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  /** 把当前页面的 RootXC 根节点交给 SDL，必须在启动 QEMU 之前调用。 */
  static attachRootNode(): boolean {
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      sdl.createNativeNode(SdlHost.ROOT_NODE_ID, info.width, info.height, 0, 0);
      return true;
    } catch (err) {
      console.error(`SDL 根节点注册失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  /** 页面退出时销毁 SDL 自建的节点树。 */
  static detachRootNode(): void {
    try {
      sdl.removeNode(SdlHost.ROOT_NODE_ID);
    } catch (err) {
      console.error(`SDL 节点销毁失败: ${JSON.stringify(err)}`);
    }
  }
}
