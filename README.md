# 计件通 · Jijian (HarmonyOS NEXT)

计件通（应用名）—— 计件工资记账助手，HarmonyOS NEXT 原生应用（ArkTS / ArkUI），本地优先、离线可用、数据不出本机。

JijianTong (app name) — a piece-rate wage bookkeeping assistant as a native HarmonyOS NEXT app built with ArkTS / ArkUI. Local-first, fully offline, all data stays on-device.

> 本工程为 [jijian-app](https://github.com/wdre9/jijian-app) 的鸿蒙原生重写版（Android 版功能对齐），与 Android 版 JSON 备份文件互相兼容（备份包 `app` 字段为 `jijian-pwa`）。
> This repository is a native HarmonyOS rewrite of [jijian-app](https://github.com/wdre9/jijian-app) with feature parity; JSON backup files are interchangeable with the Android version (backup package `app` field is `jijian-pwa`).

---

## 项目介绍 · Introduction

「计件」面向计件制工厂/车间记账场景：工人按产品工序计件，班组长或老板快速录入当天产量，按日/周/月查看金额与件数，支持 OCR 相册选图识别批量录入（识别文本须同时包含货号、单价、数量）、CSV/Excel/JSON 导出、本地自动备份。

Jijian targets piece-rate workshops: record daily output per product & process, view amount/quantity by day/week/month, OCR batch entry from album photos (recognized text must contain item code, unit price and quantity), export to CSV/Excel/JSON, and local automatic backups.

## 功能特性 · Features

| 中文 | English |
| --- | --- |
| 快速记账：产品工序选择、数量步进、单价、班次、工人、备注 | Quick entry: product/process picker, quantity stepper, price, shift, worker, note |
| 首页概览：今日/本周/本月金额、件数、目标进度、最近记录 | Home overview: today/week/month amount & quantity, goal progress, recent records |
| 明细查询：日期区间/产品/工人/班次筛选，按日分组，多选批量导出 | Details: filter by date/product/worker/shift, grouped by day, multi-select batch export |
| 多维统计：多区间汇总、趋势折线图、产品占比饼图、工序/工人排行柱状图（Canvas 自绘） | Statistics: ranges, trend line chart, product pie chart, process/worker bar charts (custom Canvas) |
| OCR 本地识别：相册选图，设备端 CoreVisionKit 识别，数据不出本机；识别文本须同时包含货号、单价、数量方可批量录入 | On-device OCR: pick photo from album, CoreVisionKit recognition locally; batch entry requires recognized text to contain item code, unit price and quantity |
| 本地自动备份：保存后 24h 节流，滚动保留最近 14 份 JSON（仅存本机沙箱，无服务器、不上传） | Local auto backup: 24h throttle after save, keeps latest 14 JSON backups (stored in the local sandbox only, no server, no upload) |
| 导出：CSV(带 BOM) / Excel(.xls) / JSON / 文本 / 统计长图 | Export: CSV(BOM) / Excel(.xls) / JSON / text / stats snapshot image |
| 主题：浅色 / 深色 / 跟随系统 | Themes: light / dark / follow system |
| 中英双文文档与自动化 CI 构建 | Bilingual docs & automated CI builds |
| AGC 隐私托管合规：首次启动隐私确认、隐私政策/用户协议托管链接 | AGC hosted privacy compliance: first-launch consent, hosted privacy policy / user agreement links |

## 技术栈 · Tech Stack

- 语言/框架：ArkTS + ArkUI，Stage 模型，DevEco Studio 26（API 26 / HarmonyOS NEXT 6.0.0）
- 数据：`@ohos.data.relationalStore`（关系型数据库，单文档语义 + schemaVersion 迁移链）
- 偏好：`@ohos.data.preferences`（主题/目标/默认工人等 UI 偏好）
- 隐私合规：`@kit.AppGalleryKit`（AGC 隐私托管：requestAppPrivacyConsent / getAppPrivacyResult，协议链接托管于 AGC）
- OCR：`@kit.CoreVisionKit`（textRecognition，本地识别）
- 图片：`@ohos.file.picker`（PhotoViewPicker / documentViewPicker）、`@kit.ImageKit`
- 图表：ArkUI `Canvas` 自绘 LineChart / BarChart / PieChart
- 导出：手写 SpreadsheetML 2003 XML（.xls）；统计长图用 `componentSnapshot`

## 本地构建 · Build Locally

1. 安装 [DevEco Studio 26](https://developer.huawei.com/consumer/cn/deveco-studio/)（HarmonyOS NEXT 6.0.0 / API 26 SDK）
2. 用 DevEco Studio 打开工程根目录（或命令行构建）：
   - 命令行需配置 DevEco Command Line Tools（内含 hvigor / ohpm / SDK）
   - Node.js 24+（工具自带或自行安装）
3. 安装依赖并构建：
   ```bash
   ohpm install --all
   hvigorw assembleHap --mode module -p product=default --no-daemon
   ```
4. HAP 产物位于 `entry/build/default/outputs/default/*.hap`；构建上架用 App Pack（.app）：
   ```bash
   hvigorw assembleApp --mode project -p product=default -p buildMode=release --no-daemon
   ```
5. 正式分发请使用发布证书 + hap-sign-tool 离线签名（见下节 CI 说明）

## CI 构建说明 · CI Build

`.github/workflows/build-harmony.yml` 在以下时机自动构建：

- push 到 `main`
- 推送 `v*` 标签（同时创建 GitHub Release 并上传 App Pack）
- 手动触发（workflow_dispatch）

构建流程：DevEco Command Line Tools → `assembleApp --mode project -p buildMode=release` 产出 App Pack（.app）与 HAP，签名 Secrets 齐全时用官方 `hap-sign-tool.jar` 离线签名（hvigor 内置 SignHap 仅认 AES-GCM 密文密码，CI 不可用），产物上传 artifact `jijian-harmony-app`（含 `*.app` 与 `entry/build/**/*.hap`）。

首次运行前，请在仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 说明 |
| --- | --- |
| `HARMONY_CLT_URL` | DevEco Command Line Tools Linux x64 直链（华为开发者官网「搭建流水线」页面获取，需登录） |
| `HARMONY_P12_BASE64` | 签名 keystore（.p12）的 Base64 |
| `HARMONY_P12_PASSWORD` | keystore / key 密码 |
| `HARMONY_PROFILE_BASE64` | 发布 Profile（.p7b）的 Base64 |
| `HARMONY_CERT_BASE64` | 应用证书（.cer）的 Base64 |
| `HARMONY_ALIAS` | 签名密钥别名 |

签名 Secrets 未配置时，CI 会构建**未签名产物**并在 Release 说明中标注，需本机用 DevEco Studio 或 `hap-sign-tool` 离线签名后安装/上架。

## 安装方式 · Installation

- 真机：DevEco Studio 连接设备后 Run；或命令行 `hdc shell bm install -p xxx.hap`
- 未签名 HAP：先用 DevEco Studio 配置签名（File → Project Structure → Signing Configs）或 `hap-sign-tool` 离线签名，再安装
- 应用商店分发：使用正式签名证书与 Profile 构建 App Pack（.app）上传 AGC（华为应用市场）

## 数据安全 · Data Security

- 所有数据仅保存在本机应用沙箱（RelationalStore 关系型数据库 + 沙箱文件），**不联网、不上传、不收集任何个人信息**
- OCR 识别在设备端完成，图片不离开设备
- 隐私合规走 AGC 隐私托管：首次启动展示托管隐私政策/用户协议，用户同意后才进入应用，拒绝即退出；已同意用户后续直接进入
- 卸载应用前请先在「我的 → 数据与导出」导出 JSON 备份
- 自动备份位于应用沙箱 `files/计件自动备份/`，滚动保留最近 14 份

All data is stored only in the local app sandbox (RelationalStore + sandbox files). No network, no upload, no personal data collection. OCR runs fully on-device. Privacy consent is hosted via AGC (first-launch dialog with hosted policy/user agreement links; app exits on refusal). Export a JSON backup before uninstalling.

## 开源协议 · License

本项目基于 [MIT 许可证](LICENSE) 开源，版权归 wdre9 所有（2026）。MIT 许可允许自由使用、修改、分发（含商用），但需保留版权声明。

This project is open-sourced under the [MIT License](LICENSE), Copyright (c) 2026 wdre9. You are free to use, modify and distribute (including commercially) provided the copyright notice is retained.

## 参与贡献 · Contributing

欢迎参与本项目。提交 Issue 或 Pull Request 之前，建议先阅读：

- [贡献指南](CONTRIBUTING.md)：开发环境、分支与提交约定、Pull Request 流程
- [行为准则](CODE_OF_CONDUCT.md)：社区交流的基本约定
- [安全政策](SECURITY.md)：漏洞上报方式与处理时限

问题反馈请使用 Issue 模板：https://github.com/wdre9/jijian-harmony/issues/new/choose
代码变更请按 Pull Request 模板填写变更说明与验证方式。Release history is kept in [CHANGELOG.md](CHANGELOG.md).
