import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DEVICE_TYPES, LimboUiState, Section, StorageDeviceUiState } from '../model/LimboUiState';
import { limboState, StorageEditorParams } from '../model/LimboStore';
import { LimboFont, LimboSize } from '../theme/LimboTheme';
import { SectionCard } from '../components/SectionCard';
import { LimboDropdown } from '../components/LimboDropdown';
import { LabeledTextFieldRow, StatusDot, SwitchRow } from '../components/LimboRows';
import { ArchDefinitions } from '../business/ArchDefinitions';
import { LimboConfig } from '../business/LimboConfig';
import { LimboSettingsManager } from '../business/LimboSettingsManager';
import { Machine } from '../business/Machine';
import { MachineController, MachineStatus } from '../business/MachineController';
import { MachineDatabase } from '../business/MachineDatabase';
import { MachineProperty } from '../business/MachineProperty';
import { StorageDevices } from '../business/StorageDevices';
import { VmExecutor } from '../business/VmExecutor';

/** 控制按钮（图标 / 背景色 / 点击回调）的参数对象。 */
class ControlButtonOptions {
  icon: Resource;
  background: Resource;
  action: () => void;

  constructor(icon: Resource, background: Resource, action: () => void) {
    this.icon = icon;
    this.background = background;
    this.action = action;
  }
}

/**
 * Limbo 主配置页（迁移自 Android Compose 版 LimboMainScreen）。
 *
 * 结构：顶部栏 + 虚拟机卡片 + 运行状态卡片 + 四个控制按钮
 *      + 用户界面 / 主板 / 存储设备 / 启动 / 图形 / 音频 / 网络 / 高级 八个可折叠分区。
 */
@Entry
@Component
struct Index {
  @State state: LimboUiState = limboState;
  private savedMachineNames: string[] = [];

  aboutToAppear(): void {
    this.initialize();
  }

  onPageShow(): void {
    // 从存储设备编辑页 / SDL 显示页返回后同步状态与存储列表
    this.state.storageDevices = StorageDevices.rebuild(MachineController.getInstance().getMachine());
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  /** 初始化业务层：数据库 / 设置 / 架构选项，然后恢复已保存的虚拟机。 */
  private async initialize(): Promise<void> {
    try {
      const context: common.Context = getContext(this) as common.Context;
      await MachineDatabase.getInstance().ensureReady(context);
      await LimboSettingsManager.ensureReady(context);
      await ArchDefinitions.ensureReady(context);
      this.refreshOptions();
      this.state.archLabel = LimboConfig.ARCH_LABEL;
      this.state.dns = LimboSettingsManager.getDnsServer();
      await this.reloadMachines();
      if (this.savedMachineNames.length > 0) {
        await this.selectMachine(this.savedMachineNames[0]);
      } else {
        this.clearMachineState();
      }
    } catch (err) {
      console.error(`initialize failed: ${JSON.stringify(err)}`);
      this.clearMachineState();
    }
  }

  private refreshOptions(): void {
    this.state.uiOptions = ArchDefinitions.getUIValues();
    this.state.keyboardOptions = ArchDefinitions.getKeyboardValues();
    this.state.mouseOptions = ArchDefinitions.getMouseValues();
    this.state.machineTypeOptions = ArchDefinitions.getMachineTypeValues();
    this.state.cpuOptions = ArchDefinitions.getCpuValues();
    this.state.accelOptions = ArchDefinitions.getAccelLabels();
    this.state.nvramOptions = ArchDefinitions.getNvramOptions();
    this.state.bootOptions = ArchDefinitions.getBootDevices();
    this.state.biosOptions = ['默认'].concat(ArchDefinitions.getBiosFirmwareValues());
    this.state.kernelOptions = ArchDefinitions.getDiskOptions();
    this.state.initrdOptions = ArchDefinitions.getDiskOptions();
    this.state.vgaOptions = ArchDefinitions.getVGAValues();
    this.state.soundOptions = ArchDefinitions.getSoundcards();
    this.state.nicOptions = ArchDefinitions.getNetworkDevices();
    this.state.usbControllerOptions = ArchDefinitions.getUsbControllerValues();
  }

  private async reloadMachines(): Promise<void> {
    this.savedMachineNames = await MachineController.getInstance().getStoredMachines();
    this.state.machines = ['未选择虚拟机', '新建虚拟机…'].concat(this.savedMachineNames);
  }

  /** 把数据库中的 Machine 同步到界面状态。 */
  private bindMachine(machine: Machine): void {
    // 历史数据里可能保存过 GTK / AGL；HarmonyOS 版本统一回落到 SDL
    let uiValue: string = machine.getUI();
    if (uiValue === 'GTK' || uiValue === 'AGL') {
      uiValue = 'SDL';
    }
    this.state.uiOptions = this.withValue(this.state.uiOptions, uiValue);
    this.state.uiSel = this.indexOfValue(this.state.uiOptions, uiValue);
    this.state.keyboardOptions = this.withValue(this.state.keyboardOptions, machine.keyboard);
    this.state.keyboardSel = this.indexOfValue(this.state.keyboardOptions, machine.keyboard);
    this.state.mouseOptions = this.withValue(this.state.mouseOptions, machine.mouse);
    this.state.mouseSel = this.indexOfValue(this.state.mouseOptions, machine.mouse);

    this.state.machineTypeOptions = this.withValue(this.state.machineTypeOptions, machine.machineType);
    this.state.machineTypeSel = this.indexOfValue(this.state.machineTypeOptions, machine.machineType);
    this.state.cpuOptions = this.withValue(this.state.cpuOptions, machine.cpu);
    this.state.cpuSel = this.indexOfValue(this.state.cpuOptions, machine.cpu);
    this.state.cpuNumValue = machine.cpuNum.toString();
    this.state.ramValue = machine.memory.toString();

    this.state.disableI8042 = machine.disableI8042 === 1;
    this.state.enableNvram = machine.enableNvram === 1;
    this.state.nvramSel = 0;
    this.state.enableMTTCG = machine.enableMTTCG === 1;
    this.state.disableACPI = machine.disableACPI === 1;
    this.state.disableHPET = machine.disableHPET === 1;
    this.state.disableTSC = machine.disableTSC === 1;

    this.state.accelOptions = ArchDefinitions.getAccelLabels();
    this.state.accelSel = 0; // HMOS 只提供 TCG
    this.state.showMTTCGSwitch = true;

    this.state.bootOptions = this.withValue(this.state.bootOptions, machine.bootDevice);
    this.state.bootSel = this.indexOfValue(this.state.bootOptions, machine.bootDevice);
    const biosValue: string = machine.bios === null ? '默认' : machine.bios;
    this.state.biosOptions = this.withValue(this.state.biosOptions, biosValue);
    this.state.biosSel = this.indexOfValue(this.state.biosOptions, biosValue);
    this.state.kernelOptions = this.withValue(this.state.kernelOptions, machine.kernel ?? 'None');
    this.state.kernelSel = this.indexOfValue(this.state.kernelOptions, machine.kernel ?? 'None');
    this.state.initrdOptions = this.withValue(this.state.initrdOptions, machine.initRd ?? 'None');
    this.state.initrdSel = this.indexOfValue(this.state.initrdOptions, machine.initRd ?? 'None');
    this.state.append = machine.append ?? '';

    this.state.vgaOptions = this.withValue(this.state.vgaOptions, machine.vga);
    this.state.vgaSel = this.indexOfValue(this.state.vgaOptions, machine.vga);
    const soundValue: string = machine.soundCard === null ? 'None' : machine.soundCard;
    this.state.soundOptions = this.withValue(this.state.soundOptions, soundValue);
    this.state.soundSel = this.indexOfValue(this.state.soundOptions, soundValue);

    const netValue: string = machine.network === null ? 'None' : machine.network;
    this.state.netOptions = this.withValue(this.state.netOptions, netValue);
    this.state.netSel = this.indexOfValue(this.state.netOptions, netValue);
    this.state.nicOptions = this.withValue(this.state.nicOptions, machine.networkCard);
    this.state.nicSel = this.indexOfValue(this.state.nicOptions, machine.networkCard);
    this.state.hostFwd = machine.hostFwd ?? '';

    this.state.usbControllerOptions = this.withValue(this.state.usbControllerOptions, machine.usbController);
    this.state.usbControllerSel = this.indexOfValue(this.state.usbControllerOptions, machine.usbController);
    this.state.extraParams = machine.extraParams ?? '';

    this.state.setMachineLoaded(true);
    this.state.storageDevices = StorageDevices.rebuild(machine);
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  /** 控制器状态 -> 状态卡片/可用性。 */
  private applyStatus(status: MachineStatus): void {
    switch (status) {
      case MachineStatus.Running:
        this.state.statusKind = 1;
        this.state.statusRunning = true;
        this.state.machineEnabled = false;
        this.state.addDeviceEnabled = false;
        break;
      case MachineStatus.Paused:
        this.state.statusKind = 2;
        this.state.statusRunning = false;
        this.state.machineEnabled = true;
        this.state.addDeviceEnabled = true;
        break;
      case MachineStatus.Saving:
        this.state.statusKind = 3;
        this.state.statusRunning = true;
        this.state.machineEnabled = false;
        this.state.addDeviceEnabled = false;
        break;
      default:
        this.state.statusKind = 0;
        this.state.statusRunning = false;
        this.state.machineEnabled = this.state.machineSel >= 2;
        this.state.addDeviceEnabled = this.state.machineSel >= 2;
        break;
    }
  }

  private clearMachineState(): void {
    MachineController.getInstance().clearMachine();
    this.savedMachineNames = [];
    this.state.machines = ['未选择虚拟机', '新建虚拟机…'];
    this.state.machineSel = 0;
    this.state.storageDevices = [];
    this.state.setMachineLoaded(false);
    this.applyStatus(MachineStatus.Stopped);
  }

  private async selectMachine(name: string): Promise<void> {
    const machine: Machine | null = await MachineController.getInstance().loadMachine(name);
    if (machine === null) {
      this.state.machineSel = 0;
      this.state.setMachineLoaded(false);
      this.state.storageDevices = [];
      return;
    }
    await this.reloadMachines();
    const selected: number = this.savedMachineNames.indexOf(name);
    this.state.machineSel = selected >= 0 ? selected + 2 : 0;
    this.bindMachine(machine);
  }

  private withValue(options: string[], value: string): string[] {
    if (value.length === 0 || this.indexOfValue(options, value) >= 0) {
      return options;
    }
    return options.concat([value]);
  }

  private indexOfValue(options: string[], value: string): number {
    for (let i = 0; i < options.length; i++) {
      if (options[i] === value) {
        return i;
      }
    }
    return 0;
  }

  private persist(property: MachineProperty, value: string): void {
    MachineController.getInstance().updateField(property, value);
  }

  build() {
    Column() {
      this.TopBar()

      List() {
        ListItem() {
          this.MachineCard()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.StatusCard()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.ControlButtons()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: 16 })

        ListItem() {
          this.UISection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.BoardSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.StorageSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.BootSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.GraphicsSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.AudioSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.NetworkSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: LimboSize.cardGap })

        ListItem() {
          this.AdvancedSection()
        }
        .padding({ left: LimboSize.pageHorizontal, right: LimboSize.pageHorizontal, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .padding({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.limbo_window_background'))
  }

  // ============================================================
  // 顶部栏
  // ============================================================

  @Builder
  TopBar() {
    Row() {
      Image($r('app.media.limbo'))
        .width(LimboSize.icon)
        .height(LimboSize.icon)
        .objectFit(ImageFit.Contain)

      Text($r('app.string.app_name'))
        .fontSize(LimboFont.title3)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .margin({ left: 10 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button({ type: ButtonType.Circle }) {
        Text('⋮')
          .fontSize(LimboFont.title3)
          .fontColor($r('app.color.limbo_text_primary'))
      }
      .width(40)
      .height(40)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .bindMenu(this.topMenu())
    }
    .width('100%')
    .height(LimboSize.topBarHeight)
    .padding({ left: 16, right: 8 })
  }

  private topMenu(): MenuElement[] {
    const items: MenuElement[] = [
      {
        value: $r('app.string.create_machine'),
        action: () => {
          this.createMachine();
        }
      },
      {
        value: $r('app.string.delete_machine'),
        action: () => {
          this.deleteMachine();
        }
      },
      {
        value: $r('app.string.help'),
        action: () => {
          promptAction.showToast({ message: $r('app.string.feature_not_migrated') });
        }
      }
    ];
    return items;
  }

  // ============================================================
  // 虚拟机卡片 / 状态卡片 / 控制按钮
  // ============================================================

  @Builder
  MachineCard() {
    Column() {
      LimboDropdown({
        title: $r('app.string.machine_header'),
        icon: $r('app.media.limbo'),
        summary: '模拟架构：' + this.state.archLabel,
        options: this.state.machines,
        selectedIndex: this.state.machineSel,
        isEnabled: this.state.machineEnabled,
        onSelected: (index: number) => {
          this.onMachineSelected(index);
        }
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(LimboSize.cardRadius)
    .clip(true)
  }

  @Builder
  StatusCard() {
    Row() {
      StatusDot({ dotColor: this.statusColor() })
      Text(this.statusText())
        .fontSize(LimboFont.title3)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.limbo_text_primary'))
        .margin({ left: 12 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
    .backgroundColor($r('app.color.limbo_card'))
    .borderRadius(LimboSize.cardRadius)
  }

  @Builder
  ControlButtons() {
    Row({ space: 12 }) {
      this.ControlButton(new ControlButtonOptions($r('app.media.play'),
        $r('app.color.limbo_primary_container'), () => {
          this.startVm();
        }))
      this.ControlButton(new ControlButtonOptions($r('app.media.pause'),
        $r('app.color.limbo_secondary_container'), () => {
          this.pauseVm();
        }))
      this.ControlButton(new ControlButtonOptions($r('app.media.stop'),
        $r('app.color.limbo_error_container'), () => {
          this.stopVm();
        }))
      this.ControlButton(new ControlButtonOptions($r('app.media.reset'),
        $r('app.color.limbo_tertiary_container'), () => {
          this.restartVm();
        }))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ControlButton(options: ControlButtonOptions) {
    Button({ type: ButtonType.Circle }) {
      Image(options.icon)
        .width(LimboSize.controlIcon)
        .height(LimboSize.controlIcon)
        .objectFit(ImageFit.Contain)
    }
    .width(LimboSize.controlButton)
    .height(LimboSize.controlButton)
    .padding(0)
    .backgroundColor(options.background)
    .onClick(() => {
      options.action();
    })
  }

  // ============================================================
  // 用户界面分区
  // ============================================================

  @Builder
  UISection() {
    SectionCard({
      title: $r('app.string.title_user_interface'),
      icon: $r('app.media.ui'),
      summary: this.uiSummary(),
      collapsed: this.state.uiCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.UI);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_display'),
        icon: $r('app.media.ui'),
        options: this.state.uiOptions,
        selectedIndex: this.state.uiSel,
        isEnabled: this.state.uiEnabled,
        onSelected: (index: number) => {
          this.state.uiSel = index;
          this.persist(MachineProperty.UI, this.optionAt(this.state.uiOptions, index));
        }
      })
      LimboDropdown({
        title: $r('app.string.title_keyboard'),
        icon: $r('app.media.keyboard'),
        options: this.state.keyboardOptions,
        selectedIndex: this.state.keyboardSel,
        isEnabled: this.state.keyboardEnabled,
        onSelected: (index: number) => {
          this.state.keyboardSel = index;
          this.persist(MachineProperty.KEYBOARD, this.optionAt(this.state.keyboardOptions, index));
        }
      })
      LimboDropdown({
        title: $r('app.string.title_mouse'),
        icon: $r('app.media.mouse'),
        options: this.state.mouseOptions,
        selectedIndex: this.state.mouseSel,
        isEnabled: this.state.mouseEnabled,
        onSelected: (index: number) => {
          this.state.mouseSel = index;
          this.persist(MachineProperty.MOUSE, this.optionAt(this.state.mouseOptions, index));
        }
      })
    }
  }

  // ============================================================
  // 主板分区
  // ============================================================

  @Builder
  BoardSection() {
    SectionCard({
      title: $r('app.string.title_board'),
      icon: $r('app.media.machinetype'),
      summary: this.boardSummary(),
      collapsed: this.state.boardCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.BOARD);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_machine_type'),
        icon: $r('app.media.machinetype'),
        options: this.state.machineTypeOptions,
        selectedIndex: this.state.machineTypeSel,
        isEnabled: this.state.machineTypeEnabled,
        onSelected: (index: number) => {
          this.state.machineTypeSel = index;
          this.persist(MachineProperty.MACHINETYPE, this.optionAt(this.state.machineTypeOptions, index));
        }
      })
      LimboDropdown({
        title: $r('app.string.label_cpu_model'),
        icon: $r('app.media.cpu'),
        options: this.state.cpuOptions,
        selectedIndex: this.state.cpuSel,
        isEnabled: this.state.cpuEnabled,
        onSelected: (index: number) => {
          this.state.cpuSel = index;
          this.persist(MachineProperty.CPU, this.optionAt(this.state.cpuOptions, index));
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_cpu_cores'),
        value: this.state.cpuNumValue,
        numeric: true,
        isEnabled: this.state.cpuNumEnabled,
        onValueChange: (value: string) => {
          this.state.cpuNumValue = this.digitsOnly(value, 3);
          this.persist(MachineProperty.CPUNUM, this.state.cpuNumValue);
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_ram_memory_mb'),
        value: this.state.ramValue,
        numeric: true,
        isEnabled: this.state.ramEnabled,
        onValueChange: (value: string) => {
          this.state.ramValue = this.digitsOnly(value, 6);
          this.persist(MachineProperty.MEMORY, this.state.ramValue);
        }
      })
      SwitchRow({
        label: $r('app.string.label_disable_i8042'),
        checked: this.state.disableI8042,
        isEnabled: this.state.disableI8042Enabled,
        onCheckedChange: (checked: boolean) => {
          this.state.disableI8042 = checked;
          this.persist(MachineProperty.DISABLE_I8042, checked ? '1' : '0');
        }
      })
      SwitchRow({
        label: $r('app.string.label_enable_nvram'),
        checked: this.state.enableNvram,
        isEnabled: this.state.enableNvramEnabled,
        onCheckedChange: (checked: boolean) => {
          this.state.enableNvram = checked;
          this.persist(MachineProperty.ENABLE_NVRAM, checked ? '1' : '0');
        }
      })
      LimboDropdown({
        title: $r('app.string.label_nvram_file'),
        icon: $r('app.media.sysfile'),
        options: this.state.nvramOptions,
        selectedIndex: this.state.nvramSel,
        isEnabled: this.state.enableNvram && this.state.nvramEnabled,
        onSelected: (index: number) => {
          this.state.nvramSel = index;
        }
      })
      LimboDropdown({
        title: $r('app.string.label_accel'),
        icon: $r('app.media.cpu'),
        options: this.state.accelOptions,
        selectedIndex: this.state.accelSel,
        isEnabled: this.state.accelEnabled,
        onSelected: (index: number) => {
          this.state.accelSel = index;
          this.state.showMTTCGSwitch = this.optionAt(this.state.accelOptions, index) === 'TCG';
          this.state.enableMTTCGEnabled = this.state.showMTTCGSwitch;
          const accelValues: string[] = ArchDefinitions.getAccelValues();
          this.persist(MachineProperty.ACCEL_MODE, this.optionAt(accelValues, index));
        }
      })
      if (this.state.showMTTCGSwitch) {
        SwitchRow({
          label: $r('app.string.label_enable_mttcg'),
          checked: this.state.enableMTTCG,
          isEnabled: this.state.enableMTTCGEnabled,
          onCheckedChange: (checked: boolean) => {
            this.state.enableMTTCG = checked;
            this.persist(MachineProperty.ENABLE_MTTCG, checked ? '1' : '0');
          }
        })
      }
      SwitchRow({
        label: $r('app.string.label_disable_hpet'),
        checked: this.state.disableHPET,
        isEnabled: this.state.disableHPETEnabled,
        onCheckedChange: (checked: boolean) => {
          this.state.disableHPET = checked;
          this.persist(MachineProperty.DISABLE_HPET, checked ? '1' : '0');
        }
      })
      SwitchRow({
        label: $r('app.string.label_disable_tsc'),
        checked: this.state.disableTSC,
        isEnabled: this.state.disableTSCEnabled,
        onCheckedChange: (checked: boolean) => {
          this.state.disableTSC = checked;
          this.persist(MachineProperty.DISABLE_TSC, checked ? '1' : '0');
        }
      })
      SwitchRow({
        label: $r('app.string.label_disable_acpi'),
        checked: this.state.disableACPI,
        isEnabled: this.state.disableACPIEnabled,
        onCheckedChange: (checked: boolean) => {
          this.state.disableACPI = checked;
          this.persist(MachineProperty.DISABLE_ACPI, checked ? '1' : '0');
        }
      })
    }
  }

  // ============================================================
  // 存储设备分区
  // ============================================================

  @Builder
  StorageSection() {
    SectionCard({
      title: $r('app.string.title_storage_devices'),
      icon: $r('app.media.harddisk'),
      summary: this.storageSummary(),
      collapsed: this.state.storageCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.STORAGE);
      }
    }) {
      ForEach(this.state.storageDevices, (device: StorageDeviceUiState) => {
        StorageDeviceRow({
          device: device,
          onRowClick: () => {
            this.openEditor(device.tag, false);
          }
        })
      }, (device: StorageDeviceUiState) => device.tag.toString())

      Row() {
        Button($r('app.string.add_storage_device'))
          .width('100%')
          .height(40)
          .fontSize(LimboFont.body)
          .fontColor($r('app.color.limbo_on_primary'))
          .backgroundColor($r('app.color.limbo_primary'))
          .enabled(this.state.addDeviceEnabled)
          .onClick(() => {
            this.addDevice();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
  }

  // ============================================================
  // 启动分区
  // ============================================================

  @Builder
  BootSection() {
    SectionCard({
      title: $r('app.string.title_boot'),
      icon: $r('app.media.drives'),
      summary: this.bootSummary(),
      collapsed: this.state.bootCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.BOOT);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_boot_from_device'),
        icon: $r('app.media.drives'),
        options: this.state.bootOptions,
        selectedIndex: this.state.bootSel,
        isEnabled: this.state.bootEnabled,
        onSelected: (index: number) => {
          this.state.bootSel = index;
          this.persist(MachineProperty.BOOT_CONFIG, this.optionAt(this.state.bootOptions, index));
        }
      })
      LimboDropdown({
        title: $r('app.string.label_bios'),
        icon: $r('app.media.sysfile'),
        options: this.state.biosOptions,
        selectedIndex: this.state.biosSel,
        isEnabled: this.state.biosEnabled,
        onSelected: (index: number) => {
          this.state.biosSel = index;
          const value: string = this.optionAt(this.state.biosOptions, index);
          this.persist(MachineProperty.BIOS, value === '默认' ? '' : value);
        }
      })
      LimboDropdown({
        title: $r('app.string.label_kernel'),
        icon: $r('app.media.sysfile'),
        options: this.state.kernelOptions,
        selectedIndex: this.state.kernelSel,
        isEnabled: this.state.kernelEnabled,
        onSelected: (index: number) => {
          this.state.kernelSel = index;
          const value: string = this.optionAt(this.state.kernelOptions, index);
          this.persist(MachineProperty.KERNEL, value === 'None' || value === '打开' ? '' : value);
        }
      })
      LimboDropdown({
        title: $r('app.string.label_initrd'),
        icon: $r('app.media.sysfile'),
        options: this.state.initrdOptions,
        selectedIndex: this.state.initrdSel,
        isEnabled: this.state.initrdEnabled,
        onSelected: (index: number) => {
          this.state.initrdSel = index;
          const value: string = this.optionAt(this.state.initrdOptions, index);
          this.persist(MachineProperty.INITRD, value === 'None' || value === '打开' ? '' : value);
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_append'),
        value: this.state.append,
        placeholder: 'root=/dev/sda1',
        isEnabled: this.state.appendEnabled,
        onValueChange: (value: string) => {
          this.state.append = value;
          this.persist(MachineProperty.APPEND, value);
        }
      })
    }
  }

  // ============================================================
  // 图形分区
  // ============================================================

  @Builder
  GraphicsSection() {
    SectionCard({
      title: $r('app.string.title_graphics'),
      icon: $r('app.media.screen'),
      summary: this.graphicsSummary(),
      collapsed: this.state.graphicsCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.GRAPHICS);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_video_display'),
        icon: $r('app.media.screen'),
        options: this.state.vgaOptions,
        selectedIndex: this.state.vgaSel,
        isEnabled: this.state.vgaEnabled,
        onSelected: (index: number) => {
          this.state.vgaSel = index;
          this.persist(MachineProperty.VGA, this.optionAt(this.state.vgaOptions, index));
        }
      })
    }
  }

  // ============================================================
  // 音频分区
  // ============================================================

  @Builder
  AudioSection() {
    SectionCard({
      title: $r('app.string.title_audio'),
      icon: $r('app.media.audiocard'),
      summary: this.audioSummary(),
      collapsed: this.state.audioCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.AUDIO);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_sound_card'),
        icon: $r('app.media.audiocard'),
        options: this.state.soundOptions,
        selectedIndex: this.state.soundSel,
        isEnabled: this.state.soundEnabled,
        onSelected: (index: number) => {
          this.state.soundSel = index;
          const value: string = this.optionAt(this.state.soundOptions, index);
          this.persist(MachineProperty.SOUNDCARD, value === 'None' ? '' : value);
        }
      })
    }
  }

  // ============================================================
  // 网络分区
  // ============================================================

  @Builder
  NetworkSection() {
    SectionCard({
      title: $r('app.string.title_network'),
      icon: $r('app.media.network'),
      summary: this.networkSummary(),
      collapsed: this.state.networkCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.NETWORK);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_network'),
        icon: $r('app.media.network'),
        options: this.state.netOptions,
        selectedIndex: this.state.netSel,
        isEnabled: this.state.netEnabled,
        onSelected: (index: number) => {
          this.state.netSel = index;
          const hasNetwork: boolean = index > 0 && this.state.netEnabled;
          this.state.nicEnabled = hasNetwork;
          this.state.dnsEnabled = hasNetwork;
          this.state.hostFwdEnabled = hasNetwork;
          const value: string = this.optionAt(this.state.netOptions, index);
          this.persist(MachineProperty.NETCONFIG, value === 'None' ? '' : value);
        }
      })
      LimboDropdown({
        title: $r('app.string.label_network_card'),
        icon: $r('app.media.networkcard'),
        options: this.state.nicOptions,
        selectedIndex: this.state.nicSel,
        isEnabled: this.state.nicEnabled,
        onSelected: (index: number) => {
          this.state.nicSel = index;
          this.persist(MachineProperty.NICCONFIG, this.optionAt(this.state.nicOptions, index));
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_dns_server'),
        value: this.state.dns,
        placeholder: '8.8.8.8',
        isEnabled: this.state.dnsEnabled,
        onValueChange: (value: string) => {
          this.state.dns = value;
          LimboSettingsManager.setDnsServer(value);
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_host_forward'),
        value: this.state.hostFwd,
        placeholder: 'tcp:2222:22',
        isEnabled: this.state.hostFwdEnabled,
        onValueChange: (value: string) => {
          this.state.hostFwd = value;
          this.persist(MachineProperty.HOSTFWD, value);
        }
      })
    }
  }

  // ============================================================
  // 高级分区
  // ============================================================

  @Builder
  AdvancedSection() {
    SectionCard({
      title: $r('app.string.title_advanced'),
      icon: $r('app.media.advanced'),
      summary: this.advancedSummary(),
      collapsed: this.state.advancedCollapsed,
      onToggle: () => {
        this.state.toggleSection(Section.ADVANCED);
      }
    }) {
      LimboDropdown({
        title: $r('app.string.label_usb_controller'),
        icon: $r('app.media.advanced'),
        options: this.state.usbControllerOptions,
        selectedIndex: this.state.usbControllerSel,
        isEnabled: this.state.usbControllerEnabled,
        onSelected: (index: number) => {
          this.state.usbControllerSel = index;
          this.persist(MachineProperty.USB_CONTROLLER,
            this.optionAt(this.state.usbControllerOptions, index));
        }
      })
      LabeledTextFieldRow({
        label: $r('app.string.label_extra_qemu_params'),
        value: this.state.extraParams,
        isEnabled: this.state.extraParamsEnabled,
        onValueChange: (value: string) => {
          this.state.extraParams = value;
          this.persist(MachineProperty.EXTRA_PARAMS, value);
        }
      })
    }
  }

  // ============================================================
  // 交互逻辑（对应 Android LimboUiCallbacks 的本地实现）
  // ============================================================

  private onMachineSelected(index: number): void {
    if (index === 0) {
      this.clearMachine();
      return;
    }
    if (index === 1) {
      this.createMachine();
      return;
    }
    this.selectMachine(this.state.machines[index]);
  }

  private clearMachine(): void {
    MachineController.getInstance().clearMachine();
    this.state.machineSel = 0;
    this.state.storageDevices = [];
    this.state.setMachineLoaded(false);
    this.applyStatus(MachineStatus.Stopped);
  }

  private async createMachine(): Promise<void> {
    let name: string = '新虚拟机';
    let seq: number = 1;
    while (this.savedMachineNames.indexOf(name) >= 0) {
      seq++;
      name = '新虚拟机 ' + seq;
    }
    const machine: Machine | null = await MachineController.getInstance().createMachine(name);
    if (machine === null) {
      promptAction.showToast({ message: $r('app.string.machine_name_exists') });
      return;
    }
    await this.reloadMachines();
    const index: number = this.savedMachineNames.indexOf(name);
    this.state.machineSel = index >= 0 ? index + 2 : 0;
    this.bindMachine(machine);
    promptAction.showToast({ message: '已创建 ' + name });
  }

  private async deleteMachine(): Promise<void> {
    if (this.state.machineSel < 2) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }
    const deleted: boolean = await MachineController.getInstance().deleteMachine();
    if (!deleted) {
      promptAction.showToast({ message: $r('app.string.machine_delete_failed') });
      return;
    }
    await this.reloadMachines();
    this.state.machineSel = 0;
    this.state.storageDevices = [];
    this.state.setMachineLoaded(false);
    this.applyStatus(MachineStatus.Stopped);
    promptAction.showToast({ message: $r('app.string.machine_deleted') });
  }

  private async startVm(): Promise<void> {
    const machine: Machine | null = MachineController.getInstance().getMachine();
    if (this.state.machineSel < 2 || machine === null) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }

    // 有原生 QEMU 引擎时：SDL 显示需要先建立 XComponent 的 SDL 原生节点
    if (VmExecutor.getInstance().isAvailable()) {
      if (machine.getUI() === 'SDL') {
        try {
          await router.pushUrl({ url: 'pages/VmDisplay' });
        } catch (err) {
          console.error(`open VmDisplay failed: ${JSON.stringify(err)}`);
        }
        return;
      }
      await MachineController.getInstance().start();
      this.applyStatus(MachineController.getInstance().getStatus());
      if (MachineController.getInstance().getStatus() !== MachineStatus.Running) {
        const error: string = VmExecutor.getInstance().getLastError();
        promptAction.showToast({ message: error.length > 0 ? error : '虚拟机启动失败' });
      }
      return;
    }

    // 未打包 QEMU 引擎时保持原有的状态机演示
    await MachineController.getInstance().start();
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  private async pauseVm(): Promise<void> {
    if (MachineController.getInstance().getStatus() !== MachineStatus.Running) {
      promptAction.showToast({ message: $r('app.string.vm_not_running') });
      return;
    }
    await MachineController.getInstance().pause();
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  private async stopVm(): Promise<void> {
    const status: MachineStatus = MachineController.getInstance().getStatus();
    if (status !== MachineStatus.Running && status !== MachineStatus.Paused) {
      promptAction.showToast({ message: $r('app.string.vm_not_running') });
      return;
    }
    await MachineController.getInstance().stop();
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  private async restartVm(): Promise<void> {
    const status: MachineStatus = MachineController.getInstance().getStatus();
    if (status !== MachineStatus.Running && status !== MachineStatus.Paused) {
      promptAction.showToast({ message: $r('app.string.vm_not_running') });
      return;
    }
    await MachineController.getInstance().restart();
    this.applyStatus(MachineController.getInstance().getStatus());
  }

  /** 添加设备：选出第一个未达数量上限的类型，插入列表后进入编辑页。 */
  private addDevice(): void {
    if (MachineController.getInstance().getMachine() === null || this.state.machineSel < 2) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }
    if (MachineController.getInstance().getStatus() === MachineStatus.Running) {
      promptAction.showToast({ message: $r('app.string.vm_running') });
      return;
    }
    const typeIndex: number = this.firstAvailableType();
    if (typeIndex < 0) {
      promptAction.showToast({ message: $r('app.string.device_already_exists') });
      return;
    }
    const device: StorageDeviceUiState = new StorageDeviceUiState();
    device.tag = this.nextDeviceTag();
    device.applyType(typeIndex);
    this.state.storageDevices = this.state.storageDevices.concat([device]);
    this.openEditor(device.tag, true);
  }

  /** 生成不与现有行冲突的 tag（重建列表后 tag 从 0 重新开始）。 */
  private nextDeviceTag(): number {
    let maxTag: number = -1;
    for (let i = 0; i < this.state.storageDevices.length; i++) {
      if (this.state.storageDevices[i].tag > maxTag) {
        maxTag = this.state.storageDevices[i].tag;
      }
    }
    return maxTag + 1;
  }

  private firstAvailableType(): number {
    for (let typeIndex = 0; typeIndex < DEVICE_TYPES.length; typeIndex++) {
      let count: number = 0;
      for (let i = 0; i < this.state.storageDevices.length; i++) {
        if (this.state.storageDevices[i].typeSel === typeIndex) {
          count++;
        }
      }
      if (count < DEVICE_TYPES[typeIndex].maxCount) {
        return typeIndex;
      }
    }
    return -1;
  }

  private async openEditor(tag: number, isNew: boolean): Promise<void> {
    if (MachineController.getInstance().getMachine() === null) {
      promptAction.showToast({ message: $r('app.string.select_machine_first') });
      return;
    }
    if (MachineController.getInstance().getStatus() === MachineStatus.Running) {
      promptAction.showToast({ message: $r('app.string.vm_running') });
      return;
    }
    const params: StorageEditorParams = { tag: tag, isNew: isNew };
    try {
      await router.pushUrl({ url: 'pages/StorageDeviceEditor', params: params });
    } catch (err) {
      console.error(`openEditor failed: ${JSON.stringify(err)}`);
    }
  }

  // ============================================================
  // 摘要文本（格式与 Android build*Summary 一致）
  // ============================================================

  private optionAt(options: string[], index: number): string {
    if (index >= 0 && index < options.length) {
      return options[index];
    }
    return '';
  }

  private uiSummary(): string {
    let text: string = '显示: ' + this.optionAt(this.state.uiOptions, this.state.uiSel);
    text += ', 键盘: ' + this.optionAt(this.state.keyboardOptions, this.state.keyboardSel);
    text += ', 鼠标: ' + this.optionAt(this.state.mouseOptions, this.state.mouseSel);
    return text;
  }

  private boardSummary(): string {
    let text: string = '机型: ' + this.optionAt(this.state.machineTypeOptions, this.state.machineTypeSel);
    text += ', CPU: ' + this.optionAt(this.state.cpuOptions, this.state.cpuSel);
    text += ', ' + this.state.cpuNumValue + ' CPU';
    text += ', ' + this.state.ramValue + ' MB';
    text += ', 加速器: ' + this.optionAt(this.state.accelOptions, this.state.accelSel);
    if (this.state.disableACPI) {
      text += ', 禁用 ACPI';
    }
    if (this.state.disableHPET) {
      text += ', 禁用 HPET';
    }
    if (this.state.disableTSC) {
      text += ', 禁用 TSC';
    }
    return text;
  }

  private storageSummary(): string {
    if (this.state.storageDevices.length === 0) {
      return '无';
    }
    const parts: string[] = [];
    for (let i = 0; i < this.state.storageDevices.length; i++) {
      const device: StorageDeviceUiState = this.state.storageDevices[i];
      const image: string = device.imageDisplay();
      parts.push(device.typeLabel() + ': ' + (image.length > 0 ? image : '空'));
    }
    return parts.join(', ');
  }

  private bootSummary(): string {
    let text: string = '启动: ' + this.optionAt(this.state.bootOptions, this.state.bootSel);
    const bios: string = this.optionAt(this.state.biosOptions, this.state.biosSel);
    if (bios.length > 0 && bios !== '默认') {
      text += ', BIOS: ' + bios;
    }
    const kernel: string = this.optionAt(this.state.kernelOptions, this.state.kernelSel);
    if (kernel.length > 0 && kernel !== 'None' && kernel !== '打开') {
      text += ', 内核: ' + kernel;
    }
    const initrd: string = this.optionAt(this.state.initrdOptions, this.state.initrdSel);
    if (initrd.length > 0 && initrd !== 'None' && initrd !== '打开') {
      text += ', Initrd: ' + initrd;
    }
    if (this.state.append.length > 0) {
      text += ', 附加参数: ' + this.state.append;
    }
    return text;
  }

  private graphicsSummary(): string {
    return '显卡: ' + this.optionAt(this.state.vgaOptions, this.state.vgaSel);
  }

  private audioSummary(): string {
    return '声卡: ' + this.optionAt(this.state.soundOptions, this.state.soundSel);
  }

  private networkSummary(): string {
    const net: string = this.optionAt(this.state.netOptions, this.state.netSel);
    let text: string = '网络: ' + net;
    if (net !== 'None') {
      text += ', 网卡: ' + this.optionAt(this.state.nicOptions, this.state.nicSel);
      if (this.state.dns.length > 0) {
        text += ', DNS 服务器: ' + this.state.dns;
      }
      if (this.state.hostFwd.length > 0) {
        text += ', 主机转发: ' + this.state.hostFwd;
      }
    }
    return text;
  }

  private advancedSummary(): string {
    const parts: string[] = [];
    const usb: string = this.optionAt(this.state.usbControllerOptions, this.state.usbControllerSel);
    if (usb.length > 0 && usb !== 'None') {
      parts.push('USB 控制器: ' + usb);
    }
    if (this.state.extraParams.length > 0) {
      parts.push('附加参数: ' + this.state.extraParams);
    }
    return parts.join(', ');
  }

  // ============================================================
  // 其它工具方法
  // ============================================================

  private statusColor(): Resource {
    switch (this.state.statusKind) {
      case 1:
        return $r('app.color.status_running');
      case 2:
        return $r('app.color.status_paused');
      case 3:
        return $r('app.color.status_saving');
      default:
        return $r('app.color.status_stopped');
    }
  }

  private statusText(): ResourceStr {
    if (this.state.machineSel === 0) {
      return $r('app.string.no_machine_selected');
    }
    switch (this.state.statusKind) {
      case 1:
        return $r('app.string.status_running');
      case 2:
        return $r('app.string.status_paused');
      case 3:
        return $r('app.string.status_saving');
      default:
        return $r('app.string.status_stopped');
    }
  }

  private digitsOnly(value: string, maxLength: number): string {
    const digits: string = value.replace(/[^0-9]/g, '');
    return digits.length > maxLength ? digits.substring(0, maxLength) : digits;
  }
}

/**
 * 存储设备摘要行（对应 Android LimboMainScreen 的 StorageDeviceSummaryRow）。
 * 使用 @ObjectLink 观察单个设备对象，编辑页写回后自动刷新。
 */
@Component
struct StorageDeviceRow {
  @ObjectLink device: StorageDeviceUiState;
  onRowClick: () => void = () => {
  };

  build() {
    Row() {
      Image($r('app.media.harddisk'))
        .width(LimboSize.iconSmall)
        .height(LimboSize.iconSmall)
        .objectFit(ImageFit.Contain)

      Column() {
        Text(this.device.typeLabel())
          .fontSize(LimboFont.main)
          .fontColor($r('app.color.limbo_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.device.imageDisplay().length > 0) {
          Text(this.device.imageDisplay())
            .fontSize(LimboFont.footnote)
            .fontColor($r('app.color.limbo_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Text('›')
        .fontSize(LimboFont.title4)
        .fontColor($r('app.color.limbo_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      this.onRowClick();
    })
  }
}
