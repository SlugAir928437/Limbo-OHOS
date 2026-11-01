/**
 * ohos_sdl2（ohos_sdl2_capi 分支）提供的 N-API（libsdl2.so）。
 * 使用方式：XComponent(NODE, libraryname: 'sdl2') + prepare() + createNativeNode()
 * + nativeResume()/nativePause()，之后 SDL 才能在该根节点下创建渲染子节点。
 */
export interface SdlModule {
  /** 初始化 SDL 的运行环境，参数为 UI 侧回调对象。 */
  init(callback: object): void;

  setScaledDensity(density: number): void;

  setResourceManager(cacheDir: string, resourceManager: object): void;

  /**
   * 告知 SDL 屏幕分辨率。第 5 个参数官方示例传入的是 densityPixels（并非像素格式），
   * 第 6 个是刷新率；官方版本只传这 6 个参数。
   */
  nativeSetScreenResolution(nodeWidth: number, nodeHeight: number, deviceWidth: number,
                            deviceHeight: number, format: number, rate: number): void;

  /**
   * 注册 id 为 RootXC 的 XComponent 根节点（capi 分支内部直接挂到 EWAdapterC，
   * 无返回值，成功与否只能从 hilog 里看到）。
   */
  createNativeNode(id: string, width: number, height: number, x: number, y: number): void;

  removeNode(id: string): void;

  destroyNode(): void;

  /** 页面隐藏时阻塞 SDL 渲染线程。 */
  nativePause(): void;

  /** 页面重新显示时恢复 SDL 渲染线程。 */
  nativeResume(): void;

  /** 页面销毁时通知 SDL 退出并销毁页面互斥量。 */
  nativeSendQuit(): void;
}

declare const sdl: SdlModule;
export default sdl;
