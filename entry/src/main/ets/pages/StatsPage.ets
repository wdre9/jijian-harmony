/**
 * 统计 Tab：多区间汇总指标、金额趋势（长区间按月聚合）、近7天趋势、产品占比、
 * 班次对比、近6月对比、工序/工人排行、最高单日、统计长图导出、五表 Excel 导出
 */
import { componentSnapshot, promptAction } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { picker as documentViewPicker, fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { BestDayInfo, DataDoc, RankItem, ShareItem, TrendPoint } from '../model/Types'
import { AppStore } from '../store/AppStore'
import {
  EnrichedRecord, enrichRecords, shiftStats, ShiftStat, recent6Months, monthBuckets,
  bestDayInfo, rankBy, sharesOf, sumAmount, sumQty, sumCount, trendByDay
} from '../utils/StatsUtils'
import { todayStr, weekRangeOf, lastNDaysRange } from '../utils/DateUtils'
import { money, qty } from '../utils/FormatUtils'
import { LineChart } from '../components/LineChart'
import { BarChart } from '../components/BarChart'
import { PieChart } from '../components/PieChart'
import { RangeTabs, RangeTabOption } from '../components/RangeTabs'
import { Theme } from '../common/Theme'
import {
  SheetData, buildXls, detailAoa, productSummaryAoa, processSummaryAoa,
  workerSummaryAoa, daySummaryAoa, shiftSummaryAoa, monthSummaryAoa
} from '../utils/ExporterUtils'

const RANGE_OPTIONS: RangeTabOption[] = [
  { key: 'week', label: '本周' },
  { key: 'month', label: '本月' },
  { key: 'lastMonth', label: '上月' },
  { key: 'near30', label: '近30天' },
  { key: 'near90', label: '近90天' },
  { key: 'year', label: '年度' },
  { key: 'custom', label: '自定义' }
]

@Component
export struct StatsPage {
  @Prop doc: DataDoc
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  private store: AppStore = AppStore.getInstance()
  private shareColors: string[] = ['#1989fa', '#36d399', '#f67a2e', '#ffc928', '#7d5bf5', '#fa4d4d', '#00b8c5', '#b3a4ff']

  @State rangeType: string = 'week'
  @State customStart: string = todayStr()
  @State customEnd: string = todayStr()
  @State showExportSheet: boolean = false

  private rangeStartEnd(): string[] {
    const today: string = todayStr()
    if (this.rangeType === 'week') {
      const r = weekRangeOf(today)
      return [r.start, r.end]
    }
    if (this.rangeType === 'month') {
      const ym: string = today.substring(0, 7)
      return [`${ym}-01`, today]
    }
    if (this.rangeType === 'lastMonth') {
      const d: Date = new Date(`${today}T00:00:00`)
      d.setMonth(d.getMonth() - 1)
      const y: number = d.getFullYear()
      const m: number = d.getMonth() + 1
      const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
      const lastDay: Date = new Date(y, m, 0)
      return [`${y}-${p(m)}-01`, `${y}-${p(m)}-${p(lastDay.getDate())}`]
    }
    if (this.rangeType === 'year') {
      return [`${today.substring(0, 4)}-01-01`, today]
    }
    if (this.rangeType === 'custom') {
      return [this.customStart, this.customEnd]
    }
    // near30 / near90
    const n: number = this.rangeType === 'near30' ? 30 : 90
    const r = lastNDaysRange(n)
    return [r.start, r.end]
  }

  private rangeDays(): number {
    const r: string[] = this.rangeStartEnd()
    const sd: number = new Date(`${r[0]}T00:00:00`).getTime()
    const ed: number = new Date(`${r[1]}T00:00:00`).getTime()
    return Math.max(1, Math.floor((ed - sd) / 86400000) + 1)
  }

  private inRange(): EnrichedRecord[] {
    const r: string[] = this.rangeStartEnd()
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    return all.filter((x: EnrichedRecord) => x.date >= r[0] && x.date <= r[1])
  }

  /** 长区间（>62 天）按月份聚合展示 */
  private longRange(): boolean {
    return this.rangeDays() > 62
  }

  private total(): number {
    return sumAmount(this.inRange())
  }

  private qtySum(): number {
    return sumQty(this.inRange())
  }

  private count(): number {
    return this.inRange().length
  }

  /** 次数合计（手动模式累加用户输入的 count，自动模式按条数计 1） */
  private times(): number {
    return sumCount(this.inRange())
  }

  /** 有记录的天数（区间内出现记录的唯一日期数） */
  private activeDays(): number {
    const list: EnrichedRecord[] = this.inRange()
    const seen: Map<string, boolean> = new Map<string, boolean>()
    for (let i = 0; i < list.length; i++) {
      seen.set(list[i].date, true)
    }
    return seen.size
  }

  /** 日均金额 = 合计金额 / 有记录天数（对齐安卓 dailyAverage 口径） */
  private dailyAvg(): number {
    const days: number = this.activeDays()
    return days > 0 ? this.total() / days : 0
  }

  private avgPrice(): number {
    return this.qtySum() > 0 ? this.total() / this.qtySum() : 0
  }

  /** 最高单日（金额 + 日期） */
  private best(): BestDayInfo {
    return bestDayInfo(this.inRange())
  }

  /** 趋势：长区间按月聚合，否则按日 */
  private trend(): TrendPoint[] {
    const r: string[] = this.rangeStartEnd()
    if (this.longRange()) {
      return monthBuckets(this.inRange(), r[0], r[1])
    }
    return trendByDay(this.inRange(), r[0], r[1])
  }

  /** 近 7 天趋势（独立于当前区间） */
  private last7(): TrendPoint[] {
    const r = lastNDaysRange(7)
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    const list: EnrichedRecord[] = all.filter((x: EnrichedRecord) => x.date >= r.start && x.date <= r.end)
    return trendByDay(list, r.start, r.end)
  }

  private productShares(): ShareItem[] {
    return sharesOf(this.inRange(), (r: EnrichedRecord) => r.productName, 7)
  }

  private processRank(): RankItem[] {
    return rankBy(this.inRange(), (r: EnrichedRecord) => r.processName, 8)
  }

  private workerRank(): RankItem[] {
    return rankBy(this.inRange(), (r: EnrichedRecord) => (r.worker || '未填'), 8)
  }

  private shiftList(): ShiftStat[] {
    return shiftStats(this.inRange())
  }

  /** 近 6 个月对比（全局近 6 月，不随区间） */
  private recent6(): RankItem[] {
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    const pts: TrendPoint[] = recent6Months(all)
    const items: RankItem[] = []
    for (let i = 0; i < pts.length; i++) {
      items.push({ name: pts[i].date.substring(5) + '月', amount: pts[i].amount, quantity: 0 })
    }
    return items
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  /** 五表 + 明细 + 按月 Excel 导出（原生 SpreadsheetML .xls） */
  private async exportExcel(): Promise<void> {
    this.showExportSheet = false
    const rows: EnrichedRecord[] = this.inRange()
    if (rows.length === 0) {
      this.toast('当前区间没有可导出的记录')
      return
    }
    const r: string[] = this.rangeStartEnd()
    const total: number = this.total()
    const sheets: SheetData[] = [
      { name: '计件明细', aoa: detailAoa(rows) },
      { name: '产品汇总', aoa: productSummaryAoa(rows) },
      { name: '工序汇总', aoa: processSummaryAoa(rows) },
      { name: '工人汇总', aoa: workerSummaryAoa(rows) },
      { name: '日期汇总', aoa: daySummaryAoa(rows) },
      { name: '班次汇总', aoa: shiftSummaryAoa(rows) },
      { name: '按月汇总', aoa: monthSummaryAoa(rows, r[0], r[1]) },
      {
        name: '汇总',
        aoa: [
          ['计件统计汇总'],
          ['区间', `${r[0]} ~ ${r[1]}`],
          ['项目', '数值'],
          ['合计金额(元)', total],
          ['件数', qty(this.qtySum())],
          ['次数', qty(this.times())],
          ['笔数', rows.length],
          ['日均金额(元)', money(this.dailyAvg())],
          ['平均单价(元)', money(this.avgPrice())],
          ['最高单日', `${this.best().date} ${money(this.best().amount)}`],
          ['导出时间', todayStr()]
        ]
      }
    ]
    const fileName: string = `计件统计-${todayStr()}.xls`
    try {
      const picker = new documentViewPicker.DocumentViewPicker()
      const opt = new documentViewPicker.DocumentSaveOptions()
      opt.newFileNames = [fileName]
      const uris: Array<string> = await picker.save(opt)
      if (uris.length === 0) {
        return
      }
      const uri: string = uris[0]
      const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, buildXls(sheets))
      fs.closeSync(file)
      this.toast(`已导出 ${fileName}`)
    } catch (e) {
      this.toast('导出失败，请检查文件权限')
    }
  }

  /** 截图统计区域并写入沙箱，经 documentViewPicker 弹系统保存框由用户确认保存（无需任何媒体权限） */
  private async saveSnapshot(): Promise<void> {
    componentSnapshot.get('statsArea', async (err: BusinessError, data: image.PixelMap) => {
      if (err) {
        this.toast('截图失败')
        return
      }
      try {
        const packer = image.createImagePacker()
        const opt: image.PackingOption = { format: 'image/png', quality: 100 }
        const buf: ArrayBuffer = await packer.packToData(data, opt)
        const ctx = getContext(this)
        const fileName: string = `stats_${Date.now()}.png`
        const sandboxPath: string = `${ctx.filesDir}/${fileName}`
        const file = fs.openSync(sandboxPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(file.fd, buf)
        fs.closeSync(file)
        packer.release()
        data.release()
        const documentPicker = new documentViewPicker.DocumentViewPicker(ctx)
        const saveOptions = new documentViewPicker.DocumentSaveOptions()
        saveOptions.newFileNames = [fileName]
        const savedUris: Array<string> = await documentPicker.save(saveOptions)
        if (savedUris && savedUris.length > 0) {
          const dest = fs.openSync(savedUris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
          fs.writeSync(dest.fd, buf)
          fs.closeSync(dest)
          this.toast('统计长图已保存')
        } else {
          this.toast('已取消保存')
        }
      } catch (e) {
        this.toast('保存失败，请检查文件权限')
      }
    })
  }

  @Builder
  metricCard(label: string, value: string, color: string = Theme.text()) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(Theme.sub())
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(Theme.card())
    .borderRadius(10)
  }

  @Builder
  last7Chart() {
    LineChart({ points: this.last7(), dark: Theme.isDark() })
      .width('100%')
  }

  @Builder
  trendChart() {
    LineChart({ points: this.trend(), dark: Theme.isDark() })
      .width('100%')
  }

  @Builder
  productShareChart() {
    PieChart({ items: this.productShares(), dark: Theme.isDark() })
      .width('100%')
    Column({ space: 0 }) {
      ForEach(this.productShares(), (s: ShareItem, idx: number) => {
        this.legendRow(s.name, s.ratio, s.amount, this.shareColors[idx] ?? '#1989fa')
      }, (s: ShareItem, idx: number) => `${s.name}-${idx}`)
    }
    .width('100%')
  }

  @Builder
  shiftCompareChart() {
    Column({ space: 8 }) {
      ForEach(this.shiftList(), (s: ShiftStat) => {
        Row({ space: 8 }) {
          Text(s.name)
            .fontSize(13)
            .fontColor(Theme.text())
            .width(48)
          Column({ space: 4 }) {
            Progress({ value: s.amount, total: Math.max(this.shiftList()[0].amount + this.shiftList()[1].amount, 1) })
              .width('100%')
              .height(8)
              .color(s.name === '夜班' ? Theme.orange() : Theme.blue())
              .backgroundColor(Theme.line())
            Row({ space: 6 }) {
              Text(money(s.amount))
                .fontSize(12)
                .fontColor(s.name === '夜班' ? Theme.orange() : Theme.blue())
              Text(`${qty(s.quantity)} 件 · ${s.count} 笔`)
                .fontSize(11)
                .fontColor(Theme.sub())
            }
            .width('100%')
          }
          .layoutWeight(1)
        }
        .width('100%')
      }, (s: ShiftStat) => s.name)
    }
    .width('100%')
  }

  @Builder
  recent6Chart() {
    BarChart({ items: this.recent6(), dark: Theme.isDark() })
      .width('100%')
    Column({ space: 0 }) {
      ForEach(this.recent6(), (r: RankItem, idx: number) => {
        Row({ space: 6 }) {
          Text(r.name)
            .fontSize(12)
            .fontColor(Theme.text())
            .width(48)
          Text(money(r.amount))
            .fontSize(12)
            .fontColor(Theme.blue())
            .layoutWeight(1)
          Text(qty(r.quantity) + ' 件')
            .fontSize(11)
            .fontColor(Theme.sub())
            .visibility(Visibility.Hidden)
        }
        .width('100%')
        .margin({ top: 2, bottom: 2 })
      }, (r: RankItem, idx: number) => `${r.name}-${idx}`)
    }
    .width('100%')
  }

  @Builder
  processRankChart() {
    BarChart({ items: this.processRank(), dark: Theme.isDark() })
      .width('100%')
    Column({ space: 0 }) {
      ForEach(this.processRank(), (r: RankItem, idx: number) => {
        this.rankRow(r, idx)
      }, (r: RankItem, idx: number) => `${r.name}-${idx}`)
    }
    .width('100%')
  }

  @Builder
  workerRankChart() {
    BarChart({ items: this.workerRank(), dark: Theme.isDark() })
      .width('100%')
    Column({ space: 0 }) {
      ForEach(this.workerRank(), (r: RankItem, idx: number) => {
        this.rankRow(r, idx)
      }, (r: RankItem, idx: number) => `${r.name}-${idx}`)
    }
    .width('100%')
  }

  @Builder
  legendRow(name: string, ratio: number, amount: number, color: string) {
    Row({ space: 6 }) {
      Circle({ width: 10, height: 10 })
        .fill(color)
      Text(name)
        .fontSize(12)
        .fontColor(Theme.text())
        .layoutWeight(1)
        .maxLines(1)
      Text(`${Math.round(ratio * 100)}%`)
        .fontSize(11)
        .fontColor(Theme.sub())
      Text(money(amount))
        .fontSize(12)
        .fontColor(Theme.text())
        .width(70)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  rankRow(r: RankItem, idx: number) {
    Row({ space: 6 }) {
      Text(`${idx + 1}`)
        .fontSize(12)
        .width(20)
        .height(20)
        .textAlign(TextAlign.Center)
        .backgroundColor(idx < 3 ? Theme.weakBlue() : Theme.chip())
        .fontColor(idx === 0 ? Theme.orange() : Theme.text())
        .borderRadius(10)
      Text(r.name)
        .fontSize(12)
        .fontColor(Theme.text())
        .layoutWeight(1)
        .maxLines(1)
      Text(`${qty(r.quantity)} 件`)
        .fontSize(11)
        .fontColor(Theme.sub())
      Text(money(r.amount))
        .fontSize(12)
        .fontColor(Theme.text())
        .width(70)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: 3, bottom: 3 })
  }

  @Builder
  exportSheet() {
    Column({ space: 6 }) {
      Text('导出 Excel（.xls 多表）')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text())
        .padding({ top: 16, bottom: 10 })
      Text('包含：计件明细 / 产品汇总 / 工序汇总 / 工人汇总 / 日期汇总 / 班次汇总 / 按月汇总 / 区间汇总')
        .fontSize(12)
        .fontColor(Theme.sub())
        .padding({ bottom: 10 })
      Text('确认导出当前区间统计')
        .fontSize(14)
        .fontColor(Theme.blue())
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(12)
        .backgroundColor(Theme.bg())
        .borderRadius(8)
        .onClick(() => {
          this.exportExcel()
        })
      Blank().height(20)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(Theme.card())
  }

  build() {
    Column() {
      Row() {
        Text('统计')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text())
        Blank()
        Text('导出Excel')
          .fontSize(14)
          .fontColor(Theme.blue())
          .onClick(() => {
            this.showExportSheet = true
          })
        Text('  ')
        Button('下载')
          .fontSize(14)
          .fontColor(Theme.blue())
          .backgroundColor(Theme.card())
          .borderRadius(0)
          .height(48)
          .onClick(() => {
            this.saveSnapshot()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.card())

      Scroll() {
        Column({ space: 10 }) {
          // 范围选择
          Column({ space: 8 }) {
            RangeTabs({ options: RANGE_OPTIONS, selectedKey: this.rangeType, onSelect: (k: string) => {
              this.rangeType = k
            } })

            if (this.rangeType === 'custom') {
              Row({ space: 10 }) {
                Text(`开始 ${this.customStart}`)
                  .fontSize(12)
                  .fontColor(Theme.text())
                  .padding(6)
                  .backgroundColor(Theme.chip())
                  .borderRadius(6)
                  .onClick(() => {
                    DatePickerDialog.show({
                      selected: new Date(`${this.customStart}T00:00:00`),
                      start: new Date('2020-01-01'),
                      end: new Date('2032-12-31'),
                      onDateAccept: (d: Date) => {
                        const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
                        this.customStart = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
                        if (this.customStart > this.customEnd) {
                          this.customEnd = this.customStart
                        }
                      }
                    })
                  })
                Text(`结束 ${this.customEnd}`)
                  .fontSize(12)
                  .fontColor(Theme.text())
                  .padding(6)
                  .backgroundColor(Theme.chip())
                  .borderRadius(6)
                  .onClick(() => {
                    DatePickerDialog.show({
                      selected: new Date(`${this.customEnd}T00:00:00`),
                      start: new Date('2020-01-01'),
                      end: new Date('2032-12-31'),
                      onDateAccept: (d: Date) => {
                        const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
                        this.customEnd = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
                      }
                    })
                  })
              }
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 指标
          Row({ space: 10 }) {
            this.metricCard('合计金额(元)', money(this.total()), Theme.orange())
            this.metricCard('件数', qty(this.qtySum()))
            this.metricCard('次数', qty(this.times()))
            this.metricCard('笔数', String(this.count()))
          }
          .width('100%')
          Row({ space: 10 }) {
            this.metricCard('日均金额(元)', money(this.dailyAvg()))
            this.metricCard('平均单价(元)', money(this.avgPrice()))
            this.metricCard('最高单日(元)', money(this.best().amount))
          }
          .width('100%')

          // 最高单日日期
          if (this.best().amount > 0) {
            Row() {
              Text(`最高单日：${this.best().date}  ${money(this.best().amount)} 元`)
                .fontSize(12)
                .fontColor(Theme.orange())
              Blank()
              Text(`${qty(maxDayQty(this.inRange(), this.best().date))} 件`)
                .fontSize(12)
                .fontColor(Theme.sub())
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(Theme.orangeBg())
            .borderRadius(8)
          }

          // 近 7 天趋势
          Column({ space: 8 }) {
            Text('近7天趋势')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.last7Chart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 金额趋势（长区间按月聚合）
          Column({ space: 8 }) {
            Text(this.longRange() ? '金额趋势（按月）' : '金额趋势')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.trendChart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 产品占比
          Column({ space: 8 }) {
            Text('产品金额占比')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.productShareChart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 班次对比
          Column({ space: 8 }) {
            Text('班次对比')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.shiftCompareChart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 近 6 月对比
          Column({ space: 8 }) {
            Text('近6月对比')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.recent6Chart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 工序排行
          Column({ space: 8 }) {
            Text('工序排行（金额）')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.processRankChart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          // 工人排行
          Column({ space: 8 }) {
            Text('工人排行（金额）')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text())
            this.workerRankChart()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          Blank().height(20)
        }
        .width('100%')
        .padding(12)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg())
    }
    .width('100%')
    .height('100%')
    .id('statsArea')
    .bindSheet(this.showExportSheet, this.exportSheet(), { height: 300 })
  }
}

/** 某日期件数合计 */
function maxDayQty(list: EnrichedRecord[], date: string): number {
  let q: number = 0
  for (let i = 0; i < list.length; i++) {
    if (list[i].date === date) {
      q += list[i].quantity
    }
  }
  return q
}
