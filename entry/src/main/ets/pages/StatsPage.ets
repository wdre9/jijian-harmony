/**
 * 统计 Tab：多区间汇总指标、金额趋势折线图、产品占比饼图、工序/工人排行柱状图、统计长图导出
 */
import { componentSnapshot, promptAction } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { abilityAccessCtrl, common } from '@kit.AbilityKit'
import { fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DataDoc, RankItem, ShareItem, TrendPoint } from '../model/Types'
import { AppStore } from '../store/AppStore'
import {
  EnrichedRecord, enrichRecords, maxDayAmount, rankBy, sharesOf,
  sumAmount, sumQty, trendByDay
} from '../utils/StatsUtils'
import { todayStr, weekRangeOf } from '../utils/DateUtils'
import { money, qty } from '../utils/FormatUtils'
import { LineChart } from '../components/LineChart'
import { BarChart } from '../components/BarChart'
import { PieChart } from '../components/PieChart'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'

@Component
export struct StatsPage {
  @Prop doc: DataDoc
  onDocChanged: (d: DataDoc) => void = (d: DataDoc) => {
  }
  private store: AppStore = AppStore.getInstance()

  @State rangeType: string = 'week'
  @State customStart: string = todayStr()
  @State customEnd: string = todayStr()
  @State pickingStart: boolean = false
  @State pickingEnd: boolean = false

  private rangeStartEnd(): string[] {
    const today: string = todayStr()
    if (this.rangeType === 'week') {
      return weekRangeOf(today)
    }
    if (this.rangeType === 'month') {
      const ym: string = today.substring(0, 7)
      return [`${ym}-01`, today]
    }
    if (this.rangeType === 'lastMonth') {
      const d: Date = new Date(`${today}T00:00:00`)
      d.setMonth(d.getMonth() - 1)
      const y: number = d.getFullYear()
      const m: number = d.getMonth() + 1
      const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
      const lastDay: Date = new Date(y, m, 0)
      return [`${y}-${p(m)}-01`, `${y}-${p(m)}-${p(lastDay.getDate())}`]
    }
    if (this.rangeType === 'year') {
      return [`${today.substring(0, 4)}-01-01`, today]
    }
    if (this.rangeType === 'custom') {
      return [this.customStart, this.customEnd]
    }
    // near30 / near90
    const days: number = this.rangeType === 'near30' ? 29 : 89
    const d: Date = new Date(`${today}T00:00:00`)
    d.setDate(d.getDate() - days)
    const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
    return [`${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`, today]
  }

  private rangeDays(): number {
    const r: string[] = this.rangeStartEnd()
    const sd: number = new Date(`${r[0]}T00:00:00`).getTime()
    const ed: number = new Date(`${r[1]}T00:00:00`).getTime()
    return Math.max(1, Math.floor((ed - sd) / 86400000) + 1)
  }

  private inRange(): EnrichedRecord[] {
    const r: string[] = this.rangeStartEnd()
    const all: EnrichedRecord[] = enrichRecords(this.doc.records, this.doc.products, this.doc.processes)
    return all.filter((x: EnrichedRecord) => x.date >= r[0] && x.date <= r[1])
  }

  private total(): number {
    return sumAmount(this.inRange())
  }

  private qtySum(): number {
    return sumQty(this.inRange())
  }

  private count(): number {
    return this.inRange().length
  }

  private dailyAvg(): number {
    return this.count() > 0 ? this.total() / this.rangeDays() : 0
  }

  private avgPrice(): number {
    return this.qtySum() > 0 ? this.total() / this.qtySum() : 0
  }

  private maxDay(): number {
    return maxDayAmount(this.inRange())
  }

  private trend(): TrendPoint[] {
    const r: string[] = this.rangeStartEnd()
    return trendByDay(this.inRange(), r[0], r[1])
  }

  private productShares(): ShareItem[] {
    return sharesOf(this.inRange(), (r: EnrichedRecord) => r.productName, 7)
  }

  private processRank(): RankItem[] {
    return rankBy(this.inRange(), (r: EnrichedRecord) => r.processName, 8)
  }

  private workerRank(): RankItem[] {
    return rankBy(this.inRange(), (r: EnrichedRecord) => (r.worker || '未填'), 8)
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  /** 截图统计区域并保存到相册 */
  private async saveSnapshot(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const atManager = abilityAccessCtrl.createAtManager()
    const perm: string = 'ohos.permission.WRITE_IMAGEVIDEO'
    let granted: boolean =
      atManager.checkAccessTokenSync(context.applicationInfo.accessToken, perm) ===
      abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    if (!granted) {
      const req = await atManager.requestPermissionsFromUser(context, [perm])
      granted = req.authResults.length > 0 && req.authResults[0] === 0
      if (!granted) {
        this.toast('需要相册写入权限才能保存长图')
        return
      }
    }
    componentSnapshot.get('statsArea', async (err: BusinessError, data: image.PixelMap) => {
      if (err) {
        this.toast('截图失败')
        return
      }
      try {
        const packer = image.createImagePacker()
        const opt: image.PackingOption = { format: 'image/png', quality: 100 }
        const buf: ArrayBuffer = await packer.packingToData(data, opt)
        const phAccess = photoAccessHelper.getPhotoAccessHelper(context)
        const createOpt = new photoAccessHelper.PhotoCreateOptions()
        createOpt.newFileNames = [`计件统计-${todayStr()}.png`]
        const uri: string = await phAccess.createAsset(createOpt)
        const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(file.fd, buf)
        fs.closeSync(file)
        packer.release()
        data.release()
        this.toast('统计长图已保存到相册')
      } catch (e) {
        this.toast('保存失败，请检查相册权限')
      }
    })
  }

  @Builder
  rangeChip(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(this.rangeType === key ? BLUE : '#ffffff')
      .fontColor(this.rangeType === key ? '#ffffff' : '#323233')
      .borderRadius(12)
      .onClick(() => {
        this.rangeType = key
      })
  }

  @Builder
  metricCard(label: string, value: string, color: string = '#323233') {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(GRAY)
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .backgroundColor('#ffffff')
    .borderRadius(10)
  }

  @Builder
  chartCard(title: string, chart: () => void) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
      chart()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor('#ffffff')
    .borderRadius(10)
  }

  @Builder
  legendRow(name: string, ratio: number, amount: number, color: string) {
    Row({ space: 6 }) {
      Circle({ width: 10, height: 10 })
        .fill(color)
      Text(name)
        .fontSize(12)
        .fontColor('#323233')
        .layoutWeight(1)
        .maxLines(1)
      Text(`${Math.round(ratio * 100)}%`)
        .fontSize(11)
        .fontColor(GRAY)
      Text(money(amount))
        .fontSize(12)
        .fontColor('#323233')
        .width(70)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
  }

  build() {
    Column() {
      Row() {
        Text('统计')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('导出长图')
          .fontSize(14)
          .fontColor(BLUE)
          .onClick(() => {
            this.saveSnapshot()
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#ffffff')

      Scroll() {
        Column({ space: 10 }) {
          // 范围选择
          Column({ space: 8 }) {
            Scroll() {
              Row({ space: 8 }) {
                this.rangeChip('week', '本周')
                this.rangeChip('month', '本月')
                this.rangeChip('lastMonth', '上月')
                this.rangeChip('near30', '近30天')
                this.rangeChip('near90', '近90天')
                this.rangeChip('year', '年度')
                this.rangeChip('custom', '自定义')
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            if (this.rangeType === 'custom') {
              Row({ space: 10 }) {
                Text(`开始 ${this.customStart}`)
                  .fontSize(12)
                  .padding(6)
                  .backgroundColor('#f2f3f5')
                  .borderRadius(6)
                  .onClick(() => {
                    DatePickerDialog.show({
                      selected: new Date(`${this.customStart}T00:00:00`),
                      start: new Date('2020-01-01'),
                      end: new Date('2032-12-31'),
                      onDateAccept: (d: Date) => {
                        const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
                        this.customStart = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
                        if (this.customStart > this.customEnd) {
                          this.customEnd = this.customStart
                        }
                      }
                    })
                  })
                Text(`结束 ${this.customEnd}`)
                  .fontSize(12)
                  .padding(6)
                  .backgroundColor('#f2f3f5')
                  .borderRadius(6)
                  .onClick(() => {
                    DatePickerDialog.show({
                      selected: new Date(`${this.customEnd}T00:00:00`),
                      start: new Date('2020-01-01'),
                      end: new Date('2032-12-31'),
                      onDateAccept: (d: Date) => {
                        const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
                        this.customEnd = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
                      }
                    })
                  })
              }
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#ffffff')
          .borderRadius(10)

          // 指标
          Row({ space: 10 }) {
            this.metricCard('合计金额(元)', money(this.total()), '#f67a2e')
            this.metricCard('件数', qty(this.qtySum()))
            this.metricCard('笔数', String(this.count()))
          }
          .width('100%')
          Row({ space: 10 }) {
            this.metricCard('日均金额(元)', money(this.dailyAvg()))
            this.metricCard('平均单价(元)', money(this.avgPrice()))
            this.metricCard('最高单日(元)', money(this.maxDay()))
          }
          .width('100%')

          // 趋势
          this.chartCard('金额趋势', () => {
            LineChart({ points: this.trend() })
              .width('100%')
          })

          // 产品占比
          this.chartCard('产品金额占比', () => {
            PieChart({ items: this.productShares() })
              .width('100%')
            Column({ space: 0 }) {
              ForEach(this.productShares(), (s: ShareItem, idx: number) => {
                const colors: string[] = ['#1989fa', '#36d399', '#f67a2e', '#ffc928', '#7d5bf5', '#fa4d4d', '#00b8c5', '#b3a4ff']
                this.legendRow(s.name, s.ratio, s.amount, colors[idx] ?? '#1989fa')
              }, (s: ShareItem, idx: number) => `${s.name}-${idx}`)
            }
            .width('100%')
          })

          // 工序排行
          this.chartCard('工序排行（金额）', () => {
            BarChart({ items: this.processRank() })
              .width('100%')
            Column({ space: 0 }) {
              ForEach(this.processRank(), (r: RankItem, idx: number) => {
                Row({ space: 6 }) {
                  Text(`${idx + 1}`)
                    .fontSize(12)
                    .width(20)
                    .height(20)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(idx < 3 ? '#e8f3ff' : '#f2f3f5')
                    .fontColor(idx === 0 ? '#f67a2e' : '#323233')
                    .borderRadius(10)
                  Text(r.name)
                    .fontSize(12)
                    .layoutWeight(1)
                    .maxLines(1)
                  Text(`${qty(r.quantity)} 件`)
                    .fontSize(11)
                    .fontColor(GRAY)
                  Text(money(r.amount))
                    .fontSize(12)
                    .width(70)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .margin({ top: 3, bottom: 3 })
              }, (r: RankItem, idx: number) => `${r.name}-${idx}`)
            }
            .width('100%')
          })

          // 工人排行
          this.chartCard('工人排行（金额）', () => {
            BarChart({ items: this.workerRank() })
              .width('100%')
            Column({ space: 0 }) {
              ForEach(this.workerRank(), (r: RankItem, idx: number) => {
                Row({ space: 6 }) {
                  Text(`${idx + 1}`)
                    .fontSize(12)
                    .width(20)
                    .height(20)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(idx < 3 ? '#e8f3ff' : '#f2f3f5')
                    .fontColor(idx === 0 ? '#f67a2e' : '#323233')
                    .borderRadius(10)
                  Text(r.name)
                    .fontSize(12)
                    .layoutWeight(1)
                    .maxLines(1)
                  Text(`${qty(r.quantity)} 件`)
                    .fontSize(11)
                    .fontColor(GRAY)
                  Text(money(r.amount))
                    .fontSize(12)
                    .width(70)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .margin({ top: 3, bottom: 3 })
              }, (r: RankItem, idx: number) => `${r.name}-${idx}`)
            }
            .width('100%')
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
    .id('statsArea')
  }
}
