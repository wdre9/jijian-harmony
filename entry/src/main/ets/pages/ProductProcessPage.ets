/**
 * 产品与工序管理页：产品 CRUD、工序 CRUD（启停/编辑/删除）
 */
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc, Process, Product } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { money } from '../utils/FormatUtils'
import { sumAmount, enrichRecords, EnrichedRecord } from '../utils/StatsUtils'
import { Theme } from '../common/Theme'


@CustomDialog
struct ProductSheetDialog {
  controller?: CustomDialogController
  @Link pName: string
  @Link pSpec: string
  @Link pNote: string
  onSave: () => void = () => {
  }

  build() {
    Column({ space: 10 }) {
      Text('新增产品')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16 })
      TextInput({ text: this.pName, placeholder: '产品名称（如 法兰盘）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.pName = v
        })
      TextInput({ text: this.pSpec, placeholder: '规格（选填，如 φ100）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.pSpec = v
        })
      TextInput({ text: this.pNote, placeholder: '备注（选填）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.pNote = v
        })
      Button('保存')
        .width('100%')
        .height(40)
        .backgroundColor(Theme.blue())
        .onClick(() => {
          this.onSave()
        })
      Blank().height(20)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor(Theme.card())
  }
}

@CustomDialog
struct ProcessSheetDialog {
  controller?: CustomDialogController
  @Link cName: string
  @Link cPrice: string
  @Link cNote: string
  @Link cProductId: string
  title: string = '新增工序'
  products: Product[] = []
  onSave: () => void = () => {
  }

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding({ top: 16 })
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.products, (p: Product) => {
            Text(p.name)
              .fontSize(12)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.cProductId === p.id ? Theme.blue() : Theme.chip())
              .fontColor(this.cProductId === p.id ? Theme.card() : Theme.text())
              .borderRadius(12)
              .onClick(() => {
                this.cProductId = p.id
              })
          }, (p: Product) => p.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      TextInput({ text: this.cName, placeholder: '工序名称（如 车外圆）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.cName = v
        })
      TextInput({ text: this.cPrice, placeholder: '单价（元）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.cPrice = v
        })
      TextInput({ text: this.cNote, placeholder: '备注（选填）' })
        .width('100%')
        .height(40)
        .onChange((v: string) => {
          this.cNote = v
        })
      Button('保存')
        .width('100%')
        .height(40)
        .backgroundColor(Theme.blue())
        .onClick(() => {
          this.onSave()
        })
      Blank().height(20)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor(Theme.card())
  }
}


@Entry
@Component
export struct ProductProcessPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State tab: string = 'product'
  @State filterProductId: string = ''
  @State editingProcess: Process | null = null
  // 表单
  @State pName: string = ''
  @State pSpec: string = ''
  @State pNote: string = ''
  @State cName: string = ''
  @State cPrice: string = ''
  @State cProductId: string = ''
  @State cNote: string = ''
  private productDialogCtrl: CustomDialogController = new CustomDialogController({
    builder: ProductSheetDialog({
      pName: $pName, pSpec: $pSpec, pNote: $pNote,
      onSave: () => { this.doAddProduct() }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })
  private processDialogCtrl: CustomDialogController = new CustomDialogController({
    builder: ProcessSheetDialog({
      cName: $cName, cPrice: $cPrice, cNote: $cNote, cProductId: $cProductId,
      title: '新增工序',
      products: this.doc.products,
      onSave: () => { this.doSaveProcess() }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })
  private store: AppStore = AppStore.getInstance()

  private productOf(id: string): Product | undefined {
    return this.doc.products.find((p: Product) => p.id === id)
  }

  private processCount(productId: string): number {
    return this.doc.processes.filter((c: Process) => c.productId === productId).length
  }

  private recordCountOfProduct(productId: string): number {
    return this.doc.records.filter((r) => r.productId === productId).length
  }

  private amountOfProduct(productId: string): number {
    const rows: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
      .filter((r: EnrichedRecord) => r.productId === productId)
    return sumAmount(rows)
  }

  private visibleProcesses(): Process[] {
    let list: Process[] = this.doc.processes
    if (this.filterProductId) {
      list = list.filter((c: Process) => c.productId === this.filterProductId)
    }
    list.sort((a, b) => {
      if (a.productId !== b.productId) {
        return a.productId < b.productId ? -1 : 1
      }
      return a.sort - b.sort
    })
    return list
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  private openAddProduct(): void {
    this.pName = ''
    this.pSpec = ''
    this.pNote = ''
    this.productDialogCtrl = new CustomDialogController({
      builder: ProductSheetDialog({
        pName: $pName, pSpec: $pSpec, pNote: $pNote,
        onSave: () => { this.doAddProduct() }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this.productDialogCtrl.open()
  }

  private async doAddProduct(): Promise<void> {
    if (!this.pName.trim()) {
      this.toast('请输入产品名称')
      return
    }
    this.doc = await this.store.addProduct(this.pName.trim(), this.pSpec.trim(), this.pNote.trim())
    this.productDialogCtrl.close()
    this.toast('已添加产品')
  }

  private async doDeleteProduct(p: Product): Promise<void> {
    const res = await promptAction.showDialog({
      title: '删除产品',
      message: `删除「${p.name}」将同时删除其工序与相关记录，确定？`,
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '删除', color: Theme.red() }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.deleteProduct(p.id)
      this.toast('已删除')
    }
  }

  private openAddProcess(): void {
    this.cName = ''
    this.cPrice = '0'
    this.cNote = ''
    this.cProductId = this.filterProductId || (this.doc.products.length > 0 ? this.doc.products[0].id : '')
    this.editingProcess = null
    this.processDialogCtrl = new CustomDialogController({
      builder: ProcessSheetDialog({
        cName: $cName, cPrice: $cPrice, cNote: $cNote, cProductId: $cProductId,
        title: '新增工序',
        products: this.doc.products,
        onSave: () => { this.doSaveProcess() }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this.processDialogCtrl.open()
  }

  private openEditProcess(c: Process): void {
    this.cName = c.name
    this.cPrice = String(c.price)
    this.cNote = c.note
    this.cProductId = c.productId
    this.editingProcess = c
    this.processDialogCtrl = new CustomDialogController({
      builder: ProcessSheetDialog({
        cName: $cName, cPrice: $cPrice, cNote: $cNote, cProductId: $cProductId,
        title: '编辑工序',
        products: this.doc.products,
        onSave: () => { this.doSaveProcess() }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this.processDialogCtrl.open()
  }

  private async doSaveProcess(): Promise<void> {
    if (!this.cProductId) {
      this.toast('请选择产品')
      return
    }
    if (!this.cName.trim()) {
      this.toast('请输入工序名称')
      return
    }
    const price: number = parseFloat(this.cPrice) || 0
    if (price < 0) {
      this.toast('单价不合法')
      return
    }
    if (this.editingProcess) {
      const c: Process = this.editingProcess
      const updated: Process = {
        id: c.id,
        productId: this.cProductId,
        name: this.cName.trim(),
        price: price,
        note: this.cNote.trim(),
        active: c.active,
        sort: c.sort,
        createdAt: c.createdAt,
        updatedAt: Date.now()
      }
      this.doc = await this.store.updateProcess(updated)
      this.toast('已保存')
    } else {
      this.doc = await this.store.addProcess(this.cProductId, this.cName.trim(), price, this.cNote.trim())
      this.toast('已添加工序')
    }
    this.processDialogCtrl.close()
  }

  private async doDeleteProcess(c: Process): Promise<void> {
    const res = await promptAction.showDialog({
      title: '删除工序',
      message: `确定删除工序「${c.name}」？历史记录保留。`,
      buttons: [
        { text: '取消', color: Theme.sub() },
        { text: '删除', color: Theme.red() }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.deleteProcess(c.id)
      this.toast('已删除')
    }
  }

  private async toggleProcessActive(c: Process): Promise<void> {
    const updated: Process = {
      id: c.id,
      productId: c.productId,
      name: c.name,
      price: c.price,
      note: c.note,
      active: !c.active,
      sort: c.sort,
      createdAt: c.createdAt,
      updatedAt: Date.now()
    }
    this.doc = await this.store.updateProcess(updated)
  }

  @Builder
  productList() {
    List({ space: 10 }) {
      ForEach(this.doc.products, (p: Product) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Row({ space: 6 }) {
                Text(p.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                if (p.spec) {
                  Text(p.spec)
                    .fontSize(11)
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .backgroundColor(Theme.weakBlue())
                    .fontColor(Theme.blue())
                    .borderRadius(8)
                }
              }
              Text(`${this.processCount(p.id)} 道工序 · ${this.recordCountOfProduct(p.id)} 条记录`)
                .fontSize(12)
                .fontColor(Theme.sub())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Column({ space: 3 }) {
              Text(money(this.amountOfProduct(p.id)))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text())
              Text('删除')
                .fontSize(11)
                .fontColor(Theme.red())
                .onClick(() => {
                  this.doDeleteProduct(p)
                })
            }
            .alignItems(HorizontalAlign.End)
            Text('›')
              .fontSize(18)
              .fontColor(Theme.divider())
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProductDetailPage', params: { id: p.id } })
          })
        }
      }, (p: Product) => p.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 8 })
    .scrollBar(BarState.Auto)
  }

  @Builder
  processList() {
    Column() {
      Scroll() {
        Row({ space: 8 }) {
          Text('全部')
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.filterProductId === '' ? Theme.blue() : Theme.card())
            .fontColor(this.filterProductId === '' ? Theme.card() : Theme.text())
            .borderRadius(12)
            .onClick(() => {
              this.filterProductId = ''
            })
          ForEach(this.doc.products, (p: Product) => {
            Text(p.name)
              .fontSize(12)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.filterProductId === p.id ? Theme.blue() : Theme.card())
              .fontColor(this.filterProductId === p.id ? Theme.card() : Theme.text())
              .borderRadius(12)
              .onClick(() => {
                this.filterProductId = p.id
              })
          }, (p: Product) => p.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding(12)

      List({ space: 10 }) {
        ForEach(this.visibleProcesses(), (c: Process) => {
          ListItem() {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(c.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(c.active ? Theme.text() : Theme.sub())
                  if (this.productOf(c.productId)) {
                    Text(this.productOf(c.productId)!.name)
                      .fontSize(11)
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .backgroundColor(Theme.chip())
                      .fontColor(Theme.sub())
                      .borderRadius(8)
                  }
                  if (!c.active) {
                    Text('停用')
                      .fontSize(10)
                      .fontColor(Theme.red())
                  }
                }
                Text(money(c.price) + ' / 件')
                  .fontSize(12)
                  .fontColor(Theme.sub())
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: c.active })
                .selectedColor(Theme.blue())
                .onChange((on: boolean) => {
                  this.toggleProcessActive(c)
                })
              Text('编辑')
                .fontSize(12)
                .fontColor(Theme.blue())
                .onClick(() => {
                  this.openEditProcess(c)
                })
              Text('删除')
                .fontSize(12)
                .fontColor(Theme.red())
                .onClick(() => {
                  this.doDeleteProcess(c)
                })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Theme.card())
            .borderRadius(10)
          }
        }, (c: Process) => c.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .layoutWeight(1)
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
        Text('产品与工序')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.tab === 'product' ? '新增产品' : '新增工序')
          .fontSize(14)
          .fontColor(Theme.blue())
          .onClick(() => {
            if (this.tab === 'product') {
              this.openAddProduct()
            } else {
              this.openAddProcess()
            }
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.card())

      // 分段
      Row({ space: 6 }) {
        Text('产品')
          .fontSize(14)
          .width(90)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.tab === 'product' ? Theme.blue() : Theme.chip())
          .fontColor(this.tab === 'product' ? Theme.card() : Theme.text())
          .borderRadius(16)
          .onClick(() => {
            this.tab = 'product'
          })
        Text('工序')
          .fontSize(14)
          .width(90)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.tab === 'process' ? Theme.blue() : Theme.chip())
          .fontColor(this.tab === 'process' ? Theme.card() : Theme.text())
          .borderRadius(16)
          .onClick(() => {
            this.tab = 'process'
          })
      }
      .margin({ top: 8, bottom: 4 })

      if (this.tab === 'product') {
        this.productList()
      } else {
        this.processList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg())
  }
}
