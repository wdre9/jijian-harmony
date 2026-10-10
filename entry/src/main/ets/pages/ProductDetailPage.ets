/**
 * 产品详情页：产品信息（可编辑）、该产品工序列表、统计与最近记录
 */
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc, PieceRecord, Process, Product } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { money, qty } from '../utils/FormatUtils'
import { EnrichedRecord, enrichRecords, sumAmount, sumQty } from '../utils/StatsUtils'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'

interface DetailParams {
  id: string
}

@Component
export struct ProductDetailPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State productId: string = ''
  @State showEditSheet: boolean = false
  @State eName: string = ''
  @State eSpec: string = ''
  @State eNote: string = ''
  private store: AppStore = AppStore.getInstance()

  private product(): Product | undefined {
    return this.doc.products.find((p: Product) => p.id === this.productId)
  }

  private processes(): Process[] {
    const list: Process[] = this.doc.processes.filter((c: Process) => c.productId === this.productId)
    list.sort((a, b) => a.sort - b.sort)
    return list
  }

  private records(): EnrichedRecord[] {
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    const list: EnrichedRecord[] = all.filter((r: EnrichedRecord) => r.productId === this.productId)
    list.sort((a, b) => (a.date < b.date ? 1 : -1))
    return list.slice(0, 20)
  }

  private totalAmount(): number {
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    return sumAmount(all.filter((r: EnrichedRecord) => r.productId === this.productId))
  }

  private totalQty(): number {
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    return sumQty(all.filter((r: EnrichedRecord) => r.productId === this.productId))
  }

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams
    if (params && params.id) {
      this.productId = params.id
    }
  }

  private openEdit(): void {
    const p: Product | undefined = this.product()
    if (!p) {
      return
    }
    this.eName = p.name
    this.eSpec = p.spec
    this.eNote = p.note
    this.showEditSheet = true
  }

  private async doSave(): Promise<void> {
    const p: Product | undefined = this.product()
    if (!p) {
      return
    }
    if (!this.eName.trim()) {
      this.toast('名称不能为空')
      return
    }
    const updated: Product = {
      id: p.id,
      name: this.eName.trim(),
      spec: this.eSpec.trim(),
      note: this.eNote.trim(),
      createdAt: p.createdAt,
      updatedAt: Date.now()
    }
    this.doc = await this.store.updateProduct(updated)
    this.showEditSheet = false
    this.toast('已保存')
  }

  private async doDelete(): Promise<void> {
    const p: Product | undefined = this.product()
    if (!p) {
      return
    }
    const res = await promptAction.showDialog({
      title: '删除产品',
      message: `删除「${p.name}」将同时删除其工序与相关记录，确定？`,
      buttons: [
        { text: '取消', color: GRAY },
        { text: '删除', color: '#ee0a24' }
      ]
    })
    if (res.index === 1) {
      await this.store.deleteProduct(p.id)
      router.back()
    }
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  @Builder
  editSheet() {
    Column({ space: 10 }) {
      Text('编辑产品')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16 })
      TextInput({ text: this.eName, placeholder: '产品名称' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.eName = v
        })
      TextInput({ text: this.eSpec, placeholder: '规格' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.eSpec = v
        })
      TextInput({ text: this.eNote, placeholder: '备注' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.eNote = v
        })
      Button('保存')
        .width('100%')
        .height(40)
        .backgroundColor(BLUE)
        .onClick(() => {
          this.doSave()
        })
      Blank().height(20)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#ffffff')
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(BLUE)
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('产品详情')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('编辑')
          .fontSize(15)
          .fontColor(BLUE)
          .onClick(() => {
            this.openEdit()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#ffffff')

      Scroll() {
        Column({ space: 10 }) {
          // 信息
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(this.product() ? this.product()!.name : '')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              if (this.product() && this.product()!.spec) {
                Text(this.product()!.spec)
                  .fontSize(12)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor('#e8f3ff')
                  .fontColor(BLUE)
                  .borderRadius(10)
              }
            }
            if (this.product() && this.product()!.note) {
              Text(this.product()!.note)
                .fontSize(12)
                .fontColor(GRAY)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 统计
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('笔数')
                .fontSize(11)
                .fontColor(GRAY)
              Text(String(this.doc.records.filter((r) => r.productId === this.productId).length))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor('#ffffff')
            .borderRadius(10)

            Column({ space: 4 }) {
              Text('件数')
                .fontSize(11)
                .fontColor(GRAY)
              Text(qty(this.totalQty()))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor('#ffffff')
            .borderRadius(10)

            Column({ space: 4 }) {
              Text('金额(元)')
                .fontSize(11)
                .fontColor(GRAY)
              Text(money(this.totalAmount()))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f67a2e')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor('#ffffff')
            .borderRadius(10)
          }
          .width('100%')

          // 工序
          Column({ space: 6 }) {
            Text(`工序（${this.processes().length}）`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            if (this.processes().length === 0) {
              Text('暂无工序，请到「产品与工序」中添加')
                .fontSize(12)
                .fontColor(GRAY)
            }
            ForEach(this.processes(), (c: Process) => {
              Row() {
                Text(c.name)
                  .fontSize(14)
                Blank()
                Text(money(c.price) + ' / 件')
                  .fontSize(13)
                  .fontColor(BLUE)
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .backgroundColor('#ffffff')
              .borderRadius(8)
            }, (c: Process) => c.id)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#f2f3f5')
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          // 最近记录
          Column({ space: 6 }) {
            Text('最近记录')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            ForEach(this.records(), (r: EnrichedRecord) => {
              Row() {
                Column({ space: 2 }) {
                  Text(r.date)
                    .fontSize(12)
                    .fontColor(GRAY)
                  Text(r.processName)
                    .fontSize(14)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Column({ space: 2 }) {
                  Text(money(r.amount))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                  Text(`${qty(r.quantity)}×${money(r.price)}`)
                    .fontSize(11)
                    .fontColor(GRAY)
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#ffffff')
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({ url: 'pages/RecordDetailPage', params: { id: r.id } })
              })
            }, (r: EnrichedRecord) => r.id)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#f2f3f5')
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)

          Button('删除产品')
            .width('100%')
            .height(44)
            .backgroundColor('#ffffff')
            .fontColor('#ee0a24')
            .borderRadius(10)
            .onClick(() => {
              this.doDelete()
            })

          Blank().height(20)
        }
        .width('100%')
        .padding(12)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f7f8fa')
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.showEditSheet, this.editSheet(), { height: 360 })
  }
}
