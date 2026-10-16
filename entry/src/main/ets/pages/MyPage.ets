/**
 * 我的 Tab：设置（主题/目标/默认工人/记住上次/首页范围）+ 功能入口（管理/导入/导出/关于）+ 数据说明
 */
import { router, promptAction } from '@kit.ArkUI'
import { AppSettings, DataDoc } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { cloneSettings } from '../model/DataDoc'
import { Theme } from '../common/Theme'


@Component
export struct MyPage {
  @Prop doc: DataDoc
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  private store: AppStore = AppStore.getInstance()

  @State theme: string = 'auto'
  @State homeRange: string = 'today'
  @State dailyGoal: string = ''
  @State monthlyGoal: string = ''
  @State defaultWorker: string = ''
  @State rememberLast: boolean = false

  aboutToAppear(): void {
    this.syncFromDoc()
  }

  private syncFromDoc(): void {
    const s: AppSettings = this.doc.settings
    this.theme = s.theme
    this.homeRange = s.homeRange
    this.dailyGoal = String(s.dailyGoal || 0)
    this.monthlyGoal = String(s.monthlyGoal || 0)
    this.defaultWorker = s.defaultWorker
    this.rememberLast = s.rememberLast
  }

  private async saveSettings(patch: (s: AppSettings) => void): Promise<void> {
    const s: AppSettings = cloneSettings(this.doc.settings)
    patch(s)
    const next: DataDoc = await this.store.updateSettings(s)
    this.doc = next
    this.onDocChanged(next)
    this.syncFromDoc()
    // 主题变更后立即同步窗口颜色模式（dark=1 / light=0 / auto=-1）
    this.store.applyThemeToWindow()
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  private async doSaveDailyGoal(): Promise<void> {
    const v: number = parseFloat(this.dailyGoal) || 0
    await this.saveSettings((s: AppSettings) => {
      s.dailyGoal = v < 0 ? 0 : v
    })
    this.toast('已保存每日目标')
  }

  private async doSaveMonthlyGoal(): Promise<void> {
    const v: number = parseFloat(this.monthlyGoal) || 0
    await this.saveSettings((s: AppSettings) => {
      s.monthlyGoal = v < 0 ? 0 : v
    })
    this.toast('已保存每月目标')
  }

  private async doSaveWorker(): Promise<void> {
    await this.saveSettings((s: AppSettings) => {
      s.defaultWorker = this.defaultWorker.trim()
    })
    this.toast('已保存默认工人')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(Theme.sub())
      .padding({ left: 4, top: 12, bottom: 6 })
      .alignSelf(ItemAlign.Start)
  }

  @Builder
  row(title: string, sub: string, action: () => void) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
        if (sub) {
          Text(sub)
            .fontSize(11)
            .fontColor(Theme.sub())
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(16)
        .fontColor(Theme.divider())
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Theme.card())
    .onClick(() => {
      action()
    })
  }

  @Builder
  chipRow(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor(this.theme === key ? Theme.blue() : Theme.chip())
      .fontColor(this.theme === key ? Theme.white() : Theme.text())
      .borderRadius(12)
      .onClick(() => {
        this.saveSettings((s: AppSettings) => {
          s.theme = key
        })
      })
  }

  @Builder
  rangeChip(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor(this.homeRange === key ? Theme.blue() : Theme.chip())
      .fontColor(this.homeRange === key ? Theme.white() : Theme.text())
      .borderRadius(12)
      .onClick(() => {
        // 首页范围切换：立即更新高亮并走 PrefStore 轻量键值，不触发整库事务，避免闪退
        this.homeRange = key
        this.store.setHomeRange(key)
      })
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        // 头部
        Column({ space: 4 }) {
          Text('计件')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text('v0.1.0 · 数据仅存本机')
            .fontSize(11)
            .fontColor(Theme.sub())
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Theme.card())
        .borderRadius(10)
        .margin({ top: 10, left: 12, right: 12 })

        // 外观
        this.sectionTitle('外观')
        Column({ space: 0 }) {
          Row({ space: 8 }) {
            Text('主题')
              .fontSize(14)
              .layoutWeight(1)
            this.chipRow('auto', '跟随系统')
            this.chipRow('light', '浅色')
            this.chipRow('dark', '深色')
          }
          .width('100%')
          .height(48)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
        }
        .width('100%')
        .borderRadius(10)
        .margin({ left: 12, right: 12 })

        // 目标与首页
        this.sectionTitle('目标与首页')
        Column({ space: 0 }) {
          Row({ space: 8 }) {
            Text('每日目标(元)')
              .fontSize(14)
              .layoutWeight(1)
            TextInput({ text: this.dailyGoal, placeholder: '如 500' })
              .width(120)
              .height(32)
              .fontSize(13)
              .onChange((v: string) => {
                this.dailyGoal = v
              })
              .onSubmit(() => {
                this.doSaveDailyGoal()
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
          Row({ space: 8 }) {
            Text('每月目标(元)')
              .fontSize(14)
              .layoutWeight(1)
            TextInput({ text: this.monthlyGoal, placeholder: '如 12000' })
              .width(120)
              .height(32)
              .fontSize(13)
              .onChange((v: string) => {
                this.monthlyGoal = v
              })
              .onSubmit(() => {
                this.doSaveMonthlyGoal()
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
          Row({ space: 8 }) {
            Text('首页概览范围')
              .fontSize(14)
              .layoutWeight(1)
            this.rangeChip('today', '今日')
            this.rangeChip('week', '本周')
            this.rangeChip('month', '本月')
          }
          .width('100%')
          .height(48)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
        }
        .width('100%')
        .borderRadius(10)
        .margin({ left: 12, right: 12 })

        // 记账偏好
        this.sectionTitle('记账偏好')
        Column({ space: 0 }) {
          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text('默认工人')
                .fontSize(14)
              Text('记一笔时自动填入')
                .fontSize(11)
                .fontColor(Theme.sub())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            TextInput({ text: this.defaultWorker, placeholder: '工人姓名' })
              .width(130)
              .height(32)
              .fontSize(13)
              .onChange((v: string) => {
                this.defaultWorker = v
              })
              .onSubmit(() => {
                this.doSaveWorker()
              })
          }
          .width('100%')
          .height(52)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text('记住上次选择')
                .fontSize(14)
              Text('记一笔时沿用上次产品/工序')
                .fontSize(11)
                .fontColor(Theme.sub())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.rememberLast })
              .selectedColor(Theme.blue())
              .onChange((on: boolean) => {
                this.saveSettings((s: AppSettings) => {
                  s.rememberLast = on
                })
              })
          }
          .width('100%')
          .height(52)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
        }
        .width('100%')
        .borderRadius(10)
        .margin({ left: 12, right: 12 })

        // 数据入口
        this.sectionTitle('数据')
        Column({ space: 0 }) {
          this.row('产品与工序', `${this.doc.products.length} 产品 · ${this.doc.processes.length} 工序`, () => {
            router.pushUrl({ url: 'pages/ProductProcessPage' })
          })
          this.row('工人管理', `${this.doc.workers.length} 名工人`, () => {
            router.pushUrl({ url: 'pages/WorkersPage' })
          })
          this.row('批量导入', 'OCR 识别 + 文本解析批量录入', () => {
            router.pushUrl({ url: 'pages/BatchImportPage' })
          })
          this.row('数据与导出', `${this.doc.records.length} 条记录，备份/CSV/Excel/导入/演示数据`, () => {
            router.pushUrl({ url: 'pages/DataPage' })
          })
        }
        .width('100%')
        .borderRadius(10)
        .margin({ left: 12, right: 12 })

        // 其他
        this.sectionTitle('其他')
        Column({ space: 0 }) {
          this.row('关于', '版本、功能特性、数据安全说明', () => {
            router.pushUrl({ url: 'pages/AboutPage' })
          })
        }
        .width('100%')
        .borderRadius(10)
        .margin({ left: 12, right: 12 })

        // 说明
        Column({ space: 4 }) {
          Text('数据安全说明')
            .fontSize(12)
            .fontColor(Theme.sub())
          Text('所有数据仅保存在本机（RelationalStore + 沙箱文件），不联网、不上传；保存数据后每 24 小时最多自动备份一次，备份写入「计件自动备份」目录，滚动保留最近 14 份。')
            .fontSize(11)
            .fontColor(Theme.sub())
            .lineHeight(17)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.card())
        .borderRadius(10)
        .margin({ left: 12, right: 12, top: 10 })
        .alignItems(HorizontalAlign.Start)

        Blank().height(24)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg())
  }
}
