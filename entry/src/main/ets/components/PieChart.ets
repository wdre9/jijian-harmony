/**
 * Canvas 自绘环形饼图（统计页：产品金额占比）
 */
import { ShareItem } from '../model/Types'
import { money } from '../utils/FormatUtils'
import { Theme } from '../common/Theme'

const COLORS: string[] = ['#1989fa', '#36d399', '#f67a2e', '#ffc928', '#7d5bf5', '#fa4d4d', '#00b8c5', '#b3a4ff']

@Component
export struct PieChart {
  @Prop @Watch('onDataChange') items: ShareItem[] = []
  @Prop @Watch('onDataChange') dark: boolean = false
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private readyFlag: boolean = false

  private onDataChange(): void {
    if (this.readyFlag) {
      this.draw()
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(200)
      .onReady(() => {
        this.readyFlag = true
        this.draw()
      })
  }

  private draw(): void {
    const ctx = this.ctx
    const list: ShareItem[] = this.items
    const W: number = ctx.width
    const H: number = ctx.height
    ctx.clearRect(0, 0, W, H)
    if (list.length === 0) {
      return
    }
    const cx: number = W / 2
    const cy: number = H / 2
    const R: number = Math.min(W, H) / 2 - 16
    const rInner: number = R * 0.62
    let total: number = 0
    for (let i = 0; i < list.length; i++) {
      total += list[i].amount
    }
    if (total <= 0) {
      return
    }
    let startAngle: number = -Math.PI / 2
    for (let i = 0; i < list.length; i++) {
      const sweep: number = 2 * Math.PI * (list[i].amount / total)
      ctx.beginPath()
      ctx.arc(cx, cy, R, startAngle, startAngle + sweep)
      ctx.arc(cx, cy, rInner, startAngle + sweep, startAngle, true)
      ctx.closePath()
      ctx.fillStyle = COLORS[i % COLORS.length]
      ctx.fill()
      startAngle += sweep
    }
    // 中心文字：总额（深色下用浅色文字）
    ctx.fillStyle = Theme.isDark() ? '#e8e8ec' : '#333333'
    ctx.font = '12vp sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(money(total), cx, cy)
  }
}
