/**
 * 应用入口 Ability：加载主页面、初始化数据层、监听系统深浅色（auto 主题用）。
 */
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { AppStore } from '../store/AppStore'

const TAG: string = 'Jijian'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'EntryAbility onCreate')
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'EntryAbility onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 初始化数据层（RelationalStore + Preferences）
    const store: AppStore = AppStore.getInstance()
    store.init(this.context)
      .then(() => {
        hilog.info(0x0000, TAG, 'store init ok')
        // 数据层就绪后按 settings.theme 应用窗口颜色模式
        store.applyThemeToWindow()
      })
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, `store init failed: ${e.message}`)
      })
    // 读取初始系统深浅色
    try {
      const cm: ConfigurationConstant.ColorMode = this.context.config.colorMode
      store.setSystemDark(cm === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      // 绑定主窗口，用于主题切换时修改窗口颜色模式
      const win: window.Window = windowStage.getMainWindowSync()
      store.setWindow(win)
    } catch (e) {
      // 窗口属性读取失败忽略
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, `loadContent failed: ${JSON.stringify(err)}`)
        return
      }
      hilog.info(0x0000, TAG, 'loadContent succeed')
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'onForeground')
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, 'onBackground')
  }

  /** 系统配置变化（深浅色切换等） */
  onConfigurationUpdate(newConfig: Configuration): void {
    const dark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    const store: AppStore = AppStore.getInstance()
    store.setSystemDark(dark)
    // auto 主题下随系统切换窗口深浅色
    store.applyThemeToWindow()
  }
}
