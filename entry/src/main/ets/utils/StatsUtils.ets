/**
 * 统计聚合（对齐 jijian-app/src/utils/stats.ts 的核心口径）
 */
import { PieceRecord, Process, Product, RankItem, ShareItem, TrendPoint } from '../model/Types'
import { round } from './FormatUtils'
import { ymOf } from './DateUtils'

/** 富化记录：附带产品/工序名称与规格 */
export interface EnrichedRecord extends PieceRecord {
  productName: string
  processName: string
  spec: string
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
    const er: EnrichedRecord = {
      id: r.id,
      date: r.date,
      productId: r.productId,
      processId: r.processId,
      quantity: r.quantity,
      price: r.price,
      amount: r.amount,
      worker: r.worker,
      shift: r.shift,
      note: r.note,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      productName: p ? p.name : r.productId,
      processName: c ? c.name : '未知工序',
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
