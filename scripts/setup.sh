#!/usr/bin/env bash
# caiyizou-skill-hub 一键搭建脚本（交互式）
# 用法：bash setup.sh
# 不硬编码任何个人配置——所有飞书信息通过 URL 由用户填入，agent 用 lark-cli 解析

set -e

SKILL_NAME="caiyizou-skill-hub"
AGENTS_DIR="$HOME/.agents/skills"
CONFIG_DIR="$HOME/.config/caiyizou-skill-hub"
ENV_FILE="$CONFIG_DIR/env"

echo "🚀 搭建 caiyizou-skill-hub 体系"
echo ""

# 1. 询问 agent 类型
echo "1️⃣ 你用的是什么 AI agent 工具？"
echo "   1) Claude Code   (默认路径: ~/.claude/skills/)"
echo "   2) Codex         (默认路径: ~/.codex/skills/)"
echo "   3) Cursor        (默认路径: ~/.cursor/skills/)"
echo "   4) Gemini CLI    (默认路径: ~/.gemini/skills/)"
echo "   5) 其他（手动输入路径）"
read -p "   请选择 [1-5]（默认 1）: " agent_choice
agent_choice="${agent_choice:-1}"

case "$agent_choice" in
    1) AGENT_NAME="Claude Code"; AGENT_SKILLS_DIR="$HOME/.claude/skills" ;;
    2) AGENT_NAME="Codex";       AGENT_SKILLS_DIR="$HOME/.codex/skills" ;;
    3) AGENT_NAME="Cursor";      AGENT_SKILLS_DIR="$HOME/.cursor/skills" ;;
    4) AGENT_NAME="Gemini CLI";  AGENT_SKILLS_DIR="$HOME/.gemini/skills" ;;
    5) read -p "   请输入 agent skills 目录的完整路径: " AGENT_SKILLS_DIR; AGENT_NAME="自定义" ;;
    *) echo "   ⚠️ 无效选择，使用默认 Claude Code"; AGENT_NAME="Claude Code"; AGENT_SKILLS_DIR="$HOME/.claude/skills" ;;
esac

echo "   ✓ 选择: $AGENT_NAME → $AGENT_SKILLS_DIR"

# 2. 检查必备目录
echo ""
echo "2️⃣ 检查目录结构..."
mkdir -p "$AGENTS_DIR" "$AGENT_SKILLS_DIR" \
         "$HOME/.claude/rules" "$HOME/.claude/templates" "$CONFIG_DIR"

# 3. 检查/补建软链
echo ""
echo "3️⃣ 检查软链..."
if [ ! -e "$AGENT_SKILLS_DIR/$SKILL_NAME" ]; then
    ln -s "$AGENTS_DIR/$SKILL_NAME" "$AGENT_SKILLS_DIR/$SKILL_NAME"
    echo "   ✅ 已创建软链：$AGENT_SKILLS_DIR/$SKILL_NAME"
else
    echo "   ✓ 软链已存在"
fi

# 4. 飞书表格配置（交互式）
echo ""
echo "4️⃣ 飞书技能库表格配置"
echo "   请提供你的飞书表格链接（不是 base-token）"
echo "   格式类似: https://<tenant>.feishu.cn/base/<bascnXXX>?table=tblXXX"
echo "   或 wiki 链接: https://<tenant>.feishu.cn/wiki/<wikitoken>"
read -p "   飞书表格 URL（直接回车跳过飞书配置）: " feishu_table_url

if [ -z "$feishu_table_url" ]; then
    echo "   ⚠️ 跳过飞书配置，仅启用本地 rules"
    BASE_TOKEN=""
    TABLE_ID=""
else
    if ! command -v lark-cli >/dev/null 2>&1; then
        echo "   ⚠️ lark-cli 未安装，无法解析 URL。请先安装 lark-cli 并完成 lark-cli auth login。"
        BASE_TOKEN=""
        TABLE_ID=""
    else
        # 用 lark-cli 自动解析
        echo "   解析 URL..."
        resolved=$(lark-cli base +url-resolve --url "$feishu_table_url" --format json 2>/dev/null || echo "")
        BASE_TOKEN=$(echo "$resolved" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('base_token',''))" 2>/dev/null || echo "")
        TABLE_ID=$(echo "$resolved" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('table_id',''))" 2>/dev/null || echo "")
        if [ -z "$BASE_TOKEN" ] || [ -z "$TABLE_ID" ]; then
            echo "   ⚠️ 自动解析失败，请手动输入"
            read -p "   Base Token: " BASE_TOKEN
            read -p "   Table ID:  " TABLE_ID
        else
            echo "   ✅ 已解析：base-token=${BASE_TOKEN:0:8}... table-id=$TABLE_ID"
        fi
    fi
fi

# 5. 父 wiki 配置
echo ""
echo "5️⃣ 父 wiki 节点配置（用于生成小白使用指南）"
read -p "   「创建类」父 wiki URL（直接回车跳过）: " create_wiki_url
read -p "   「安装类」父 wiki URL（直接回车跳过）: " install_wiki_url

CREATE_WIKI_NODE=""
INSTALL_WIKI_NODE=""
if [ -n "$create_wiki_url" ] && command -v lark-cli >/dev/null 2>&1; then
    CREATE_WIKI_NODE=$(lark-cli wiki +url-resolve --url "$create_wiki_url" --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('node_token',''))" 2>/dev/null || echo "")
fi
if [ -n "$install_wiki_url" ] && command -v lark-cli >/dev/null 2>&1; then
    INSTALL_WIKI_NODE=$(lark-cli wiki +url-resolve --url "$install_wiki_url" --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('node_token',''))" 2>/dev/null || echo "")
fi

# 6. 写环境变量文件
echo ""
echo "6️⃣ 写入配置..."
cat > "$ENV_FILE" <<ENV_EOF
# caiyizou-skill-hub 配置（setup 时生成，请勿手动编辑）
export CAIYIZOU_AGENT_NAME="$AGENT_NAME"
export CAIYIZOU_AGENT_SKILLS_DIR="$AGENT_SKILLS_DIR"
export CAIYIZOU_BASE_TOKEN="$BASE_TOKEN"
export CAIYIZOU_TABLE_ID="$TABLE_ID"
export CAIYIZOU_CREATE_WIKI_NODE="$CREATE_WIKI_NODE"
export CAIYIZOU_INSTALL_WIKI_NODE="$INSTALL_WIKI_NODE"
export CAIYIZOU_CREATE_WIKI_URL="$create_wiki_url"
export CAIYIZOU_INSTALL_WIKI_URL="$install_wiki_url"
export CAIYIZOU_TABLE_URL="$feishu_table_url"
ENV_EOF
chmod 600 "$ENV_FILE"
echo "   ✅ 配置已写入：$ENV_FILE"

# 7. 写全局 rules 文件
echo ""
echo "7️⃣ 写入全局规则文件..."
RULES_FILE="$HOME/.claude/rules/skill-creation-workflow.md"
cat > "$RULES_FILE" <<RULES_EOF
# Skill 创建工作规范（由 caiyizou-skill-hub setup 生成于 $(date +%Y-%m-%d)）

## 当前配置

| 字段 | 值 |
|------|----|
| Agent | $AGENT_NAME |
| Agent Skills 目录 | $AGENT_SKILLS_DIR |
| 飞书表格 URL | ${feishu_table_url:-（未配置）} |
| 飞书表格 base-token | ${BASE_TOKEN:-（未配置）} |
| 飞书表格 table-id | ${TABLE_ID:-（未配置）} |
| 创建类父 wiki | ${create_wiki_url:-（未配置）} |
| 安装类父 wiki | ${install_wiki_url:-（未配置）} |

> **重要**：所有 token 配置从 \`$ENV_FILE\` 读取，不要在 rules 文件中硬编码。

## 存放位置规则

所有 skill 必须装到 \`~/.agents/skills/<name>/\`，并在当前 agent 的 skills 目录建软链：

\`\`\`bash
mkdir -p ~/.agents/skills/<name>
ln -s ~/.agents/skills/<name> $AGENT_SKILLS_DIR/<name>
\`\`\`

**禁止**直接写入 agent skills 目录（其他 Agent 读不到）。

## 分享/公开/发布 skill 时的清理流程

**当用户说"分享"、"公开"、"发布"、"给别人用"时，必须先清理所有个人配置：**

1. 扫描 skill 目录中所有 \`.sh\` / \`.md\` / \`.json\` 文件
2. 找出硬编码的：飞书 base-token / table-id / wiki URL / 邮箱 / 个人路径 / API key
3. 全部替换为：
   - 环境变量（从 \`~/.config/caiyizou-skill-hub/env\` 读取）
   - 占位符（如 \`YOUR_BASE_TOKEN_HERE\`）
   - 或在 setup 时由用户填入
4. **禁止**问用户要 base-token / table-id / node-token——只问飞书 URL

## Agent 适配

setup 时询问用户用什么 agent 工具，根据回答决定软链路径：
- Claude Code → \`~/.claude/skills/\`
- Codex → \`~/.codex/skills/\`
- Cursor → \`~/.cursor/skills/\`
- Gemini CLI → \`~/.gemini/skills/\`
- 其他 → 询问用户

## 创建/安装后必须归档 + 生成小白使用指南

### 顺序：先建指南 → 一次性归档（零回填）

1. 读取对应场景的模板（\`~/.claude/templates/skill-guide-{create,install}.md\`）
2. 用 \`lark-cli wiki +node-create --parent-node-token \$CAIYIZOU_{CREATE,INSTALL}_WIKI_NODE\` 在对应父 wiki 下创建子文档
3. \`lark-cli docs +update\` 写入指南内容（markdown 模式）
4. 飞书表格如无「使用指南」列，\`lark-cli base +field-create\` 新增
5. \`lark-cli base +record-batch-create\` 一次性归档，**带上「使用指南」URL**

### 加载环境变量

\`\`\`bash
source \$HOME/.config/caiyizou-skill-hub/env
\`\`\`

archive 时用 \$CAIYIZOU_BASE_TOKEN / \$CAIYIZOU_TABLE_ID 替换硬编码。
RULES_EOF
echo "   ✅ Rules 已写入：$RULES_FILE"

# 8. 检查 lark-cli
echo ""
echo "8️⃣ 检查 lark-cli..."
if ! command -v lark-cli >/dev/null 2>&1; then
    echo "   ⚠️ lark-cli 未安装，归档到飞书的功能将不可用"
    echo "   安装方式：brew install lark-cli"
else
    echo "   ✓ lark-cli 已安装：$(lark-cli --version 2>&1 | head -1)"
fi

echo ""
echo "✨ 搭建完成！"
echo ""
echo "📋 当前配置:"
echo "   Agent: $AGENT_NAME"
echo "   飞书表格: ${feishu_table_url:-未配置（仅本地模式）}"
echo "   配置文件: $ENV_FILE"
echo ""
echo "下一步："
echo "  - 安装 Skill：/caiyizou-skill-hub install <name>"
echo "  - 创建 Skill：/caiyizou-skill-hub create <name>"
echo "  - 查看列表：/caiyizou-skill-hub list"
echo ""
echo "🔁 以后任何 agent 脚本调用 archive/add-field 前，记得先:"
echo "   source $ENV_FILE"
