/**
 * 批量导入页：OCR 识别 + 文本解析（对齐 importer.ts 规则）+ 确认写入
 * 解析全部在本机完成，不上传任何数据。
 */
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc, ImportParseResult, ImportRow, Process, Product } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { parseImportText } from '../utils/ImporterUtils'
import { pickImageAndRecognize } from '../utils/OcrUtils'
import { money, qty } from '../utils/FormatUtils'
import { round, uid } from '../utils/FormatUtils'
import { Theme } from '../common/Theme'

const GREEN: string = '#36d399'

/** 解析行匹配到的产品与工序 */
interface ResolvedRow {
  product: Product
  process: Process
}

@Entry
@Component
export struct BatchImportPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State text: string = ''
  @State worker: string = ''
  @State shift: string = 'day'
  @State result: ImportParseResult | null = null
  @State importing: boolean = false
  @State ocrBusy: boolean = false
  @State importedCount: number = 0
  private store: AppStore = AppStore.getInstance()

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  private async doOcr(): Promise<void> {
    this.ocrBusy = true
    const text: string = await pickImageAndRecognize()
    this.ocrBusy = false
    if (!text) {
      this.toast('未识别到文本或已取消')
      return
    }
    this.text = this.text ? `${this.text}\n${text}` : text
    this.toast('已识别，请检查或直接解析')
  }

  private doParse(): void {
    if (!this.text.trim()) {
      this.toast('请先输入文本或使用 OCR 识别')
      return
    }
    this.result = parseImportText(this.text, this.worker)
    if (this.result.rows.length === 0) {
      this.toast('未解析到有效记录，请检查格式')
    }
  }

  private totalAmountOfResult(): number {
    if (!this.result) {
      return 0
    }
    let sum: number = 0
    for (let i = 0; i < this.result.rows.length; i++) {
      sum += this.result.rows[i].amount
    }
    return round(sum, 2)
  }

  /** 匹配或创建产品/工序，返回行 id */
  private resolveRow(row: ImportRow): ResolvedRow | null {
    // 产品：按名称（四位货号）匹配，无则创建
    let product: Product | undefined = this.doc.products.find((p: Product) => p.name === row.productName)
    if (!product) {
      const now: number = Date.now()
      product = {
        id: uid('p'),
        name: row.productName,
        spec: '',
        note: '批量导入自动创建',
        createdAt: now,
        updatedAt: now
      }
      this.doc.products.push(product)
    }
    // 工序：该产品下按名称匹配，无则创建（单价取本行）
    let process: Process | undefined = this.doc.processes.find(
      (c: Process) => c.productId === product!.id && c.name === row.processName)
    if (!process) {
      const now: number = Date.now()
      let maxSort: number = 0
      for (let i = 0; i < this.doc.processes.length; i++) {
        if (this.doc.processes[i].productId === product!.id) {
          maxSort = Math.max(maxSort, this.doc.processes[i].sort)
        }
      }
      process = {
        id: uid('c'),
        productId: product!.id,
        name: row.processName,
        price: row.price,
        note: '批量导入自动创建',
        active: true,
        sort: maxSort + 1,
        createdAt: now,
        updatedAt: now
      }
      this.doc.processes.push(process)
    }
    return { product: product!, process: process! }
  }

  private async doImport(): Promise<void> {
    if (this.importing) {
      return
    }
    if (!this.result || this.result.rows.length === 0) {
      this.toast('请先解析文本')
      return
    }
    this.importing = true
    const res = await promptAction.showDialog({
      title: '确认导入',
      message: `将导入 ${this.result.rows.length} 条记录，未解析 ${this.result.unparsed.length} 行（自动跳过）。确定？`,
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '导入', color: Theme.blue() }
      ]
    })
    if (res.index !== 1) {
      this.importing = false
      return
    }
    let okCount: number = 0
    try {
      for (let i = 0; i < this.result.rows.length; i++) {
        const row: ImportRow = this.result.rows[i]
        const r: ResolvedRow | null = this.resolveRow(row)
        if (!r) {
          continue
        }
        this.doc = await this.store.addRecord(
          row.date, r.product.id, r.process.id, row.quantity, row.price,
          row.worker || this.worker, row.shift, row.note)
        okCount++
      }
      this.importedCount = okCount
      this.toast(`导入完成：${okCount} 条`)
    } catch (e) {
      this.toast('导入失败，请重试')
    } finally {
      this.importing = false
      this.result = null
    }
  }

  @Builder
  resultPreview() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('可导入')
            .fontSize(11)
            .fontColor(Theme.sub())
          Text(String(this.result ? this.result.rows.length : 0))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(GREEN)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text('跳过标题')
            .fontSize(11)
            .fontColor(Theme.sub())
          Text(String(this.result ? this.result.skippedCount : 0))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.red())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text('金额合计(元)')
            .fontSize(11)
            .fontColor(Theme.sub())
          Text(money(this.totalAmountOfResult()))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.orange())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.result ? this.result.rows : [], (r: ImportRow, idx: number) => {
          ListItem() {
            Row({ space: 8 }) {
              Text(`${idx + 1}`)
                .fontSize(11)
                .width(22)
                .textAlign(TextAlign.Center)
                .fontColor(Theme.sub())
              Column({ space: 2 }) {
                Text(`${r.date} ${r.productName} · ${r.processName}`)
                  .fontSize(13)
                  .maxLines(1)
                Text(r.raw)
                  .fontSize(11)
                  .fontColor(Theme.sub())
                  .maxLines(1)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Column({ space: 2 }) {
                Text(money(r.amount))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                Text(`${qty(r.quantity)} × ${money(r.price)}`)
                  .fontSize(11)
                  .fontColor(Theme.sub())
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(Theme.card())
            .borderRadius(8)
          }
        }, (r: ImportRow, idx: number) => `${idx}-${r.line}-${r.raw}`)
      }
      .width('100%')
      .height(240)
      .scrollBar(BarState.Auto)

      if (this.result && this.result.unparsed.length > 0) {
        Column({ space: 4 }) {
          Text(`未解析行（${this.result.unparsed.length}）：`)
            .fontSize(12)
            .fontColor(Theme.red())
          ForEach(this.result.unparsed, (u: string, idx: number) => {
            Text(`${idx + 1}. ${u}`)
              .fontSize(11)
              .fontColor(Theme.sub())
              .maxLines(1)
          }, (u: string, idx: number) => `${idx}-${u}`)
        }
        .width('100%')
        .padding(10)
        .backgroundColor(Theme.redBg())
        .borderRadius(8)
        .alignItems(HorizontalAlign.Start)
      }

      Button('确认导入')
        .width('100%')
        .height(44)
        .backgroundColor(Theme.blue())
        .enabled(!this.importing)
        .onClick(() => {
          this.doImport()
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.bg())
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
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
        Text('批量导入')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.ocrBusy ? '识别中…' : 'OCR 识别')
          .fontSize(14)
          .fontColor(Theme.blue())
          .onClick(() => {
            this.doOcr()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.card())

      Scroll() {
        Column({ space: 10 }) {
          // 导入成功结果卡：明确反馈，避免空白页误导重复提交
          if (this.importedCount > 0) {
            Row({ space: 8 }) {
              Text('✓')
                .fontSize(18)
                .fontColor(GREEN)
              Column({ space: 2 }) {
                Text(`已导入 ${this.importedCount} 条记录`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.text())
                Text('可在「明细」页查看，如需再次导入请重新粘贴文本或 OCR')
                  .fontSize(11)
                  .fontColor(Theme.sub())
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#e8f9f0')
            .borderRadius(10)
            .alignItems(VerticalAlign.Center)
          }

          // 输入
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text('工人（选填）')
                .fontSize(12)
                .fontColor(Theme.sub())
              TextInput({ text: this.worker, placeholder: '默认工人' })
                .layoutWeight(1)
                .height(32)
                .fontSize(13)
                .onChange((v: string) => {
                  this.worker = v
                })
            }
            Row({ space: 8 }) {
              Text('班次')
                .fontSize(12)
                .fontColor(Theme.sub())
              Text('白班')
                .fontSize(12)
                .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                .backgroundColor(this.shift === 'day' ? Theme.blue() : Theme.card())
                .fontColor(this.shift === 'day' ? Theme.card() : Theme.text())
                .borderRadius(12)
                .onClick(() => {
                  this.shift = 'day'
                })
              Text('夜班')
                .fontSize(12)
                .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                .backgroundColor(this.shift === 'night' ? Theme.blue() : Theme.card())
                .fontColor(this.shift === 'night' ? Theme.card() : Theme.text())
                .borderRadius(12)
                .onClick(() => {
                  this.shift = 'night'
                })
            }
            TextArea({ text: this.text, placeholder: '粘贴计件明细文本，或点右上角「OCR 识别」从相册选图识别。支持格式：日期行（6/10 或 6月10日）、四位货号行、数量×单价=金额 行。' })
              .width('100%')
              .height(160)
              .fontSize(13)
              .onChange((v: string) => {
                this.text = v
              })
            Row({ space: 10 }) {
              Button('解析预览')
                .layoutWeight(1)
                .height(40)
                .backgroundColor(Theme.card())
                .fontColor(Theme.blue())
                .onClick(() => {
                  this.doParse()
                })
              Button('清空')
                .width(80)
                .height(40)
                .backgroundColor(Theme.card())
                .fontColor(Theme.red())
                .onClick(() => {
                  this.text = ''
                  this.result = null
                })
            }
          }
          .width('100%')
          .padding(12)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 解析结果
          if (this.result) {
            this.resultPreview()
          }

          Column({ space: 4 }) {
            Text('格式说明')
              .fontSize(13)
              .fontColor(Theme.sub())
            Text('每行一条：日期头（6/10、6月10日、2026/6/10）、四位货号或「计时」作为产品名、数量×单价=金额 自动计算、工序名从行尾清洗；无法解析的行会列入未解析清单，不会静默丢失。')
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
