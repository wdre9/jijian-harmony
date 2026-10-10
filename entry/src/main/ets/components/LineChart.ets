/**
 * Canvas 自绘折线趋势图（统计页：金额按日趋势）
 */
import { TrendPoint } from '../model/Types'

const BLUE: string = '#1989fa'
const GRID: string = '#e5e5e5'
const TEXT: string = '#666666'

@Component
export struct LineChart {
  @Prop @Watch('onDataChange') points: TrendPoint[] = []
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
      .height(180)
      .onReady(() => {
        this.readyFlag = true
        this.draw()
      })
  }

  private draw(): void {
    const ctx = this.ctx
    const pts: TrendPoint[] = this.points
    const W: number = ctx.width
    const H: number = ctx.height
    ctx.clearRect(0, 0, W, H)
    if (pts.length === 0) {
      return
    }
    const padL: number = 40
    const padR: number = 10
    const padT: number = 14
    const padB: number = 26
    const plotW: number = W - padL - padR
    const plotH: number = H - padT - padB
    let maxV: number = 0
    for (let i = 0; i < pts.length; i++) {
      if (pts[i].amount > maxV) {
        maxV = pts[i].amount
      }
    }
    if (maxV <= 0) {
      maxV = 1
    }
    // 网格 + y 轴标签
    ctx.strokeStyle = GRID
    ctx.lineWidth = 1
    ctx.fillStyle = TEXT
    ctx.font = '10vp sans-serif'
    ctx.textAlign = 'right'
    ctx.textBaseline = 'middle'
    for (let g = 0; g <= 4; g++) {
      const y: number = padT + plotH * g / 4
      ctx.beginPath()
      ctx.moveTo(padL, y)
      ctx.lineTo(W - padR, y)
      ctx.stroke()
      const label: number = maxV * (4 - g) / 4
      ctx.fillText(String(Math.round(label)), padL - 6, y)
    }
    // 折线
    ctx.strokeStyle = BLUE
    ctx.lineWidth = 2
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) {
      const x: number = pts.length === 1 ? padL + plotW / 2 : padL + plotW * i / (pts.length - 1)
      const y: number = padT + plotH * (1 - pts[i].amount / maxV)
      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    }
    ctx.stroke()
    // 数据点 + x 轴日期标签
    ctx.fillStyle = BLUE
    ctx.textAlign = 'center'
    ctx.textBaseline = 'top'
    const labelIdx: number[] = [0, Math.floor(pts.length / 2), pts.length - 1]
    for (let i = 0; i < pts.length; i++) {
      const x: number = pts.length === 1 ? padL + plotW / 2 : padL + plotW * i / (pts.length - 1)
      const y: number = padT + plotH * (1 - pts[i].amount / maxV)
      ctx.beginPath()
      ctx.arc(x, y, 2.5, 0, Math.PI * 2)
      ctx.fill()
      if (labelIdx.indexOf(i) >= 0) {
        const ds: string = pts[i].date
        ctx.fillText(ds.length >= 10 ? ds.substring(5) : ds, x, padT + plotH + 6)
      }
    }
  }
}
