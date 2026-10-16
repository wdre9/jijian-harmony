/**
 * 导出工具（对齐 jijian-app/src/utils/exporter.ts）
 * - CSV（带 BOM）/ JSON / 文本由调用方保存到 documentViewPicker 选择的路径
 * - Excel：手写 SpreadsheetML 2003 XML 生成 .xls（避免引入第三方库）
 */
import { EnrichedRecord } from './StatsUtils'
import { escapeCsvCell, priceText, qty, round } from './FormatUtils'
import { ymOf } from './DateUtils'

/** 聚合统计：件数 + 金额 */
interface QtyAmount {
  qty: number
  amount: number
}

/** 聚合统计：件数 + 金额 + 规格 */
interface QtyAmountSpec {
  qty: number
  amount: number
  spec: string
}

/** 聚合统计：件数 + 金额 + 笔数 */
interface QtyAmountCount {
  qty: number
  amount: number
  count: number
}

/** 工作表数据 */
export interface SheetData {
  name: string
  aoa: Array<Array<string | number>>
}

/** 明细表表头（任务要求表头：日期/产品/规格/工序/数量/单价(元)/金额(元)/工人/班次/备注，含次数列） */
export const DETAIL_HEADER: string[] = ['日期', '产品', '规格', '工序', '数量', '次数', '单价(元)', '金额(元)', '工人', '班次', '备注']

/** 明细记录 -> 二维数组 */
export function detailAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    const cnt: string | number = r.countMode === 'manual' ? (typeof r.count === 'number' ? r.count : 1) : ''
    body.push([
      r.date,
      r.productName,
      r.spec,
      r.processName,
      r.quantity,
      cnt,
      priceText(r.price),
      r.amount,
      r.worker || '',
      r.shift === 'night' ? '夜班' : '白班',
      r.note || ''
    ])
  }
  const out: Array<Array<string | number>> = [DETAIL_HEADER]
  for (let i = 0; i < body.length; i++) {
    out.push(body[i])
  }
  return out
}

/** 明细 -> CSV 文本（带 BOM 由调用方负责） */
export function detailCsv(rows: EnrichedRecord[]): string {
  const aoa: Array<Array<string | number>> = detailAoa(rows)
  const lines: string[] = []
  for (let i = 0; i < aoa.length; i++) {
    const row: Array<string | number> = aoa[i]
    const cells: string[] = []
    for (let j = 0; j < row.length; j++) {
      cells.push(escapeCsvCell(String(row[j])))
    }
    lines.push(cells.join(','))
  }
  return lines.join('\r\n')
}

/** 汇总 -> 二维数组（标题 + 表头 + 数据 + 导出时间） */
export function summaryAoa(title: string, header: string[], rows: Array<Array<string | number>>): Array<Array<string | number>> {
  const out: Array<Array<string | number>> = [[title], header]
  for (let i = 0; i < rows.length; i++) {
    out.push(rows[i])
  }
  const d: Date = new Date()
  out.push([])
  out.push(['导出时间', `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()} ${d.getHours()}:${d.getMinutes()}`])
  return out
}

/** 记录条数描述 */
export function countText(rows: EnrichedRecord[]): string {
  let q: number = 0
  for (let i = 0; i < rows.length; i++) {
    q += rows[i].quantity || 0
  }
  return `${rows.length} 笔 · ${qty(q)} 件`
}

/* ----------------------------- SpreadsheetML 2003 XML ----------------------------- */

/** XML 转义 */
function xmlEsc(s: string): string {
  let out: string = ''
  for (let i = 0; i < s.length; i++) {
    const ch: string = s.charAt(i)
    if (ch === '&') {
      out += '&amp;'
    } else if (ch === '<') {
      out += '&lt;'
    } else if (ch === '>') {
      out += '&gt;'
    } else if (ch === '"') {
      out += '&quot;'
    } else if (ch === "'") {
      out += '&apos;'
    } else {
      out += ch
    }
  }
  return out
}

/** 生成 .xls（SpreadsheetML 2003 XML） */
export function buildXls(sheets: SheetData[]): string {
  let body: string = '<?xml version="1.0" encoding="UTF-8"?>\n'
  body += '<?mso-application progid="Excel.Sheet"?>\n'
  body += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
  body += 'xmlns:o="urn:schemas-microsoft-com:office:office" '
  body += 'xmlns:x="urn:schemas-microsoft-com:office:excel" '
  body += 'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" '
  body += 'xmlns:html="http://www.w3.org/TR/REC-html40">\n'
  for (let si = 0; si < sheets.length; si++) {
    const sheet: SheetData = sheets[si]
    body += `<Worksheet ss:Name="${xmlEsc(sheet.name)}">\n<Table>\n`
    for (let ri = 0; ri < sheet.aoa.length; ri++) {
      const row: Array<string | number> = sheet.aoa[ri]
      body += '<Row>\n'
      for (let ci = 0; ci < row.length; ci++) {
        const cell: string | number = row[ci]
        const isNum: boolean = typeof cell === 'number'
        const val: string = isNum ? String(cell) : xmlEsc(String(cell))
        body += `<Cell><Data ss:Type="${isNum ? 'Number' : 'String'}">${val}</Data></Cell>\n`
      }
      body += '</Row>\n'
    }
    body += '</Table>\n</Worksheet>\n'
  }
  body += '</Workbook>\n'
  return body
}

/* ----------------------------- 统计五表（Excel 导出） ----------------------------- */

/** 产品汇总表：产品 / 规格 / 件数 / 金额（按金额降序） */
export function productSummaryAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const map: Map<string, QtyAmountSpec> = new Map<string, QtyAmountSpec>()
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    const key: string = r.productName
    const cur: QtyAmountSpec | undefined = map.get(key)
    if (cur === undefined) {
      map.set(key, { qty: r.quantity, amount: r.amount, spec: r.spec })
    } else {
      cur.qty += r.quantity
      cur.amount += r.amount
      if (!cur.spec && r.spec) {
        cur.spec = r.spec
      }
    }
  }
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort((a, b) => (map.get(b)!.amount) - (map.get(a)!.amount))
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < keys.length; i++) {
    const c = map.get(keys[i])!
    body.push([keys[i], c.spec, round(c.qty, 3), round(c.amount, 2)])
  }
  const out: Array<Array<string | number>> = [['产品', '规格', '件数', '金额(元)']]
  for (let i = 0; i < body.length; i++) {
    out.push(body[i])
  }
  return out
}

/** 工序汇总表：工序 / 件数 / 金额 */
export function processSummaryAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const map: Map<string, QtyAmount> = new Map<string, QtyAmount>()
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    const key: string = r.processName
    const cur = map.get(key)
    if (cur === undefined) {
      map.set(key, { qty: r.quantity, amount: r.amount })
    } else {
      cur.qty += r.quantity
      cur.amount += r.amount
    }
  }
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort((a, b) => (map.get(b)!.amount) - (map.get(a)!.amount))
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < keys.length; i++) {
    const c = map.get(keys[i])!
    body.push([keys[i], round(c.qty, 3), round(c.amount, 2)])
  }
  const out: Array<Array<string | number>> = [['工序', '件数', '金额(元)']]
  for (let i = 0; i < body.length; i++) {
    out.push(body[i])
  }
  return out
}

/** 工人汇总表：工人 / 件数 / 金额 */
export function workerSummaryAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const map: Map<string, QtyAmount> = new Map<string, QtyAmount>()
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    const key: string = r.worker || '未填'
    const cur = map.get(key)
    if (cur === undefined) {
      map.set(key, { qty: r.quantity, amount: r.amount })
    } else {
      cur.qty += r.quantity
      cur.amount += r.amount
    }
  }
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort((a, b) => (map.get(b)!.amount) - (map.get(a)!.amount))
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < keys.length; i++) {
    const c = map.get(keys[i])!
    body.push([keys[i], round(c.qty, 3), round(c.amount, 2)])
  }
  const out: Array<Array<string | number>> = [['工人', '件数', '金额(元)']]
  for (let i = 0; i < body.length; i++) {
    out.push(body[i])
  }
  return out
}

/** 日期汇总表：日期 / 笔数 / 件数 / 金额（升序） */
export function daySummaryAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const map: Map<string, QtyAmountCount> = new Map<string, QtyAmountCount>()
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    const key: string = r.date
    const cur = map.get(key)
    if (cur === undefined) {
      map.set(key, { qty: r.quantity, amount: r.amount, count: 1 })
    } else {
      cur.qty += r.quantity
      cur.amount += r.amount
      cur.count += 1
    }
  }
  const keys: string[] = []
  const iter = map.keys()
  let k = iter.next()
  while (!k.done) {
    keys.push(k.value)
    k = iter.next()
  }
  keys.sort()
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < keys.length; i++) {
    const c = map.get(keys[i])!
    body.push([keys[i], c.count, round(c.qty, 3), round(c.amount, 2)])
  }
  const out: Array<Array<string | number>> = [['日期', '笔数', '件数', '金额(元)']]
  for (let i = 0; i < body.length; i++) {
    out.push(body[i])
  }
  return out
}

/** 班次汇总表：班次 / 笔数 / 件数 / 金额 */
export function shiftSummaryAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const dayRows: EnrichedRecord[] = []
  const nightRows: EnrichedRecord[] = []
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].shift === 'night') {
      nightRows.push(rows[i])
    } else {
      dayRows.push(rows[i])
    }
  }
  const agg = (list: EnrichedRecord[]): Array<number> => {
    let q: number = 0
    let a: number = 0
    for (let i = 0; i < list.length; i++) {
      q += list[i].quantity
      a += list[i].amount
    }
    const res: Array<number> = [list.length, round(q, 3), round(a, 2)]
    return res
  }
  const out: Array<Array<string | number>> = [['班次', '笔数', '件数', '金额(元)']]
  const dAgg: Array<number> = agg(dayRows)
  const nAgg: Array<number> = agg(nightRows)
  out.push(['白班', dAgg[0], dAgg[1], dAgg[2]])
  out.push(['夜班', nAgg[0], nAgg[1], nAgg[2]])
  return out
}

/** 按月汇总表：月份 / 笔数 / 件数 / 金额（升序） */
export function monthSummaryAoa(rows: EnrichedRecord[], start: string, end: string): Array<Array<string | number>> {
  const map: Map<string, QtyAmountCount> = new Map<string, QtyAmountCount>()
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    if (r.date < start || r.date > end) {
      continue
    }
    const key: string = ymOf(r.date)
    const cur = map.get(key)
    if (cur === undefined) {
      map.set(key, { qty: r.quantity, amount: r.amount, count: 1 })
    } else {
      cur.qty += r.quantity
      cur.amount += r.amount
      cur.count += 1
    }
  }
  const cur: Date = new Date(`${start}T00:00:00`)
  const endD: Date = new Date(`${end}T00:00:00`)
  const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
  const out: Array<Array<string | number>> = [['月份', '笔数', '件数', '金额(元)']]
  let y: number = cur.getFullYear()
  let m: number = cur.getMonth()
  const ey: number = endD.getFullYear()
  const em: number = endD.getMonth()
  while (y < ey || (y === ey && m <= em)) {
    const ym: string = `${y}-${p(m + 1)}`
    const c = map.get(ym)
    if (c !== undefined) {
      out.push([ym, c.count, round(c.qty, 3), round(c.amount, 2)])
    }
    m++
    if (m > 11) {
      m = 0
      y++
    }
  }
  return out
}
