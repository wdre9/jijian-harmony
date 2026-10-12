/**
 * UI 偏好存储：@ohos.data.preferences
 * 保存 theme / defaultWorker / rememberLast / lastProductId / lastProcessId /
 * homeRange / dailyGoal / monthlyGoal 以及自动备份时间戳等轻量键值。
 */
import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'

const PREF_NAME: string = 'jijian_prefs'

export class PrefStore {
  private static prefs: preferences.Preferences | null = null

  static async init(ctx: common.Context): Promise<void> {
    if (PrefStore.prefs === null) {
      PrefStore.prefs = await preferences.getPreferences(ctx, PREF_NAME)
    }
  }

  static async getString(key: string, def: string): Promise<string> {
    if (PrefStore.prefs === null) {
      return def
    }
    const v = await PrefStore.prefs.get(key, def)
    return typeof v === 'string' ? v : def
  }

  static async getNumber(key: string, def: number): Promise<number> {
    if (PrefStore.prefs === null) {
      return def
    }
    const v = await PrefStore.prefs.get(key, def)
    return typeof v === 'number' ? v : def
  }

  static async getBool(key: string, def: boolean): Promise<boolean> {
    if (PrefStore.prefs === null) {
      return def
    }
    const v = await PrefStore.prefs.get(key, def)
    return typeof v === 'boolean' ? v : def
  }

  static async setString(key: string, value: string): Promise<void> {
    if (PrefStore.prefs === null) {
      return
    }
    await PrefStore.prefs.put(key, value)
    await PrefStore.prefs.flush()
  }

  static async setNumber(key: string, value: number): Promise<void> {
    if (PrefStore.prefs === null) {
      return
    }
    await PrefStore.prefs.put(key, value)
    await PrefStore.prefs.flush()
  }

  static async setBool(key: string, value: boolean): Promise<void> {
    if (PrefStore.prefs === null) {
      return
    }
    await PrefStore.prefs.put(key, value)
    await PrefStore.prefs.flush()
  }
}
