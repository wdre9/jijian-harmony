/**
 * CI 签名材料准备脚本（Node ESM）
 * 读取 GitHub Secrets：HARMONY_P12_BASE64 / HARMONY_P12_PASSWORD /
 *   HARMONY_PROFILE_BASE64 / HARMONY_CERT_BASE64 / HARMONY_ALIAS
 * 若任一缺失 → 输出 "unsigned"（后续构建未签名 HAP）
 * 全部齐全 → 解码写 .sign/ 文件（供 hap-sign-tool.jar 离线签名），输出 "signed"
 *
 * 注意：hvigor 26 的 SignHap 只认 AES-GCM 加密后的十六进制密文密码，
 *       明文密码会触发 00308018 ENOENT（需 .sign/material 随机块解密），
 *       因此不再向 build-profile.json5 注入 signingConfigs，
 *       改由 workflow 的 Sign HAP 步骤用 hap-sign-tool.jar 对未签名 HAP 离线签名。
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

const env = {
  p12: process.env.HARMONY_P12_BASE64 || '',
  p12Pwd: process.env.HARMONY_P12_PASSWORD || '',
  profileB64: process.env.HARMONY_PROFILE_BASE64 || '',
  cert: process.env.HARMONY_CERT_BASE64 || '',
  alias: process.env.HARMONY_ALIAS || ''
}

if (!env.p12 || !env.p12Pwd || !env.profileB64 || !env.cert || !env.alias) {
  console.log('unsigned')
  process.exit(0)
}

const signDir = join(root, '.sign')
mkdirSync(signDir, { recursive: true })
writeFileSync(join(signDir, 'harmony.p12'), Buffer.from(env.p12, 'base64'))
writeFileSync(join(signDir, 'harmony.profile'), Buffer.from(env.profileB64, 'base64'))
writeFileSync(join(signDir, 'harmony.cer'), Buffer.from(env.cert, 'base64'))
console.log('signed')
