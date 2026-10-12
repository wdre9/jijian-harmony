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
    } else if (code === 0x00b9) {          // ¹ Latin-1 区
      out += '1'
    } else if (code === 0x00b2) {          // ²
      out += '2'
    } else if (code === 0x00b3) {          // ³
      out += '3'
    } else if (code === 0x2070) {          // ⁰ U+2070 区
      out += '0'
    } else if (code >= 0x2074 && code <= 0x2079) {  // ⁴-⁹
      out += String.fromCharCode(code - 0x2070 + 0x30)
    } else if (code === 0x207a) {          // ⁺ 上标加号
      out += '+'
    } else if (code === 0x207b) {          // ⁻ 上标减号
      out += '-'
    } else if (code === 0x207c) {          // ⁼ 上标等号
      out += '='
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
/** 「计时」= 独立货号（产品名），与四位数字货号同等对待，如「10.9，计时，11×11.3=124.3」；行首或前接逗号/空格/空白符 */
const JISHI_CODE_RE = /(?:^|[,，\s])(计时)/
/** 数量×单价=金额（OCR 常见 ×/x/* 混用，= 可能为全角；从数字本身开始匹配，前导 × 由 cleanProcessSuffix 前缀清理兜底，避免把「二夹623…」的「夹」吞进表达式） */
const QTY_PRICE_RE = /(\d+(?:\.\d+)?)\s*[×x*]\s*(\d+(?:\.\d+)?)\s*[=:：]\s*(\d+(?:\.\d+)?)/
/** 标题/表头特征行（非账目内容，如「2026年10月计件明细」） */
const TITLE_RE = /年|明细|汇总|合计|总计|小计|报表|工资|对账|记账/
/** 尾部残留的 ×数量（无单价） */
const TRAIL_QTY_RE = /×\s*\d+(?:\.\d+)?\s*$/
/** 角标 +8 / ⁺⁵ 等（任意位置；归一化后形如 +N，工序中间的角标同样需要清理，如「cnc+5」→「cnc」） */
const TAG_RE = /[+＋⁺]\s*\d+(?:\.\d+)?/g
/** OCR 序号前缀（如「13. 」「14. 」）：后跟非数字或日期（如「13. 10.11」）时剥离，避免误伤「10.11」日期头 */
const SEQ_RE = /^\d{1,3}[.、．]\s+(?=\D|\d{1,2}[.、．／/]\d{1,2})/

function cleanProcessSuffix(rest: string): string {
  let s: string = rest
  s = s.replace(QTY_PRICE_RE, '')
  s = s.replace(TRAIL_QTY_RE, '')
  s = s.replace(TAG_RE, '')
  s = s.replace(/^[\s\-·、,，:：.×x*]+/, '')
  s = s.replace(/[\s\-·、,，:：.×x*]+$/, '')
  return s.trim()
}

/**
 * OCR 常把「日期 货号 工序」与「工序 数量×单价=金额」两行合并成一行（换行丢失），
 * 表现为一行里逗号分隔多段、账目只出现在最后一段，如：
 *   10.11, 9854cnc+5, 一夹623×0.094=58.567
 * 这里按账目前文本的逗号/分号拆成多行：前面各段作为上下文行（货号/工序），
 * 最后一段与账目合并成真正的账目行，使「cnc / 一夹 / 二夹」各归其位。
 */
function expandMergedLines(lines: string[], today: string): string[] {
  const out: string[] = []
  for (let li = 0; li < lines.length; li++) {
    const line: string = lines[li]
    const lineNoSeq: string = line.replace(SEQ_RE, '')
    const hd: HeaderDate | null = matchHeaderDate(lineNoSeq, today)
    const rest0: string = hd !== null ? hd.rest : lineNoSeq
    const qp0: RegExpMatchArray | null = rest0.match(QTY_PRICE_RE)
    if (qp0 === null) {
      out.push(lineNoSeq)
      continue
    }
    const prefix: string = rest0.slice(0, qp0.index)
    const segs: string[] = prefix.split(/[,，;；]/)
    if (segs.length < 2) {
      out.push(lineNoSeq)
      continue
    }
    const datePre: string = hd !== null ? lineNoSeq.slice(0, lineNoSeq.length - rest0.length) : ''
    let first: boolean = true
    for (let i = 0; i < segs.length - 1; i++) {
      const seg: string = segs[i].trim()
      if (seg.length === 0) {
        continue
      }
      out.push(datePre.length > 0 && first ? `${datePre} ${seg}` : seg)
      first = false
    }
    const lastSeg: string = segs[segs.length - 1].trim()
    out.push(lastSeg + rest0.slice(qp0.index))
  }
  return out
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
  const logicalLines: string[] = expandMergedLines(lines, today)

  for (let li = 0; li < logicalLines.length; li++) {
    const line: string = logicalLines[li]

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

    // 3b) 「计时」独立货号（无四位数字货号时，行首或前接逗号/空格/空白符的「计时」视为货号）
    const jishiMatch: RegExpMatchArray | null = codeMatch === null ? rest.match(JISHI_CODE_RE) : null
    if (jishiMatch !== null) {
      currentCode = '计时'
    }

    // 4) 纯日期头行
    if (hd && !rest.trim()) {
      continue
    }

    // 5) 标题/表头行
    if (!qp && !codeMatch && jishiMatch === null) {
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
    const hasHeadCode: boolean = codeMatch !== null ? codeStart2 !== qtyStart2 : jishiMatch !== null
    let suffix: string = rest
    if (hasHeadCode) {
      suffix = codeMatch !== null
        ? rest.slice((codeMatch!.index ?? 0) + codeMatch![0].length)
        : rest.slice((jishiMatch!.index ?? 0) + jishiMatch![0].length)
    }
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
