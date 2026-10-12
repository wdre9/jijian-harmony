/**
 * 格式化与通用工具（对齐 jijian-app/src/utils/format.ts）
 */

/** 四舍五入到指定小数位 */
export function round(n: number, digits: number): number {
  const f: number = Math.pow(10, digits)
  return Math.round((n + Number.EPSILON) * f) / f
}

/** 金额显示：两位小数 */
export function money(n: number): string {
  return n.toFixed(2)
}

/** 单价显示：两位小数 */
export function priceText(n: number): string {
  return n.toFixed(2)
}

/** 数量显示：去掉多余小数 0 */
export function qty(n: number): string {
  if (Number.isInteger(n)) {
    return String(n)
  }
  return String(round(n, 3))
}

/** 生成唯一 ID：时间戳 + 随机 */
export function uid(prefix: string): string {
  const t: number = Date.now()
  const r: number = Math.floor(Math.random() * 1000000)
  return `${prefix}${t}${r}`
}

/** 深拷贝（手写递归，替代 JSON 往返；仅支持纯 JSON 数据：object/array/string/number/boolean/null） */
export function deepClone<T>(obj: T): T {
  if (obj === null || typeof obj !== 'object') {
    return obj
  }
  if (Array.isArray(obj)) {
    const out: object[] = []
    const arr: object[] = obj as object[]
    for (let i = 0; i < arr.length; i++) {
      out.push(deepClone<object>(arr[i]))
    }
    return out as T
  }
  const out: Record<string, object> = {}
  const src: Record<string, object> = obj as Record<string, object>
  const keys: string[] = Object.keys(src)
  for (let i = 0; i < keys.length; i++) {
    const k: string = keys[i]
    out[k] = deepClone<object>(src[k])
  }
  return out as T
}

/** CSV 单元格转义 */
export function escapeCsvCell(s: string): string {
  if (s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0) {
    return `"${s.replace(/"/g, '""')}"`
  }
  return s
}

/** 当前年月日时间戳字符串（用于导出文件名） */
export function exportStamp(): string {
  const d: Date = new Date()
  const p = (n: number, w: number): string => {
    let s = String(n)
    while (s.length < w) {
      s = '0' + s
    }
    return s
  }
  return `${d.getFullYear()}${p(d.getMonth() + 1, 2)}${p(d.getDate(), 2)}_${p(d.getHours(), 2)}${p(d.getMinutes(), 2)}`
}
