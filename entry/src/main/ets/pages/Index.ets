/**
 * 首页：底部四个主 Tab（记账 / 明细 / 统计 / 我的）
 */
import { DataDoc } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { HomePage } from './HomePage'
import { DetailPage } from './DetailPage'
import { StatsPage } from './StatsPage'
import { MyPage } from './MyPage'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'
const BG: string = '#f7f8fa'

@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @State loading: boolean = true
  @State doc: DataDoc = AppStore.getInstance().doc
  private store: AppStore = AppStore.getInstance()

  aboutToAppear(): void {
    this.checkReady()
  }

  /** 等待数据层初始化完成 */
  private checkReady(): void {
    if (this.store.ready) {
      this.doc = this.store.snapshot()
      this.loading = false
    } else {
      setTimeout(() => {
        this.checkReady()
      }, 120)
    }
  }

  @Builder
  tabBuilder(index: number, icon: string, title: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(20)
        .fontColor(this.currentTab === index ? BLUE : GRAY)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? BLUE : GRAY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(BLUE)
          Text('正在加载数据…')
            .fontSize(14)
            .fontColor(GRAY)
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
          TabContent() {
            HomePage({
              doc: this.doc,
              onDocChanged: (d: DataDoc) => {
                this.doc = d
              },
              onJumpRecordEdit: () => {
                this.currentTab = 0
              },
              onJumpDetail: () => {
                this.currentTab = 1
              }
            })
          }
          .tabBar(this.tabBuilder(0, '记', '记账'))

          TabContent() {
            DetailPage({
              doc: this.doc,
              onDocChanged: (d: DataDoc) => {
                this.doc = d
              }
            })
          }
          .tabBar(this.tabBuilder(1, '细', '明细'))

          TabContent() {
            StatsPage({
              doc: this.doc
            })
          }
          .tabBar(this.tabBuilder(2, '统', '统计'))

          TabContent() {
            MyPage({
              doc: this.doc,
              onDocChanged: (d: DataDoc) => {
                this.doc = d
              }
            })
          }
          .tabBar(this.tabBuilder(3, '我', '我的'))
        }
        .backgroundColor(BG)
        .onChange((index: number) => {
          this.currentTab = index
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
