# 贡献指南

感谢你愿意为「计件 · Jijian (HarmonyOS NEXT)」贡献力量。本文档说明参与本项目的推荐流程与基本约定。

## 一、可以参与的方式

- 提交 Bug 报告：使用 [Bug 报告模板](.github/ISSUE_TEMPLATE/bug_report.md) 描述问题。
- 提交功能建议：使用 [功能建议模板](.github/ISSUE_TEMPLATE/feature_request.md) 描述需求与使用场景。
- 提交代码：修复缺陷、优化体验、改进文档、补充测试等。
- 完善文档：修正错别字、补充使用说明与部署说明。

## 二、开发环境准备

要求 DevEco Studio 26（HarmonyOS NEXT 6.0.0 / API 26 SDK，含 hvigor / ohpm / Node.js 24+）。

```powershell
git clone https://github.com/wdre9/jijian-harmony.git
cd jijian-harmony
ohpm install --all      # 安装 ohpm 依赖
hvigorw assembleHap --mode module -p product=default --no-daemon   # 构建 HAP
```

提交代码前请确保 `hvigorw assembleHap` 能够通过，避免引入编译错误。

## 三、分支与提交约定

- 分支命名：
  - 功能：`feat/简要说明`
  - 修复：`fix/简要说明`
  - 文档：`docs/简要说明`
- 提交信息建议采用 `类型: 简要说明` 的形式，类型可取 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`chore`。
  示例：`fix: 修复统计页区间切换后图表未刷新`
- 一次提交只做一件事，避免把无关改动混在一起。

## 四、代码规范

- 使用 ArkTS 与 ArkUI（Stage 模型），保持类型完整，不使用 `any` 规避类型检查。
- 组件、工具函数沿用 `entry/src/main/ets/` 下已有的目录划分与命名风格。
- 样式优先使用主题变量与资源目录，保证浅色与深色主题下均正常显示。
- 界面文案使用简体中文（关键文案同步英文），不添加表情符号。
- 新增功能若涉及数据存储结构变更，请同步更新 RelationalStore 的 schemaVersion 迁移链，并在 Pull Request 中说明兼容性影响。

## 五、Pull Request 流程

1. 从 `main` 分支切出特性分支进行开发。
2. 本地执行 `hvigorw assembleHap` 确认通过。
3. 提交 Pull Request，并按模板填写变更说明、关联 Issue 与验证方式。
4. 若界面有可见变化，请在 Pull Request 中附上截图。
5. 维护者审阅通过后合并。

## 六、Issue 提交建议

- 先检索已有 Issue，避免重复。
- 提供尽可能明确的信息：设备型号与系统版本、复现步骤、期望结果与实际结果。
- 涉及数据问题时，请勿粘贴真实工资数据，可使用演示数据复现。

## 七、行为准则

参与本项目即表示你同意遵守 [行为准则](CODE_OF_CONDUCT.md)。

## 八、许可

向本项目提交的代码与文档，视为同意以 [MIT 许可证](LICENSE) 授权发布。
