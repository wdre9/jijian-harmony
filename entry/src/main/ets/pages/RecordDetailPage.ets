/**
 * 记录详情页：展示单条计件记录，支持编辑/删除
 */
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { money, qty } from '../utils/FormatUtils'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'

interface DetailParams {
  id: string
}

@Entry
@Component
struct RecordDetailPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State recordId: string = ''
  private store: AppStore = AppStore.getInstance()

  private record() {
    return this.doc.records.find((r) => r.id === this.recordId)
  }

  private productName(id: string): string {
    const p = this.doc.products.find((x) => x.id === id)
    return p ? p.name : '未知产品'
  }

  private processName(id: string): string {
    const c = this.doc.processes.find((x) => x.id === id)
    return c ? c.name : '未知工序'
  }

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams
    if (params && params.id) {
      this.recordId = params.id
    }
  }

  private async doDelete(): Promise<void> {
    const r = this.record()
    if (!r) {
      return
    }
    const res = await promptAction.showDialog({
      title: '删除记录',
      message: '确定删除这条记录吗？',
      buttons: [
        { text: '取消', color: GRAY },
        { text: '删除', color: '#ee0a24' }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.deleteRecord(r.id)
      router.back()
    }
  }

  private goEdit(): void {
    router.pushUrl({ url: 'pages/RecordEditPage', params: { id: this.recordId } })
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
        Text('记录详情')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('编辑')
          .fontSize(15)
          .fontColor(BLUE)
          .onClick(() => {
            this.goEdit()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#ffffff')

      Scroll() {
        Column({ space: 10 }) {
          // 金额卡片
          Column({ space: 6 }) {
            Text(money(this.record() ? this.record()!.amount : 0))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f67a2e')
            Text(this.record() ? `${this.record()!.date}  ${this.record()!.shift === 'night' ? '夜班' : '白班'}` : '')
              .fontSize(13)
              .fontColor(GRAY)
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#fff7ec')
          .borderRadius(12)

          // 信息行
          Column({ space: 0 }) {
            Row() {
              Text('产品')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? this.productName(this.record()!.productId) : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('工序')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? this.processName(this.record()!.processId) : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('数量')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? qty(this.record()!.quantity) : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('单价(元)')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? money(this.record()!.price) : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('金额(元)')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? money(this.record()!.amount) : '')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('工人')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? (this.record()!.worker || '未填') : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
            Divider().color('#f2f3f5')

            Row() {
              Text('备注')
                .fontSize(13)
                .fontColor(GRAY)
                .width(80)
              Text(this.record() ? (this.record()!.note || '无') : '')
                .fontSize(15)
            }
            .width('100%')
            .padding(12)
          }
          .width('100%')
          .backgroundColor('#ffffff')
          .borderRadius(12)

          Button('删除这条记录')
            .width('100%')
            .height(44)
            .backgroundColor('#ffffff')
            .fontColor('#ee0a24')
            .borderRadius(10)
            .onClick(() => {
              this.doDelete()
            })
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
  }
}
