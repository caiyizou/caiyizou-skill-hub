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

agent 会自动跑 `scripts/setup.sh`，交互式询问：

1. **你用的是什么 AI agent 工具？** → 决定 skill 软链装到哪里
2. **你的飞书技能库表格链接是什么？** → agent 自动解析出 token + table-id
3. **你的"创建类"父 wiki 链接 + "安装类"父 wiki 链接是什么？** → agent 自动解析出 node-token
4. **如果未装 lark-cli → 自动引导安装**（brew/npm 二选一）
5. **如果未授权飞书 → 自动引导执行 `lark-cli auth login`**

**前置条件**：
- Homebrew 或 npm（用于自动安装 lark-cli）

## 🤖 跨 Agent 兼容性（关键实测表）

不同 agent 的 skill 发现机制不一样——**已通过实测确认**：

| Agent | 是否需要软链 | 状态 |
|-------|-------------|------|
| **Claude Code** | ✅ **必须**软链到 `~/.claude/skills/` | ✅ 已实测 |
| **Codex** | ❌ **无需**软链（直接读 `~/.agents/skills/`） | ✅ 已实测 |
| **Cursor** | ❓ 待实测 | 🧪 |
| **Gemini CLI** | ❓ 待实测 | 🧪 |

**setup 第 4 步**：如果你选 Cursor / Gemini CLI，setup 会在主目录先装好但不建软链，让你跑一次 agent 问"列出你看到的全部 skill"——识别到就不建软链，识别不到自动建软链。结果写入 env 的 `NEED_SYMLINK`。

## 日常命令

| 命令 | 做什么 | 何时用 |
|------|------|------|
| `/caiyizou-skill-hub setup` | 一键搭建整套体系 | 第一次使用本 skill |
| `/caiyizou-skill-hub install <name>` | 安装第三方 Skill 并归档 | 拿到新 Skill 想安装时 |
| `/caiyizou-skill-hub create <name>` | 创建新 Skill 并归档 | 自己写新 Skill 时 |
| `/caiyizou-skill-hub archive <name>` | 补归档已有 Skill 到飞书表格 | 漏归档、想补归档 |
| `/caiyizou-skill-hub list` | 列出当前所有 Skill 及归档状态 | 不知道装过哪些时 |

## 发布到 GitHub / 分享给别人之前 — 必走清理流程

**当用户说"发布/分享/上传/给朋友用"时，agent 必须先跑：**

```bash
bash scripts/pre-publish-clean.sh <skill-directory>
```

脚本会自动扫描目录里的所有 `.sh` / `.md` / `.json` 文件，找出硬编码的：
- 飞书 base-token / table-id / wiki URL
- 飞书租户标识（`nllsgu6nwe.feishu.cn` 等）
- 邮箱 / 个人绝对路径 / API key

agent 根据报告把所有 `⚠️` 项替换为：
1. 优先：环境变量（从 `~/.config/caiyizou-skill-hub/env` 读）
2. 次之：占位符（`YOUR_BASE_TOKEN_HERE` 等）
3. 最后：setup 时由用户填入

**清完后再 `git push`**——不要把个人 token 推到 GitHub。

## 标准化流程（任何 Skill 安装/创建都自动跑）

### 模板与父 wiki 分流（用户在 setup 时提供）

setup 第 3 步会把 skill 内嵌的 `templates/*.md` 自动 cp 到 `~/.claude/templates/`：

| 场景 | 模板（setup 自动 cp 到本地） | 父 wiki（在 setup 时配置） |
|------|------|------------------------------|
| **自创 Skill** | `~/.claude/templates/skill-guide-create.md` | setup 时填 URL，agent 自动解析 |
| **安装 Skill** | `~/.claude/templates/skill-guide-install.md` | setup 时填 URL，agent 自动解析 |

### 顺序：先建指南 → 一次性归档（零回填）

1. 读取对应场景的模板（`~/.claude/templates/skill-guide-{create,install}.md`）
2. 用 `lark-cli wiki +node-create --parent-node-token <CREATE|INSTALL>_WIKI_NODE` 建子文档
3. 用 `lark-cli docs +update --content @/tmp/<name>-guide.md --doc-format markdown` 写内容
4. 如飞书表格无「使用指南」列，用 `lark-cli base +field-create` 新增
5. 用 `lark-cli base +record-batch-create` 一次性归档（**带「使用指南」URL**）
6. **同名保护**：已存在同名记录时弹 3 选 1（更新现有 / 创建副本 / 取消）

## 飞书配置（setup 时填，不硬编码）

setup 时用户只填**飞书链接**（URL），agent 自动识别类型并解析 token：

| 用户给 | agent 解析 |
|---------|-----------|
| `/base/<token>?table=tblXXX` 表格链接 | `lark-cli base +url-resolve` → base-token + table-id |
| `/wiki/<token>` 嵌入式表格 | `lark-cli wiki +url-resolve` → `+node-get` → obj_token → `base +table-list` 拿 table-id |
| `/wiki/<node_token>` 普通 wiki 节点 | `lark-cli wiki +url-resolve` → node-token |

**禁止**在 setup 阶段直接问用户要 base-token / table-id / node-token（这些是 agent 的工作）。

## 存放位置规范（强制）

所有 Skill 必须装到 `~/.agents/skills/<name>/`，根据 agent 决定是否建软链（看上表）：

```
~/.agents/skills/
├── caiyizou-skill-hub/             ← 所有 skill 唯一源目录
└── ...

~/.claude/skills/        (Claude Code：必须软链在这里)
  └── caiyizou-skill-hub -> ../.agents/skills/caiyizou-skill-hub

~/.codex/skills/         (Codex：无需软链，可选备用)
~/.cursor/skills/        (Cursor：实测决定)
~/.gemini/skills/        (Gemini CLI：实测决定)
```

**禁止**直接把 skill 写到 `~/.claude/skills/` 等单 agent 目录（其他 Agent 读不到）。

## 同名覆盖 3 选 1（强制）

setup 写 rules / archive 写表格时，碰到已存在的同名 → **必须**弹 3 选 1，不能默默覆盖：

1. 备份现有 → 再覆盖（默认）
2. 创建副本（rename）
3. 取消

## 内置脚本

| 脚本 | 用途 |
|------|------|
| `scripts/setup.sh` | 交互式搭建（含实测 agent 兼容性 / 双 URL 解析 / 同名保护 / 引导装 lark-cli） |
| `scripts/archive.sh` | 把 Skill 归档到飞书表格（同名保护 + jq 拼 JSON + update 路径） |
| `scripts/add-field.sh` | 给飞书表格添加字段（从环境变量读 base-token/table-id） |
| `scripts/pre-publish-clean.sh` | 发布前自动扫描个人配置 |
| `templates/skill-guide-create.md` | 自创 Skill 使用指南模板（setup 自动 cp 到本地） |
| `templates/skill-guide-install.md` | 安装 Skill 使用指南模板（setup 自动 cp 到本地） |

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
git clone https://github.com/caiyizou/caiyizou-skill-hub.git ~/.agents/skills/caiyizou-skill-hub
# 按你 agent 类型决定是否建软链（见上面的实测表）
# Claude Code 必须、Codex 不需要、Cursor/Gemini 实测
```

## 不适用场景

- 公司有现成的 Skill 管理平台 → 用公司的，不要重复造轮子
- 只想管理一两个 Skill → 直接手动装就行，不需要这个体系
- 不使用飞书 → 跳过飞书相关步骤，只用本地 rules
