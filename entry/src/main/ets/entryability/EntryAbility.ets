/**
 * 应用入口 Ability：加载主页面、初始化数据层、监听系统深浅色（auto 主题用）。
 * 集成 AGC 隐私托管（AppGallery Kit 隐私管理服务）：启动时先确认隐私声明签署状态，
 * 未同意则拉起标准化隐私弹窗，用户同意后再初始化业务，确保上架合规。
 */
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { privacyManager } from '@kit.AppGalleryKit'
import { BusinessError } from '@kit.BasicServicesKit'
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
    this.startWithPrivacyCheck(windowStage)
  }

  /** 隐私声明流程：已同意则直接初始化业务，未同意/协议更新则拉起 AGC 标准化隐私弹窗 */
  private startWithPrivacyCheck(windowStage: window.WindowStage): void {
    let agreed: boolean = false
    try {
      const results: privacyManager.AppPrivacyResult[] = privacyManager.getAppPrivacyResult()
      for (let i = 0; i < results.length; i++) {
        if (results[i]['result'] === 'FULL_MODE_AGREED') {
          agreed = true
          break
        }
      }
    } catch (e) {
      // 查询签署状态异常（如未接入托管服务）时不阻塞启动，直接进入业务
      hilog.warn(0x0000, TAG, 'query privacy result failed, bootstrap directly')
      agreed = true
    }
    if (agreed) {
      this.bootstrap(windowStage)
      return
    }
    try {
      privacyManager.requestAppPrivacyConsent(this.context)
        .then(() => {
          hilog.info(0x0000, TAG, 'privacy consent agreed')
          this.bootstrap(windowStage)
        })
        .catch((err: BusinessError<Object>) => {
          hilog.error(0x0000, TAG, `privacy consent rejected: code=${err.code}, message=${err.message}`)
          // 用户拒绝隐私声明：按托管服务规范退出应用
          this.terminateSelf()
        })
    } catch (e) {
      hilog.warn(0x0000, TAG, 'request privacy consent failed, bootstrap directly')
      this.bootstrap(windowStage)
    }
  }

  /** 业务启动：初始化数据层（RelationalStore + Preferences）、应用主题并加载首页 */
  private bootstrap(windowStage: window.WindowStage): void {
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
      const cm: ConfigurationConstant.ColorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
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
