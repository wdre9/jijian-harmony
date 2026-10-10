/**
 * Canvas 自绘柱状图（统计页：工序/工人排行）
 */
import { RankItem } from '../model/Types'

const BLUE: string = '#1989fa'
const GRID: string = '#e5e5e5'
const TEXT: string = '#666666'

@Component
export struct BarChart {
  @Prop @Watch('onDataChange') items: RankItem[] = []
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
      .height(190)
      .onReady(() => {
        this.readyFlag = true
        this.draw()
      })
  }

  private draw(): void {
    const ctx = this.ctx
    const list: RankItem[] = this.items
    const W: number = ctx.width
    const H: number = ctx.height
    ctx.clearRect(0, 0, W, H)
    if (list.length === 0) {
      return
    }
    const padL: number = 40
    const padR: number = 10
    const padT: number = 14
    const padB: number = 30
    const plotW: number = W - padL - padR
    const plotH: number = H - padT - padB
    let maxV: number = 0
    for (let i = 0; i < list.length; i++) {
      if (list[i].amount > maxV) {
        maxV = list[i].amount
      }
    }
    if (maxV <= 0) {
      maxV = 1
    }
    // 网格
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
    // 柱体
    const n: number = list.length
    const slot: number = plotW / n
    const barW: number = Math.min(slot * 0.55, 48)
    ctx.textAlign = 'center'
    ctx.textBaseline = 'top'
    for (let i = 0; i < n; i++) {
      const h: number = plotH * (list[i].amount / maxV)
      const cx: number = padL + slot * i + slot / 2
      const x: number = cx - barW / 2
      const y: number = padT + plotH - h
      ctx.fillStyle = BLUE
      ctx.fillRect(x, y, barW, h)
      // 名称（太长截断）
      let name: string = list[i].name
      if (name.length > 5) {
        name = name.substring(0, 5) + '…'
      }
      ctx.fillStyle = TEXT
      ctx.fillText(name, cx, padT + plotH + 6)
    }
  }
}
