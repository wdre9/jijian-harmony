/**
 * 关于页：版本信息、功能特性、数据安全与技术栈说明
 */
import { router, promptAction } from '@kit.ArkUI'

const BLUE: string = '#1989fa'
const GRAY: string = '#969799'

@Component
export struct AboutPage {
  @State version: string = '0.1.0'

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 })
  }

  @Builder
  featureRow(icon: string, title: string, desc: string) {
    Row({ space: 10 }) {
      Text(icon)
        .fontSize(18)
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor('#e8f3ff')
        .borderRadius(17)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        Text(desc)
          .fontSize(11)
          .fontColor(GRAY)
          .lineHeight(16)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
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
        Text('关于')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`v${this.version}`)
          .fontSize(13)
          .fontColor(GRAY)
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#ffffff')

      Scroll() {
        Column({ space: 10 }) {
          Column({ space: 6 }) {
            Text('计件')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
            Text('计件工资记账助手 · HarmonyOS NEXT 原生版')
              .fontSize(12)
              .fontColor(GRAY)
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#ffffff')
          .borderRadius(10)

          Column({ space: 0 }) {
            Text('功能特性')
              .fontSize(13)
              .fontColor(GRAY)
              .padding({ left: 4, top: 10, bottom: 4 })
            Column({ space: 0 }) {
              this.featureRow('📝', '快速记账', '选择产品工序、步进数量、自动算金额，支持白班/夜班与工人')
              this.featureRow('📊', '多维统计', '本周/本月/上月/近30/近90/年度/自定义区间，趋势图、占比图、排行图')
              this.featureRow('📷', 'OCR 本地识别', '相册选图本地识别文本，配合批量导入一键录入，数据不出本机')
              this.featureRow('🔄', '自动备份', '保存后按 24 小时节流自动备份 JSON，滚动保留最近 14 份')
              this.featureRow('📁', '灵活导出', 'CSV / Excel(.xls) / JSON / 文本 / 统计长图导出')
              this.featureRow('🌓', '多主题', '浅色 / 深色 / 跟随系统三模式')
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#ffffff')
            .borderRadius(10)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('数据安全')
              .fontSize(13)
              .fontColor(GRAY)
              .padding({ left: 4, top: 10 })
            Text('所有数据仅保存在本机应用沙箱（RelationalStore 关系型数据库与本地文件）中，不联网、不上传、不收集任何个人信息；OCR 识别在设备端完成；卸载应用前请先导出备份。')
              .fontSize(12)
              .fontColor(GRAY)
              .lineHeight(18)
              .padding(10)
              .backgroundColor('#ffffff')
              .borderRadius(10)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('技术栈')
              .fontSize(13)
              .fontColor(GRAY)
              .padding({ left: 4, top: 10 })
            Text('ArkTS + ArkUI（Stage 模型）、@ohos.data.relationalStore、@ohos.data.preferences、@kit.CoreVisionKit（OCR）、@kit.ImageKit、@kit.CoreFileKit、@kit.ArkUI（Canvas 自绘图表 / componentSnapshot）')
              .fontSize(12)
              .fontColor(GRAY)
              .lineHeight(18)
              .padding(10)
              .backgroundColor('#ffffff')
              .borderRadius(10)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('开源')
              .fontSize(13)
              .fontColor(GRAY)
              .padding({ left: 4, top: 10 })
            Text('源码开源在 GitHub：github.com/wdre9/jijian-harmony，欢迎提交 Issue 与 PR。')
              .fontSize(12)
              .fontColor(GRAY)
              .lineHeight(18)
              .padding(10)
              .backgroundColor('#ffffff')
              .borderRadius(10)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

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
  }
}
