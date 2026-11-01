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
 * 工作流程（与官方示例 Index.ets / service/SdlModule.ets 保持一致）：
 *  1. prepare()：创建页面互斥量、告知 SDL 屏幕分辨率与缩放密度；
 *  2. attachRootNode()：注册 XComponent(NODE, libraryname: 'sdl2') 的根节点；
 *  3. 页面显示/隐藏时通知 nativeResume()/nativePause()；
 *  4. 页面销毁时 removeNode() + nativeSendQuit()，并复位环境以便下次进入时重新 init。
 *
 * 第 2 步缺失时 SDL_GetRootNode() 拿到空指针，SDL_CreateWindow() 直接返回 -1，
 * QEMU 启动后立即退出，表现就是 SDL 页面黑屏、无画面。
 * 第 3 步缺失时页面互斥量会一直处于暂停态，
 * OHOS_GLES_CreateContext 卡在 OHOS_PAGEMUTEX_LockRunning() 里，同样表现为黑屏。
 */
export class SdlHost {
  /**
   * ohos_sdl2 只把 id 为 RootXC 的 XComponent 记录为 SDL 窗口的根节点，
   * 因此 XComponent 的 id 必须是这个常量。
   */
  static readonly ROOT_NODE_ID: string = 'RootXC';

  private static readonly callback: SdlUiCallback = new SdlUiCallback();
  private static environmentReady: boolean = false;
  private static rootNodeAttached: boolean = false;
  /** 当前是否处于“运行”态（对应 SDL 的 nativePause/nativeResume 信号量）。 */
  private static visible: boolean = true;

  /** 初始化 SDL 运行环境；应在 Ability 创建阶段调用一次，早于任何 XComponent 创建。 */
  static prepare(context: common.Context): boolean {
    if (SdlHost.environmentReady) {
      return true;
    }
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      // init 会创建页面互斥量，必须早于 nativeSetScreenResolution
      sdl.init(SdlHost.callback);
      sdl.setResourceManager(context.cacheDir, context.resourceManager);
      // 官方示例第 5 个参数传的就是 densityPixels，且只有 6 个参数
      sdl.nativeSetScreenResolution(info.width, info.height, info.width, info.height,
        info.densityPixels, info.refreshRate);
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
      SdlHost.rootNodeAttached = true;
      // 若页面此前被 pause 过，这里恢复一次，保证 pause/resume 信号量平衡；
      // 处于暂停态时 SDL 的 OHOS_PAGEMUTEX_LockRunning() 会一直阻塞，
      // 窗口与 GL 上下文都建不出来（黑屏）。
      if (!SdlHost.visible) {
        sdl.nativeResume();
        SdlHost.visible = true;
      }
      return true;
    } catch (err) {
      console.error(`SDL 根节点注册失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  /** 销毁 SDL 自建的节点树。 */
  static detachRootNode(): void {
    if (!SdlHost.rootNodeAttached) {
      return;
    }
    SdlHost.rootNodeAttached = false;
    try {
      sdl.removeNode(SdlHost.ROOT_NODE_ID);
    } catch (err) {
      console.error(`SDL 节点销毁失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 页面显示/隐藏通知。隐藏期间 SDL 会阻塞渲染线程，重新显示时必须 resume，
   * 否则后续的窗口/GL 上下文创建会卡在页面互斥量上。
   */
  static setVisible(visible: boolean): void {
    if (SdlHost.visible === visible) {
      return;
    }
    SdlHost.visible = visible;
    try {
      if (visible) {
        sdl.nativeResume();
      } else {
        sdl.nativePause();
      }
    } catch (err) {
      console.error(`SDL ${visible ? 'resume' : 'pause'} 失败: ${JSON.stringify(err)}`);
    }
  }

  /** 页面销毁时释放 SDL 侧资源，并复位环境让下次进入页面时重新 init。 */
  static shutdown(): void {
    SdlHost.detachRootNode();
    try {
      // nativeSendQuit 内部会清空 pause 信号量、恢复 resume 并销毁页面互斥量
      sdl.nativeSendQuit();
    } catch (err) {
      console.error(`SDL 退出通知失败: ${JSON.stringify(err)}`);
    }
    SdlHost.environmentReady = false;
    SdlHost.visible = true;
  }
}
