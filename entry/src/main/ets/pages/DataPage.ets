/**
 * 数据与导出页：备份导出/导入、CSV/Excel/文本导出、演示数据、清空数据
 */
import { router, promptAction } from '@kit.ArkUI'
import { picker as documentViewPicker, fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { DataDoc, Process, Product } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { detailCsv, buildXls, SheetData, detailAoa, countText } from '../utils/ExporterUtils'
import { EnrichedRecord, enrichRecords, sumCount } from '../utils/StatsUtils'
import { todayStr, lastNDaysRange, monthRangeOf } from '../utils/DateUtils'
import { Theme } from '../common/Theme'


@Entry
@Component
export struct DataPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State exportRange: string = 'all'
  private store: AppStore = AppStore.getInstance()

  private rows(): EnrichedRecord[] {
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    if (this.exportRange === 'all') {
      return all
    }
    const r = this.exportRange === 'month' ? monthRangeOf(0) : lastNDaysRange(90)
    return all.filter((x: EnrichedRecord) => x.date >= r.start && x.date <= r.end)
  }

  private stamp(): string {
    const d: Date = new Date()
    const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
    return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  /** 保存文本到用户选择位置 */
  private async saveText(fileName: string, content: string): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const picker = new documentViewPicker.DocumentViewPicker(context)
    const opt = new documentViewPicker.DocumentSaveOptions()
    opt.newFileNames = [fileName]
    const uris: Array<string> = await picker.save(opt)
    if (uris.length === 0) {
      this.toast('已取消保存')
      return
    }
    const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, content)
    fs.closeSync(file)
    this.toast(`已导出 ${fileName}`)
  }

  private async doExportJson(): Promise<void> {
    const text: string = this.store.exportDocText()
    await this.saveText(`计件备份-${this.stamp()}.json`, text)
  }

  private async doExportCsv(): Promise<void> {
    const csv: string = '\ufeff' + detailCsv(this.rows())
    await this.saveText(`计件明细-${this.stamp()}.csv`, csv)
  }

  private async doExportXls(): Promise<void> {
    const rows: EnrichedRecord[] = this.rows()
    const aoa: Array<Array<string | number>> = detailAoa(rows)
    const sheets: SheetData[] = [
      { name: '明细', aoa: aoa },
      { name: '汇总', aoa: [['计件工资明细表'], ['总笔数', `${rows.length}`], ['总件数', countText(rows)], ['总次数', `${sumCount(rows)}`], ['导出时间', todayStr()]] }
    ]
    const xml: string = buildXls(sheets)
    await this.saveText(`计件明细-${this.stamp()}.xls`, xml)
  }

  private async doExportTxt(): Promise<void> {
    const rows: EnrichedRecord[] = this.rows()
    const lines: string[] = []
    lines.push('计件工资明细')
    lines.push(`导出时间：${todayStr()}`)
    lines.push('')
    lines.push('日期\t产品\t规格\t工序\t数量\t次数\t单价(元)\t金额(元)\t工人\t班次\t备注')
    for (let i = 0; i < rows.length; i++) {
      const r: EnrichedRecord = rows[i]
      const cnt: string | number = r.countMode === 'manual' ? (typeof r.count === 'number' ? r.count : 1) : ''
      lines.push(
        `${r.date}\t${r.productName}\t${r.spec}\t${r.processName}\t${r.quantity}\t${cnt}\t${r.price}\t${r.amount}\t${r.worker || ''}\t${r.shift === 'night' ? '夜班' : '白班'}\t${r.note || ''}`
      )
    }
    await this.saveText(`计件明细-${this.stamp()}.txt`, lines.join('\r\n'))
  }

  private async doImportJson(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const picker = new documentViewPicker.DocumentViewPicker(context)
    const opt = new documentViewPicker.DocumentSelectOptions()
    const uris: Array<string> = await picker.select(opt)
    if (uris.length === 0) {
      this.toast('已取消选择')
      return
    }
    const res = await promptAction.showDialog({
      title: '导入备份',
      message: '导入将覆盖当前全部数据，确定继续？',
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '导入', color: Theme.blue() }
      ]
    })
    if (res.index !== 1) {
      return
    }
    try {
      const text: string = fs.readTextSync(uris[0])
      const err: string = await this.store.importDocText(text)
      if (err) {
        this.toast(err)
        return
      }
      this.doc = this.store.doc
      this.toast('导入成功')
    } catch (e) {
      this.toast('读取文件失败')
    }
  }

  private async doLoadDemo(): Promise<void> {
    const res = await promptAction.showDialog({
      title: '载入演示数据',
      message: '将覆盖当前全部数据并写入演示记录（近 14 天），确定？',
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '载入', color: Theme.blue() }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.loadDemoData()
      this.toast('已载入演示数据')
    }
  }

  private async doClearAll(): Promise<void> {
    const res = await promptAction.showDialog({
      title: '清空数据',
      message: '将删除全部产品、工序、记录与工人，此操作不可恢复，确定？',
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '清空', color: Theme.red() }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.clearAll()
      this.toast('已清空')
    }
  }

  @Builder
  exportRangeBar() {
    Column({ space: 6 }) {
      Text('明细导出范围')
        .fontSize(12)
        .fontColor(Theme.sub())
      Row({ space: 8 }) {
        ForEach(['all', 'month', '90d'] as string[], (key: string) => {
          Text(this.rangeLabel(key))
            .fontSize(12)
            .fontColor(this.exportRange === key ? Theme.blue() : Theme.sub())
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.exportRange === key ? Theme.weakBlue() : Theme.chip())
            .borderRadius(14)
            .onClick(() => {
              this.exportRange = key
            })
        }, (key: string) => key)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .backgroundColor(Theme.card())
    .borderRadius(10)
  }

  private rangeLabel(key: string): string {
    if (key === 'all') {
      return '全部'
    }
    if (key === 'month') {
      return '本月'
    }
    return '近90天'
  }

  @Builder
  group(title: string, children: Array<string>) {
    Column({ space: 0 }) {
      Text(title)
        .fontSize(13)
        .fontColor(Theme.sub())
        .padding({ left: 4, top: 12, bottom: 6 })
      Column({ space: 0 }) {
        ForEach(children, (key: string) => {
          Row() {
            Text(this.labelOf(key))
              .fontSize(14)
              .layoutWeight(1)
            Text('›')
              .fontSize(16)
              .fontColor(Theme.divider())
          }
          .width('100%')
          .height(44)
          .padding({ left: 14, right: 14 })
          .backgroundColor(Theme.card())
          .onClick(() => {
            this.onTap(key)
          })
        }, (key: string) => key)
      }
      .width('100%')
      .borderRadius(10)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private labelOf(key: string): string {
    if (key === 'exportJson') {
      return '导出 JSON 备份'
    }
    if (key === 'exportCsv') {
      return '导出 CSV（Excel 可打开）'
    }
    if (key === 'exportXls') {
      return '导出 Excel（.xls）'
    }
    if (key === 'exportTxt') {
      return '导出文本'
    }
    if (key === 'importJson') {
      return '导入 JSON 备份'
    }
    if (key === 'demo') {
      return '载入演示数据'
    }
    if (key === 'clear') {
      return '清空全部数据'
    }
    if (key === 'stats') {
      return '自动备份与数据说明'
    }
    return key
  }

  private onTap(key: string): void {
    if (key === 'exportJson') {
      this.doExportJson()
    } else if (key === 'exportCsv') {
      this.doExportCsv()
    } else if (key === 'exportXls') {
      this.doExportXls()
    } else if (key === 'exportTxt') {
      this.doExportTxt()
    } else if (key === 'importJson') {
      this.doImportJson()
    } else if (key === 'demo') {
      this.doLoadDemo()
    } else if (key === 'clear') {
      this.doClearAll()
    } else if (key === 'stats') {
      router.pushUrl({ url: 'pages/AboutPage' })
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(Theme.blue())
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('数据与导出')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.doc.records.length} 条记录`)
          .fontSize(13)
          .fontColor(Theme.sub())
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.card())

      Scroll() {
        Column({ space: 8 }) {
          this.exportRangeBar()
          this.group('导出', ['exportJson', 'exportCsv', 'exportXls', 'exportTxt'])
          this.group('导入与维护', ['importJson', 'demo', 'clear'])
          this.group('关于', ['stats'])

          Column({ space: 4 }) {
            Text('数据安全说明')
              .fontSize(13)
              .fontColor(Theme.sub())
              .padding({ left: 4, top: 10 })
            Text('所有数据仅保存在本机沙箱与关系型数据库中，不联网、不上传；自动备份 JSON 写入应用沙箱「计件自动备份」目录，滚动保留最近 14 份。')
              .fontSize(12)
              .fontColor(Theme.sub())
              .lineHeight(18)
              .padding(10)
              .backgroundColor(Theme.card())
              .borderRadius(10)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

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
  }
}
