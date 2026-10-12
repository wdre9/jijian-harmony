/**
 * 数据层：@ohos.data.relationalStore 关系型数据库
 * 实现「单文档」语义：业务数据分散在业务表，逻辑上以 meta.schemaVersion / meta.savedAt
 * 标识一份完整文档；saveDoc 在事务中全量重写（与 jijian-app 的 saveDoc 全量落盘一致）。
 */
import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { AppSettings, BackupPackage, DataDoc, PieceRecord, Process, Product, Worker } from '../model/Types'
import {
  SCHEMA_VERSION,
  cloneSettings,
  emptyDoc,
  migrateDoc,
  buildBackup,
  restoreBackup,
  DEFAULT_SETTINGS
} from '../model/DataDoc'

const DB_NAME: string = 'jijian.db'
const T_PRODUCTS = 'products'
const T_PROCESSES = 'processes'
const T_RECORDS = 'records'
const T_WORKERS = 'workers'
const T_SETTINGS = 'settings'
const T_META = 'meta'

const SQL_PRODUCTS: string =
  'CREATE TABLE IF NOT EXISTS products (' +
  'id TEXT PRIMARY KEY, name TEXT NOT NULL, spec TEXT, note TEXT, ' +
  'createdAt INTEGER, updatedAt INTEGER)'
const SQL_PROCESSES: string =
  'CREATE TABLE IF NOT EXISTS processes (' +
  'id TEXT PRIMARY KEY, productId TEXT, name TEXT NOT NULL, price REAL, note TEXT, ' +
  'active INTEGER, sort INTEGER, createdAt INTEGER, updatedAt INTEGER)'
const SQL_RECORDS: string =
  'CREATE TABLE IF NOT EXISTS records (' +
  'id TEXT PRIMARY KEY, date TEXT NOT NULL, productId TEXT, processId TEXT, ' +
  'quantity REAL, price REAL, amount REAL, worker TEXT, shift TEXT, note TEXT, ' +
  'createdAt INTEGER, updatedAt INTEGER)'
const SQL_WORKERS: string =
  'CREATE TABLE IF NOT EXISTS workers (name TEXT PRIMARY KEY, createdAt INTEGER)'
const SQL_SETTINGS: string =
  'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'
const SQL_META: string =
  'CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)'
const SQL_CLEAR: string[] = [
  'DELETE FROM products',
  'DELETE FROM processes',
  'DELETE FROM records',
  'DELETE FROM workers',
  'DELETE FROM settings',
  'DELETE FROM meta'
]

/** 关系型数据库访问层（单例） */
export class DataStore {
  private static instance: DataStore | null = null
  private rdb: relationalStore.RdbStore | null = null
  private ctx: common.UIAbilityContext | null = null

  static getInstance(): DataStore {
    if (DataStore.instance === null) {
      DataStore.instance = new DataStore()
    }
    return DataStore.instance
  }

  /** 初始化：打开数据库并建表 */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.rdb !== null) {
      return
    }
    this.ctx = ctx
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    this.rdb = await relationalStore.getRdbStore(ctx, config)
    const tables: string[] = [SQL_PRODUCTS, SQL_PROCESSES, SQL_RECORDS, SQL_WORKERS, SQL_SETTINGS, SQL_META]
    for (let i = 0; i < tables.length; i++) {
      await this.rdb.executeSql(tables[i])
    }
  }

  /** 读取整份文档（单文档语义） */
  async loadDoc(): Promise<DataDoc> {
    const doc: DataDoc = emptyDoc()
    if (this.rdb === null) {
      return doc
    }
    const rdb = this.rdb
    try {
      doc.products = await this.loadProducts(rdb)
      doc.processes = await this.loadProcesses(rdb)
      doc.records = await this.loadRecords(rdb)
      doc.workers = await this.loadWorkers(rdb)
      doc.settings = await this.loadSettings(rdb)
      const meta: Map<string, string> = await this.loadMeta(rdb)
      const sv = meta.get('schemaVersion')
      if (sv !== undefined) {
        doc.schemaVersion = Number(sv)
      }
      const sa = meta.get('savedAt')
      if (sa !== undefined) {
        doc.savedAt = Number(sa)
      }
    } catch (e) {
      // 读取失败按空文档处理，避免白屏
      return emptyDoc()
    }
    return migrateDoc(doc)
  }

  /** 保存整份文档（事务内全量重写） */
  async saveDoc(doc: DataDoc): Promise<void> {
    if (this.rdb === null) {
      return
    }
    const rdb = this.rdb
    await rdb.beginTransaction()
    try {
      for (let i = 0; i < SQL_CLEAR.length; i++) {
        await rdb.executeSql(SQL_CLEAR[i])
      }
      for (let i = 0; i < doc.products.length; i++) {
        const p = doc.products[i]
        const bucket: relationalStore.ValuesBucket = {
          'id': p.id,
          'name': p.name,
          'spec': p.spec,
          'note': p.note,
          'createdAt': p.createdAt,
          'updatedAt': p.updatedAt
        }
        await rdb.insert(T_PRODUCTS, bucket)
      }
      for (let i = 0; i < doc.processes.length; i++) {
        const o = doc.processes[i]
        const bucket: relationalStore.ValuesBucket = {
          'id': o.id,
          'productId': o.productId,
          'name': o.name,
          'price': o.price,
          'note': o.note,
          'active': o.active ? 1 : 0,
          'sort': o.sort,
          'createdAt': o.createdAt,
          'updatedAt': o.updatedAt
        }
        await rdb.insert(T_PROCESSES, bucket)
      }
      for (let i = 0; i < doc.records.length; i++) {
        const r = doc.records[i]
        const bucket: relationalStore.ValuesBucket = {
          'id': r.id,
          'date': r.date,
          'productId': r.productId,
          'processId': r.processId,
          'quantity': r.quantity,
          'price': r.price,
          'amount': r.amount,
          'worker': r.worker,
          'shift': r.shift,
          'note': r.note,
          'createdAt': r.createdAt,
          'updatedAt': r.updatedAt
        }
        await rdb.insert(T_RECORDS, bucket)
      }
      for (let i = 0; i < doc.workers.length; i++) {
        const w = doc.workers[i]
        const bucket: relationalStore.ValuesBucket = {
          'name': w.name,
          'createdAt': w.createdAt
        }
        await rdb.insert(T_WORKERS, bucket)
      }
      const settingKeys: string[] = ['theme', 'defaultWorker', 'rememberLast', 'lastProductId',
        'lastProcessId', 'homeRange', 'dailyGoal', 'monthlyGoal']
      const s = doc.settings
      const settingValues: string[] = [s.theme, s.defaultWorker, s.rememberLast ? '1' : '0',
        s.lastProductId, s.lastProcessId, s.homeRange, String(s.dailyGoal), String(s.monthlyGoal)]
      for (let i = 0; i < settingKeys.length; i++) {
        const bucket: relationalStore.ValuesBucket = {
          'key': settingKeys[i],
          'value': settingValues[i]
        }
        await rdb.insert(T_SETTINGS, bucket)
      }
      await this.writeMeta(rdb, 'schemaVersion', String(doc.schemaVersion))
      await this.writeMeta(rdb, 'savedAt', String(doc.savedAt))
      await rdb.commit()
    } catch (e) {
      try {
        await rdb.rollBack()
      } catch (e2) {
        // 回滚失败不吞主错误
      }
      if (e instanceof Error) {
        throw e
      }
      throw new Error(String(e))
    }
  }

  /** 清空全部业务数据（保留表结构） */
  async clearAll(): Promise<void> {
    if (this.rdb === null) {
      return
    }
    const rdb = this.rdb
    await rdb.beginTransaction()
    try {
      for (let i = 0; i < SQL_CLEAR.length; i++) {
        await rdb.executeSql(SQL_CLEAR[i])
      }
      await rdb.commit()
    } catch (e) {
      try {
        await rdb.rollBack()
      } catch (e2) {
        // ignore
      }
      if (e instanceof Error) {
        throw e
      }
      throw new Error(String(e))
    }
  }

  // ---------- 私有读取 ----------

  private async loadProducts(rdb: relationalStore.RdbStore): Promise<Product[]> {
    const list: Product[] = []
    const rs = await rdb.querySql('SELECT * FROM products ORDER BY createdAt ASC')
    try {
      while (rs.goToNextRow()) {
        const p: Product = {
          id: rs.getString(rs.getColumnIndex('id')),
          name: rs.getString(rs.getColumnIndex('name')),
          spec: rs.getString(rs.getColumnIndex('spec')),
          note: rs.getString(rs.getColumnIndex('note')),
          createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
          updatedAt: rs.getLong(rs.getColumnIndex('updatedAt'))
        }
        list.push(p)
      }
    } finally {
      rs.close()
    }
    return list
  }

  private async loadProcesses(rdb: relationalStore.RdbStore): Promise<Process[]> {
    const list: Process[] = []
    const rs = await rdb.querySql('SELECT * FROM processes ORDER BY sort ASC, createdAt ASC')
    try {
      while (rs.goToNextRow()) {
        const o: Process = {
          id: rs.getString(rs.getColumnIndex('id')),
          productId: rs.getString(rs.getColumnIndex('productId')),
          name: rs.getString(rs.getColumnIndex('name')),
          price: rs.getDouble(rs.getColumnIndex('price')),
          note: rs.getString(rs.getColumnIndex('note')),
          active: rs.getLong(rs.getColumnIndex('active')) === 1,
          sort: rs.getLong(rs.getColumnIndex('sort')),
          createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
          updatedAt: rs.getLong(rs.getColumnIndex('updatedAt'))
        }
        list.push(o)
      }
    } finally {
      rs.close()
    }
    return list
  }

  private async loadRecords(rdb: relationalStore.RdbStore): Promise<PieceRecord[]> {
    const list: PieceRecord[] = []
    const rs = await rdb.querySql('SELECT * FROM records ORDER BY date DESC, createdAt DESC')
    try {
      while (rs.goToNextRow()) {
        const r: PieceRecord = {
          id: rs.getString(rs.getColumnIndex('id')),
          date: rs.getString(rs.getColumnIndex('date')),
          productId: rs.getString(rs.getColumnIndex('productId')),
          processId: rs.getString(rs.getColumnIndex('processId')),
          quantity: rs.getDouble(rs.getColumnIndex('quantity')),
          price: rs.getDouble(rs.getColumnIndex('price')),
          amount: rs.getDouble(rs.getColumnIndex('amount')),
          worker: rs.getString(rs.getColumnIndex('worker')),
          shift: rs.getString(rs.getColumnIndex('shift')),
          note: rs.getString(rs.getColumnIndex('note')),
          createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
          updatedAt: rs.getLong(rs.getColumnIndex('updatedAt'))
        }
        list.push(r)
      }
    } finally {
      rs.close()
    }
    return list
  }

  private async loadWorkers(rdb: relationalStore.RdbStore): Promise<Worker[]> {
    const list: Worker[] = []
    const rs = await rdb.querySql('SELECT * FROM workers ORDER BY createdAt ASC')
    try {
      while (rs.goToNextRow()) {
        const w: Worker = {
          name: rs.getString(rs.getColumnIndex('name')),
          createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
        }
        list.push(w)
      }
    } finally {
      rs.close()
    }
    return list
  }

  private async loadSettings(rdb: relationalStore.RdbStore): Promise<AppSettings> {
    const s: AppSettings = cloneSettings(DEFAULT_SETTINGS)
    const map: Map<string, string> = new Map<string, string>()
    const rs = await rdb.querySql('SELECT * FROM settings')
    try {
      while (rs.goToNextRow()) {
        map.set(rs.getString(rs.getColumnIndex('key')), rs.getString(rs.getColumnIndex('value')))
      }
    } finally {
      rs.close()
    }
    const num = (k: string, def: number): number => {
      const v = map.get(k)
      if (v === undefined || v === '') {
        return def
      }
      const n = Number(v)
      return isNaN(n) ? def : n
    }
    const str = (k: string, def: string): string => {
      const v = map.get(k)
      return v === undefined ? def : v
    }
    const bool = (k: string, def: boolean): boolean => {
      const v = map.get(k)
      if (v === undefined) {
        return def
      }
      return v === '1' || v === 'true'
    }
    s.theme = str('theme', DEFAULT_SETTINGS.theme)
    s.defaultWorker = str('defaultWorker', '')
    s.rememberLast = bool('rememberLast', true)
    s.lastProductId = str('lastProductId', '')
    s.lastProcessId = str('lastProcessId', '')
    s.homeRange = str('homeRange', 'today')
    s.dailyGoal = num('dailyGoal', 0)
    s.monthlyGoal = num('monthlyGoal', 0)
    return s
  }

  private async loadMeta(rdb: relationalStore.RdbStore): Promise<Map<string, string>> {
    const map: Map<string, string> = new Map<string, string>()
    const rs = await rdb.querySql('SELECT * FROM meta')
    try {
      while (rs.goToNextRow()) {
        map.set(rs.getString(rs.getColumnIndex('key')), rs.getString(rs.getColumnIndex('value')))
      }
    } finally {
      rs.close()
    }
    return map
  }

  private async writeMeta(rdb: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      'key': key,
      'value': value
    }
    await rdb.insert(T_META, bucket)
  }

  /** 构建备份包（与手动导出一致） */
  buildBackupPackage(doc: DataDoc): BackupPackage {
    return buildBackup(doc)
  }

  /** 还原备份包 */
  restoreFromPackage(pkg: BackupPackage): DataDoc {
    return restoreBackup(pkg)
  }
}
