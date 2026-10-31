/**
 * Limbo 的视觉规格，取自 Android 端 Miuix（HyperOS）主题。
 * 颜色走资源文件（$r('app.color.*')）以自动适配深浅色，这里只放尺寸与字号。
 */

export class LimboSize {
  static readonly pageHorizontal: number = 12;
  static readonly cardRadius: number = 16;
  static readonly cardGap: number = 12;
  static readonly sectionHeaderHorizontal: number = 16;
  static readonly sectionHeaderVertical: number = 14;
  static readonly rowHorizontal: number = 16;
  static readonly rowVertical: number = 14;
  static readonly fieldVertical: number = 8;
  static readonly icon: number = 28;
  static readonly iconSmall: number = 24;
  static readonly statusDot: number = 16;
  static readonly controlButton: number = 64;
  static readonly controlIcon: number = 28;
  static readonly topBarHeight: number = 56;
  static readonly inputHeight: number = 40;
}

export class LimboFont {
  static readonly title1: number = 32;
  static readonly title3: number = 20;
  static readonly title4: number = 18;
  static readonly main: number = 17;
  static readonly body: number = 16;
  static readonly subtitle: number = 15;
  static readonly footnote: number = 13;
}
