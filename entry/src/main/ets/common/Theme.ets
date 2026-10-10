/**
 * 全局主题工具（深色模式配色中心）
 * 所有页面通过 Theme.xxx() 取色，构建时实时读取 AppStore.isDark()，
 * 切换主题 / 系统深浅色变化后，页面因 doc 变化或 @State 刷新重新求值即可全局生效。
 */
import { AppStore } from '../store/AppStore'

export class Theme {
  /** 当前是否深色（读取全局主题设置 + 系统模式） */
  static isDark(): boolean {
    return AppStore.getInstance().isDark()
  }

  /** 页面背景 */
  static bg(): string {
    return Theme.isDark() ? '#14151a' : '#f7f8fa'
  }

  /** 卡片 / 白色块背景 */
  static card(): string {
    return Theme.isDark() ? '#1f2026' : '#ffffff'
  }

  /** 分组灰底（列表项未选中 / 次级底） */
  static group(): string {
    return Theme.isDark() ? '#1a1b21' : '#f2f3f5'
  }

  /** 芯片未选中底 */
  static chip(): string {
    return Theme.isDark() ? '#2a2b33' : '#f2f3f5'
  }

  /** 分隔线 / 进度条底 */
  static line(): string {
    return Theme.isDark() ? '#3a3b45' : '#ebedf0'
  }

  /** 输入框底 */
  static input(): string {
    return Theme.isDark() ? '#26272e' : '#f7f8fa'
  }

  /** 主文字 */
  static text(): string {
    return Theme.isDark() ? '#e8e8ec' : '#323233'
  }

  /** 次要文字 */
  static sub(): string {
    return Theme.isDark() ? '#9a9aa5' : '#969799'
  }

  /** 弱化文字（提示 / 箭头） */
  static divider(): string {
    return Theme.isDark() ? '#5c5c66' : '#c8c9cc'
  }

  /** 选中浅蓝底 */
  static weakBlue(): string {
    return Theme.isDark() ? '#1f3a56' : '#e8f3ff'
  }

  /** 品牌蓝 */
  static blue(): string {
    return Theme.isDark() ? '#3d9bfb' : '#1989fa'
  }

  /** 强调橙 */
  static orange(): string {
    return Theme.isDark() ? '#ff9f4d' : '#f67a2e'
  }

  /** 危险红 */
  static red(): string {
    return Theme.isDark() ? '#ff5c5c' : '#ee0a24'
  }

  /** 金额橙底 */
  static orangeBg(): string {
    return Theme.isDark() ? '#3a2d1f' : '#fff7ec'
  }

  /** 错误 / 删除红底 */
  static redBg(): string {
    return Theme.isDark() ? '#3a2020' : '#fdf0f0'
  }

  /** 纯白（蓝底按钮文字等固定场景） */
  static white(): string {
    return '#ffffff'
  }

  /** 图表坐标文字 */
  static chartText(): string {
    return Theme.isDark() ? '#8a8a95' : '#666666'
  }

  /** 图表网格线 */
  static grid(): string {
    return Theme.isDark() ? '#3a3b45' : '#e5e5e5'
  }
}
