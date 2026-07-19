---
name: caiyizou-skill-hub
version: 1.5.0
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
3. **你之后装/创建 skill 时生的小白使用指南，分别放飞书哪两份文档下面？** → agent 自动解析出 node-token
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
| `/caiyizou-skill-hub uninstall` | 卸载本体系（删软链/主目录/config/rules/模板） | 不想用了时 |

### 卸载细节

```bash
bash ~/.agents/skills/caiyizou-skill-hub/scripts/uninstall.sh                    # 全删
bash ~/.agents/skills/caiyizou-skill-hub/scripts/uninstall.sh --keep-config       # 保留飞书配置
bash ~/.agents/skills/caiyizou-skill-hub/scripts/uninstall.sh --keep-rules        # 保留全局 rules
bash ~/.agents/skills/caiyizou-skill-hub/scripts/uninstall.sh --keep-templates    # 保留使用指南模板
```

卸载 rules 前会自动 `cp` 备份到 `*.pre-uninstall.<timestamp>` 防误删。

## 🔧 命令 → 动作映射（agent 怎么执行每个命令）

用户跟 AI agent 说上面任何一条命令时，agent 必须**严格按下面流程**执行，不能让用户多说话：

### `/caiyizou-skill-hub setup`

```bash
bash ~/.agents/skills/caiyizou-skill-hub/scripts/setup.sh
```

setup.sh 会自动问 3 个问题、写 env、写 rules。详见上文"一键搭建"段。

### `/caiyizou-skill-hub install <name>`

1. `mkdir -p ~/.agents/skills/<name>`
2. 拉取 skill：
   - GitHub：`git clone https://github.com/<owner>/<name>.git ~/.agents/skills/<name>`
   - RedSkill：`redskill install <name>`（自动处理）
3. 建立软链（如你的 agent 需要，参考跨 Agent 实测表）
4. **模板预处理**（强制步骤，否则飞书文档会有占位符和附录）：
   ```bash
   # 读模板 + 填充占位符 + 删附录段 + 删 HTML 注释
   python3 -c "
   import re, sys
   from string import Template
   tpl_path = '$HOME/.claude/templates/skill-guide-install.md'
   values = {'skill-name': '<name>', 'version': '1.0.0', 'category': '开发工具',
             'created': '$(date +%Y-%m-%d)', 'updated': '$(date +%Y-%m-%d)',
             'skill-command': '<name>', 'current-version': '1.0.0',
             '功能分类': '开发工具', '分类': '开发工具'}
   with open(tpl_path) as f: content = f.read()
   # 占位符替换（{xxx} 形式 + 中文键名）
   for k, v in values.items():
       content = content.replace('{' + k + '}', v)
   # 删除 HTML 注释（<!-- ... -->）
   content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
   # 删除「附录：章节更新方式速查」段（模板自带的最后一段）
   content = re.sub(r'\n## 📚 附录.*$', '', content, flags=re.DOTALL)
   with open('/tmp/<name>-guide-final.md', 'w') as f: f.write(content)
   "
   ```
5. 跑下面"标准化流程 § 顺序"里的 6 步（用 `/tmp/<name>-guide-final.md` 而非模板原文）

### `/caiyizou-skill-hub create <name>`

1. `mkdir -p ~/.agents/skills/<name>`
2. **写 `~/.agents/skills/<name>/SKILL.md`** —— frontmatter 必备：
   ```markdown
   ---
   name: <name>
   description: 一句话说明这个 skill 做什么 + 何时用（"Use when..."）
   ---
   ```
   建议长度 80-200 行，含「设计原则 / 命令 / 命令→动作映射 / 内置脚本」段
3. 建软链（如需要）
4. **模板预处理**（同 install 步骤 4，用 create 模板）
5. 跑"标准化流程 § 顺序"里的 6 步（生成使用指南 + 归档）

### `/caiyizou-skill-hub archive <name>`

```bash
source ~/.config/caiyizou-skill-hub/env  # 必须 source，否则 token 为空
bash ~/.agents/skills/caiyizou-skill-hub/scripts/archive.sh <name> <version> <category> 自制 "" <guide-url>
```

或更简单：跑"标准化流程"§ 步骤 2-6（生成 / 写 / 归档）

### `/caiyizou-skill-hub list`

```bash
ls -la ~/.agents/skills/   # 本地已装 skill
lark-cli base +record-list --base-token "$CAIYIZOU_BASE_TOKEN" --table-id "$CAIYIZOU_TABLE_ID"   # 飞书已归档 skill
```

agent 交叉对比，给用户两栏：本地 vs 飞书已归档，标出"已装未归档"。



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

| 场景 | 模板（setup 自动 cp 到本地） | 使用指南存放文档（在 setup 时配置） |
|------|------|------------------------------|
| **自创 Skill** | `~/.claude/templates/skill-guide-create.md` | setup 时填飞书文档 URL，agent 自动解析为 node-token |
| **安装 Skill** | `~/.claude/templates/skill-guide-install.md` | setup 时填飞书文档 URL，agent 自动解析为 node-token |

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
| `scripts/pre-publish-clean.sh` | 发布前自动扫描个人配置（支持 --apply 自动替换） |
| `scripts/uninstall.sh` | 卸载脚本（支持 --keep-config / --keep-rules / --keep-templates） |
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

# 方式 3：手动（克隆完只需按你 agent 建 1 条软链，不要脏建 4 个目录）
git clone https://github.com/caiyizou/caiyizou-skill-hub.git ~/.agents/skills/caiyizou-skill-hub

# Claude Code（必须软链）：
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.claude/skills/caiyizou-skill-hub

# Codex（无需软链，直接读 ~/.agents/skills/）：
echo "无需操作"

# Cursor / Gemini CLI（先实测，按结果决定）：
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.cursor/skills/caiyizou-skill-hub
# 或
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.gemini/skills/caiyizou-skill-hub
```

## 🍴 Fork 后必改

如果你 fork 了本仓库再发到自己的 GitHub，记得全局替换：

| 占位符 | 你的值 |
|--------|--------|
| `https://github.com/caiyizou/caiyizou-skill-hub` | 你 fork 后的仓库 URL |
| `Caiyi zou <caiyizou@...>` (commit author) | 你的 git config user.name + user.email |
| skill 名称 `caiyizou-skill-hub` | 你自己的 skill 名（建议 `xxx-skill-hub` 之类） |

最简单：用 VSCode / Cursor 全局搜索替换 `caiyizou` 为你的标识符。

## 不适用场景

## 不适用场景

- 公司有现成的 Skill 管理平台 → 用公司的，不要重复造轮子
- 只想管理一两个 Skill → 直接手动装就行，不需要这个体系
- 不使用飞书 → 跳过飞书相关步骤，只用本地 rules

---

## 🐛 已知边界

| 项 | 现状 | 绕开方式 |
|----|------|---------|
| lark-cli 不同版本 `+url-resolve` 返回结构可能不同 | setup 内部用 python + 异常兜底 | 升级 lark-cli 后跑一次 setup 校验 |
| 飞书表格不在 wiki 嵌入时 | setup 第 4 步走 base 路径 | 拿 base URL 而不是 wiki URL |
| Cursor / Gemini CLI 是否识别 `~/.agents/skills/` | setup 第 4 步让你实测 | 实测结果决定要不要软链 |
| 同一父 wiki 下大规模新建子文档 | 飞书 API 限频 | 慢点跑 + 多脚本时分批 |
