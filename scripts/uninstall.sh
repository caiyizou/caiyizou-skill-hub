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
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    AGENT_SKILLS_DIR="$CAIYIZOU_AGENT_SKILLS_DIR"
    echo "   检测到旧配置：$ENV_FILE"
fi

# 删 5 种可能路径下的软链（兼容历史安装）
for dir in "$AGENT_SKILLS_DIR" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills" "$HOME/.gemini/skills"; do
    [ -z "$dir" ] && continue
    link="$dir/$SKILL_NAME"
    if [ -L "$link" ]; then
        rm "$link"
        echo "   🗑️  删软链：$link"
    elif [ -d "$link" ] && [ ! -L "$link" ]; then
        echo "   ⚠️  $link 是目录不是软链（可能你装过同名 skill），跳过"
    fi
done

if [ -d "$HOME/.agents/skills/$SKILL_NAME" ]; then
    rm -rf "$HOME/.agents/skills/$SKILL_NAME"
    echo "   🗑️  删主目录：~/.agents/skills/$SKILL_NAME"
fi

if [ "$KEEP_CONFIG" != "true" ] && [ -f "$ENV_FILE" ]; then
    rm "$ENV_FILE"
    rmdir "$HOME/.config/caiyizou-skill-hub" 2>/dev/null || true
    echo "   🗑️  删配置：$ENV_FILE"
else
    echo "   📦 保留配置：$ENV_FILE"
fi

RULES_FILE="$HOME/.claude/rules/skill-creation-workflow.md"
if [ "$KEEP_RULES" != "true" ] && [ -f "$RULES_FILE" ]; then
    cp "$RULES_FILE" "${RULES_FILE}.pre-uninstall.$(date +%Y%m%d-%H%M%S)"
    rm "$RULES_FILE"
    echo "   🗑️  删 rules（备份到 *.pre-uninstall.<ts>）"
fi

for tpl in skill-guide-create.md skill-guide-install.md; do
    if [ "$KEEP_TEMPLATES" != "true" ] && [ -f "$HOME/.claude/templates/$tpl" ]; then
        rm "$HOME/.claude/templates/$tpl"
        echo "   🗑️  删模板：~/.claude/templates/$tpl"
    fi
done

echo ""
echo "✨ 卸载完成。重装：/caiyizou-skill-hub setup"
