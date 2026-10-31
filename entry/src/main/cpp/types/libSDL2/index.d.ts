/**
 * ohos_sdl2 提供的 N-API（libSDL2.so）。
 * 参考 https://gitcode.com/CPF-ApplicationTPC/ohos_sdl2 的用法：
 * XComponent(NODE, libraryname: 'SDL2') + createNativeNode()。
 */
export interface SdlModule {
  createNativeNode(id: string, width: number, height: number, x: number, y: number): void;
  setScaledDensity(density: number): void;
  quit(): void;
}

declare const sdl: SdlModule;
export default sdl;
