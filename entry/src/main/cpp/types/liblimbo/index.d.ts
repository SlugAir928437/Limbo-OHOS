/**
 * Limbo 原生模块（liblimbo.so）。
 * 仅支持 TCG 的进程内 QEMU；显示后端为 SDL（不含 GTK）。
 */

/** 设置存储目录与基础目录（用于定位随包 QEMU 引擎）。 */
export const setPaths: (storageDir: string, baseDir: string) => boolean;

/** libqemu-system-x86_64.so 是否可用。 */
export const isEngineAvailable: () => boolean;

/** 启动 QEMU；返回空字符串表示成功，否则为错误信息。 */
export const start: (args: Array<string>, scaleMode: number, refreshRateHz: number) => string;

/** 请求关机（restart=true 时改为重启）；返回空字符串表示成功。 */
export const stop: (restart: boolean) => string;

/** 通过 QMP 暂停 / 恢复。 */
export const pause: () => string;
export const resume: () => string;

/** 0=空闲 1=启动中 2=运行中 3=停止中。 */
export const getState: () => number;

/** 0=拉伸 1=等比 2=1:1。 */
export const setScaleMode: (mode: number) => boolean;

/** 可变刷新率目标（Hz，0=关闭）。 */
export const setRefreshRateHz: (hz: number) => boolean;

/** 请求整屏刷新。 */
export const refreshScreen: (value: number) => boolean;

/** 发送键盘组合（逗号分隔的 QKeyCode 名称，如 "ctrl,alt,delete"）。返回空字符串表示成功。 */
export const sendKeyCombo: (keysCsv: string, holdMs: number) => string;

/** 发送单个按键按下/抬起；返回空字符串表示成功。 */
export const sendKeyEvent: (key: string, down: boolean) => string;

/** 向客户机输入 ASCII 文本；返回空字符串表示成功。 */
export const sendText: (text: string, delayMs: number) => string;

/** 鼠标按键：left / middle / right；返回空字符串表示成功。 */
export const sendMouseButton: (button: string, down: boolean) => string;

/** 鼠标移动：relative=true 为相对位移，否则为 0..0x7fff 的绝对坐标。 */
export const sendMouseMove: (relative: boolean, x: number, y: number) => string;
