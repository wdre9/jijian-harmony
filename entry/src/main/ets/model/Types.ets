/**
 * 领域模型定义（对齐 jijian-app/src/types/index.ts）
 * 纯 ArkTS：禁止 any / unknown，结构化类型用 interface / class。
 */

/** 产品 */
export interface Product {
  id: string
  name: string
  spec: string
  note: string
  createdAt: number
  updatedAt: number
}

/** 工序 */
export interface Process {
  id: string
  productId: string
  name: string
  price: number
  note: string
  active: boolean
  sort: number
  createdAt: number
  updatedAt: number
}

/** 计件记录 */
export interface PieceRecord {
  id: string
  /** 日期 YYYY-MM-DD */
  date: string
  productId: string
  processId: string
  quantity: number
  price: number
  amount: number
  worker: string
  /** 'day' | 'night' */
  shift: string
  note: string
  createdAt: number
  updatedAt: number
}

/** 工人 */
export interface Worker {
  name: string
  createdAt: number
}

/** 应用设置 */
export interface AppSettings {
  /** 'auto' | 'light' | 'dark' */
  theme: string
  defaultWorker: string
  rememberLast: boolean
  lastProductId: string
  lastProcessId: string
  /** 'today' | 'week' | 'month' */
  homeRange: string
  dailyGoal: number
  monthlyGoal: number
}

/** 单文档结构（RelationalStore 之上的逻辑单文档） */
export interface DataDoc {
  schemaVersion: number
  savedAt: number
  products: Product[]
  processes: Process[]
  records: PieceRecord[]
  workers: Worker[]
  settings: AppSettings
}

/** 备份包：app 字段固定 'jijian-pwa'，保持与 Android 版备份文件互导兼容 */
export interface BackupPackage {
  app: string
  kind: string
  version: number
  exportedAt: number
  doc: DataDoc
}

/** 批量导入：解析结果（对齐 jijian-app importer.ts ParseResult） */
export interface ImportParseResult {
  rows: ImportRow[]
  /** 「计时」「标题」等跳过的行数 */
  skippedCount: number
  /** 无法解析的原始行 */
  unparsed: string[]
}

/** 批量导入：单行候选记录（对齐 jijian-app DraftRow，含预览可编辑字段） */
export interface ImportRow {
  /** 原文本行号（从 1 开始） */
  line: number
  /** YYYY-MM-DD */
  date: string
  /** 四位货号 = 产品名（入库前由预览确认映射） */
  productName: string
  /** 工序名，无工序为「未分类」 */
  processName: string
  quantity: number
  price: number
  /** 数量×单价 程序重算 */
  amount: number
  worker: string
  shift: string
  note: string
  /** 原始文本行，便于校对 */
  raw: string
  /** 入库后回填的产品/工序 id（预览确认阶段填充） */
  productId: string
  processId: string
  /** 预览编辑标记 */
  ok: boolean
  error: string
}

/** 统计区间 */
export interface StatsRange {
  key: string
  label: string
  start: string
  end: string
}

/** 趋势点 */
export interface TrendPoint {
  date: string
  amount: number
}

/** 排行项 */
export interface RankItem {
  name: string
  amount: number
  quantity: number
}

/** 占比项 */
export interface ShareItem {
  name: string
  amount: number
  ratio: number
}
