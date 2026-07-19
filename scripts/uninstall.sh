#!/usr/bin/env bash
# caiyizou-skill-hub 卸载脚本（v1.4）
# 用法：bash uninstall.sh [--keep-config] [--keep-rules] [--keep-templates]

set -e

KEEP_CONFIG="false"
KEEP_RULES="false"
KEEP_TEMPLATES="false"
for arg in "$@"; do
    case "$arg" in
        --keep-config) KEEP_CONFIG="true" ;;
        --keep-rules) KEEP_RULES="true" ;;
        --keep-templates) KEEP_TEMPLATES="true" ;;
    esac
done

SKILL_NAME="caiyizou-skill-hub"

echo "🗑️  卸载 caiyizou-skill-hub"
echo ""

ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"
AGENT_SKILLS_DIR=""
NEVER_SETUP="false"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    AGENT_SKILLS_DIR="$CAIYIZOU_AGENT_SKILLS_DIR"
else
    NEVER_SETUP="true"
    echo "⚠️  没找到 env 文件：$ENV_FILE"
    echo "   你可能从未跑过 setup。仍然继续会按下面的清单逐项询问确认删除。"
    echo ""
fi

# ===== 第一步：列出将删除的所有路径 =====
echo "📋 即将删除："
echo ""

TO_DELETE=()

for dir in "$AGENT_SKILLS_DIR" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills" "$HOME/.gemini/skills"; do
    [ -z "$dir" ] && continue
    link="$dir/$SKILL_NAME"
    if [ -L "$link" ]; then
        echo "   🗑️  软链：$link"
        TO_DELETE+=("$link")
    elif [ -d "$link" ] && [ ! -L "$link" ]; then
        echo "   ⚠️  $link 是目录不是软链（可能你装过同名 skill），跳过"
    fi
done

[ -d "$HOME/.agents/skills/$SKILL_NAME" ] && {
    echo "   🗑️  主目录：~/.agents/skills/$SKILL_NAME"
    TO_DELETE+=("$HOME/.agents/skills/$SKILL_NAME")
}

if [ "$KEEP_CONFIG" != "true" ] && [ -f "$ENV_FILE" ]; then
    echo "   🗑️  配置：$ENV_FILE"
    TO_DELETE+=("$ENV_FILE")
fi

RULES_FILE="$HOME/.claude/rules/skill-creation-workflow.md"
if [ "$KEEP_RULES" != "true" ] && [ -f "$RULES_FILE" ]; then
    echo "   🗑️  rules：$RULES_FILE（先备份到 *.pre-uninstall.<ts>）"
    TO_DELETE+=("$RULES_FILE")
fi

for tpl in skill-guide-create.md skill-guide-install.md; do
    if [ "$KEEP_TEMPLATES" != "true" ] && [ -f "$HOME/.claude/templates/$tpl" ]; then
        echo "   🗑️  模板：~/.claude/templates/$tpl"
        TO_DELETE+=("$HOME/.claude/templates/$tpl")
    fi
done

if [ "${#TO_DELETE[@]}" -eq 0 ]; then
    echo "   （未发现任何需删除的文件）"
    echo ""
    echo "✨ 干净，无需操作"
    exit 0
fi

if [ "$NEVER_SETUP" = "true" ]; then
    echo "💡 这是「你从未 setup 过」模式：env / rules / 模板都不在你的本机，"
    echo "   唯一可删的只剩主目录 + agent 目录下的软链。"
fi

# ===== 第二步：二次确认 =====
echo ""
echo "⚠️  删除以上 ${#TO_DELETE[@]} 个路径不可逆。rules 文件会备份到 *.pre-uninstall.<ts> 其他没备份。"
echo ""
read -p "确认删除？(yes 才行 / N 取消): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo ""
    echo "⏭️  已取消"
    exit 0
fi

echo ""
echo "🔧 执行删除..."
echo ""

# ===== 第三步：实际删除 =====
for dir in "$AGENT_SKILLS_DIR" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills" "$HOME/.gemini/skills"; do
    [ -z "$dir" ] && continue
    link="$dir/$SKILL_NAME"
    if [ -L "$link" ]; then
        rm "$link"
    fi
done

if [ -d "$HOME/.agents/skills/$SKILL_NAME" ]; then
    rm -rf "$HOME/.agents/skills/$SKILL_NAME"
fi

if [ "$KEEP_CONFIG" != "true" ] && [ -f "$ENV_FILE" ]; then
    rm "$ENV_FILE"
    rmdir "$HOME/.config/caiyizou-skill-hub" 2>/dev/null || true
fi

if [ "$KEEP_RULES" != "true" ] && [ -f "$RULES_FILE" ]; then
    cp "$RULES_FILE" "${RULES_FILE}.pre-uninstall.$(date +%Y%m%d-%H%M%S)"
    rm "$RULES_FILE"
    echo "   📦 rules 备份到 *.pre-uninstall.<ts>"
fi

for tpl in skill-guide-create.md skill-guide-install.md; do
    if [ "$KEEP_TEMPLATES" != "true" ] && [ -f "$HOME/.claude/templates/$tpl" ]; then
        rm "$HOME/.claude/templates/$tpl"
    fi
done

echo ""
echo "✨ 卸载完成。重装：/caiyizou-skill-hub setup"
