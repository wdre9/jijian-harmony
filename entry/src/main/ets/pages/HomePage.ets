/**
 * 记账 Tab：今日/本周/本月概览 + 目标进度 + 最近记录 + 快捷录入
 */
import { router } from '@kit.ArkUI'
import { DataDoc, PieceRecord } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { EnrichedRecord, enrichRecords, sumAmount, sumQty } from '../utils/StatsUtils'
import { todayStr, weekRangeOf } from '../utils/DateUtils'
import { money, qty } from '../utils/FormatUtils'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'
const CARD: string = '#ffffff'

@Component
export struct HomePage {
  @Prop doc: DataDoc
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  onJumpRecordEdit: () => void = () => {
  }
  onJumpDetail: () => void = () => {
  }
  private store: AppStore = AppStore.getInstance()

  /** 富化全部记录 */
  private enriched(): EnrichedRecord[] {
    return enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
  }

  private todayRecords(): EnrichedRecord[] {
    const today: string = todayStr()
    return this.enriched().filter((r: EnrichedRecord) => r.date === today)
  }

  private weekRecords(): EnrichedRecord[] {
    const range: string[] = weekRangeOf(todayStr())
    return this.enriched().filter((r: EnrichedRecord) => r.date >= range[0] && r.date <= range[1])
  }

  private monthRecords(): EnrichedRecord[] {
    const ym: string = todayStr().substring(0, 7)
    return this.enriched().filter((r: EnrichedRecord) => r.date.startsWith(ym))
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
    router.pushUrl({ url: 'pages/RecordEditPage' })
  }

  private goDetail(): void {
    // 切换到明细 Tab
    this.onJumpDetail()
  }

  private goRecordDetail(id: string): void {
    router.pushUrl({ url: 'pages/RecordDetailPage', params: { id: id } })
  }

  @Builder
  statCard(label: string, amount: number, qtyVal: number, color: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(GRAY)
      Text(money(amount))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 6 })
      Text(`${qty(qtyVal)} 件`)
        .fontSize(11)
        .fontColor(GRAY)
        .margin({ top: 4 })
    }
    .width('50%')
    .padding(14)
    .backgroundColor(CARD)
    .borderRadius(12)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 今日卡片
        Row() {
          Column({ space: 4 }) {
            Text('今日')
              .fontSize(13)
              .fontColor('#ffffff')
              .opacity(0.85)
            Text(money(sumAmount(this.todayRecords())))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#ffffff')
            Text(`${qty(sumQty(this.todayRecords()))} 件 · ${this.todayRecords().length} 笔`)
              .fontSize(12)
              .fontColor('#ffffff')
              .opacity(0.85)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('记一笔')
            .type(ButtonType.Capsule)
            .backgroundColor('#ffffff')
            .fontColor(BLUE)
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
          Row() {
            Text('今日目标')
              .fontSize(12)
              .fontColor(GRAY)
              .width(64)
            LinearProgress({ value: this.dayGoalPercent(), total: 100 })
              .width(120)
              .height(8)
              .color(BLUE)
              .backgroundColor('#ebedf0')
              .layoutWeight(1)
            Text(`${money(sumAmount(this.todayRecords()))}/${money(this.doc.settings.dailyGoal)}`)
              .fontSize(11)
              .fontColor(GRAY)
              .width(120)
              .textAlign(TextAlign.End)
          }
          Row() {
            Text('本月目标')
              .fontSize(12)
              .fontColor(GRAY)
              .width(64)
            LinearProgress({ value: this.monthGoalPercent(), total: 100 })
              .width(120)
              .height(8)
              .color('#f67a2e')
              .backgroundColor('#ebedf0')
              .layoutWeight(1)
            Text(`${money(sumAmount(this.monthRecords()))}/${money(this.doc.settings.monthlyGoal)}`)
              .fontSize(11)
              .fontColor(GRAY)
              .width(120)
              .textAlign(TextAlign.End)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor(CARD)
        .borderRadius(12)

        // 本周 / 本月概览
        Row({ space: 12 }) {
          this.statCard('本周', sumAmount(this.weekRecords()), sumQty(this.weekRecords()), BLUE)
          this.statCard('本月', sumAmount(this.monthRecords()), sumQty(this.monthRecords()), '#f67a2e')
        }
        .width('100%')

        // 最近记录
        Column() {
          Row() {
            Text('最近记录')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
            Blank()
            Text('全部明细 ›')
              .fontSize(12)
              .fontColor(BLUE)
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
                  .fontColor('#323233')
                Text(`${r.date}  ${r.worker || '未填工人'}  ${r.shift === 'night' ? '夜班' : '白班'}`)
                  .fontSize(11)
                  .fontColor(GRAY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 2 }) {
                Text(money(r.amount))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#323233')
                Text(`${qty(r.quantity)} 件 × ${money(r.price)}`)
                  .fontSize(11)
                  .fontColor(GRAY)
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
                .fontColor(GRAY)
              Text('点击右上角「记一笔」开始录入')
                .fontSize(12)
                .fontColor('#c8c9cc')
            }
            .width('100%')
            .padding({ top: 28, bottom: 28 })
          }
        }
        .width('100%')
        .backgroundColor(CARD)
        .borderRadius(12)
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#f7f8fa')
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
