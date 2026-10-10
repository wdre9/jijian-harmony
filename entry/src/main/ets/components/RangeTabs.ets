/**
 * RangeTabs：区间切换组件（横向可滚动 chip 行）
 * 供统计页 / 明细页等复用；选中态品牌蓝，未选中态主题适配。
 */
import { Theme } from '../common/Theme'

/** 区间选项 */
export interface RangeTabOption {
  key: string
  label: string
}

@Component
export struct RangeTabs {
  /** 选项列表 */
  @Prop options: RangeTabOption[] = []
  /** 当前选中 key */
  @Prop selectedKey: string = 'week'
  onSelect: (key: string) => void = (key: string) => {
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.options, (o: RangeTabOption) => {
          Text(o.label)
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.selectedKey === o.key ? Theme.blue() : Theme.chip())
            .fontColor(this.selectedKey === o.key ? Theme.white() : Theme.text())
            .borderRadius(12)
            .onClick(() => {
              this.onSelect(o.key)
            })
        }, (o: RangeTabOption) => o.key)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
