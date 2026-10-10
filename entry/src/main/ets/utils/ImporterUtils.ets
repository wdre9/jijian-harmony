/**
 * 批量导入解析：OCR 文本 → 结构化行（对齐 jijian-app/src/utils/importer.ts 全部规则）
 * 所有解析都在本机完成，不上传任何数据。
 */
import { ImportParseResult, ImportRow } from '../model/Types'
import { round } from './FormatUtils'
import { daysBetween, todayStr, toDateStr } from './DateUtils'

/* ----------------------------- 文本规范化 ----------------------------- */

/** 全角字符转半角（OCR 常见噪声） */
function normalizeText(s: string): string {
  let out: string = ''
  for (let i = 0; i < s.length; i++) {
    const ch: string = s.charAt(i)
    const code: number = ch.charCodeAt(0)
    if (code >= 0xff10 && code <= 0xff19) {
      out += String.fromCharCode(code - 0xfee0)
    } else if (code >= 0xff21 && code <= 0xff3a) {
      out += String.fromCharCode(code - 0xfee0)
    } else if (code >= 0xff41 && code <= 0xff5a) {
      out += String.fromCharCode(code - 0xfee0)
    } else if (ch === '＝') {
      out += '='
    } else if (ch === '／') {
      out += '/'
    } else if (ch === '．') {
      out += '.'
    } else if (ch === 'Ｘ' || ch === 'ｘ') {
      out += '×'
    } else {
      out += ch
    }
  }
  return out.replace(/x/g, '×').replace(/X/g, '×')
}

/* ----------------------------- 日期解析 ----------------------------- */

const DATE_HEAD_RE = /^(\d{1,2})[./、/-]\s*(\d{1,2})日?/
const DATE_CN_HEAD_RE = /^(\d{1,2})月(\d{1,2})日?/

interface HeaderDate {
  date: string
  rest: string
}

function matchHeaderDate(line: string, today: string): HeaderDate | null {
  const m1 = line.match(DATE_HEAD_RE)
  const m2 = m1 ? null : line.match(DATE_CN_HEAD_RE)
  const m = m1 ? m1 : m2
  if (!m) {
    return null
  }
  const month: number = parseInt(m[1], 10)
  const day: number = parseInt(m[2], 10)
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null
  }
  let year: number = new Date().getFullYear()
  let date: string = toDateStr(new Date(year, month - 1, day))
  if (date > today && daysBetween(today, date) > 30) {
    year -= 1
    date = toDateStr(new Date(year, month - 1, day))
  }
  return { date: date, rest: line.slice(m[0].length) }
}

/* ----------------------------- 记录行解析 ----------------------------- */

/** 四位数字 = 货号（行首或前接逗号/空格等分隔符；「3500×0.1=350」中的数量不视为货号） */
const CODE_RE = /(?:^|[^\d])(\d{4})(?!\d)/
/** 数量×单价=金额（OCR 常见 ×/x/* 混用，= 可能为全角；兼容「×数量×单价=金额」的前导 ×） */
const QTY_PRICE_RE = /(?:^|[^\d.])(\d+(?:\.\d+)?)\s*[×x*]\s*(\d+(?:\.\d+)?)\s*[=:：]\s*(\d+(?:\.\d+)?)/
/** 标题/表头特征行（非账目内容，如「2026年10月计件明细」） */
const TITLE_RE = /年|明细|汇总|合计|总计|小计|报表|工资|对账|记账/
/** 尾部残留的 ×数量（无单价） */
const TRAIL_QTY_RE = /×\s*\d+(?:\.\d+)?\s*$/
/** 尾部角标 +8 等 */
const TRAIL_TAG_RE = /[+＋]\s*\d+(?:\.\d+)?\s*$/
/** 行首角标 +8 等（货号后紧跟） */
const LEAD_TAG_RE = /^[+＋]\s*\d+(?:\.\d+)?\s*/

function cleanProcessSuffix(rest: string): string {
  let s: string = rest
  s = s.replace(QTY_PRICE_RE, '')
  s = s.replace(TRAIL_QTY_RE, '')
  s = s.replace(TRAIL_TAG_RE, '')
  s = s.replace(LEAD_TAG_RE, '')
  s = s.replace(/^[\s\-·、,，:：.]+/, '')
  s = s.replace(/[\s\-·、,，:：.]+$/, '')
  return s.trim()
}

/** 解析整段文本（OCR 或手动粘贴） */
export function parseImportText(rawText: string, worker: string): ImportParseResult {
  const rows: ImportRow[] = []
  const unparsed: string[] = []
  let skippedCount: number = 0
  let currentDate: string = ''
  let currentCode: string = ''

  const today: string = todayStr()
  const rawLines: string[] = normalizeText(rawText).split(/\r?\n/)
  const lines: string[] = []
  for (let i = 0; i < rawLines.length; i++) {
    const t: string = rawLines[i].trim()
    if (t.length > 0) {
      lines.push(t)
    }
  }

  for (let li = 0; li < lines.length; li++) {
    const line: string = lines[li]
    if (line.indexOf('计时') >= 0) {
      skippedCount++
      continue
    }

    // 1) 行首日期头
    let rest: string = line
    const hd: HeaderDate | null = matchHeaderDate(line, today)
    if (hd) {
      currentDate = hd.date
      rest = hd.rest
    }

    // 2) 账目表达式（数量×单价=金额）
    const qp = rest.match(QTY_PRICE_RE)

    // 3) 行内货号
    const codeMatch = rest.match(CODE_RE)
    if (codeMatch) {
      const code: string = codeMatch[1]
      const codeStart: number = (codeMatch.index ?? 0) + codeMatch[0].lastIndexOf(code)
      const qtyStart: number = qp ? (qp.index ?? 0) + qp[0].indexOf(qp[1]) : -1
      const isQtyItself: boolean = qp !== null && qtyStart >= 0 && codeStart === qtyStart && code === qp[1]
      if (!isQtyItself) {
        currentCode = code
      }
    }

    // 4) 纯日期头行
    if (hd && !rest.trim()) {
      continue
    }

    // 5) 标题/表头行
    if (!qp && !codeMatch) {
      if (TITLE_RE.test(rest)) {
        skippedCount++
        continue
      }
      unparsed.push(line)
      continue
    }

    // 6) 纯货号/工序行（无账目）：仅作为后续行上下文
    if (!qp) {
      continue
    }

    // 7) 账目行但前面没有货号上下文
    if (!currentCode) {
      unparsed.push(line)
      continue
    }

    const quantity: number = parseFloat(qp[1])
    const price: number = parseFloat(qp[2])
    const productCode: string = currentCode

    const qtyStart2: number = (qp.index ?? 0) + qp[0].indexOf(qp[1])
    const codeStart2: number = codeMatch ? (codeMatch.index ?? 0) + codeMatch[0].lastIndexOf(codeMatch[1]) : -1
    const hasHeadCode: boolean = codeMatch !== null && codeStart2 !== qtyStart2
    const suffix: string = hasHeadCode ? rest.slice(codeMatch![0].length) : rest
    const processName: string = cleanProcessSuffix(suffix) || '未分类'

    const row: ImportRow = {
      line: li + 1,
      date: currentDate,
      productName: productCode,
      processName: processName,
      quantity: quantity,
      price: price,
      amount: round(quantity * price, 3),
      worker: worker,
      shift: 'day',
      note: '',
      raw: line,
      productId: '',
      processId: '',
      ok: true,
      error: ''
    }
    rows.push(row)
  }

  return { rows: rows, skippedCount: skippedCount, unparsed: unparsed }
}
