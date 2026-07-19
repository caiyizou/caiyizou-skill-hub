# caiyizou-skill-hub

一站式 Skill 管理体系。让任何 AI agent（Claude Code / Codex / Cursor / Gemini CLI）一键搭建完整的 Skill 安装/创建/归档/分发流程。

---

## 🚀 快速开始（5 步搞定）

| 步骤 | 你做什么 |
|------|---------|
| 1️⃣ | 选一种安装方式装这个 skill（下面 §安装 列了 3 选 1） |
| 2️⃣ | 让 AI agent 跑 `/caiyizou-skill-hub setup` |
| 3️⃣ | setup 会问你 3 个问题：用什么 agent？飞书表格链接在哪？你想把使用指南放飞书哪两份文档下？ |
| 4️⃣ | setup 自动建好软链 + 写配置 + 写全局 rules |
| 5️⃣ | 之后你跟 AI agent 说「帮我装 xxx skill」或「帮我建个叫 xxx 的新 skill」 → agent 自动跑下面的 install/create 流程（建使用指南 + 归档飞书表格） |

详细命令见 §使用。

---

## 📦 安装

3 种方式任选一种。前置依赖各不同：

```bash
# 方式 1：RedSkill 商店（推荐）
# 前置：已装 npm（brew install node / 自带）
redskill install caiyizou-skill-hub

# 方式 2：npx skills（跨 Agent）
# 前置：已装 Node.js
npx skills add https://github.com/caiyizou/caiyizou-skill-hub

# 方式 3：手动
# 前置：已装 git
git clone https://github.com/caiyizou/caiyizou-skill-hub.git ~/.agents/skills/caiyizou-skill-hub

# Claude Code（必须软链）：
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.claude/skills/caiyizou-skill-hub

# Codex（无需软链）：
echo "无需操作"

# Cursor / Gemini CLI（先实测，再决定是否建软链）：
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.cursor/skills/caiyizou-skill-hub
# 或
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.gemini/skills/caiyizou-skill-hub
```

> 不确定你 agent 该不该建软链？跑 setup 走流程实测。

---

## 🛠️ 使用

```bash
/caiyizou-skill-hub setup        # 一键搭建
/caiyizou-skill-hub install <n>  # 安装并归档（如：「帮我装一个叫 xxx 的 skill」）
/caiyizou-skill-hub create <n>   # 创建并归档（如：「帮我建一个叫 xxx 的新 skill」）
/caiyizou-skill-hub archive <n>  # 补归档已有 Skill 到飞书表格
/caiyizou-skill-hub list         # 列出所有
/caiyizou-skill-hub doctor       # 自检：检查依赖/env/软链/模板/lark-cli 授权/飞书通达
/caiyizou-skill-hub uninstall    # 卸载本体系
```

---

## ✨ 功能

- **一键 setup**：交互式询问你的 agent 类型 + 飞书配置，自动建好整套体系
- **多 Agent 适配**：支持 Claude Code / Codex / Cursor / Gemini CLI，软链路径自动选
- **标准化流程**：装 Skill → 建小白使用指南 → 一次性归档到飞书表格（零回填）
- **零硬编码**：所有飞书 token / wiki URL 都在 setup 时由用户填入，可分发给别人

---

## 📁 文件结构

```
caiyizou-skill-hub/
├── SKILL.md                     # Skill 定义（给 AI agent 看）
├── README.md                    # 本文件（GitHub 用户看）
├── scripts/
│   ├── setup.sh                 # 交互式搭建
│   ├── archive.sh               # 飞书归档
│   ├── add-field.sh             # 加飞书字段
│   ├── pre-publish-clean.sh     # 发布前清理
│   └── uninstall.sh             # 卸载
└── templates/
    ├── skill-guide-create.md    # 自创 Skill 使用指南模板
    └── skill-guide-install.md   # 安装 Skill 使用指南模板
```

---

## 🔐 配置

setup 时所有配置写入 `~/.config/caiyizou-skill-hub/env`：

| 变量 | 说明 |
|------|------|
| `CAIYIZOU_AGENT_NAME` | 你用的 agent（Claude Code / Codex / ...） |
| `CAIYIZOU_AGENT_SKILLS_DIR` | agent 的 skills 目录 |
| `CAIYIZOU_BASE_TOKEN` | 飞书表格 base-token |
| `CAIYIZOU_TABLE_ID` | 飞书表格 table-id |
| `CAIYIZOU_CREATE_WIKI_NODE` | 「创建类」使用指南放哪份飞书文档 |
| `CAIYIZOU_INSTALL_WIKI_NODE` | 「安装类」使用指南放哪份飞书文档 |
| `CAIYIZOU_TABLE_URL` | 飞书表格 URL |

---

## 🩺 Troubleshooting — 出问题先跑这个

```bash
bash ~/.agents/skills/caiyizou-skill-hub/scripts/doctor.sh
```

会依次检查：依赖（python3 / jq / lark-cli / git）→ env 配置 → 软链 → 模板 → lark-cli 授权 → 飞书表格可达 → 父 wiki 通达。任意 ❌ 会给出修复建议。

### 常见问题速查

| 问题 | 解决 |
|------|------|
| `command not found: lark-cli` | `brew install lark-cli` 或 `npm i -g @larksuite/cli` |
| `command not found: jq` | `brew install jq` |
| setup 写 env 失败 / Permission denied | `chmod 700 ~/.config/caiyizou-skill-hub && touch ~/.config/caiyizou-skill-hub/env && chmod 600 ~/.config/caiyizou-skill-hub/env` |
| archive 报「飞书表格无该字段」 | 字段名走别名兼容（功能分类↔分类↔category 等）；改你表格里的字段名也行 |
| agent 找不到我装的 skill | doctor 看「软链」段；Claude Code 必须软链到 `~/.claude/skills/`，Codex 直接读 `~/.agents/skills/` |
| 飞书表格写入部分字段没生效 | doctor 看「飞书表格」段；用 `lark-cli base +field-list` 看你的表格实际字段名 |
| Skill hub 的 SKILL.md 改了不生效 | Claude Code：检查软链在不在；Codex：直接重启对话 |
| 模板占位符没替换（旧版 SKILL.md） | 跑 `bash scripts/render-guide.sh <create|install> <name> <ver> <cat>` 手动渲染 |

---

## 🍴 Fork 后必改

| 占位符 | 替换为 |
|--------|--------|
| `https://github.com/caiyizou/caiyizou-skill-hub` | 你 fork 后的仓库 URL |
| `Caiyi zou <caiyizou@...>` | 你的 git config user.name + user.email |
| skill 名称 `caiyizou-skill-hub` | 你的标识符 |

最简单：VSCode/Cursor 全局搜索 `caiyizou` 替换。

---

## 📄 License

MIT