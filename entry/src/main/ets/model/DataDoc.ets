/**
 * 单文档 + 版本迁移链（对齐 jijian-app/src/db/index.ts 的 SCHEMA_VERSION / migrateDoc）
 */
import { AppSettings, BackupPackage, DataDoc } from './Types'

/** 当前文档版本 */
export const SCHEMA_VERSION: number = 1

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

/** 沿迁移链把任意旧版本数据升级到当前版本 */
export function migrateDoc(raw: object): DataDoc {
  const anyDoc = raw as DataDoc
  let version: number = 0
  if (typeof anyDoc.schemaVersion === 'number') {
    version = anyDoc.schemaVersion
  }
  let doc: DataDoc
  if (version >= SCHEMA_VERSION) {
    doc = anyDoc
  } else {
    // v0 -> v1：补齐缺失字段，未来新增版本在此追加迁移步骤
    doc = normalizeV0(anyDoc)
  }
  doc.schemaVersion = SCHEMA_VERSION
  doc.savedAt = Date.now()
  return doc
}

/** v0 -> v1 归一化：缺失字段用默认值补齐 */
function normalizeV0(raw: DataDoc): DataDoc {
  const base: DataDoc = emptyDoc()
  const src: DataDoc = raw
  return {
    schemaVersion: base.schemaVersion,
    savedAt: typeof src.savedAt === 'number' ? src.savedAt : Date.now(),
    products: Array.isArray(src.products) ? src.products : [],
    processes: Array.isArray(src.processes) ? src.processes : [],
    records: Array.isArray(src.records) ? src.records : [],
    workers: Array.isArray(src.workers) ? src.workers : [],
    settings: src.settings ? mergeSettings(base.settings, src.settings) : cloneSettings(base.settings)
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

/** 从备份包还原文档：校验格式并沿迁移链升级 */
export function restoreBackup(pkg: BackupPackage): DataDoc {
  if (!pkg || typeof pkg !== 'object') {
    throw new Error('备份文件格式错误：不是有效的 JSON 对象')
  }
  if (pkg.kind !== 'jijian-backup') {
    throw new Error(`备份文件格式错误：kind 不是 jijian-backup（实际 ${pkg.kind}）`)
  }
  const doc: DataDoc = migrateDoc(pkg.doc as object)
  return doc
}
