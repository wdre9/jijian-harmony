/**
 * 工人管理页：工人名单维护（新增/删除），展示每人记录数与金额
 */
import { router, promptAction } from '@kit.ArkUI'
import { DataDoc, Worker } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { money } from '../utils/FormatUtils'
import { EnrichedRecord, enrichRecords, sumAmount } from '../utils/StatsUtils'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'

@Component
export struct WorkersPage {
  @State doc: DataDoc = AppStore.getInstance().doc
  @State name: string = ''
  private store: AppStore = AppStore.getInstance()

  private rowsOf(worker: string): EnrichedRecord[] {
    return enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
      .filter((r: EnrichedRecord) => r.worker === worker)
  }

  private lastUsed(worker: string): string {
    const rows: EnrichedRecord[] = this.rowsOf(worker)
    if (rows.length === 0) {
      return '未使用'
    }
    let max: string = rows[0].date
    for (let i = 1; i < rows.length; i++) {
      if (rows[i].date > max) {
        max = rows[i].date
      }
    }
    return max
  }

  private async doAdd(): Promise<void> {
    if (!this.name.trim()) {
      this.toast('请输入工人姓名')
      return
    }
    this.doc = await this.store.addWorker(this.name.trim())
    this.name = ''
    this.toast('已添加')
  }

  private async doRemove(w: Worker): Promise<void> {
    const res = await promptAction.showDialog({
      title: '删除工人',
      message: `确定将「${w.name}」移出名单？历史记录保留。`,
      buttons: [
        { text: '取消', color: GRAY },
        { text: '删除', color: '#ee0a24' }
      ]
    })
    if (res.index === 1) {
      this.doc = await this.store.removeWorker(w.name)
      this.toast('已删除')
    }
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
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
        Text('工人管理')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.doc.workers.length} 人`)
          .fontSize(13)
          .fontColor(GRAY)
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#ffffff')

      // 新增
      Row({ space: 8 }) {
        TextInput({ text: this.name, placeholder: '输入工人姓名' })
          .layoutWeight(1)
          .height(40)
          .onChange((v: string) => {
            this.name = v
          })
          .onSubmit(() => {
            this.doAdd()
          })
        Button('添加')
          .height(40)
          .backgroundColor(BLUE)
          .onClick(() => {
            this.doAdd()
          })
      }
      .width('100%')
      .padding(12)

      List({ space: 10 }) {
        ForEach(this.doc.workers, (w: Worker) => {
          ListItem() {
            Row({ space: 10 }) {
              Circle({ width: 36, height: 36 })
                .fill('#e8f3ff')
              Text(w.name.substring(0, 1))
                .fontSize(15)
                .fontColor(BLUE)
              Column({ space: 3 }) {
                Text(w.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                Text(`${this.rowsOf(w.name).length} 条记录 · 最近 ${this.lastUsed(w.name)}`)
                  .fontSize(11)
                  .fontColor(GRAY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Column({ space: 3 }) {
                Text(money(sumAmount(this.rowsOf(w.name))))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#f67a2e')
                Text('删除')
                  .fontSize(11)
                  .fontColor('#ee0a24')
                  .onClick(() => {
                    this.doRemove(w)
                  })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#ffffff')
            .borderRadius(10)
          }
        }, (w: Worker) => w.name)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f7f8fa')
  }
}
