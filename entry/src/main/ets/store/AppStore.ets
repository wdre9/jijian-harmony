/**
 * 全局状态层（对齐 jijian-app/src/stores/app.ts）
 * 全量 CRUD + 单文档持久化（RelationalStore 事务全量重写）+ 自动备份钩子 + 演示数据 + 主题状态。
 * 变更方法返回新引用快照，页面通过 @State doc 接收以触发 UI 刷新。
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { DataStore } from '../db/Database'
import { PrefStore } from '../db/PrefStore'
import { BackupUtils } from '../utils/BackupUtils'
import { AppSettings, BackupPackage, DataDoc, PieceRecord, Process, Product, Worker } from '../model/Types'
import { SCHEMA_VERSION, buildBackup, cloneSettings, DEFAULT_SETTINGS, emptyDoc, parseBackupPackage } from '../model/DataDoc'
import { deepClone, round, uid } from '../utils/FormatUtils'

export class AppStore {
  private static instance: AppStore | null = null
  doc: DataDoc = emptyDoc()
  ready: boolean = false
  private ctx: common.UIAbilityContext | null = null
  private win: window.Window | null = null

  static getInstance(): AppStore {
    if (AppStore.instance === null) {
      AppStore.instance = new AppStore()
    }
    return AppStore.instance
  }

  /** 初始化：偏好 + 数据库 + 加载文档 */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    this.ctx = ctx
    await PrefStore.init(ctx)
    const ds: DataStore = DataStore.getInstance()
    await ds.init(ctx)
    this.doc = await ds.loadDoc()
    this.ready = true
  }

  /** 快照（新引用，触发页面刷新） */
  snapshot(): DataDoc {
    return deepClone<DataDoc>(this.doc)
  }

  /** 当前主题是否深色（含 auto 跟随系统） */
  isDark(): boolean {
    const s: AppSettings = this.doc.settings
    if (s.theme === 'dark') {
      return true
    }
    if (s.theme === 'light') {
      return false
    }
    const sys: boolean = AppStorage.get<boolean>('systemDark') ?? false
    return sys
  }

  /** 记录系统深浅色（EntryAbility 回调写入） */
  setSystemDark(dark: boolean): void {
    AppStorage.setOrCreate<boolean>('systemDark', dark)
  }

  /** 绑定主窗口（EntryAbility 传入，用于全局深浅色生效） */
  setWindow(win: window.Window): void {
    this.win = win
  }

  /**
   * 将主题设置应用到窗口（状态栏 / 导航栏底色随深色模式切换）：
   * dark -> 强制深色；light -> 强制浅色；auto -> 跟随系统（COLOR_MODE_NOT_SET）。
   */
  applyThemeToWindow(): void {
    if (this.ctx === null) {
      return
    }
    try {
      const s: AppSettings = this.doc.settings
      let mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
      if (s.theme === 'dark') {
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      } else if (s.theme === 'light') {
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      }
      this.ctx.getApplicationContext().setColorMode(mode)
    } catch (e) {
      // 窗口模式设置失败不影响功能
    }
  }

  // ---------- 持久化与备份 ----------

  private async persist(): Promise<void> {
    if (this.ctx === null) {
      return
    }
    this.doc.savedAt = Date.now()
    const ds: DataStore = DataStore.getInstance()
    await ds.saveDoc(this.doc)
    const pkg: BackupPackage = buildBackup(this.doc)
    await BackupUtils.maybeAutoBackup(this.ctx, pkg)
  }

  /** 导出备份文本 */
  exportDocText(): string {
    const pkg: BackupPackage = buildBackup(this.doc)
    return JSON.stringify(pkg, null, 2)
  }

  /** 导入备份文本（返回是否成功） */
  async importDocText(text: string): Promise<string> {
    const pkg: BackupPackage | null = parseBackupPackage(text)
    if (pkg === null) {
      return '备份文件不是有效的 JSON'
    }
    const ds: DataStore = DataStore.getInstance()
    try {
      const doc: DataDoc = ds.restoreFromPackage(pkg)
      this.doc = doc
      await ds.saveDoc(this.doc)
      return ''
    } catch (e) {
      return e instanceof Error ? e.message : '备份文件格式错误'
    }
  }

  // ---------- 设置 ----------

  /** 保存完整设置 */
  async updateSettings(s: AppSettings): Promise<DataDoc> {
    this.doc.settings = cloneSettings(s)
    await this.persist()
    return this.snapshot()
  }

  // ---------- 产品 CRUD ----------

  async addProduct(name: string, spec: string, note: string): Promise<DataDoc> {
    const now: number = Date.now()
    const p: Product = {
      id: uid('p'),
      name: name,
      spec: spec,
      note: note,
      createdAt: now,
      updatedAt: now
    }
    this.doc.products.push(p)
    await this.persist()
    return this.snapshot()
  }

  async updateProduct(p: Product): Promise<DataDoc> {
    for (let i = 0; i < this.doc.products.length; i++) {
      if (this.doc.products[i].id === p.id) {
        this.doc.products[i] = p
      }
    }
    await this.persist()
    return this.snapshot()
  }

  /** 删除产品：级联删除其工序与记录 */
  async deleteProduct(id: string): Promise<DataDoc> {
    const products: Product[] = []
    for (let i = 0; i < this.doc.products.length; i++) {
      if (this.doc.products[i].id !== id) {
        products.push(this.doc.products[i])
      }
    }
    this.doc.products = products
    const processes: Process[] = []
    for (let i = 0; i < this.doc.processes.length; i++) {
      if (this.doc.processes[i].productId !== id) {
        processes.push(this.doc.processes[i])
      }
    }
    this.doc.processes = processes
    const records: PieceRecord[] = []
    for (let i = 0; i < this.doc.records.length; i++) {
      if (this.doc.records[i].productId !== id) {
        records.push(this.doc.records[i])
      }
    }
    this.doc.records = records
    await this.persist()
    return this.snapshot()
  }

  // ---------- 工序 CRUD ----------

  async addProcess(productId: string, name: string, price: number, note: string): Promise<DataDoc> {
    const now: number = Date.now()
    const sort: number = this.doc.processes.length
    const c: Process = {
      id: uid('c'),
      productId: productId,
      name: name,
      price: price,
      note: note,
      active: true,
      sort: sort,
      createdAt: now,
      updatedAt: now
    }
    this.doc.processes.push(c)
    await this.persist()
    return this.snapshot()
  }

  async updateProcess(c: Process): Promise<DataDoc> {
    for (let i = 0; i < this.doc.processes.length; i++) {
      if (this.doc.processes[i].id === c.id) {
        this.doc.processes[i] = c
      }
    }
    await this.persist()
    return this.snapshot()
  }

  async deleteProcess(id: string): Promise<DataDoc> {
    const processes: Process[] = []
    for (let i = 0; i < this.doc.processes.length; i++) {
      if (this.doc.processes[i].id !== id) {
        processes.push(this.doc.processes[i])
      }
    }
    this.doc.processes = processes
    await this.persist()
    return this.snapshot()
  }

  // ---------- 记录 CRUD ----------

  async addRecord(date: string, productId: string, processId: string, quantity: number, price: number,
    worker: string, shift: string, note: string, processNameSnapshot: string = '',
    countMode: string = 'auto', count: number = 1): Promise<DataDoc> {
    const now: number = Date.now()
    // 工序名快照：未显式传入时用工序表当前名回填（工序删除后明细/统计仍显示原工序名）
    let snap: string = processNameSnapshot
    if (snap.length === 0 && processId.length > 0) {
      for (let i = 0; i < this.doc.processes.length; i++) {
        if (this.doc.processes[i].id === processId) {
          snap = this.doc.processes[i].name
        }
      }
    }
    const isManual: boolean = countMode === 'manual'
    const r: PieceRecord = {
      id: uid('r'),
      date: date,
      productId: productId,
      processId: processId,
      processNameSnapshot: snap,
      countMode: isManual ? 'manual' : 'auto',
      count: isManual ? count : 1,
      quantity: quantity,
      price: price,
      amount: round(quantity * price, 2),
      worker: worker,
      shift: shift,
      note: note,
      createdAt: now,
      updatedAt: now
    }
    this.doc.records.push(r)
    // 记住上次选择
    this.doc.settings.rememberLast = this.doc.settings.rememberLast
    if (this.doc.settings.rememberLast) {
      this.doc.settings.lastProductId = productId
      this.doc.settings.lastProcessId = processId
    }
    // 记录默认工人
    if (worker) {
      let found: boolean = false
      for (let i = 0; i < this.doc.workers.length; i++) {
        if (this.doc.workers[i].name === worker) {
          found = true
        }
      }
      if (!found) {
        const w: Worker = { name: worker, createdAt: now }
        this.doc.workers.push(w)
      }
    }
    await this.persist()
    return this.snapshot()
  }

  async updateRecord(r: PieceRecord): Promise<DataDoc> {
    for (let i = 0; i < this.doc.records.length; i++) {
      if (this.doc.records[i].id === r.id) {
        this.doc.records[i] = r
      }
    }
    await this.persist()
    return this.snapshot()
  }

  async deleteRecord(id: string): Promise<DataDoc> {
    const records: PieceRecord[] = []
    for (let i = 0; i < this.doc.records.length; i++) {
      if (this.doc.records[i].id !== id) {
        records.push(this.doc.records[i])
      }
    }
    this.doc.records = records
    await this.persist()
    return this.snapshot()
  }

  // ---------- 工人 ----------

  async addWorker(name: string): Promise<DataDoc> {
    if (!name) {
      return this.snapshot()
    }
    for (let i = 0; i < this.doc.workers.length; i++) {
      if (this.doc.workers[i].name === name) {
        return this.snapshot()
      }
    }
    const w: Worker = { name: name, createdAt: Date.now() }
    this.doc.workers.push(w)
    await this.persist()
    return this.snapshot()
  }

  async removeWorker(name: string): Promise<DataDoc> {
    const workers: Worker[] = []
    for (let i = 0; i < this.doc.workers.length; i++) {
      if (this.doc.workers[i].name !== name) {
        workers.push(this.doc.workers[i])
      }
    }
    this.doc.workers = workers
    await this.persist()
    return this.snapshot()
  }

  // ---------- 数据维护 ----------

  /** 清空全部数据 */
  async clearAll(): Promise<DataDoc> {
    this.doc = emptyDoc()
    const ds: DataStore = DataStore.getInstance()
    await ds.saveDoc(this.doc)
    return this.snapshot()
  }

  /** 载入演示数据（近 14 天确定性生成） */
  async loadDemoData(): Promise<DataDoc> {
    this.doc = emptyDoc()
    const now: number = Date.now()
    // 产品
    const p1: Product = { id: 'p_demo_5551', name: '法兰盘', spec: 'φ100', note: '演示数据', createdAt: now, updatedAt: now }
    const p2: Product = { id: 'p_demo_5552', name: '轴承套', spec: '6205', note: '演示数据', createdAt: now, updatedAt: now }
    const p3: Product = { id: 'p_demo_5553', name: '端盖', spec: 'D80', note: '演示数据', createdAt: now, updatedAt: now }
    this.doc.products = [p1, p2, p3]
    // 工序
    const c1: Process = { id: 'c_demo_1', productId: p1.id, name: '车外圆', price: 1.2, note: '', active: true, sort: 0, createdAt: now, updatedAt: now }
    const c2: Process = { id: 'c_demo_2', productId: p1.id, name: '钻孔', price: 0.6, note: '', active: true, sort: 1, createdAt: now, updatedAt: now }
    const c3: Process = { id: 'c_demo_3', productId: p2.id, name: '镗孔', price: 0.9, note: '', active: true, sort: 0, createdAt: now, updatedAt: now }
    const c4: Process = { id: 'c_demo_4', productId: p2.id, name: '攻丝', price: 0.5, note: '', active: true, sort: 1, createdAt: now, updatedAt: now }
    const c5: Process = { id: 'c_demo_5', productId: p3.id, name: '铣平面', price: 1.4, note: '', active: true, sort: 0, createdAt: now, updatedAt: now }
    const c6: Process = { id: 'c_demo_6', productId: p3.id, name: '去毛刺', price: 0.3, note: '', active: true, sort: 1, createdAt: now, updatedAt: now }
    this.doc.processes = [c1, c2, c3, c4, c5, c6]
    // 工人
    this.doc.workers = [
      { name: '张伟', createdAt: now },
      { name: '李娜', createdAt: now },
      { name: '王强', createdAt: now }
    ]
    // 记录：近 14 天，每天 3~6 条
    const workers: string[] = ['张伟', '李娜', '王强']
    const processes: Process[] = this.doc.processes
    const records: PieceRecord[] = []
    let seq: number = 0
    for (let day = 13; day >= 0; day--) {
      const d: Date = new Date()
      d.setDate(d.getDate() - day)
      const dd: Date = new Date(d.getTime())
      const fmt = (x: Date): string => {
        const p = (n: number): string => (n < 10 ? `0${n}` : String(n))
        return `${x.getFullYear()}-${p(x.getMonth() + 1)}-${p(x.getDate())}`
      }
      const dateStr: string = fmt(dd)
      const cnt: number = 3 + (seq % 4)
      for (let j = 0; j < cnt; j++) {
        const proc: Process = processes[(seq * 3 + j) % processes.length]
        const workerName: string = workers[(seq + j) % workers.length]
        const q: number = 10 + ((seq * 7 + j * 13) % 45)
        records.push({
          id: uid('r'),
          date: dateStr,
          productId: proc.productId,
          processId: proc.id,
          processNameSnapshot: proc.name,
          countMode: 'auto',
          count: 1,
          quantity: q,
          price: proc.price,
          amount: round(q * proc.price, 2),
          worker: workerName,
          shift: j % 2 === 0 ? 'day' : 'night',
          note: '',
          createdAt: dd.getTime() + j,
          updatedAt: dd.getTime() + j
        })
      }
      seq++
    }
    this.doc.records = records
    // 设置
    this.doc.settings = cloneSettings(DEFAULT_SETTINGS)
    this.doc.settings.defaultWorker = '张伟'
    await this.persist()
    return this.snapshot()
  }
}
