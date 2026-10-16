/**
 * 记账编辑页：产品/工序选择、数量步进、单价、日期、班次、工人、备注
 */
import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { DataDoc, PieceRecord, Process, Product, Worker } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { todayStr, toDateStr } from '../utils/DateUtils'
import { money, round } from '../utils/FormatUtils'
import { Theme } from '../common/Theme'


interface EditParams {
  id?: string
}

@Entry
@Component
struct RecordEditPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State editId: string = ''
  @State dateText: string = todayStr()
  @State productId: string = ''
  @State processId: string = ''
  /** 'existing' 已有工序 | 'custom' 手动输入 | 'none' 不填（未分类） */
  @State processMode: string = 'existing'
  @State customProcessName: string = ''
  /** 'auto' 按条数 | 'manual' 手动输入件次 */
  @State countMode: string = 'auto'
  @State countText: string = '1'
  @State quantityText: string = '1'
  @State priceText: string = '0'
  @State workerText: string = ''
  @State shift: string = 'day'
  @State noteText: string = ''
  @State showProductSheet: boolean = false
  @State showProcessSheet: boolean = false
  @State saving: boolean = false
  private store: AppStore = AppStore.getInstance()

  aboutToAppear(): void {
    const params = router.getParams() as EditParams
    if (params && params.id) {
      this.editId = params.id
      const r: PieceRecord | undefined = this.store.doc.records.find((x: PieceRecord) => x.id === params.id)
      if (r) {
        this.dateText = r.date
        this.productId = r.productId
        this.processId = r.processId
        this.processMode = r.processId.length > 0 ? 'existing' : (r.processNameSnapshot.length > 0 ? 'custom' : 'none')
        this.customProcessName = r.processId.length > 0 ? '' : r.processNameSnapshot
        this.countMode = typeof r.countMode === 'string' ? r.countMode : 'auto'
        this.countText = String(typeof r.count === 'number' ? r.count : 1)
        this.quantityText = String(r.quantity)
        this.priceText = String(r.price)
        this.workerText = r.worker
        this.shift = r.shift
        this.noteText = r.note
      }
    } else {
      const s = this.store.doc.settings
      if (s.rememberLast && s.lastProductId) {
        this.productId = s.lastProductId
        if (s.lastProcessId) {
          this.processId = s.lastProcessId
        }
      }
      this.workerText = s.defaultWorker
    }
    this.syncPrice()
  }

  private products(): Product[] {
    return this.store.doc.products
  }

  private processesOf(): Process[] {
    if (!this.productId) {
      return []
    }
    return this.store.doc.processes.filter((c: Process) => c.productId === this.productId)
  }

  private currentProduct(): Product | undefined {
    return this.store.doc.products.find((p: Product) => p.id === this.productId)
  }

  private currentProcess(): Process | undefined {
    return this.store.doc.processes.find((c: Process) => c.id === this.processId)
  }

  private currentAmount(): number {
    const q: number = parseFloat(this.quantityText) || 0
    const p: number = parseFloat(this.priceText) || 0
    return round(q * p, 2)
  }

  /** 选择工序后自动带出单价（用户可改） */
  private syncPrice(): void {
    const c: Process | undefined = this.currentProcess()
    if (c && (!this.priceText || parseFloat(this.priceText) <= 0)) {
      this.priceText = String(c.price)
    }
  }

  private selectProduct(p: Product): void {
    this.productId = p.id
    this.processId = ''
    this.processMode = 'existing'
    this.priceText = '0'
    this.showProductSheet = false
  }

  private selectProcess(c: Process): void {
    this.processId = c.id
    this.processMode = 'existing'
    this.customProcessName = ''
    this.priceText = String(c.price)
    this.showProcessSheet = false
  }

  private currentProcessName(): string {
    if (this.processMode === 'custom') {
      return this.customProcessName.trim()
    }
    if (this.processMode === 'none') {
      return ''
    }
    const c: Process | undefined = this.currentProcess()
    return c ? c.name : ''
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return
    }
    if (!this.productId) {
      this.toast('请选择产品')
      return
    }
    let snap: string = ''
    let finalProcessId: string = ''
    if (this.processMode === 'existing') {
      if (!this.processId) {
        this.toast('请选择工序')
        return
      }
      const c: Process | undefined = this.currentProcess()
      if (!c) {
        this.toast('工序不存在，请重新选择')
        return
      }
      finalProcessId = c.id
      snap = c.name
    } else if (this.processMode === 'custom') {
      const name: string = this.customProcessName.trim()
      if (!name) {
        this.toast('请输入工序名称')
        return
      }
      finalProcessId = ''
      snap = name
    } else {
      finalProcessId = ''
      snap = ''
    }
    const isManual: boolean = this.countMode === 'manual'
    const cnt: number = isManual ? Math.max(0, Math.round(parseFloat(this.countText) || 0)) : 1
    const q: number = parseFloat(this.quantityText) || 0
    const p: number = parseFloat(this.priceText) || 0
    if (!(q > 0)) {
      this.toast('数量需大于 0')
      return
    }
    if (!(p >= 0)) {
      this.toast('单价不合法')
      return
    }
    this.saving = true
    try {
      const now: number = Date.now()
      if (this.editId) {
        const old: PieceRecord | undefined = this.store.doc.records.find((x: PieceRecord) => x.id === this.editId)
        const r: PieceRecord = {
          id: this.editId,
          date: this.dateText,
          productId: this.productId,
          processId: finalProcessId,
          processNameSnapshot: snap,
          countMode: isManual ? 'manual' : 'auto',
          count: isManual ? cnt : 1,
          quantity: q,
          price: p,
          amount: round(q * p, 2),
          worker: this.workerText.trim(),
          shift: this.shift,
          note: this.noteText.trim(),
          createdAt: old ? old.createdAt : now,
          updatedAt: now
        }
        this.doc = await this.store.updateRecord(r)
      } else {
        this.doc = await this.store.addRecord(
          this.dateText, this.productId, finalProcessId, q, p,
          this.workerText.trim(), this.shift, this.noteText.trim(), snap,
          isManual ? 'manual' : 'auto', isManual ? cnt : 1)
      }
      this.toast(this.editId ? '已保存' : '记账成功')
      router.back()
    } catch (e) {
      this.toast('保存失败，请重试')
    } finally {
      this.saving = false
    }
  }

  @Builder
  header() {
    Row() {
      Text('‹ 返回')
        .fontSize(15)
        .fontColor(Theme.blue())
        .onClick(() => {
          router.back()
        })
      Blank()
      Text(this.editId ? '编辑记录' : '记一笔')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Blank()
      Text(this.saving ? '保存中…' : '保存')
        .fontSize(15)
        .fontColor(this.saving ? Theme.sub() : Theme.blue())
        .onClick(() => {
          if (!this.saving) {
            this.save()
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Theme.card())
  }

  @Builder
  productSheet() {
    Column() {
      Text('选择产品')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16, bottom: 8 })
      List({ space: 4 }) {
        ForEach(this.products(), (p: Product) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(p.name)
                .fontSize(15)
                .layoutWeight(1)
              if (p.spec) {
                Text(p.spec)
                  .fontSize(12)
                  .fontColor(Theme.sub())
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.productId === p.id ? Theme.weakBlue() : Theme.card())
            .borderRadius(8)
            .onClick(() => {
              this.selectProduct(p)
            })
          }
        }, (p: Product) => p.id)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(Theme.bg())
  }

  @Builder
  processSheet() {
    Column() {
      Text('选择工序')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16, bottom: 8 })
      List({ space: 4 }) {
        ForEach(this.processesOf(), (c: Process) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(c.name)
                .fontSize(15)
                .layoutWeight(1)
              Text(money(c.price))
                .fontSize(13)
                .fontColor(Theme.blue())
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.processId === c.id ? Theme.weakBlue() : Theme.card())
            .borderRadius(8)
            .onClick(() => {
              this.selectProcess(c)
            })
          }
        }, (c: Process) => c.id)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(Theme.bg())
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column({ space: 10 }) {
          // 产品
          Row() {
            Column({ space: 4 }) {
              Text('产品')
                .fontSize(12)
                .fontColor(Theme.sub())
              Text(this.currentProduct() ? `${this.currentProduct()!.name}${this.currentProduct()!.spec ? '  ' + this.currentProduct()!.spec : ''}` : '点击选择产品')
                .fontSize(15)
                .fontColor(this.currentProduct() ? Theme.text() : Theme.blue())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor(Theme.divider())
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .onClick(() => {
            this.showProductSheet = true
          })
          .bindSheet(this.showProductSheet, this.productSheet(), { height: 420 })

          // 工序（三态：已有 / 手动输入 / 不填未分类）
          Column({ space: 8 }) {
            Text('工序')
              .fontSize(12)
              .fontColor(Theme.sub())
            Row({ space: 8 }) {
              Text('已有')
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.processMode === 'existing' ? Theme.blue() : Theme.chip())
                .fontColor(this.processMode === 'existing' ? Theme.card() : Theme.text())
                .borderRadius(14)
                .onClick(() => {
                  this.processMode = 'existing'
                  if (!this.productId) {
                    this.toast('请先选择产品')
                  } else if (!this.processId) {
                    this.showProcessSheet = true
                  }
                })
              Text('手动输入')
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.processMode === 'custom' ? Theme.blue() : Theme.chip())
                .fontColor(this.processMode === 'custom' ? Theme.card() : Theme.text())
                .borderRadius(14)
                .onClick(() => {
                  this.processMode = 'custom'
                })
              Text('不填(未分类)')
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.processMode === 'none' ? Theme.blue() : Theme.chip())
                .fontColor(this.processMode === 'none' ? Theme.card() : Theme.text())
                .borderRadius(14)
                .onClick(() => {
                  this.processMode = 'none'
                  this.processId = ''
                  this.customProcessName = ''
                })
            }
            if (this.processMode === 'existing') {
              Row() {
                Column({ space: 4 }) {
                  Text(this.currentProcess() ? this.currentProcess()!.name : '点击选择工序')
                    .fontSize(15)
                    .fontColor(this.currentProcess() ? Theme.text() : Theme.blue())
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›')
                  .fontSize(18)
                  .fontColor(Theme.divider())
              }
              .width('100%')
              .padding(10)
              .backgroundColor(Theme.line())
              .borderRadius(8)
              .onClick(() => {
                if (!this.productId) {
                  this.toast('请先选择产品')
                  return
                }
                this.showProcessSheet = true
              })
              .bindSheet(this.showProcessSheet, this.processSheet(), { height: 420 })
            } else if (this.processMode === 'custom') {
              TextInput({ text: this.customProcessName, placeholder: '输入自定义工序名' })
                .width('100%')
                .height(36)
                .fontSize(14)
                .onChange((v: string) => {
                  this.customProcessName = v
                })
            } else {
              Row() {
                Text('未分类（不填工序）')
                  .fontSize(14)
                  .fontColor(Theme.sub())
              }
              .width('100%')
              .padding(10)
              .backgroundColor(Theme.line())
              .borderRadius(8)
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 次数（件次）：自动按条数计 1 / 手动输入件次
          Column({ space: 8 }) {
            Text('次数')
              .fontSize(12)
              .fontColor(Theme.sub())
            Row({ space: 8 }) {
              Text('按条数(自动)')
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.countMode === 'auto' ? Theme.blue() : Theme.chip())
                .fontColor(this.countMode === 'auto' ? Theme.card() : Theme.text())
                .borderRadius(14)
                .onClick(() => {
                  this.countMode = 'auto'
                })
              Text('手动输入件次')
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.countMode === 'manual' ? Theme.blue() : Theme.chip())
                .fontColor(this.countMode === 'manual' ? Theme.card() : Theme.text())
                .borderRadius(14)
                .onClick(() => {
                  this.countMode = 'manual'
                })
            }
            if (this.countMode === 'manual') {
              TextInput({ text: this.countText, placeholder: '件次，如 12' })
                .width('100%')
                .height(36)
                .fontSize(14)
                .type(InputType.Normal)
                .onChange((v: string) => {
                  this.countText = v
                })
            } else {
              Text('每条记录计 1 次')
                .fontSize(13)
                .fontColor(Theme.sub())
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 数量 / 单价 / 金额
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
                    const v: number = (parseFloat(this.quantityText) || 1) - 1
                    this.quantityText = v > 0 ? String(v) : '1'
                  })
                TextInput({ text: this.quantityText, placeholder: '数量' })
                  .width(70)
                  .height(30)
                  .fontSize(14)
                  .type(InputType.Normal)
                  .textAlign(TextAlign.Center)
                  .onChange((v: string) => {
                    this.quantityText = v
                  })
                Button('+')
                  .width(30)
                  .height(30)
                  .fontSize(16)
                  .type(ButtonType.Circle)
                  .backgroundColor(Theme.weakBlue())
                  .fontColor(Theme.blue())
                  .onClick(() => {
                    const v: number = (parseFloat(this.quantityText) || 0) + 1
                    this.quantityText = String(v)
                  })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 4 }) {
              Text('单价(元)')
                .fontSize(12)
                .fontColor(Theme.sub())
              TextInput({ text: this.priceText, placeholder: '0.00' })
                .width(90)
                .height(30)
                .fontSize(14)
                .type(InputType.Normal)
                .textAlign(TextAlign.Center)
                .onChange((v: string) => {
                  this.priceText = v
                })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)

          Row() {
            Text('金额')
              .fontSize(14)
            Blank()
            Text(money(this.currentAmount()))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.orange())
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.orangeBg())
          .borderRadius(10)

          // 日期
          Row() {
            Column({ space: 4 }) {
              Text('日期')
                .fontSize(12)
                .fontColor(Theme.sub())
              Text(this.dateText)
                .fontSize(15)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('选择 ›')
              .fontSize(13)
              .fontColor(Theme.blue())
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .onClick(() => {
            DatePickerDialog.show({
              selected: new Date(`${this.dateText}T00:00:00`),
              start: new Date('2020-01-01'),
              end: new Date('2032-12-31'),
              onDateAccept: (d: Date) => {
                this.dateText = toDateStr(d)
              }
            })
          })

          // 班次
          Column({ space: 6 }) {
            Text('班次')
              .fontSize(12)
              .fontColor(Theme.sub())
            Row({ space: 8 }) {
              Text('白班')
                .fontSize(14)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.shift === 'day' ? Theme.blue() : Theme.line())
                .fontColor(this.shift === 'day' ? Theme.card() : Theme.text())
                .borderRadius(6)
                .onClick(() => {
                  this.shift = 'day'
                })
              Text('夜班')
                .fontSize(14)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.shift === 'night' ? Theme.blue() : Theme.line())
                .fontColor(this.shift === 'night' ? Theme.card() : Theme.text())
                .borderRadius(6)
                .onClick(() => {
                  this.shift = 'night'
                })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 工人
          Column({ space: 6 }) {
            Text('工人')
              .fontSize(12)
              .fontColor(Theme.sub())
            TextInput({ text: this.workerText, placeholder: '输入工人姓名' })
              .width('100%')
              .height(36)
              .fontSize(14)
              .onChange((v: string) => {
                this.workerText = v
              })
            if (this.store.doc.workers.length > 0) {
              Scroll() {
                Row({ space: 6 }) {
                  ForEach(this.store.doc.workers, (w: Worker) => {
                    Text(w.name)
                      .fontSize(12)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.workerText === w.name ? Theme.weakBlue() : Theme.chip())
                      .fontColor(this.workerText === w.name ? Theme.blue() : Theme.text())
                      .borderRadius(10)
                      .onClick(() => {
                        this.workerText = w.name
                      })
                  }, (w: Worker) => w.name)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 备注
          Column({ space: 6 }) {
            Text('备注')
              .fontSize(12)
              .fontColor(Theme.sub())
            TextInput({ text: this.noteText, placeholder: '选填' })
              .width('100%')
              .height(36)
              .fontSize(14)
              .onChange((v: string) => {
                this.noteText = v
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
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
