---
name: caiyizou-skill-hub
description: 一站式 Skill 管理体系。setup 一键搭建整套体系；install/create/archive 命令标准化 Skill 的安装、创建、归档、生成小白使用指南并回填飞书表格。适配任意 AI agent（Claude Code / Codex / Cursor / Gemini CLI 等）。Use when the user asks to "搭建 skill 体系"、"管理 skill"、"初始化 skill hub"、"安装 skill 并归档"、"创建新 skill 并归档"、"列出我所有 skill"。
---

# caiyizou-skill-hub

一站式 Skill 管理体系。别人拿到这个 skill 后，只需让他的 AI agent 跑 `/caiyizou-skill-hub setup`，就能搭起完整的 Skill 管理流程。

## 设计原则（重要）

⚠️ **本 skill 不硬编码任何个人配置**——所有飞书表格 / wiki URL / agent 路径都通过 setup 时的交互式询问填入。每个用户跑 setup 都用自己的配置，互不干扰。

## 解决什么问题

- 每次安装/创建 Skill 后不知道该不该归档、归档到哪里
- 小白用户不知道某个 Skill 怎么用，找不到使用指南
- 没有统一的目录结构，软链混乱，跨 Agent 兼容性差
- 想给别人一套完整流程，但只能口述、不能直接分发

## 一键搭建（setup）

```bash
/caiyizou-skill-hub setup
```

agent 会自动跑 `scripts/setup.sh`，交互式询问 3 件事：

1. **你用的是什么 AI agent 工具？** → 决定 skill 软链装到哪里
2. **你的飞书技能库表格链接是什么？** → agent 自动解析出 token + table-id
3. **你的"创建类"父 wiki 链接 + "安装类"父 wiki 链接是什么？** → agent 自动解析出 node-token

**前置条件**：
- 已安装 `lark-cli`（`brew install lark-cli` 或参考官方文档）
- 已 `lark-cli auth login` 完成飞书授权

## Agent 适配（setup 时自动选）

不同 agent 的 skill 路径不一样，setup 会按用户的选择放到对应目录：

| Agent | Skill 安装路径 | 备注 |
|-------|--------------|------|
| Claude Code | `~/.claude/skills/` | 默认 |
| Codex | `~/.codex/skills/` | |
| Cursor | `~/.cursor/skills/` | |
| Gemini CLI | `~/.gemini/skills/` | |
| 其他 | setup 时询问 | |

跨 agent 通用时，**主目录仍是 `~/.agents/skills/`**，各 agent 的 skills 目录是软链。

## 日常命令

| 命令 | 做什么 | 何时用 |
|------|------|------|
| `/caiyizou-skill-hub setup` | 一键搭建整套体系 | 第一次使用本 skill |
| `/caiyizou-skill-hub install <name>` | 安装第三方 Skill 并归档 | 拿到新 Skill 想安装时 |
| `/caiyizou-skill-hub create <name>` | 创建新 Skill 并归档 | 自己写新 Skill 时 |
| `/caiyizou-skill-hub archive <name>` | 补归档已有 Skill 到飞书表格 | 漏归档、想补归档 |
| `/caiyizou-skill-hub list` | 列出当前所有 Skill 及归档状态 | 不知道装过哪些时 |

## 标准化流程（任何 Skill 安装/创建都自动跑）

### 模板与父 wiki 分流（用户在 setup 时提供）

| 场景 | 模板 | 父 wiki（在 setup 时配置） |
|------|------|------------------------------|
| **自创 Skill** | `~/.claude/templates/skill-guide-create.md` | setup 时填 URL，agent 自动解析 |
| **安装 Skill** | `~/.claude/templates/skill-guide-install.md` | setup 时填 URL，agent 自动解析 |

### 顺序：先建指南 → 一次性归档（零回填）

1. 读取对应场景的模板
2. 用 `lark-cli wiki +node-create` 在父 wiki 下创建子文档，拿到完整 URL
3. 把填好的内容用 `lark-cli docs +update` 写入子文档（markdown 模式）
4. 如飞书表格无「使用指南」列，用 `lark-cli base +field-create` 新增
5. 用 `lark-cli base +record-batch-create` 一次性归档 Skill 记录，**写入时直接带上「使用指南」URL**，不再回填

## 飞书配置（setup 时填，不硬编码）

setup 时用户只填**飞书链接**（URL），agent 用 lark-cli 自动解析 token：

| 用户提供 | agent 解析 |
|---------|-----------|
| 飞书表格链接（`https://nllsgu0xxx.feishu.cn/wiki/<token>` 或 `/base/<token>`） | `lark-cli base +url-resolve` → base-token + table-id |
| 父 wiki 链接 | `lark-cli wiki +url-resolve` → space-id + node-token |

**禁止**在 setup 阶段直接问用户要 base-token / table-id / node-token（这些是 agent 的工作）。

## 存放位置规范（强制）

所有 Skill 必须装到 `~/.agents/skills/<name>/`，并在**当前 agent 的 skills 目录**建软链：

```
~/.agents/skills/
├── caiyizou-skill-hub/             # 本 skill（自创）
└── ...

~/.claude/skills/    (Claude Code)
~/.codex/skills/     (Codex)
~/.cursor/skills/    (Cursor)
~/.gemini/skills/    (Gemini CLI)
└── caiyizou-skill-hub -> ../.agents/skills/caiyizou-skill-hub
```

**禁止**直接写入 `~/.claude/skills/` 等单 agent 目录（其他 Agent 读不到）。

## 内置脚本

| 脚本 | 用途 |
|------|------|
| `scripts/setup.sh` | 交互式搭建（询问 agent + 飞书 URL，自动写入 rules） |
| `scripts/archive.sh` | 把 Skill 归档到飞书表格（从环境变量读 base-token/table-id） |
| `scripts/add-field.sh` | 给飞书表格添加字段（从环境变量读 base-token/table-id） |

scripts 中所有 token 从环境变量 `$CAIYIZOU_BASE_TOKEN` / `$CAIYIZOU_TABLE_ID` 读取，setup 时写入 `~/.config/caiyizou-skill-hub/env`。

## 必读参考资料

- `~/.claude/rules/skill-creation-workflow.md`：完整规则文档（本 skill setup 时写入）
- 飞书技能库表格：见 setup 时用户填入的链接

## 安装方式

```bash
# 方式 1：RedSkill 商店（推荐）
redskill install caiyizou-skill-hub

# 方式 2：npx skills（跨 Agent）
npx skills add https://github.com/caiyizou/caiyizou-skill-hub

# 方式 3：手动
curl -L https://github.com/caiyizou/caiyizou-skill-hub/archive/main.tar.gz | tar xz
mv caiyizou-skill-hub-main ~/.agents/skills/caiyizou-skill-hub
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.{claude,codex,cursor,gemini}/skills/caiyizou-skill-hub
```

## 不适用场景

- 公司有现成的 Skill 管理平台 → 用公司的，不要重复造轮子
- 只想管理一两个 Skill → 直接手动装就行，不需要这个体系
- 不使用飞书 → 跳过飞书相关步骤，只用本地 rules
