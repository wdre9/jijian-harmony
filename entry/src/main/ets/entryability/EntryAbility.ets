/**
 * 应用入口 Ability：加载主页面、初始化数据层、监听系统深浅色（auto 主题用）。
 */
import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant'
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
      })
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, `store init failed: ${e.message}`)
      })
    // 读取初始系统深浅色
    try {
      const win: window.Window = windowStage.getMainWindowSync()
      const cm: number = win.getWindowProperties().colorMode
      store.setSystemDark(cm === 1)
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
    AppStore.getInstance().setSystemDark(dark)
  }
}
