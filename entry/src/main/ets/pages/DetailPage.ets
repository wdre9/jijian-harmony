/**
 * 明细 Tab：日期区间/产品/工人/班次筛选、按日分组、多选批量导出（CSV/Excel/JSON/文本）
 */
import { picker as documentViewPicker, fileIo as fs } from '@kit.CoreFileKit'
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc, Product, Worker } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { EnrichedRecord, enrichRecords, groupByDate, sumAmount, sumQty } from '../utils/StatsUtils'
import { DateRange, todayStr, weekRangeOf } from '../utils/DateUtils'
import { money, qty } from '../utils/FormatUtils'
import { detailAoa, detailCsv, buildXls, SheetData, countText } from '../utils/ExporterUtils'
import { Theme } from '../common/Theme'

/** 导出选项 */
interface ExportOption {
  key: string
  label: string
}

/** JSON 导出包 */
interface JsonExportPayload {
  exportedAt: number
  count: number
  records: EnrichedRecord[]
}


@Component
export struct DetailPage {
  @Prop doc: DataDoc
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  private store: AppStore = AppStore.getInstance()

  @State rangeType: string = 'week'
  @State filterProduct: string = ''
  @State filterWorker: string = ''
  @State filterShift: string = ''
  @State selecting: boolean = false
  @State selectedIds: string[] = []
  @State showExportSheet: boolean = false

  /** 富化 + 排序（日期倒序，同日 createdAt 倒序） */
  private enrichedAll(): EnrichedRecord[] {
    const list: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    list.sort((a: EnrichedRecord, b: EnrichedRecord) => {
      if (a.date !== b.date) {
        return a.date < b.date ? 1 : -1
      }
      return a.createdAt > b.createdAt ? -1 : 1
    })
    return list
  }

  /** 应用筛选 */
  private filtered(): EnrichedRecord[] {
    let list: EnrichedRecord[] = this.enrichedAll()
    const range: string[] = this.rangeStartEnd()
    list = list.filter((r: EnrichedRecord) => r.date >= range[0] && r.date <= range[1])
    if (this.filterProduct) {
      list = list.filter((r: EnrichedRecord) => r.productId === this.filterProduct)
    }
    if (this.filterWorker) {
      list = list.filter((r: EnrichedRecord) => r.worker === this.filterWorker)
    }
    if (this.filterShift) {
      list = list.filter((r: EnrichedRecord) => r.shift === this.filterShift)
    }
    return list
  }

  private rangeStartEnd(): string[] {
    const today: string = todayStr()
    if (this.rangeType === 'week') {
      const r: DateRange = weekRangeOf(today)
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
      const ym: string = `${y}-${m < 10 ? '0' + m : m}`
      const lastDay: Date = new Date(y, m, 0)
      const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
      return [`${ym}-01`, `${y}-${p(m)}-${p(lastDay.getDate())}`]
    }
    if (this.rangeType === 'year') {
      return [`${today.substring(0, 4)}-01-01`, today]
    }
    // all：取最早日期到今日
    let min: string = today
    for (let i = 0; i < this.doc.records.length; i++) {
      if (this.doc.records[i].date < min) {
        min = this.doc.records[i].date
      }
    }
    return [min, today]
  }

  private sortedDateKeys(rows: EnrichedRecord[]): string[] {
    const set: Set<string> = new Set<string>()
    for (let i = 0; i < rows.length; i++) {
      set.add(rows[i].date)
    }
    const keys: string[] = []
    const iter = set.keys()
    let k = iter.next()
    while (!k.done) {
      keys.push(k.value)
      k = iter.next()
    }
    keys.sort((a, b) => (a < b ? 1 : -1))
    return keys
  }

  private rowsOfDate(date: string, rows: EnrichedRecord[]): EnrichedRecord[] {
    return rows.filter((r: EnrichedRecord) => r.date === date)
  }

  /** 待导出的行（多选模式取选中，否则取当前筛选） */
  private exportRows(): EnrichedRecord[] {
    const all: EnrichedRecord[] = this.filtered()
    if (!this.selecting) {
      return all
    }
    return all.filter((r: EnrichedRecord) => this.selectedIds.indexOf(r.id) >= 0)
  }

  private toggleSelect(id: string): void {
    const idx: number = this.selectedIds.indexOf(id)
    if (idx >= 0) {
      const arr: string[] = []
      for (let i = 0; i < this.selectedIds.length; i++) {
        if (i !== idx) {
          arr.push(this.selectedIds[i])
        }
      }
      this.selectedIds = arr
    } else {
      this.selectedIds = [...this.selectedIds, id]
    }
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  /** 导出到 documentViewPicker 选择的路径 */
  private async doExport(kind: string): Promise<void> {
    this.showExportSheet = false
    const rows: EnrichedRecord[] = this.exportRows()
    if (rows.length === 0) {
      this.toast('没有可导出的记录')
      return
    }
    let fileName: string = ''
    let content: string = ''
    if (kind === 'csv') {
      fileName = `计件明细-${todayStr()}.csv`
      content = '\ufeff' + detailCsv(rows)
    } else if (kind === 'json') {
      fileName = `计件明细-${todayStr()}.json`
      const payload: JsonExportPayload = {
        exportedAt: Date.now(),
        count: rows.length,
        records: rows
      }
      content = JSON.stringify(payload, null, 2)
    } else if (kind === 'text') {
      fileName = `计件明细-${todayStr()}.txt`
      const lines: string[] = []
      for (let i = 0; i < rows.length; i++) {
        const r: EnrichedRecord = rows[i]
        lines.push(`${r.date} ${r.productName} ${r.processName} ${qty(r.quantity)}×${money(r.price)}=${money(r.amount)} ${r.worker || ''} ${r.shift === 'night' ? '夜班' : '白班'}${r.note ? ' ' + r.note : ''}`)
      }
      content = lines.join('\n')
    } else if (kind === 'xls') {
      fileName = `计件明细-${todayStr()}.xls`
      const total: number = sumAmount(rows)
      const sheets: SheetData[] = [
        { name: '计件明细', aoa: detailAoa(rows) },
        {
          name: '汇总',
          aoa: [
            ['计件明细汇总'],
            ['项目', '数值'],
            ['合计金额(元)', total],
            ['件数', qty(sumQty(rows))],
            ['笔数', rows.length],
            ['导出时间', todayStr()]
          ]
        }
      ]
      content = buildXls(sheets)
    } else {
      return
    }
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
      fs.writeSync(file.fd, content)
      fs.closeSync(file)
      this.toast(`已导出 ${fileName}`)
    } catch (e) {
      this.toast('导出失败')
    }
  }

  @Builder
  rangeChip(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(this.rangeType === key ? Theme.blue() : Theme.card())
      .fontColor(this.rangeType === key ? Theme.card() : Theme.text())
      .borderRadius(12)
      .onClick(() => {
        this.rangeType = key
      })
  }

  /** 导出选项列表 */
  private exportOptions(): ExportOption[] {
    return [
      { key: 'csv', label: 'CSV 文件（Excel 可直接打开）' },
      { key: 'xls', label: 'Excel 文件（.xls，含汇总表）' },
      { key: 'json', label: 'JSON 文件' },
      { key: 'text', label: '文本文件' }
    ]
  }

  @Builder
  exportSheet() {
    Column({ space: 6 }) {
      Text('导出明细')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16, bottom: 10 })
      ForEach(this.exportOptions(), (item: ExportOption) => {
        Text(item.label)
          .fontSize(14)
          .width('100%')
          .padding(12)
          .backgroundColor(Theme.bg())
          .borderRadius(8)
          .onClick(() => {
            this.doExport(item.key)
          })
      }, (item: ExportOption) => item.key)
      Blank().height(20)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(Theme.card())
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('明细')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        if (this.selecting) {
          Text(`已选 ${this.selectedIds.length} 项`)
            .fontSize(13)
            .fontColor(Theme.sub())
            .margin({ right: 12 })
          Text('导出选中')
            .fontSize(14)
            .fontColor(Theme.blue())
            .margin({ right: 12 })
            .onClick(() => {
              this.showExportSheet = true
            })
          Text('取消')
            .fontSize(14)
            .fontColor(Theme.sub())
            .onClick(() => {
              this.selecting = false
              this.selectedIds = []
            })
        } else {
          Text('批量导出')
            .fontSize(14)
            .fontColor(Theme.blue())
            .onClick(() => {
              this.showExportSheet = true
            })
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.card())

      // 筛选区
      Column({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            this.rangeChip('week', '本周')
            this.rangeChip('month', '本月')
            this.rangeChip('lastMonth', '上月')
            this.rangeChip('year', '年度')
            this.rangeChip('all', '全部')
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Scroll() {
          Row({ space: 8 }) {
            Text('全部产品')
              .fontSize(12)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.filterProduct === '' ? Theme.blue() : Theme.card())
              .fontColor(this.filterProduct === '' ? Theme.card() : Theme.text())
              .borderRadius(12)
              .onClick(() => {
                this.filterProduct = ''
              })
            ForEach(this.doc.products, (p: import('../model/Types').Product) => {
              Text(p.name)
                .fontSize(12)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.filterProduct === p.id ? Theme.blue() : Theme.card())
                .fontColor(this.filterProduct === p.id ? Theme.card() : Theme.text())
                .borderRadius(12)
                .onClick(() => {
                  this.filterProduct = p.id
                })
            }, (p: import('../model/Types').Product) => p.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Row({ space: 8 }) {
          Text('全部工人')
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.filterWorker === '' ? Theme.blue() : Theme.card())
            .fontColor(this.filterWorker === '' ? Theme.card() : Theme.text())
            .borderRadius(12)
            .onClick(() => {
              this.filterWorker = ''
            })
          ForEach(this.doc.workers, (w: Worker) => {
            Text(w.name)
              .fontSize(12)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.filterWorker === w.name ? Theme.blue() : Theme.card())
              .fontColor(this.filterWorker === w.name ? Theme.card() : Theme.text())
              .borderRadius(12)
              .onClick(() => {
                this.filterWorker = w.name
              })
          }, (w: Worker) => w.name)
          Text('白班')
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.filterShift === 'day' ? Theme.blue() : Theme.card())
            .fontColor(this.filterShift === 'day' ? Theme.card() : Theme.text())
            .borderRadius(12)
            .onClick(() => {
              this.filterShift = this.filterShift === 'day' ? '' : 'day'
            })
          Text('夜班')
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.filterShift === 'night' ? Theme.blue() : Theme.card())
            .fontColor(this.filterShift === 'night' ? Theme.card() : Theme.text())
            .borderRadius(12)
            .onClick(() => {
              this.filterShift = this.filterShift === 'night' ? '' : 'night'
            })
        }
      }
      .width('100%')
      .padding(10)
      .backgroundColor(Theme.card())
      .borderRadius(10)
      .margin({ left: 10, right: 10, top: 8 })

      // 结果统计
      Row() {
        Text(`共 ${this.filtered().length} 条 · 合计 ${money(sumAmount(this.filtered()))}`)
          .fontSize(12)
          .fontColor(Theme.sub())
          .margin({ left: 14, top: 6, bottom: 4 })
        Blank()
      }
      .width('100%')

      // 分组列表
      List({ space: 6 }) {
        ForEach(this.sortedDateKeys(this.filtered()), (date: string) => {
          ListItemGroup() {
            ListItem() {
              Row() {
                Text(date)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                Text(`合计 ${money(sumAmount(this.rowsOfDate(date, this.filtered())))} · ${qty(sumQty(this.rowsOfDate(date, this.filtered())))} 件`)
                  .fontSize(12)
                  .fontColor(Theme.sub())
                Blank()
                Text(`${this.rowsOfDate(date, this.filtered()).length} 笔`)
                  .fontSize(12)
                  .fontColor(Theme.sub())
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(Theme.chip())
            }

            ForEach(this.rowsOfDate(date, this.filtered()), (r: EnrichedRecord) => {
              ListItem() {
                Row({ space: 10 }) {
                  if (this.selecting) {
                    Text(this.selectedIds.indexOf(r.id) >= 0 ? '☑' : '☐')
                      .fontSize(18)
                      .fontColor(Theme.blue())
                  }
                  Column({ space: 3 }) {
                    Text(`${r.productName} · ${r.processName}`)
                      .fontSize(14)
                      .fontColor(Theme.text())
                    Text(`${r.worker || '未填工人'}  ${r.shift === 'night' ? '夜班' : '白班'}${r.note ? '  ' + r.note : ''}`)
                      .fontSize(11)
                      .fontColor(Theme.sub())
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column({ space: 3 }) {
                    Text(money(r.amount))
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.text())
                    Text(`${qty(r.quantity)}×${money(r.price)}`)
                      .fontSize(11)
                      .fontColor(Theme.sub())
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(Theme.card())
                .onClick(() => {
                  if (this.selecting) {
                    this.toggleSelect(r.id)
                  } else {
                    router.pushUrl({ url: 'pages/RecordDetailPage', params: { id: r.id } })
                  }
                })
                .gesture(
                  LongPressGesture()
                    .onAction(() => {
                      if (!this.selecting) {
                        this.selecting = true
                        this.toggleSelect(r.id)
                      }
                    })
                )
              }
            }, (r: EnrichedRecord) => r.id)
          }
        }, (date: string) => date)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .padding({ bottom: 12 })

      if (this.filtered().length === 0) {
        Column({ space: 8 }) {
          Text('暂无符合条件的记录')
            .fontSize(14)
            .fontColor(Theme.sub())
        }
        .width('100%')
        .padding({ top: 40 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg())
    .bindSheet(this.showExportSheet, this.exportSheet(), { height: 300 })
  }
}
