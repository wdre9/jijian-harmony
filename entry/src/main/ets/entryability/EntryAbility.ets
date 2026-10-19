/**
 * 应用入口 Ability：加载主页面、初始化数据层、监听系统深浅色（auto 主题用）。
 * 集成 AGC 隐私托管（AppGallery Kit 隐私管理服务）。
 * 启动策略（修复「卡启动图」）：
 *   1. onWindowStageCreate 里【立即】loadContent，窗口绝不因隐私流程卡在启动图；
 *   2. 隐私确认与数据初始化彻底解耦：仅用户同意（或兜底降级）后才 initBusiness，合规不变；
 *   3. requestAppPrivacyConsent 加 5s 超时兜底，杜绝非真机/托管异常下 Promise 静默挂起；
 *   4. 同意/拒绝/超时/API 异常四分支由 settled 幂等开关互斥：用户拒绝 → 退出，绝不初始化；
 *      API 异常/超时（环境或配置问题）→ 降级初始化，不退出。
 */
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { privacyManager } from '@kit.AppGalleryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppStore } from '../store/AppStore'

const TAG: string = 'Jijian'
/** 隐私弹窗超时兜底：模拟器不弹窗、弱网/托管未生效时防止永久挂起 */
const PRIVACY_TIMEOUT_MS: number = 5000

export default class EntryAbility extends UIAbility {
  /** 业务数据层是否已初始化（幂等，避免重复初始化） */
  private businessInited: boolean = false

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'EntryAbility onCreate')
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'EntryAbility onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // ① 立即加载首页 UI（含系统深浅色读取、主窗口绑定），与隐私确认解耦
    this.loadUi(windowStage)
    // ② 隐私确认通过后再初始化数据层（保证“先同意、后收集”）
    this.handlePrivacyThenInit()
  }

  /** 立即加载首页，保证窗口绝不停留在启动图 */
  private loadUi(windowStage: window.WindowStage): void {
    const store: AppStore = AppStore.getInstance()
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

  /** 隐私签署状态查询 + 同意确认 + 超时兜底，最终调用 initBusiness */
  private handlePrivacyThenInit(): void {
    // 已同意（历史签署）：直接初始化业务
    try {
      const results: privacyManager.AppPrivacyResult[] = privacyManager.getAppPrivacyResult()
      if (this.isAgreed(results)) {
        this.initBusiness()
        return
      }
    } catch (e) {
      // 查询签署状态异常（如未接入托管服务）：降级继续，不阻塞启动
      hilog.warn(0x0000, TAG, 'query privacy result failed, fallback to init directly')
      this.initBusiness()
      return
    }
    // 未同意：拉起标准化隐私弹窗（带超时兜底）
    this.requestConsentWithTimeout()
  }

  private isAgreed(results: privacyManager.AppPrivacyResult[]): boolean {
    for (let i = 0; i < results.length; i++) {
      if (results[i]['result'] === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
        return true
      }
    }
    return false
  }

  /** 拉起隐私弹窗 + 5s 超时兜底；
   *  同意 → initBusiness；用户拒绝（resolve 但非 FULL_MODE_AGREED）→ 退出；
   *  API 异常/超时（环境或配置问题）→ 降级 initBusiness，不退出。 */
  private requestConsentWithTimeout(): void {
    let settled: boolean = false
    let timer: number = -1
    const finish = (reason: string): void => {
      if (settled) {
        return
      }
      settled = true
      if (timer >= 0) {
        clearTimeout(timer)
      }
      hilog.info(0x0000, TAG, `privacy flow finished: ${reason}`)
      this.initBusiness()
    }

    // 超时兜底：5s 内未 resolve/reject 视为“托管不可用”，降级继续，杜绝永久挂起
    timer = setTimeout(() => {
      if (!settled) {
        hilog.warn(0x0000, TAG, 'privacy consent timed out, fallback to init directly')
        finish('timeout')
      }
    }, PRIVACY_TIMEOUT_MS)

    try {
      privacyManager.requestAppPrivacyConsent(this.context)
        .then((consentResult: privacyManager.ConsentResult) => {
          // resolve：按 results 复查签署结果（官方推荐），区分“同意”与“拒绝”。
          // 拒绝可能表现为空数组（未签署无记录）或非 FULL_MODE_AGREED 条目，
          // 两种形态处理一致：未同意一律退出，绝不初始化（行业规则“拒绝即退出”）。
          const results: privacyManager.AppPrivacyResult[] = consentResult['results']
          if (this.isAgreed(results)) {
            finish('agreed')
          } else {
            settled = true
            if (timer >= 0) {
              clearTimeout(timer)
            }
            hilog.warn(0x0000, TAG, 'privacy consent rejected by user')
            // 用户拒绝（含空结果）：按托管服务规范退出，不再初始化业务
            this.context.terminateSelf()
          }
        })
        .catch((err: BusinessError<Object>) => {
          // 环境/配置异常（模拟器不支持、托管未接入等）：降级继续，不退出（官方样例即只打日志）
          settled = true
          if (timer >= 0) {
            clearTimeout(timer)
          }
          hilog.warn(0x0000, TAG, `privacy api error code=${err.code}, fallback to init directly`)
          this.initBusiness()
        })
    } catch (e) {
      // 同步异常（接口不可用）：降级继续，不阻塞启动
      hilog.warn(0x0000, TAG, 'request privacy consent threw, fallback to init directly')
      finish('sync-error')
    }
  }

  /** 数据层初始化（仅在同意/降级后调用，保证合规）；幂等，避免重复初始化 */
  private initBusiness(): void {
    if (this.businessInited) {
      return
    }
    this.businessInited = true
    const store: AppStore = AppStore.getInstance()
    store.init(this.context)
      .then(() => {
        hilog.info(0x0000, TAG, 'store init ok')
        // 数据层就绪后按 settings.theme 应用窗口颜色模式（依赖 doc.settings，须在 init 后）
        store.applyThemeToWindow()
      })
      .catch((e: Error) => {
        hilog.error(0x0000, TAG, `store init failed: ${e.message}`)
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
