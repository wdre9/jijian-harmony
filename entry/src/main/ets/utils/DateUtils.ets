/**
 * 日期工具（对齐 jijian-app/src/utils/date.ts）
 */

/** 日期区间 */
export interface DateRange {
  start: string
  end: string
}

/** Date -> YYYY-MM-DD */
export function toDateStr(d: Date): string {
  const p = (n: number): string => {
    return n < 10 ? `0${n}` : String(n)
  }
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

/** 今天 YYYY-MM-DD */
export function todayStr(): string {
  return toDateStr(new Date())
}

/** 两个 YYYY-MM-DD 相差天数（b - a） */
export function daysBetween(a: string, b: string): number {
  const da: Date = new Date(`${a}T00:00:00`)
  const db: Date = new Date(`${b}T00:00:00`)
  return Math.round((db.getTime() - da.getTime()) / 86400000)
}

/** 某天所在周的周一（自然周，周一到周日） */
export function mondayOf(dateStr: string): string {
  const d: Date = new Date(`${dateStr}T00:00:00`)
  const dow: number = d.getDay() === 0 ? 7 : d.getDay()
  d.setDate(d.getDate() - (dow - 1))
  return toDateStr(d)
}

/** 某天所在周区间 */
export function weekRangeOf(dateStr: string): DateRange {
  const start: string = mondayOf(dateStr)
  const s: Date = new Date(`${start}T00:00:00`)
  s.setDate(s.getDate() + 6)
  return { start: start, end: toDateStr(s) }
}

/** 本月（offset=0）/ 上月（offset=-1）区间 */
export function monthRangeOf(offset: number): DateRange {
  const now: Date = new Date()
  const y: number = now.getFullYear()
  const m: number = now.getMonth() + 1 + offset
  const first: Date = new Date(y, m - 1, 1)
  const last: Date = new Date(y, m, 0)
  return { start: toDateStr(first), end: toDateStr(last) }
}

/** 近 N 天区间（含今天） */
export function lastNDaysRange(n: number): DateRange {
  const end: Date = new Date()
  const start: Date = new Date()
  start.setDate(start.getDate() - (n - 1))
  return { start: toDateStr(start), end: toDateStr(end) }
}

/** 年度区间 */
export function yearRangeOf(year: number): DateRange {
  const y: number = year <= 0 ? new Date().getFullYear() : year
  return { start: `${y}-01-01`, end: `${y}-12-31` }
}

/** YYYY-MM-DD -> YYYY-MM */
export function ymOf(dateStr: string): string {
  return dateStr.length >= 7 ? dateStr.substring(0, 7) : dateStr
}

/** 日期友好展示：今天 / 昨天 / 周X / MM-DD */
export function groupTitle(dateStr: string): string {
  const today: string = todayStr()
  if (dateStr === today) {
    return '今天'
  }
  if (daysBetween(dateStr, today) === 1) {
    return '昨天'
  }
  if (daysBetween(dateStr, today) === 2) {
    return '前天'
  }
  const d: Date = new Date(`${dateStr}T00:00:00`)
  const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  const now: Date = new Date()
  if (d.getFullYear() === now.getFullYear()) {
    return `${d.getMonth() + 1}月${d.getDate()}日 ${week[d.getDay()]}`
  }
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
}

/** 时间友好展示 HH:mm */
export function timeHM(ms: number): string {
  const d: Date = new Date(ms)
  const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
  return `${p(d.getHours())}:${p(d.getMinutes())}`
}
