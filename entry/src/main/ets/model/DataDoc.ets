/**
 * 单文档 + 版本迁移链（对齐 jijian-app/src/db/index.ts 的 SCHEMA_VERSION / migrateDoc）
 */
import { AppSettings, BackupPackage, DataDoc, PieceRecord, Process, Product, Worker } from './Types'

/** 当前文档版本 */
export const SCHEMA_VERSION: number = 2

/** 默认设置 */
export const DEFAULT_SETTINGS: AppSettings = {
  theme: 'auto',
  defaultWorker: '',
  rememberLast: true,
  lastProductId: '',
  lastProcessId: '',
  homeRange: 'today',
  dailyGoal: 0,
  monthlyGoal: 0
}

/** 空文档 */
export function emptyDoc(): DataDoc {
  const now: number = Date.now()
  return {
    schemaVersion: SCHEMA_VERSION,
    savedAt: now,
    products: [],
    processes: [],
    records: [],
    workers: [],
    settings: cloneSettings(DEFAULT_SETTINGS)
  }
}

/** 沿迁移链把任意旧版本数据升级到当前版本（类型守卫：逐字段 typeof 检查 + 构建目标类型） */
export function migrateDoc(raw: object): DataDoc {
  return normalizeV1(normalizeV0(raw))
}

/** v1 -> v2 归一化：records 补 countMode/count/processNameSnapshot 默认值；快照缺失时用现有工序名回填 */
function normalizeV1(base: DataDoc): DataDoc {
  const nameById: Map<string, string> = new Map<string, string>()
  for (let i = 0; i < base.processes.length; i++) {
    nameById.set(base.processes[i].id, base.processes[i].name)
  }
  const records: PieceRecord[] = []
  for (let i = 0; i < base.records.length; i++) {
    const rv: object = base.records[i] as object
    if (rv === null || typeof rv !== 'object') {
      continue
    }
    const r: PieceRecord = rv as PieceRecord
    let snap: string = typeof r.processNameSnapshot === 'string' ? r.processNameSnapshot : ''
    if (snap.length === 0) {
      const n: string | undefined = nameById.get(r.processId)
      if (n !== undefined) {
        snap = n
      }
    }
    const mode: string = typeof r.countMode === 'string' ? r.countMode : 'auto'
    const cnt: number = typeof r.count === 'number' ? r.count : 1
    records.push({
      id: r.id,
      date: r.date,
      productId: r.productId,
      processId: r.processId,
      processNameSnapshot: snap,
      countMode: mode === 'manual' ? 'manual' : 'auto',
      count: cnt,
      quantity: r.quantity,
      price: r.price,
      amount: r.amount,
      worker: r.worker,
      shift: r.shift,
      note: r.note,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt
    })
  }
  return {
    schemaVersion: SCHEMA_VERSION,
    savedAt: base.savedAt,
    products: base.products,
    processes: base.processes,
    records: records,
    workers: base.workers,
    settings: base.settings
  }
}

/** v0 -> v1 归一化：缺失字段用默认值补齐（raw 来自 JSON 反序列化，不信任其静态类型） */
function normalizeV0(raw: object): DataDoc {
  const base: DataDoc = emptyDoc()
  const r: Record<string, object> = raw as Record<string, object>
  const num = (k: string, def: number): number => {
    const v: object = r[k]
    return typeof v === 'number' ? (v as number) : def
  }
  const arr = (k: string): object[] => {
    const v: object = r[k]
    return Array.isArray(v) ? (v as object[]) : []
  }
  let settings: AppSettings = cloneSettings(base.settings)
  const s: object = r['settings']
  if (s !== null && typeof s === 'object' && !Array.isArray(s)) {
    settings = mergeSettings(base.settings, s as AppSettings)
  }
  return {
    schemaVersion: SCHEMA_VERSION,
    savedAt: num('savedAt', Date.now()),
    products: arr('products') as Product[],
    processes: arr('processes') as Process[],
    records: arr('records') as PieceRecord[],
    workers: arr('workers') as Worker[],
    settings: settings
  }
}

/** 显式合并设置（避免展开运算符，ArkTS 严格模式限制） */
export function mergeSettings(base: AppSettings, patch: AppSettings): AppSettings {
  return {
    theme: patch.theme !== '' ? patch.theme : base.theme,
    defaultWorker: patch.defaultWorker !== '' ? patch.defaultWorker : base.defaultWorker,
    rememberLast: patch.rememberLast,
    lastProductId: patch.lastProductId !== '' ? patch.lastProductId : base.lastProductId,
    lastProcessId: patch.lastProcessId !== '' ? patch.lastProcessId : base.lastProcessId,
    homeRange: patch.homeRange !== '' ? patch.homeRange : base.homeRange,
    dailyGoal: patch.dailyGoal > 0 ? patch.dailyGoal : base.dailyGoal,
    monthlyGoal: patch.monthlyGoal > 0 ? patch.monthlyGoal : base.monthlyGoal
  }
}

/** 深拷贝设置对象 */
export function cloneSettings(s: AppSettings): AppSettings {
  return {
    theme: s.theme,
    defaultWorker: s.defaultWorker,
    rememberLast: s.rememberLast,
    lastProductId: s.lastProductId,
    lastProcessId: s.lastProcessId,
    homeRange: s.homeRange,
    dailyGoal: s.dailyGoal,
    monthlyGoal: s.monthlyGoal
  }
}

/** 由文档构建备份包（app 固定 'jijian-pwa'，与 Android 版互导兼容） */
export function buildBackup(doc: DataDoc): BackupPackage {
  return {
    app: 'jijian-pwa',
    kind: 'jijian-backup',
    version: SCHEMA_VERSION,
    exportedAt: Date.now(),
    doc: doc
  }
}

/** 解析备份包文本为结构化对象（类型守卫：逐字段检查 + 构建目标类型；不合法返回 null） */
export function parseBackupPackage(text: string): BackupPackage | null {
  let parsed: object | null = null
  try {
    parsed = JSON.parse(text) as object | null
  } catch (e) {
    return null
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return null
  }
  const r: Record<string, object> = parsed as Record<string, object>
  const app: string = typeof r['app'] === 'string' ? (r['app'] as string) : ''
  const kind: string = typeof r['kind'] === 'string' ? (r['kind'] as string) : ''
  if (app !== 'jijian-pwa' || kind !== 'jijian-backup') {
    return null
  }
  const version: number = typeof r['version'] === 'number' ? (r['version'] as number) : -1
  const exportedAt: number = typeof r['exportedAt'] === 'number' ? (r['exportedAt'] as number) : -1
  const docObj: object | null = r['doc']
  if (docObj === null || typeof docObj !== 'object' || Array.isArray(docObj)) {
    return null
  }
  return {
    app: app,
    kind: kind,
    version: version,
    exportedAt: exportedAt,
    doc: migrateDoc(docObj)
  }
}

/** 从备份包还原文档：校验格式并沿迁移链升级 */
export function restoreBackup(pkg: BackupPackage): DataDoc {
  if (!pkg || typeof pkg !== 'object') {
    throw new Error('备份文件格式错误：不是有效的 JSON 对象')
  }
  if (pkg.kind !== 'jijian-backup') {
    throw new Error(`备份文件格式错误：kind 不是 jijian-backup（实际 ${pkg.kind}）`)
  }
  const doc: DataDoc = migrateDoc(pkg.doc)
  return doc
}
