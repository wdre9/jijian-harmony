/**
 * CI 签名注入脚本（Node ESM）
 * 读取 GitHub Secrets：HARMONY_P12_BASE64 / HARMONY_P12_PASSWORD /
 *   HARMONY_PROFILE_BASE64 / HARMONY_CERT_BASE64 / HARMONY_ALIAS
 * 若任一缺失 → 保持未签名配置，输出 "unsigned"（构建未签名 HAP）
 * 全部齐全 → 解码写 .sign/ 文件并注入 signingConfigs，输出 "signed"
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const profile = join(root, 'build-profile.json5')

function stripComments(text) {
  return text.split('\n').map((l) => {
    const i = l.indexOf('//')
    return i >= 0 ? l.slice(0, i) : l
  }).join('\n')
}

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

let text = readFileSync(profile, 'utf8')
let cfg
try {
  cfg = JSON.parse(stripComments(text))
} catch (e) {
  console.error('parse build-profile.json5 failed:', e.message)
  process.exit(1)
}
cfg.app.signingConfigs = [{
  name: 'default',
  material: {
    certpath: join(signDir, 'harmony.cer').replaceAll('\\', '/'),
    storePassword: env.p12Pwd,
    keyAlias: env.alias,
    keyPassword: env.p12Pwd,
    profile: join(signDir, 'harmony.profile').replaceAll('\\', '/'),
    signAlg: 'SHA256withECDSA',
    storeFile: join(signDir, 'harmony.p12').replaceAll('\\', '/')
  }
}]
cfg.app.products.forEach((p) => {
  if (p.name === 'default') {
    p.signingConfig = 'default'
  }
})
writeFileSync(profile, JSON.stringify(cfg, null, 2) + '\n')
console.log('signed')
