/**
 * 导出工具（对齐 jijian-app/src/utils/exporter.ts）
 * - CSV（带 BOM）/ JSON / 文本由调用方保存到 documentViewPicker 选择的路径
 * - Excel：手写 SpreadsheetML 2003 XML 生成 .xls（避免引入第三方库）
 */
import { EnrichedRecord } from './StatsUtils'
import { escapeCsvCell, priceText, qty } from './FormatUtils'

/** 工作表数据 */
export interface SheetData {
  name: string
  aoa: Array<Array<string | number>>
}

/** 明细表表头（任务要求表头：日期/产品/规格/工序/数量/单价(元)/金额(元)/工人/班次/备注） */
export const DETAIL_HEADER: string[] = ['日期', '产品', '规格', '工序', '数量', '单价(元)', '金额(元)', '工人', '班次', '备注']

/** 明细记录 -> 二维数组 */
export function detailAoa(rows: EnrichedRecord[]): Array<Array<string | number>> {
  const body: Array<Array<string | number>> = []
  for (let i = 0; i < rows.length; i++) {
    const r: EnrichedRecord = rows[i]
    body.push([
      r.date,
      r.productName,
      r.spec,
      r.processName,
      r.quantity,
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
