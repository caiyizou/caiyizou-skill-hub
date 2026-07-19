# Changelog

All notable changes to this skill will be documented here. Format: [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/).

## [1.10.1] - 2026-07-19

### Fixed (设计边界回归)
- **回归修复**：v1.10.0 的「intent → slash command」表把通用「帮我装个 skill」「我要建 skill」也触发到了本 skill，破坏了作者个人 skill 工作流（本 skill 是给最终用户分享的，不是作者自己用的）
- 重写 frontmatter `description`：明确**只在用户明确提到「caiyizou-skill-hub」/「skill hub」/「skill 库」/「skill 体系」/「归档」时才触发**
- 重写 intent 表：加「⚠️ agent 必读：本 skill 的边界」段，明确不拦截通用 skill 工作流口述
- 这个版本**作者不需要 setup**（你本来就没跑，自己另有工作流）

## [1.10.0] - 2026-07-19

### Added (intent 自动触发)
- frontmatter description 扩展触发关键词
- 「🗣️ 你口述 → agent 该执行的命令」整段意图表

> ⚠️ **v1.10.0 的设计有问题**：作者本人没跑本 skill setup，agent 误把通用「帮我装个 skill」也路由到本 skill 流程，破坏作者个人工作流。**已被 v1.10.1 撤销**，仅留 commit 记录。

## [1.9.0] - 2026-07-19

### Fixed (第4轮)
- archive.sh 改名分支路径 bug：之前选「创建副本 foo-v2」后会写路径 `/skills/foo-v2/SKILL.md`（目录不存在），现在 `RENAME_PATH_FROM` 保留原名，路径仍指原目录
- archive.sh 查重读表里硬编码「技能名称」：现在传 `F_NAME`（别名后的真字段名）给 python，查重走别名兼容
- archive.sh update 路径里的死代码 `.[''] = .['']` 已清理
- doctor.sh 新增 1b 段：直接读 `SKILL.md` frontmatter version 字段与当前期望版本比对，不一致则提示 `git pull`

## [1.8.0] - 2026-07-19

### Fixed (P2)
- CHANGELOG.md v1.0.0 条目去掉「无同名保护」不实声明；补「archive.sh 同名 3 选 1」原始能力描述
- setup.sh 写 env 时新增 `CAIYIZOU_HUB_VERSION` 字段；doctor.sh 检测到旧 env（缺版本号或版本低于 1.8）提示重跑 setup 升级
- uninstall.sh 检测到 env 不存在时显式标识「你从未 setup 过」模式，告知只删主目录 + 软链

## [1.7.0] - 2026-07-19

### Fixed (P1)
- 新增 `scripts/doctor.sh`：自检入口（依赖/env/软链/模板/lark-cli 授权/飞书表格/wiki 通达）；失败给修复建议
- setup.sh 第 9 步 lark-cli auth 检测：用 `lark-cli auth whoami + jq 解析` 替代脆弱的文本正则
- archive.sh：先 `+field-list` 读表格实际字段，字段名走别名兼容（功能分类↔分类↔category 等），跳过不存在的字段不报错

### Changed
- SKILL.md + README.md 增加 `/caiyizou-skill-hub doctor` 命令
- README.md §快速开始 第 5 步给具体示例（"帮我装 xxx skill"）
- README.md 新增 §🩺 Troubleshooting 段（8 个常见问题速查表）
- doctor.sh 兼容 bash 3（用 tr 不用 ${var,,}）

## [1.6.0] - 2026-07-19

### Fixed (P0)
- 共享依赖检查：`scripts/_lib.sh` 新增 `require_deps` 函数；archive.sh / setup.sh / pre-publish-clean.sh / add-field.sh / render-guide.sh 全部 source 上，缺失 python3 / jq / lark-cli 时打印安装方法并退出，不再神秘报错
- add-field.sh 不再用字符串拼接 JSON，改用 `jq -n` + type 白名单校验（防字段名特殊字符注入）
- 模板预处理从 SKILL.md 内联 python 巨脚本改成 `scripts/render-guide.sh` + `scripts/_render-guide.py`：
  - 智能检测：install 模板（无 HTML 注释无附录）→ 只跑占位符替换；create 模板（含 HTML 注释 + 附录段）→ 自动剥离
  - 减少 SKILL.md 代码体积约 20 行

### Added
- `scripts/_lib.sh`：共享工具函数（require_deps）
- `scripts/render-guide.sh` + `scripts/_render-guide.py`：模板渲染（cli + python helper）

## [1.5.0] - 2026-07-19

### Changed
- README.md：新增 §快速开始 5 步表；§安装方式 3 改为按 agent 分支只建 1 条软链
- setup.sh：第 6 步问法改为大白话（「我自己创建的 skill / 我安装的 skill 使用指南放飞书哪个文档下」）；加解析成功回显
- SKILL.md：setup 第 3 步描述同步改大白话；frontmatter 新增 `version: 1.5.0`
- uninstall.sh：拆为三步（列待删 → yes 确认 → 执行）；无任何待删路径时直接 exit 0

### Added
- SKILL.md：install/create 命令→动作映射新增步骤 4「模板预处理」（python3 替换占位符 + 删 HTML 注释 + 删附录段），避免飞书文档出现占位符和模板附录
- CHANGELOG.md（本文件）
- CONTRIBUTING.md

## [1.4.0] - 2026-07-19

### Added
- pre-publish-clean.sh：发布前自动扫描 + `--apply` 自动替换（备份 *.bak.*）
- SKILL.md：发布前清理流程段

## [1.3.0] - 2026-07-19

### Changed
- scripts/setup.sh v1.2 重写：交互式询问 agent 类型、URL 自动识别（base / wiki）、同名保护 3 选 1
- 新增跨 Agent 兼容性实测表（Claude Code 必须软链 / Codex 无需软链 / Cursor 与 Gemini CLI 待实测）

## [1.2.0] - 2026-07-19

### Added
- scripts/uninstall.sh：卸脚本（--keep-config / --keep-rules / --keep-templates）
- scripts/add-field.sh：飞书表格加字段（从 env 读 base-token / table-id）
- templates/skill-guide-{create,install}.md：使用指南模板

## [1.1.0] - 2026-07-19

### Added
- scripts/archive.sh v1.2：同名保护 + jq 拼 JSON + 自动 field-create「使用指南」列
- 写全局 rules 文件 `~/.claude/rules/skill-creation-workflow.md`（同名保护 3 选 1）

## [1.0.0] - 2026-07-19

### Added
- 初版 SKILL.md + README.md + scripts/setup.sh
- 飞书表格 + 父 wiki 配置走 setup 交互式询问
- 全局 rules 文件
- archive.sh：jq 拼 JSON + 同名保护（升级 / 改名 / 取消 3 选 1）
