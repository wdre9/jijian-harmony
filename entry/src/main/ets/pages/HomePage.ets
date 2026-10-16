/**
 * 记账 Tab：今日/本周/本月概览 + 目标进度 + 今日记录 + 最近记录 + 快捷记账弹层
 */
import { promptAction, router } from '@kit.ArkUI'
import { DataDoc, PieceRecord, Process, Product } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { EnrichedRecord, enrichRecords, sumAmount, sumQty } from '../utils/StatsUtils'
import { todayStr, weekRangeOf } from '../utils/DateUtils'
import { money, qty, round } from '../utils/FormatUtils'
import { Theme } from '../common/Theme'

@Component
export struct HomePage {
  @Prop doc: DataDoc
  /** 首页概览范围（AppStorage 广播，切换立即生效，无需重建页面） */
  @StorageProp('homeRange') homeRange: string = 'today'
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  onJumpRecordEdit: () => void = () => {
  }
  onJumpDetail: () => void = () => {
  }
  private store: AppStore = AppStore.getInstance()

  @State showQuickSheet: boolean = false
  @State quickProductId: string = ''
  @State quickProcessId: string = ''
  @State quickQty: string = '1'
  @State quickPrice: string = '0'
  @State quickWorker: string = ''
  @State quickShift: string = 'day'
  @State quickSaving: boolean = false

  /** 富化全部记录 */
  private enriched(): EnrichedRecord[] {
    return enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
  }

  private todayRecords(): EnrichedRecord[] {
    const today: string = todayStr()
    return this.enriched().filter((r: EnrichedRecord) => r.date === today)
  }

  private weekRecords(): EnrichedRecord[] {
    const range = weekRangeOf(todayStr())
    return this.enriched().filter((r: EnrichedRecord) => r.date >= range.start && r.date <= range.end)
  }

  private monthRecords(): EnrichedRecord[] {
    const ym: string = todayStr().substring(0, 7)
    return this.enriched().filter((r: EnrichedRecord) => r.date.startsWith(ym))
  }

  private todayList(): EnrichedRecord[] {
    const list: EnrichedRecord[] = this.todayRecords()
    list.sort((a: EnrichedRecord, b: EnrichedRecord) => (a.createdAt > b.createdAt ? -1 : 1))
    return list.slice(0, 3)
  }

  private rangeLabel(): string {
    if (this.homeRange === 'week') {
      return '本周'
    }
    if (this.homeRange === 'month') {
      return '本月'
    }
    return '今日'
  }

  /** 当前概览范围对应的记录 */
  private rangeRecords(): EnrichedRecord[] {
    if (this.homeRange === 'week') {
      return this.weekRecords()
    }
    if (this.homeRange === 'month') {
      return this.monthRecords()
    }
    return this.todayRecords()
  }

  /** 当前概览范围内最近 3 条（供范围记录列表） */
  private rangeList(): EnrichedRecord[] {
    const list: EnrichedRecord[] = this.rangeRecords()
    list.sort((a: EnrichedRecord, b: EnrichedRecord) => (a.createdAt > b.createdAt ? -1 : 1))
    return list.slice(0, 3)
  }

  /** 非当前范围的另两个范围键（顶部大卡已展示当前范围） */
  private otherRangeKeys(): string[] {
    if (this.homeRange === 'week') {
      return ['today', 'month']
    }
    if (this.homeRange === 'month') {
      return ['today', 'week']
    }
    return ['week', 'month']
  }

  private otherRangeLabel(key: string): string {
    if (key === 'week') {
      return '本周'
    }
    if (key === 'month') {
      return '本月'
    }
    return '今日'
  }

  private otherRangeRecords(key: string): EnrichedRecord[] {
    if (key === 'week') {
      return this.weekRecords()
    }
    if (key === 'month') {
      return this.monthRecords()
    }
    return this.todayRecords()
  }

  private otherRangeColor(key: string): string {
    return key === 'month' ? Theme.orange() : Theme.blue()
  }

  private recent(): EnrichedRecord[] {
    const list: EnrichedRecord[] = this.enriched()
    list.sort((a: EnrichedRecord, b: EnrichedRecord) => {
      if (a.date !== b.date) {
        return a.date < b.date ? 1 : -1
      }
      return a.createdAt > b.createdAt ? -1 : 1
    })
    return list.slice(0, 5)
  }

  private goRecordEdit(): void {
    // 完整记账走独立页；快捷记账走弹层
    this.openQuick()
  }

  private goDetail(): void {
    this.onJumpDetail()
  }

  private goRecordDetail(id: string): void {
    router.pushUrl({ url: 'pages/RecordDetailPage', params: { id: id } })
  }

  /** 打开快捷记账弹层并预填最近产品/工序/默认工人 */
  private openQuick(): void {
    const s = this.store.doc.settings
    this.quickProductId = s.rememberLast && s.lastProductId ? s.lastProductId : ''
    this.quickProcessId = s.rememberLast && s.lastProcessId ? s.lastProcessId : ''
    this.quickWorker = s.defaultWorker
    this.quickQty = '1'
    this.quickPrice = '0'
    this.quickShift = 'day'
    this.syncQuickPrice()
    this.showQuickSheet = true
  }

  private quickProducts(): Product[] {
    return this.store.doc.products
  }

  private quickProcesses(): Process[] {
    if (!this.quickProductId) {
      return []
    }
    return this.store.doc.processes.filter((c: Process) => c.productId === this.quickProductId)
  }

  private quickWorkers(): string[] {
    const names: string[] = []
    for (let i = 0; i < this.store.doc.workers.length; i++) {
      names.push(this.store.doc.workers[i].name)
    }
    return names
  }

  private syncQuickPrice(): void {
    const c: Process | undefined = this.quickProcesses().find((x: Process) => x.id === this.quickProcessId)
    if (c && (!this.quickPrice || parseFloat(this.quickPrice) <= 0)) {
      this.quickPrice = String(c.price)
    }
  }

  private quickAmount(): number {
    const q: number = parseFloat(this.quickQty) || 0
    const p: number = parseFloat(this.quickPrice) || 0
    return round(q * p, 2)
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  /** 快捷保存：写入记录并刷新父级 doc */
  private async quickSave(): Promise<void> {
    if (this.quickSaving) {
      return
    }
    if (!this.quickProductId) {
      this.toast('请选择产品')
      return
    }
    if (!this.quickProcessId) {
      this.toast('请选择工序')
      return
    }
    const q: number = parseFloat(this.quickQty) || 0
    const p: number = parseFloat(this.quickPrice) || 0
    if (!(q > 0)) {
      this.toast('数量需大于 0')
      return
    }
    if (!(p >= 0)) {
      this.toast('单价不合法')
      return
    }
    this.quickSaving = true
    try {
      const d: DataDoc = await this.store.addRecord(
        todayStr(), this.quickProductId, this.quickProcessId, q, p,
        this.quickWorker.trim(), this.quickShift, '')
      this.onDocChanged(d)
      this.showQuickSheet = false
      this.toast('记账成功')
    } catch (e) {
      this.toast('保存失败，请重试')
    } finally {
      this.quickSaving = false
    }
  }

  @Builder
  statCard(label: string, amount: number, qtyVal: number, color: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(Theme.sub())
      Text(money(amount))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 6 })
      Text(`${qty(qtyVal)} 件`)
        .fontSize(11)
        .fontColor(Theme.sub())
        .margin({ top: 4 })
    }
    .width('50%')
    .padding(14)
    .backgroundColor(Theme.card())
    .borderRadius(12)
  }

  @Builder
  quickSheet() {
    Column({ space: 10 }) {
      Text('快捷记账')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text())
        .padding({ top: 16 })

      // 产品
      Column({ space: 6 }) {
        Text('产品')
          .fontSize(12)
          .fontColor(Theme.sub())
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.quickProducts(), (p: Product) => {
              Text(p.name)
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(this.quickProductId === p.id ? Theme.blue() : Theme.chip())
                .fontColor(this.quickProductId === p.id ? Theme.white() : Theme.text())
                .borderRadius(12)
                .onClick(() => {
                  this.quickProductId = p.id
                  this.quickProcessId = ''
                  this.quickPrice = '0'
                })
            }, (p: Product) => p.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 工序
      Column({ space: 6 }) {
        Text('工序')
          .fontSize(12)
          .fontColor(Theme.sub())
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.quickProcesses(), (c: Process) => {
              Text(`${c.name} ${money(c.price)}`)
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(this.quickProcessId === c.id ? Theme.blue() : Theme.chip())
                .fontColor(this.quickProcessId === c.id ? Theme.white() : Theme.text())
                .borderRadius(12)
                .onClick(() => {
                  this.quickProcessId = c.id
                  this.quickPrice = String(c.price)
                })
            }, (c: Process) => c.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 数量 / 单价
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('数量')
            .fontSize(12)
            .fontColor(Theme.sub())
          Row({ space: 6 }) {
            Button('-')
              .width(30)
              .height(30)
              .fontSize(16)
              .type(ButtonType.Circle)
              .backgroundColor(Theme.line())
              .fontColor(Theme.text())
              .onClick(() => {
                const v: number = (parseFloat(this.quickQty) || 1) - 1
                this.quickQty = v > 0 ? String(v) : '1'
              })
            TextInput({ text: this.quickQty, placeholder: '数量' })
              .width(64)
              .height(30)
              .fontSize(14)
              .type(InputType.Normal)
              .textAlign(TextAlign.Center)
              .onChange((v: string) => {
                this.quickQty = v
              })
            Button('+')
              .width(30)
              .height(30)
              .fontSize(16)
              .type(ButtonType.Circle)
              .backgroundColor(Theme.weakBlue())
              .fontColor(Theme.blue())
              .onClick(() => {
                const v: number = (parseFloat(this.quickQty) || 0) + 1
                this.quickQty = String(v)
              })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('单价(元)')
            .fontSize(12)
            .fontColor(Theme.sub())
          TextInput({ text: this.quickPrice, placeholder: '0.00' })
            .width(86)
            .height(30)
            .fontSize(14)
            .type(InputType.Normal)
            .textAlign(TextAlign.Center)
            .onChange((v: string) => {
              this.quickPrice = v
            })
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('金额')
            .fontSize(12)
            .fontColor(Theme.sub())
          Text(money(this.quickAmount()))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.orange())
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      // 班次
      Row({ space: 8 }) {
        Text('班次')
          .fontSize(12)
          .fontColor(Theme.sub())
        Text('白班')
          .fontSize(13)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.quickShift === 'day' ? Theme.blue() : Theme.chip())
          .fontColor(this.quickShift === 'day' ? Theme.white() : Theme.text())
          .borderRadius(8)
          .onClick(() => {
            this.quickShift = 'day'
          })
        Text('夜班')
          .fontSize(13)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.quickShift === 'night' ? Theme.blue() : Theme.chip())
          .fontColor(this.quickShift === 'night' ? Theme.white() : Theme.text())
          .borderRadius(8)
          .onClick(() => {
            this.quickShift = 'night'
          })
        Blank()
        Button(this.quickSaving ? '保存中…' : '保存')
          .type(ButtonType.Capsule)
          .backgroundColor(this.quickSaving ? Theme.line() : Theme.blue())
          .fontColor(Theme.white())
          .fontSize(14)
          .height(34)
          .enabled(!this.quickSaving)
          .onClick(() => {
            if (!this.quickSaving) {
              this.quickSave()
            }
          })
      }
      .width('100%')

      // 工人快捷 chips
      if (this.quickWorkers().length > 0) {
        Column({ space: 6 }) {
          Text('工人')
            .fontSize(12)
            .fontColor(Theme.sub())
          Scroll() {
            Row({ space: 6 }) {
              ForEach(this.quickWorkers(), (w: string) => {
                Text(w)
                  .fontSize(12)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(this.quickWorker === w ? Theme.weakBlue() : Theme.chip())
                  .fontColor(this.quickWorker === w ? Theme.blue() : Theme.text())
                  .borderRadius(10)
                  .onClick(() => {
                    this.quickWorker = w
                  })
              }, (w: string) => w)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Blank().height(16)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14 })
    .backgroundColor(Theme.card())
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 今日卡片
        Row() {
          Column({ space: 4 }) {
            Text(this.rangeLabel())
              .fontSize(13)
              .fontColor('#ffffff')
              .opacity(0.85)
            Text(money(sumAmount(this.rangeRecords())))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#ffffff')
            Text(`${qty(sumQty(this.rangeRecords()))} 件 · ${this.rangeRecords().length} 笔`)
              .fontSize(12)
              .fontColor('#ffffff')
              .opacity(0.85)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('记一笔')
            .type(ButtonType.Capsule)
            .backgroundColor('#ffffff')
            .fontColor(Theme.blue())
            .fontSize(14)
            .height(36)
            .onClick(() => {
              this.goRecordEdit()
            })
        }
        .width('100%')
        .padding(16)
        .borderRadius(14)
        .linearGradient({
          colors: [[0xff1989fa, 0], [0xff0f7ae0, 1]]
        })

        // 目标进度
        Column({ space: 8 }) {
          Text('目标进度')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.text())
          Row() {
            Text('今日目标')
              .fontSize(12)
              .fontColor(Theme.sub())
              .width(64)
            Progress({ value: this.dayGoalPercent(), total: 100, type: ProgressType.Linear })
              .width(120)
              .height(8)
              .color(Theme.blue())
              .backgroundColor(Theme.line())
              .layoutWeight(1)
            Text(`${money(sumAmount(this.todayRecords()))}/${money(this.doc.settings.dailyGoal)}`)
              .fontSize(11)
              .fontColor(Theme.sub())
              .width(120)
              .textAlign(TextAlign.End)
          }
          Row() {
            Text('本月目标')
              .fontSize(12)
              .fontColor(Theme.sub())
              .width(64)
            Progress({ value: this.monthGoalPercent(), total: 100, type: ProgressType.Linear })
              .width(120)
              .height(8)
              .color(Theme.orange())
              .backgroundColor(Theme.line())
              .layoutWeight(1)
            Text(`${money(sumAmount(this.monthRecords()))}/${money(this.doc.settings.monthlyGoal)}`)
              .fontSize(11)
              .fontColor(Theme.sub())
              .width(120)
              .textAlign(TextAlign.End)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.card())
        .borderRadius(12)

        // 其余两个范围概览（当前范围已在顶部大卡突出展示）
        Row({ space: 12 }) {
          ForEach(this.otherRangeKeys(), (key: string) => {
            this.statCard(this.otherRangeLabel(key), sumAmount(this.otherRangeRecords(key)),
              sumQty(this.otherRangeRecords(key)), this.otherRangeColor(key))
          }, (key: string) => key)
        }
        .width('100%')

        // 概览范围记录
        if (this.rangeRecords().length > 0) {
          Column() {
            Row() {
              Text(`${this.rangeLabel()}记录`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.text())
              Blank()
              Text('全部明细 ›')
                .fontSize(12)
                .fontColor(Theme.blue())
                .onClick(() => {
                  this.goDetail()
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 6 })

            ForEach(this.rangeList(), (r: EnrichedRecord) => {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(`${r.productName} · ${r.processName}`)
                    .fontSize(14)
                    .fontColor(Theme.text())
                  Text(`${r.shift === 'night' ? '夜班' : '白班'}  ${r.worker || '未填工人'}`)
                    .fontSize(11)
                    .fontColor(Theme.sub())
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 2 }) {
                  Text(money(r.amount))
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.text())
                  Text(`${qty(r.quantity)} 件 × ${money(r.price)}`)
                    .fontSize(11)
                    .fontColor(Theme.sub())
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .onClick(() => {
                this.goRecordDetail(r.id)
              })
            }, (r: EnrichedRecord) => r.id)
          }
          .width('100%')
          .backgroundColor(Theme.card())
          .borderRadius(12)
        }

        // 最近记录
        Column() {
          Row() {
            Text('最近记录')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            Blank()
            Text('全部明细 ›')
              .fontSize(12)
              .fontColor(Theme.blue())
              .onClick(() => {
                this.goDetail()
              })
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 14, bottom: 6 })

          ForEach(this.recent(), (r: EnrichedRecord) => {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(`${r.productName} · ${r.processName}`)
                  .fontSize(14)
                  .fontColor(Theme.text())
                Text(`${r.date}  ${r.worker || '未填工人'}  ${r.shift === 'night' ? '夜班' : '白班'}`)
                  .fontSize(11)
                  .fontColor(Theme.sub())
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 2 }) {
                Text(money(r.amount))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.text())
                Text(`${qty(r.quantity)} 件 × ${money(r.price)}`)
                  .fontSize(11)
                  .fontColor(Theme.sub())
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .onClick(() => {
              this.goRecordDetail(r.id)
            })
          }, (r: EnrichedRecord) => r.id)

          if (this.doc.records.length === 0) {
            Column({ space: 8 }) {
              Text('暂无记录')
                .fontSize(14)
                .fontColor(Theme.sub())
              Text('点击右上角「记一笔」开始录入')
                .fontSize(12)
                .fontColor(Theme.divider())
            }
            .width('100%')
            .padding({ top: 28, bottom: 28 })
          }
        }
        .width('100%')
        .backgroundColor(Theme.card())
        .borderRadius(12)
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.bg())
    .bindSheet(this.showQuickSheet, this.quickSheet(), { height: 520 })
  }

  private dayGoalPercent(): number {
    const g: number = this.doc.settings.dailyGoal
    if (g <= 0) {
      return 100
    }
    const v: number = sumAmount(this.todayRecords()) / g * 100
    return Math.min(v, 100)
  }

  private monthGoalPercent(): number {
    const g: number = this.doc.settings.monthlyGoal
    if (g <= 0) {
      return 100
    }
    const v: number = sumAmount(this.monthRecords()) / g * 100
    return Math.min(v, 100)
  }
}

