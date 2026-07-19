#!/usr/bin/env bash
# caiyizou-skill-hub 一键搭建脚本（v1.2 交互式）
# 用法：bash setup.sh
# 不硬编码任何个人配置——所有飞书信息通过 URL 由用户填入，agent 用 lark-cli 解析

set -e

SKILL_NAME="caiyizou-skill-hub"
AGENTS_DIR="$HOME/.agents/skills"
CONFIG_DIR="$HOME/.config/caiyizou-skill-hub"
ENV_FILE="$CONFIG_DIR/env"

echo "🚀 搭建 caiyizou-skill-hub 体系"
echo ""

# ===== 工具函数：同名文件处理（备份覆盖 / 创建副本 / 取消）=====
write_with_protect() {
    local target_file="$1"
    local payload="$2"

    if [ ! -f "$target_file" ]; then
        printf '%s' "$payload" > "$target_file"
        echo "   ✅ 已写入：$target_file"
        return 0
    fi

    echo ""
    echo "   ⚠️  已存在：$target_file"
    echo "   当前模式："
    echo "     1) 备份现有 → 再覆盖（推荐，安全）"
    echo "     2) 创建副本（rename，不动原文件）"
    echo "     3) 取消（保留现有）"
    read -p "   选择 [1-3]（默认 1）: " protect_choice
    protect_choice="${protect_choice:-1}"
    echo ""

    case "$protect_choice" in
        1)
            local backup="${target_file}.bak.$(date +%Y%m%d-%H%M%S)"
            cp "$target_file" "$backup"
            printf '%s' "$payload" > "$target_file"
            echo "   📦 已备份 → $backup"
            echo "   ✅ 已覆盖：$target_file"
            ;;
        2)
            local stamp
            stamp=$(date +%H%M%S)
            local new_file="${target_file%.*}-${stamp}.${target_file##*.}"
            printf '%s' "$payload" > "$new_file"
            echo "   ✅ 已创建副本：$new_file"
            ;;
        *)
            echo "   ⏭️  跳过（保留现有）"
            ;;
    esac
}

# ===== 工具函数：智能解析飞书 URL（自动识别 base 或 wiki 链接）=====
resolve_feishu_url() {
    local url="$1"
    local type_hint="$2"   # "table" / "wiki"

    if [ -z "$url" ]; then
        return 1
    fi

    if [[ "$url" == *"/base/"* ]]; then
        # base 链接 → 用 base +url-resolve
        local resolved
        resolved=$(lark-cli base +url-resolve --url "$url" --format json 2>/dev/null || echo "")
        if [ -n "$resolved" ]; then
            BASE_TOKEN=$(echo "$resolved" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('base_token',''))" 2>/dev/null || echo "")
            TABLE_ID=$(echo "$resolved" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('table_id',''))" 2>/dev/null || echo "")
            if [ -n "$BASE_TOKEN" ] && [ -n "$TABLE_ID" ]; then
                echo "   ✅ base 链接解析成功 → base=${BASE_TOKEN:0:8}... table=$TABLE_ID"
                return 0
            fi
        fi
        echo "   ⚠️ base 链接解析失败，尝试 wiki 兜底..."
    fi

    if [[ "$url" == *"/wiki/"* ]]; then
        # wiki 链接 → 用 wiki +url-resolve 拿 node-token，再用 docs +fetch 拿 obj_token（可能是 base）
        local wiki_resolved
        wiki_resolved=$(lark-cli wiki +url-resolve --url "$url" --format json 2>/dev/null || echo "")
        if [ -n "$wiki_resolved" ]; then
            local node_token
            node_token=$(echo "$wiki_resolved" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('node_token',''))" 2>/dev/null || echo "")
            if [ -n "$node_token" ]; then
                # 尝试找 base-token（如果 wiki 节点是 base 类型）
                local meta
                meta=$(lark-cli wiki +node-get --node-token "$node_token" --format json 2>/dev/null || echo "")
                if [ -n "$meta" ]; then
                    BASE_TOKEN=$(echo "$meta" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('obj_token',''))" 2>/dev/null || echo "")
                fi
                if [ -n "$BASE_TOKEN" ]; then
                    # 找到 base-token 后再 list tables
                    local tables
                    tables=$(lark-cli base +table-list --base-token "$BASE_TOKEN" --format json 2>/dev/null || echo "")
                    TABLE_ID=$(echo "$tables" | python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('data',{}).get('items',[]); print(items[0].get('table_id','') if items else '')" 2>/dev/null || echo "")
                    if [ -n "$TABLE_ID" ]; then
                        echo "   ✅ wiki 链接解析成功（从 wiki → base 跳转） → base=${BASE_TOKEN:0:8}... table=$TABLE_ID"
                        return 0
                    fi
                fi
                # wiki 节点可能就是 wiki doc（存为 WIKI_NODE 给后续 wiki +node-create 的 parent 用）
                if [ "$type_hint" = "wiki" ]; then
                    WIKI_NODE="$node_token"
                    echo "   ✅ wiki 节点解析成功 → node=${WIKI_NODE:0:8}..."
                    return 0
                fi
            fi
        fi
    fi

    echo "   ❌ 自动解析失败。请手动填入。"
    return 1
}

# =================== 1. 选择 agent 类型 ===================
echo "1️⃣  你用的是什么 AI agent 工具？"
echo "   1) Claude Code   (默认路径: ~/.claude/skills/)"
echo "   2) Codex         (默认路径: ~/.codex/skills/)    — ✅ 已知直接识别 ~/.agents/skills/，无需软链"
echo "   3) Cursor        (默认路径: ~/.cursor/skills/)   — ❓ 未实测，setup 会实测"
echo "   4) Gemini CLI    (默认路径: ~/.gemini/skills/)   — ❓ 未实测，setup 会实测"
echo "   5) 其他（手动输入路径）"
read -p "   请选择 [1-5]（默认 1）: " agent_choice
agent_choice="${agent_choice:-1}"

case "$agent_choice" in
    1) AGENT_NAME="Claude Code"; AGENT_SKILLS_DIR="$HOME/.claude/skills"; NEED_SYMLINK="yes" ;;
    2) AGENT_NAME="Codex";       AGENT_SKILLS_DIR="$HOME/.codex/skills"; NEED_SYMLINK="no" ;;
    3) AGENT_NAME="Cursor";      AGENT_SKILLS_DIR="$HOME/.cursor/skills"; NEED_SYMLINK="unknown" ;;
    4) AGENT_NAME="Gemini CLI";  AGENT_SKILLS_DIR="$HOME/.gemini/skills"; NEED_SYMLINK="unknown" ;;
    5) read -p "   请输入 agent skills 目录的完整路径: " AGENT_SKILLS_DIR; AGENT_NAME="自定义"; NEED_SYMLINK="yes" ;;
    *) echo "   ⚠️ 无效选择，使用默认 Claude Code"; AGENT_NAME="Claude Code"; AGENT_SKILLS_DIR="$HOME/.claude/skills"; NEED_SYMLINK="yes" ;;
esac

echo "   ✓ 选择: $AGENT_NAME → $AGENT_SKILLS_DIR"

# =================== 2. 准备目录 ===================
echo ""
echo "2️⃣  检查目录结构..."
mkdir -p "$AGENTS_DIR" "$AGENT_SKILLS_DIR" \
         "$HOME/.claude/rules" "$HOME/.claude/templates" "$CONFIG_DIR"

# =================== 3. 复制模板到 ~/.claude/templates/ ===================
echo ""
echo "3️⃣  复制指南模板..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/../templates"

if [ -d "$TPL_DIR" ]; then
    if [ -f "$TPL_DIR/skill-guide-create.md" ]; then
        cp "$TPL_DIR/skill-guide-create.md" "$HOME/.claude/templates/skill-guide-create.md"
        echo "   ✅ skill-guide-create.md → ~/.claude/templates/"
    fi
    if [ -f "$TPL_DIR/skill-guide-install.md" ]; then
        cp "$TPL_DIR/skill-guide-install.md" "$HOME/.claude/templates/skill-guide-install.md"
        echo "   ✅ skill-guide-install.md → ~/.claude/templates/"
    fi
else
    echo "   ⚠️ 模板目录不存在：$TPL_DIR（请重新 git pull）"
fi

# =================== 4. 智能建软链（按 agent 类型） ===================
echo ""
echo "4️⃣  建立软链..."

case "$NEED_SYMLINK" in
    "yes")
        if [ ! -e "$AGENT_SKILLS_DIR/$SKILL_NAME" ]; then
            ln -s "$AGENTS_DIR/$SKILL_NAME" "$AGENT_SKILLS_DIR/$SKILL_NAME"
            echo "   ✅ 已建软链 → $AGENT_SKILLS_DIR/$SKILL_NAME"
        else
            echo "   ✓ 软链已存在"
        fi
        ;;
    "no")
        echo "   ✓ $AGENT_NAME 已确认直接识别 ~/.agents/skills/，无需建软链"
        if [ ! -e "$AGENT_SKILLS_DIR/$SKILL_NAME" ]; then
            read -p "   仍然建软链备用？[y/N] " backup_link
            if [[ "$backup_link" =~ ^[Yy]$ ]]; then
                ln -s "$AGENTS_DIR/$SKILL_NAME" "$AGENT_SKILLS_DIR/$SKILL_NAME"
                echo "   ✅ 已建软链（备用）"
            fi
        fi
        ;;
    "unknown")
        echo "   🧪  未确认 $AGENT_NAME 是否识别 ~/.agents/skills/，需要实测"
        echo "   方法：先不建软链，你跑一次 agent，验证它能不能直接看到主目录里的 skill"
        echo "   测试命令（在 agent 对话框里说）："
        echo "     \"列出你看到的全部 skill，包括 caiyizou-skill-hub\""
        echo ""
        read -p "   实测后输入结果（识别得到则填 yes / 否则填 no）: " test_result
        if [[ "$test_result" =~ ^[Yy] ]]; then
            echo "   ✓ $AGENT_NAME 直接识别 ~/.agents/skills/，不建软链"
            NEED_SYMLINK="no"
        else
            echo "   → $AGENT_NAME 需要软链，已为你建立"
            ln -s "$AGENTS_DIR/$SKILL_NAME" "$AGENT_SKILLS_DIR/$SKILL_NAME"
            NEED_SYMLINK="yes"
        fi
        ;;
esac

# =================== 5. 飞书表格配置（双链接自动识别） ===================
echo ""
echo "5️⃣  飞书技能库表格配置"
echo "   请提供你的飞书表格链接（支持 /base/... 或 /wiki/... 两种格式）"
read -p "   飞书表格 URL（直接回车跳过飞书配置）: " feishu_table_url

BASE_TOKEN=""
TABLE_ID=""
if [ -n "$feishu_table_url" ]; then
    if command -v lark-cli >/dev/null 2>&1; then
        if ! resolve_feishu_url "$feishu_table_url" "table"; then
            echo "   ⚠️ 自动解析失败。请手动填入："
            read -p "   Base Token: " BASE_TOKEN
            read -p "   Table ID:  " TABLE_ID
        fi
    else
        echo "   ⚠️ lark-cli 未安装，请先安装"
    fi
fi

if [ -z "$BASE_TOKEN" ] || [ -z "$TABLE_ID" ]; then
    if [ -n "$feishu_table_url" ]; then
        echo "   ⚠️ 跳过飞书归档配置（仅本地 rules 生效）"
    fi
fi

# =================== 6. 使用指南存放位置配置 ===================
echo ""
echo "6️⃣  使用指南存放位置"
echo "   你之后装/创建任何 skill，AI agent 会自动给该 skill 生成一份小白使用指南。"
echo "   你想把这些使用指南放在飞书哪两份文档下面？"
echo "   （粘飞书文档链接即可，回车跳过该类）"
echo ""
read -p "   ⓐ「我自己创建的 skill」使用指南放飞书哪个文档下？(URL/回车跳过): " create_wiki_url
read -p "   ⓑ「我安装的 skill」使用指南放飞书哪个文档下？      (URL/回车跳过): " install_wiki_url

CREATE_WIKI_NODE=""
INSTALL_WIKI_NODE=""
if [ -n "$create_wiki_url" ] && command -v lark-cli >/dev/null 2>&1; then
    WIKI_NODE=""
    if resolve_feishu_url "$create_wiki_url" "wiki"; then
        CREATE_WIKI_NODE="$WIKI_NODE"
        echo "   ✅ ⓐ 配置完成（node=${WIKI_NODE:0:8}...）"
    else
        echo "   ⚠️ ⓐ 配置失败，跳过"
    fi
fi
if [ -n "$install_wiki_url" ] && command -v lark-cli >/dev/null 2>&1; then
    WIKI_NODE=""
    if resolve_feishu_url "$install_wiki_url" "wiki"; then
        INSTALL_WIKI_NODE="$WIKI_NODE"
        echo "   ✅ ⓑ 配置完成（node=${WIKI_NODE:0:8}...）"
    else
        echo "   ⚠️ ⓑ 配置失败，跳过"
    fi
fi

# =================== 7. 写 env 文件 ===================
echo ""
echo "7️⃣  写入配置..."
cat > "$ENV_FILE" <<ENV_EOF
# caiyizou-skill-hub 配置（$(date +%Y-%m-%d) setup 时生成）
export CAIYIZOU_AGENT_NAME="$AGENT_NAME"
export CAIYIZOU_AGENT_SKILLS_DIR="$AGENT_SKILLS_DIR"
export CAIYIZOU_NEED_SYMLINK="$NEED_SYMLINK"
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

# =================== 8. 写全局 rules 文件（同名保护）===================
echo ""
echo "8️⃣  写入全局规则文件..."
RULES_FILE="$HOME/.claude/rules/skill-creation-workflow.md"
RULES_PAYLOAD="# Skill 创建工作规范（由 caiyizou-skill-hub setup 生成于 $(date +%Y-%m-%d)）

## 当前配置

| 字段 | 值 |
|------|----|
| Agent | $AGENT_NAME |
| Agent Skills 目录 | $AGENT_SKILLS_DIR |
| 是否需要软链 | $NEED_SYMLINK |
| 飞书表格 URL | ${feishu_table_url:-（未配置）} |
| 创建类父 wiki | ${create_wiki_url:-（未配置）} |
| 安装类父 wiki | ${install_wiki_url:-（未配置）} |

> 所有 token 从 \`$ENV_FILE\` 读取，不要在 rules 里硬编码。

## 存放位置规则

所有 skill 必须装到 \`~/.agents/skills/<name>/\`，根据当前 agent 类型决定是否建软链：
- Claude Code：必须软链到 \`$AGENT_SKILLS_DIR/<name>\`
- Codex：无需软链，直接识别 ~/.agents/skills/
- Cursor / Gemini CLI：实测决定

\`\`\`bash
mkdir -p ~/.agents/skills/<name>
# Claude Code / Cursor / Gemini：
ln -s ~/.agents/skills/<name> $AGENT_SKILLS_DIR/<name>
# Codex：
echo \"无需软链\"
\`\`\`

## 模板与父 wiki 分流

| 场景 | 模板路径 | 父 wiki（env 中取）|
|------|---------|------------------|
| 自创 Skill | ~/.claude/templates/skill-guide-create.md | \$CAIYIZOU_CREATE_WIKI_NODE |
| 安装 Skill | ~/.claude/templates/skill-guide-install.md | \$CAIYIZOU_INSTALL_WIKI_NODE |

## 创建/安装 Skill 标准流程

1. 读取对应模板（cp ~/.claude/templates/skill-guide-{create,install}.md 到 /tmp）
2. 替换 {skill-name} / {version} 等占位符
3. \`lark-cli wiki +node-create --parent-node-token \$<CREATE|INSTALL>_WIKI_NODE\` 建子文档
4. \`lark-cli docs +update --content @/tmp/<name>-guide.md --doc-format markdown\` 写内容
5. 飞书表格无「使用指南」列则 \`lark-cli base +field-create\`
6. \`lark-cli base +record-batch-create\` 一次性归档（带指南 URL）

## 分享/发布前必清理

用户说「发布/分享/上传/给朋友用」时，先跑：

\`\`\`bash
bash <skill-dir>/scripts/pre-publish-clean.sh <skill-dir>
\`\`\`

按报告替换硬编码的 token / 邮箱 / 个人路径，再 git push。

## 同名覆盖策略

setup / archive 碰到同名时弹 3 选 1：
- 备份现有 → 再覆盖（默认）
- 创建副本（rename）
- 取消

实现见 \`scripts/setup.sh\` 的 \`write_with_protect()\` 函数。

## 飞书 URL 解析（agent 工作，不问 token）

| 用户给 | agent 用什么 |
|--------|-------------|
| /base/... 表格链接 | lark-cli base +url-resolve |
| /wiki/... 表格链接 | lark-cli wiki +url-resolve → +node-get → 拿 obj_token |

**禁止**问用户要 base-token / table-id / node-token。
"
write_with_protect "$RULES_FILE" "$RULES_PAYLOAD"

# =================== 9. 检查 lark-cli（如未装则引导安装）===================
echo ""
echo "9️⃣  检查 lark-cli..."
if ! command -v lark-cli >/dev/null 2>&1; then
    echo "   ⚠️  lark-cli 未安装——归档到飞书需要它"
    echo "   推荐方式：brew install lark-cli / npm i -g @larksuite/cli"
    read -p "   立即尝试安装？(y/N) " install_choice
    install_choice="${install_choice:-N}"
    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install lark-cli || echo "   ❌ brew 安装失败，请手动安装"
        elif command -v npm >/dev/null 2>&1; then
            npm install -g @larksuite/cli || echo "   ❌ npm 安装失败，请手动安装"
        fi
    fi
else
    echo "   ✓ lark-cli：$(lark-cli --version 2>&1 | head -1)"
    # 检查授权
    if lark-cli auth status 2>/dev/null | grep -qE "logged in|已登录|authorized"; then
        echo "   ✓ 已授权"
    else
        echo "   ⚠️ 未授权——归档会失败，记得跑 lark-cli auth login"
    fi
fi

echo ""
echo "✨ 搭建完成！"
echo ""
echo "📋 当前配置:"
echo "   Agent:       $AGENT_NAME (NEED_SYMLINK=$NEED_SYMLINK)"
echo "   Skills 目录: $AGENT_SKILLS_DIR"
echo "   飞书表格:    ${feishu_table_url:-未配置}"
echo "   配置文件:    $ENV_FILE"
echo ""
echo "下一步："
echo "  /caiyizou-skill-hub install <name>   # 安装并归档"
echo "  /caiyizou-skill-hub create <name>    # 创建并归档"
echo "  /caiyizou-skill-hub archive <name>   # 补归档"
echo "  /caiyizou-skill-hub list             # 列出所有"
