/**
 * 首页：底部四个主 Tab（记账 / 明细 / 统计 / 我的）
 */
import { DataDoc } from '../model/Types'
import { AppStore } from '../store/AppStore'
import { HomePage } from './HomePage'
import { DetailPage } from './DetailPage'
import { StatsPage } from './StatsPage'
import { MyPage } from './MyPage'
import { Theme } from '../common/Theme'


@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @State loading: boolean = true
  @State doc: DataDoc = AppStore.getInstance().doc
  /** 数据版本号：AppStore 每次落库/变更后 bump，跨组件通知刷新（不依赖路由回调） */
  @StorageProp('docVersion') @Watch('onDocVersion') docVersion: number = 0
  private store: AppStore = AppStore.getInstance()

  aboutToAppear(): void {
    this.checkReady()
  }

  onPageShow(): void {
    if (this.store.ready) {
      this.doc = this.store.snapshot()
    }
  }

  private onDocVersion(): void {
    if (this.store.ready) {
      this.doc = this.store.snapshot()
    }
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
        .fontColor(this.currentTab === index ? Theme.blue() : Theme.sub())
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? Theme.blue() : Theme.sub())
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
            .color(Theme.blue())
          Text('正在加载数据…')
            .fontSize(14)
            .fontColor(Theme.sub())
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
        .backgroundColor(Theme.bg())
        .onChange((index: number) => {
          this.currentTab = index
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
