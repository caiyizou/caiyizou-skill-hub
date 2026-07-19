# caiyizou-skill-hub

一站式 Skill 管理体系。让任何 AI agent（Claude Code / Codex / Cursor / Gemini CLI）一键搭建完整的 Skill 安装/创建/归档/分发流程。

## ✨ 功能

- **一键 setup**：交互式询问你的 agent 类型 + 飞书配置，自动建好整套体系
- **多 Agent 适配**：支持 Claude Code / Codex / Cursor / Gemini CLI，软链路径自动选
- **标准化流程**：装 Skill → 建小白指南 → 一次性归档到飞书表格（零回填）
- **零硬编码**：所有飞书 token / wiki URL 都在 setup 时由用户填入，可分发给别人

## 🚀 安装

```bash
# 方式 1：RedSkill 商店
redskill install caiyizou-skill-hub

# 方式 2：npx skills（跨 Agent）
npx skills add https://github.com/caiyizou/caiyizou-skill-hub

# 方式 3：手动
git clone https://github.com/caiyizou/caiyizou-skill-hub.git ~/.agents/skills/caiyizou-skill-hub
ln -s ~/.agents/skills/caiyizou-skill-hub ~/.claude/skills/caiyizou-skill-hub
```

## 🛠️ 使用

```bash
/caiyizou-skill-hub setup        # 一键搭建
/caiyizou-skill-hub install <n>  # 安装并归档
/caiyizou-skill-hub create <n>   # 创建并归档
/caiyizou-skill-hub archive <n>  # 补归档
/caiyizou-skill-hub list         # 列出所有
```

## 📦 文件结构

```
caiyizou-skill-hub/
├── SKILL.md                # Skill 定义
├── README.md               # 本文件
└── scripts/
    ├── setup.sh            # 交互式搭建脚本
    ├── archive.sh          # 飞书归档脚本（从 env 读配置）
    └── add-field.sh        # 飞书加字段脚本（从 env 读配置）
```

## 🔐 配置

setup 时所有配置写入 `~/.config/caiyizou-skill-hub/env`：

| 变量 | 说明 |
|------|------|
| `CAIYIZOU_AGENT_NAME` | 你用的 agent（Claude Code / Codex / ...） |
| `CAIYIZOU_AGENT_SKILLS_DIR` | agent 的 skills 目录 |
| `CAIYIZOU_BASE_TOKEN` | 飞书表格 base-token |
| `CAIYIZOU_TABLE_ID` | 飞书表格 table-id |
| `CAIYIZOU_CREATE_WIKI_NODE` | 「创建类」父 wiki node-token |
| `CAIYIZOU_INSTALL_WIKI_NODE` | 「安装类」父 wiki node-token |
| `CAIYIZOU_TABLE_URL` | 飞书表格 URL（供 UI 显示） |

## 📄 License

MIT
