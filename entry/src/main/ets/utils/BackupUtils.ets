/**
 * 自动备份：保存数据后按 24h 节流，把与手动导出一致的备份 JSON 写入应用沙箱
 * files/计件自动备份/，文件名 jijian-backup-YYYYMMDDHHmmss.json，滚动保留最近 14 份。
 * 使用 @ohos.file.fs（@kit.CoreFileKit）。
 */
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BackupPackage } from '../model/Types'
import { PrefStore } from '../db/PrefStore'

const DIR_NAME: string = '计件自动备份'
const FILE_PREFIX: string = 'jijian-backup-'
const MAX_FILES: number = 14
const INTERVAL_MS: number = 24 * 60 * 60 * 1000
const UI_KEY_LAST_AUTO_BACKUP: string = 'jijian:ui:lastAutoBackupAt'

export class BackupUtils {
  /** 时间戳 YYYYMMDDHHmmss */
  static stamp(): string {
    const d: Date = new Date()
    const p = (n: number, w: number): string => {
      let s = String(n)
      while (s.length < w) {
        s = '0' + s
      }
      return s
    }
    return `${d.getFullYear()}${p(d.getMonth() + 1, 2)}${p(d.getDate(), 2)}${p(d.getHours(), 2)}${p(d.getMinutes(), 2)}${p(d.getSeconds(), 2)}`
  }

  /** 满足 24h 节流即写一份备份，并滚动清理旧备份 */
  static async maybeAutoBackup(ctx: common.UIAbilityContext, pkg: BackupPackage): Promise<void> {
    const last: number = await PrefStore.getNumber(UI_KEY_LAST_AUTO_BACKUP, 0)
    if (Date.now() - last < INTERVAL_MS) {
      return
    }
    await BackupUtils.writeBackup(ctx, pkg)
    await PrefStore.setNumber(UI_KEY_LAST_AUTO_BACKUP, Date.now())
  }

  /** 写一份备份文件并滚动清理 */
  static async writeBackup(ctx: common.UIAbilityContext, pkg: BackupPackage): Promise<void> {
    const dir: string = `${ctx.filesDir}/${DIR_NAME}`
    try {
      fileIo.mkdirSync(dir, true)
    } catch (e) {
      // 目录已存在
    }
    const filePath: string = `${dir}/${FILE_PREFIX}${BackupUtils.stamp()}.json`
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    fileIo.writeSync(file.fd, JSON.stringify(pkg, null, 2))
    fileIo.closeSync(file)
    // 滚动清理：只保留最新的 MAX_FILES 份
    try {
      const names: string[] = fileIo.listFileSync(dir)
      const backups: string[] = []
      for (let i = 0; i < names.length; i++) {
        const n: string = names[i]
        if (n.startsWith(FILE_PREFIX) && n.endsWith('.json')) {
          backups.push(n)
        }
      }
      backups.sort()
      const over: number = backups.length - MAX_FILES
      for (let i = 0; i < over; i++) {
        try {
          fileIo.unlinkSync(`${dir}/${backups[i]}`)
        } catch (e) {
          // 删除失败不影响主流程
        }
      }
    } catch (e) {
      // 清理失败不影响主流程
    }
  }

  /** 查看最近一次自动备份时间（ms），未备份过返回 0 */
  static async lastAutoBackupAt(): Promise<number> {
    return await PrefStore.getNumber(UI_KEY_LAST_AUTO_BACKUP, 0)
  }
}
