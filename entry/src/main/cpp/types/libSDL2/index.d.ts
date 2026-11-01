/**
 * ohos_sdl2（ohos_sdl2_capi 分支）提供的 N-API（libSDL2.so）。
 * 使用方式：XComponent(NODE, libraryname: 'SDL2') + prepare() + createNativeNode()。
 */
export interface SdlModule {
  /** 初始化 SDL 的运行环境，参数为 UI 侧回调对象。 */
  init(callback: object): void;

  setScaledDensity(density: number): void;

  setResourceManager(cacheDir: string, resourceManager: object): void;

  nativeSetScreenResolution(nodeWidth: number, nodeHeight: number, deviceWidth: number,
                            deviceHeight: number, format: number, rate: number, density: number): void;

  /** 注册 SDL 窗口的根节点；id 必须是 RootXC。 */
  createNativeNode(id: string, width: number, height: number, x: number, y: number): void;

  removeNode(id: string): void;

  destroyNode(): void;

  nativeSendQuit(): void;
}

declare const sdl: SdlModule;
export default sdl;
