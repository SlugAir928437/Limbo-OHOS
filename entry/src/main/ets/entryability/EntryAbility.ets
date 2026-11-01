import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ArchManager } from '../business/ArchManager';
import { MachineDatabase } from '../business/MachineDatabase';
import { LimboSettingsManager } from '../business/LimboSettingsManager';
import { QemuFirmware } from '../business/QemuFirmware';
import { SdlHost } from '../business/SdlHost';
import { VmExecutor } from '../business/VmExecutor';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 提前初始化本地业务层，页面展示时即可直接读写
    MachineDatabase.getInstance().ensureReady(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Init database failed: %{public}s', err.message);
    });
    LimboSettingsManager.ensureReady(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Init settings failed: %{public}s', err.message);
    });
    // 恢复上次选择的模拟架构（数据库查询按架构过滤）
    ArchManager.initialize(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Init arch failed: %{public}s', err.message);
    });
    // 提前把随 HAP 打包的 QEMU 固件解到私有目录，避免启动虚拟机时等待
    QemuFirmware.ensureReady(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Prepare QEMU firmware failed: %{public}s', err.message);
    });
    // 原生执行体：liblimbo.so + 随包的 libqemu-system-x86_64.so / libqemu-system-aarch64.so（TCG）
    VmExecutor.getInstance().init(this.context.filesDir + '/machines', this.context.filesDir);
    // SDL 运行环境要在任何 XComponent(SDL2) 创建之前准备好，否则 SDL 拿不到根节点，
    // QEMU 的 -display sdl 会创建窗口失败后直接退出（页面停在黑屏）。
    if (!SdlHost.prepare(this.context)) {
      hilog.error(DOMAIN, 'testTag', 'Init SDL environment failed');
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}