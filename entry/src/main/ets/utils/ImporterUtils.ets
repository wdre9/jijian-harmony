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
  // 半角拉丁 x/X 刻意不归一化（避免破坏含 x 的工序/产品名，与安卓端对齐）
  return out
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
/** 「计时」= 独立货号（产品名），与四位数字货号同等对待，如「10.9，计时，11×11.3=124.3」；行首或前接逗号/空格/分号/顿号/空白符 */
const JISHI_CODE_RE = /(?:^|[,，;；、\s])(计时)/
/** 数量×单价=金额（OCR 常见 ×/* 混用，= 可能为全角；半角拉丁 x 刻意不支持，避免破坏含 x 的工序/产品名；从数字本身开始匹配，前导 × 由 cleanProcessSuffix 前缀清理兜底，避免把「二夹623…」的「夹」吞进表达式） */
const QTY_PRICE_RE = /(\d+(?:\.\d+)?)\s*[×*]\s*(\d+(?:\.\d+)?)\s*[=:：]\s*(\d+(?:\.\d+)?)/
/** 标题/表头特征行（非账目内容，如「2026年10月计件明细」） */
const TITLE_RE = /年|明细|汇总|合计|总计|小计|报表|工资|对账|记账/
/** 尾部残留的 ×数量（无单价） */
const TRAIL_QTY_RE = /×\s*\d+(?:\.\d+)?\s*$/
/** 角标 +8 / ⁺⁵ 等（任意位置；归一化后形如 +N，工序中间的角标同样需要清理，如「cnc+5」→「cnc」） */
const TAG_RE = /[+＋⁺]\s*\d+(?:\.\d+)?/g
/** OCR 序号前缀（如「13. 」「14. 」）：后跟非数字、日期（如「13. 10.11」）或账目表达式（如「13. 20×1.2=24」）时剥离，避免误伤「10.11」日期头或残留序号 */
const SEQ_RE = /^\d{1,3}[.、．]\s+(?=\D|\d{1,2}[.、．／/]\d{1,2}|\d+(?:\.\d+)?[×*])/

function cleanProcessSuffix(rest: string): string {
  let s: string = rest
  s = s.replace(QTY_PRICE_RE, '')
  s = s.replace(TRAIL_QTY_RE, '')
  s = s.replace(TAG_RE, '')
  s = s.replace(/^[\s\-·、,，:：.×*+＋]+/, '')
  s = s.replace(/[\s\-·、,，:：.×*+＋]+$/, '')
  return s.trim()
}

/**
 * OCR 常把「日期 货号 工序」与「工序 数量×单价=金额」两行合并成一行（换行丢失），
 * 表现为一行里逗号分隔多段、账目常出现在最后一段，如：
 *   10.11, 9854cnc+5, 一夹623×0.094=58.567, 二夹500×0.1=50
 * 这里按行内全部账目表达式拆分：账目前文本按逗号/分号拆成多段，
 * 各段作为上下文行（货号/工序，首段回填日期头），末段与账目合并成账目行，
 * 使「cnc / 一夹 / 二夹」各归其位；多个账目（如多工序同行）各自独立成行，
 * 不再把后置账目残留进工序名；单段合并行（如「10.11, 一夹623×0.094=58.567」）
 * 日期头同样回填，避免日期丢失。
 */
/** 展开后的逻辑行：text 参与解析，raw/srcIndex 保留原始行用于校对（对齐安卓 importer.ts ExpandedLine） */
interface ExpandedLine {
  /** 参与解析的逻辑行文本（SEQ 已剥离、合并行拆分后的片段） */
  text: string
  /** 原始输入行（合并行拆分后的各行共享同一原始行，便于与原文校对） */
  raw: string
  /** 原始输入行号（从 0 开始） */
  srcIndex: number
}

function expandMergedLines(lines: string[], today: string): ExpandedLine[] {
  const out: ExpandedLine[] = []
  for (let li = 0; li < lines.length; li++) {
    const line: string = lines[li]
    const push = (text: string): void => {
      out.push({ text: text, raw: line, srcIndex: li })
    }
    const lineNoSeq: string = line.replace(SEQ_RE, '')
    const hd: HeaderDate | null = matchHeaderDate(lineNoSeq, today)
    const rest0: string = hd !== null ? hd.rest : lineNoSeq
    // 行内全部账目表达式（含逗号/分号分隔的多账目）
    const qtyGlobal: RegExp = new RegExp(QTY_PRICE_RE.source, 'g')
    const qtyMatches: RegExpExecArray[] = []
    let m: RegExpExecArray | null = qtyGlobal.exec(rest0)
    while (m !== null) {
      qtyMatches.push(m)
      m = qtyGlobal.exec(rest0)
    }
    if (qtyMatches.length === 0) {
      push(lineNoSeq)
      continue
    }
    const datePre: string = hd !== null ? lineNoSeq.slice(0, lineNoSeq.length - rest0.length) : ''
    let first: boolean = true
    let cursor: number = 0
    for (let qi = 0; qi < qtyMatches.length; qi++) {
      const qm: RegExpExecArray = qtyMatches[qi]
      const between: string = rest0.slice(cursor, qm.index)
      cursor = qm.index + qm[0].length
      const segs: string[] = between.split(/[,，;；]/).map((s: string): string => s.trim()).filter((s: string): boolean => s.length > 0)
      // 中间上下文段：不带账目，仅作为货号/工序上下文行（首段回填日期头）
      for (let i = 0; i < segs.length - 1; i++) {
        push(datePre.length > 0 && first ? `${datePre} ${segs[i]}` : segs[i])
        first = false
      }
      // 末段（若有）与账目合并为账目行；账目前无文本则账目独立成行。日期头回填给首个输出行。
      // 拼接时在末段与账目之间补空格：OCR 常把货号段（如「9833+22」）与账目段（「630×0.391=246.33」）
      // 以逗号分隔挤在同一行，若直接拼接会数字粘连（22+630→22630），件数/金额/工序全错。
      const lastSeg: string = segs.length > 0 ? segs[segs.length - 1] : ''
      push((datePre.length > 0 && first ? `${datePre} ` : '') + lastSeg + ' ' + rest0.slice(qm.index, cursor))
      first = false
    }
    // 最后一个账目之后的尾文（极少见）：按分隔符拆为上下文行
    const tail: string = rest0.slice(cursor)
    if (tail.trim().length > 0) {
      const segs: string[] = tail.split(/[,，;；]/).map((s: string): string => s.trim()).filter((s: string): boolean => s.length > 0)
      for (let i = 0; i < segs.length; i++) {
        push(datePre.length > 0 && first ? `${datePre} ${segs[i]}` : segs[i])
        first = false
      }
    }
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
  const logicalLines: ExpandedLine[] = expandMergedLines(lines, today)

  for (let li = 0; li < logicalLines.length; li++) {
    const item: ExpandedLine = logicalLines[li]
    const line: string = item.text

    // 1) 行首日期头
    let rest: string = line
    const hd: HeaderDate | null = matchHeaderDate(line, today)
    if (hd) {
      currentDate = hd.date
      rest = hd.rest
    }

    // 2) 账目表达式（数量×单价=金额）
    const qp = rest.match(QTY_PRICE_RE)

    // 2b) 标题/汇总类行（无账目时）优先跳过：即使含 4 位数字（如「2026年10月计件明细」）
    //     也先于货号识别处理，避免被误当货号污染后续账目行的归属
    if (!qp && TITLE_RE.test(rest)) {
      skippedCount++
      continue
    }

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

    // 5) 无账目、无货号、非标题 → 无法归类 → 「未能解析」（标题已在 2b 统一处理）
    if (!qp && !codeMatch && jishiMatch === null) {
      unparsed.push(item.raw)
      continue
    }

    // 6) 纯货号/工序行（无账目）：仅作为后续行上下文
    if (!qp) {
      continue
    }

    // 7) 账目行但前面没有货号上下文
    if (!currentCode) {
      unparsed.push(item.raw)
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
      line: item.srcIndex + 1,
      date: currentDate,
      productName: productCode,
      processName: processName,
      quantity: quantity,
      price: price,
      amount: round(quantity * price, 3),
      worker: worker,
      shift: 'day',
      note: '',
      raw: item.raw,
      productId: '',
      processId: '',
      ok: true,
      error: ''
    }
    rows.push(row)
  }

  return { rows: rows, skippedCount: skippedCount, unparsed: unparsed }
}
