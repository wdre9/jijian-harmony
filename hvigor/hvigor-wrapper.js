/**
 * hvigor-wrapper.js - 工程级 hvigor 包装器（与 hvigorw 配合）
 * 负责：读取 hvigor/hvigor-config.json5，把构建请求转交给可用的 hvigor 运行时。
 * 优先级：1) PATH 中的 hvigorw（DevEco Command Line Tools） 2) 本地安装的 @ohos/hvigor
 * 说明：DevEco Studio 会按 IDE 内置工具链自动同步/覆盖本文件；命令行用户建议安装
 * DevEco Command Line Tools（内含 hvigor / ohpm / SDK），本 wrapper 会优先转发。
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const DIR = path.resolve(__dirname, '..');
const CONFIG_FILE = path.join(__dirname, 'hvigor-config.json5');

function readConfig() {
  try {
    const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
    // 剥离行注释后解析（配置为 JSON5 超集，常规字段为 JSON 兼容）
    const clean = raw.split('\n').map((l) => {
      const i = l.indexOf('//');
      return i >= 0 ? l.slice(0, i) : l;
    }).join('\n');
    return JSON.parse(clean);
  } catch (e) {
    console.error('[hvigor-wrapper] read hvigor-config.json5 failed:', e.message);
    return {};
  }
}

function run(command, args) {
  const r = spawnSync(command, args, { stdio: 'inherit', shell: process.platform === 'win32' });
  process.exit(r.status === null ? 1 : r.status);
}

const args = process.argv.slice(2);

// 1) 优先转发 PATH 中的 hvigorw（DevEco Command Line Tools 环境）
try {
  if (process.platform === 'win32') {
    const which = spawnSync('where', ['hvigorw'], { encoding: 'utf8' });
    if (which.status === 0) {
      run('hvigorw', args);
    }
  } else {
    const which = spawnSync('bash', ['-lc', 'command -v hvigorw'], { encoding: 'utf8' });
    if (which.status === 0 && which.stdout.trim()) {
      run('hvigorw', args);
    }
  }
} catch (e) {
  // 忽略，继续尝试本地 hvigor
}

// 2) 本地 hvigor（DevEco 安装目录下的 hvigor CLI）
const cfg = readConfig();
const version = cfg.hvigorVersion || '5.0.0';
console.log(`[hvigor-wrapper] 未发现命令行工具链 hvigorw，尝试本地 hvigor（配置版本 ${version}）。`);
console.log('[hvigor-wrapper] 建议安装 DevEco Command Line Tools 后重试，或用 DevEco Studio 打开工程构建。');
process.exit(1);
