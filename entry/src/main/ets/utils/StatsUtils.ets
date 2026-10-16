/**
 * 统计聚合（对齐 jijian-app/src/utils/stats.ts 的核心口径）
 */
import { BestDayInfo, PieceRecord, Process, Product, RankItem, ShareItem, TrendPoint } from '../model/Types'
import { round } from './FormatUtils'
import { ymOf } from './DateUtils'

/** 富化记录：附带产品/工序名称与规格 */
export interface EnrichedRecord extends PieceRecord {
  productName: string
  processName: string
  spec: string
  processNameSnapshot: string
  countMode: string
  count: number
}

/** 富化：为记录补充名称字段（按 id 查表） */
export function enrichRecords(records: PieceRecord[], products: Product[], processes: Process[]): EnrichedRecord[] {
  const pMap: Map<string, Product> = new Map<string, Product>()
  for (let i = 0; i < products.length; i++) {
    pMap.set(products[i].id, products[i])
  }
  const cMap: Map<string, Process> = new Map<string, Process>()
  for (let i = 0; i < processes.length; i++) {
    cMap.set(processes[i].id, processes[i])
  }
  const out: EnrichedRecord[] = []
  for (let i = 0; i < records.length; i++) {
    const r: PieceRecord = records[i]
    const p: Product | undefined = pMap.get(r.productId)
    const c: Process | undefined = cMap.get(r.processId)
    // 工序名优先使用快照（工序删除后仍显示原工序名）
    let pname: string = ''
    if (typeof r.processNameSnapshot === 'string' && r.processNameSnapshot.length > 0) {
      pname = r.processNameSnapshot
    } else {
      pname = c ? c.name : '未知工序'
    }
    const er: EnrichedRecord = {
      id: r.id,
      date: r.date,
      productId: r.productId,
      processId: r.processId,
      processNameSnapshot: typeof r.processNameSnapshot === 'string' ? r.processNameSnapshot : '',
      countMode: typeof r.countMode === 'string' ? r.countMode : 'auto',
      count: typeof r.count === 'number' ? r.count : 1,
      quantity: r.quantity,
      price: r.price,
      amount: r.amount,
      worker: r.worker,
      shift: r.shift,
      note: r.note,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      productName: p ? p.name : r.productId,
      processName: pname,
      spec: p ? p.spec : ''
    }
    out.push(er)
  }
  return out
}

/** 金额合计 */
export function sumAmount(list: EnrichedRecord[]): number {
  let s: number = 0
  for (let i = 0; i < list.length; i++) {
    s += list[i].amount || 0
  }
  return round(s, 2)
}

/** 件数合计 */
export function sumQty(list: EnrichedRecord[]): number {
  let s: number = 0
  for (let i = 0; i < list.length; i++) {
    s += list[i].quantity || 0
  }
  return round(s, 3)
}

/** 次数合计（手动模式累加用户输入的 count，自动模式按条数计 1，对齐 jijian-app times） */
export function sumCount(list: EnrichedRecord[]): number {
  let s: number = 0
  for (let i = 0; i < list.length; i++) {
    const r: EnrichedRecord = list[i]
    if (r.countMode === 'manual') {
      s += typeof r.count === 'number' ? r.count : 1
    } else {
      s += 1
    }
  }
  return round(s, 2)
}

/** 按日期分组（升序） */
export function groupByDate(list: EnrichedRecord[]): Map<string, EnrichedRecord[]> {
  const map: Map<string, EnrichedRecord[]> = new Map<string, EnrichedRecord[]>()
  for (let i = 0; i < list.length; i++) {
    const r: EnrichedRecord = list[i]
    let arr: EnrichedRecord[] | undefined = map.get(r.date)
    if (arr === undefined) {
      arr = []
      map.set(r.date, arr)
    }
    arr.push(r)
  }
  return map
}

/** 按 key 汇总金额 */
export function sumByKey(list: EnrichedRecord[], keyOf: (r: EnrichedRecord) => string): Map<string, number> {
  const map: Map<string, number> = new Map<string, number>()
  for (let i = 0; i < list.length; i++) {
    const k: string = keyOf(list[i])
    const v: number = map.get(k) ?? 0
    map.set(k, v + list[i].amount)
  }
  return map
}

/** 按 key 汇总件数 */
export function sumQtyByKey(list: EnrichedRecord[], keyOf: (r: EnrichedRecord) => string): Map<string, number> {
  const map: Map<string, number> = new Map<string, number>()
  for (let i = 0; i < list.length; i++) {
    const k: string = keyOf(list[i])
    const v: number = map.get(k) ?? 0
    map.set(k, v + list[i].quantity)
  }
  return map
}

/** 金额排行（降序 Top N） */
export function rankBy(list: EnrichedRecord[], keyOf: (r: EnrichedRecord) => string, topN: number): RankItem[] {
  const map: Map<string, number> = sumByKey(list, keyOf)
  const qmap: Map<string, number> = sumQtyByKey(list, keyOf)
  const items: RankItem[] = []
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort((a, b) => (map.get(b) ?? 0) - (map.get(a) ?? 0))
  const n: number = Math.min(keys.length, topN)
  for (let i = 0; i < n; i++) {
    const name: string = keys[i]
    items.push({
      name: name,
      amount: round(map.get(name) ?? 0, 2),
      quantity: round(qmap.get(name) ?? 0, 3)
    })
  }
  return items
}

/** 占比（Top N，其余归入「其他」） */
export function sharesOf(list: EnrichedRecord[], keyOf: (r: EnrichedRecord) => string, topN: number): ShareItem[] {
  const total: number = sumAmount(list)
  const map: Map<string, number> = sumByKey(list, keyOf)
  const items: ShareItem[] = []
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort((a, b) => (map.get(b) ?? 0) - (map.get(a) ?? 0))
  const n: number = Math.min(keys.length, topN)
  for (let i = 0; i < n; i++) {
    const name: string = keys[i]
    const amount: number = map.get(name) ?? 0
    items.push({
      name: name,
      amount: round(amount, 2),
      ratio: total > 0 ? round(amount / total, 4) : 0
    })
  }
  if (keys.length > topN) {
    let other: number = 0
    for (let i = topN; i < keys.length; i++) {
      other += map.get(keys[i]) ?? 0
    }
    items.push({
      name: '其他',
      amount: round(other, 2),
      ratio: total > 0 ? round(other / total, 4) : 0
    })
  }
  return items
}

/** 按天趋势（区间内逐日金额，缺日补 0） */
export function trendByDay(list: EnrichedRecord[], start: string, end: string): TrendPoint[] {
  const map: Map<string, number> = new Map<string, number>()
  for (let i = 0; i < list.length; i++) {
    const d: string = list[i].date
    if (d < start || d > end) {
      continue
    }
    map.set(d, (map.get(d) ?? 0) + list[i].amount)
  }
  const points: TrendPoint[] = []
  const cursor: Date = new Date(`${start}T00:00:00`)
  const endD: Date = new Date(`${end}T00:00:00`)
  const fmt = (dd: Date): string => {
    const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
    return `${dd.getFullYear()}-${p(dd.getMonth() + 1)}-${p(dd.getDate())}`
  }
  while (cursor.getTime() <= endD.getTime()) {
    const ds: string = fmt(cursor)
    points.push({ date: ds, amount: round(map.get(ds) ?? 0, 2) })
    cursor.setDate(cursor.getDate() + 1)
  }
  return points
}

/** 按月的金额合计（用于近月对比） */
export function monthAmounts(list: EnrichedRecord[], months: string[]): Map<string, number> {
  const map: Map<string, number> = new Map<string, number>()
  for (let i = 0; i < list.length; i++) {
    const ym: string = ymOf(list[i].date)
    if (months.indexOf(ym) >= 0) {
      map.set(ym, (map.get(ym) ?? 0) + list[i].amount)
    }
  }
  return map
}

/** 最高单日金额 */
export function maxDayAmount(list: EnrichedRecord[]): number {
  const map: Map<string, number> = sumByKey(list, (r) => r.date)
  let max: number = 0
  const iter = map.values()
  let v = iter.next()
  while (!v.done) {
    if (v.value > max) {
      max = v.value
    }
    v = iter.next()
  }
  return round(max, 2)
}

/** 班次统计项 */
export interface ShiftStat {
  name: string
  amount: number
  quantity: number
  count: number
}

/** 班次对比（白班 / 夜班 金额与件数，对齐 jijian-app byShift） */
export function shiftStats(list: EnrichedRecord[]): ShiftStat[] {
  const build = (name: string, rows: EnrichedRecord[]): ShiftStat => {
    let amt: number = 0
    let q: number = 0
    for (let i = 0; i < rows.length; i++) {
      amt += rows[i].amount || 0
      q += rows[i].quantity || 0
    }
    return { name: name, amount: round(amt, 2), quantity: round(q, 3), count: rows.length }
  }
  const day: EnrichedRecord[] = []
  const night: EnrichedRecord[] = []
  for (let i = 0; i < list.length; i++) {
    if (list[i].shift === 'night') {
      night.push(list[i])
    } else {
      day.push(list[i])
    }
  }
  return [build('白班', day), build('夜班', night)]
}

/** 近 N 个月（含本月，升序）YYYY-MM 列表 */
export function recentMonths(n: number): string[] {
  const now: Date = new Date()
  const list: string[] = []
  const p = (x: number): string => (x < 10 ? `0${x}` : String(x))
  for (let i = n - 1; i >= 0; i--) {
    const d: Date = new Date(now.getFullYear(), now.getMonth() - i, 1)
    list.push(`${d.getFullYear()}-${p(d.getMonth() + 1)}`)
  }
  return list
}

/** 近 6 个月金额对比（含本月，升序，缺月补 0） */
export function recent6Months(list: EnrichedRecord[]): TrendPoint[] {
  const months: string[] = recentMonths(6)
  const map: Map<string, number> = monthAmounts(list, months)
  const pts: TrendPoint[] = []
  for (let i = 0; i < months.length; i++) {
    pts.push({ date: months[i], amount: round(map.get(months[i]) ?? 0, 2) })
  }
  return pts
}

/** 按月聚合桶：区间内逐月金额（长区间 > 62 天时用，对齐 jijian-app monthBuckets） */
export function monthBuckets(list: EnrichedRecord[], start: string, end: string): TrendPoint[] {
  const map: Map<string, number> = new Map<string, number>()
  for (let i = 0; i < list.length; i++) {
    const r: EnrichedRecord = list[i]
    if (r.date < start || r.date > end) {
      continue
    }
    const ym: string = ymOf(r.date)
    map.set(ym, (map.get(ym) ?? 0) + r.amount)
  }
  const pts: TrendPoint[] = []
  const cur: Date = new Date(`${start}T00:00:00`)
  const endD: Date = new Date(`${end}T00:00:00`)
  let y: number = cur.getFullYear()
  let m: number = cur.getMonth()
  const ey: number = endD.getFullYear()
  const em: number = endD.getMonth()
  const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
  while (y < ey || (y === ey && m <= em)) {
    const ym: string = `${y}-${p(m + 1)}`
    pts.push({ date: ym, amount: round(map.get(ym) ?? 0, 2) })
    m++
    if (m > 11) {
      m = 0
      y++
    }
  }
  return pts
}

/** 最高单日：日期 + 金额（对齐 jijian-app bestDay） */
export function bestDayInfo(list: EnrichedRecord[]): BestDayInfo {
  const map: Map<string, number> = sumByKey(list, (r) => r.date)
  let maxD: string = ''
  let max: number = 0
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    const v: number = map.get(k.value) ?? 0
    if (v > max) {
      max = v
      maxD = k.value
    }
    k = iter.next()
  }
  return { date: maxD, amount: round(max, 2) }
}
