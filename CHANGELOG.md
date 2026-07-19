# Changelog

All notable changes to this skill will be documented here. Format: [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/).

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
- 全局 rules 文件（v1 版本，无同名保护）
