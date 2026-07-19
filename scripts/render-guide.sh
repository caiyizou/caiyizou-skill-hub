#!/usr/bin/env bash
# caiyizou-skill-hub 模板渲染脚本（v1.6 自动适配 create / install 模板）
# 用法：bash render-guide.sh <create|install> <skill-name> <version> <category> [output-path]
# 输出：默认 /tmp/<skill-name>-guide-final.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
require_deps python3

SCENE="${1:?用法: bash render-guide.sh <create|install> <skill-name> <version> <category> [output-path]}"
SKILL_NAME="${2:?缺少 <skill-name>}"
VERSION="${3:-1.0.0}"
CATEGORY="${4:-开发工具}"
OUTPUT="${5:-/tmp/${SKILL_NAME}-guide-final.md}"

TPL="$HOME/.claude/templates/skill-guide-${SCENE}.md"
if [ ! -f "$TPL" ]; then
    echo "❌ 模板不存在：$TPL"
    echo "   请先跑 /caiyizou-skill-hub setup"
    exit 1
fi

DATE=$(date +%Y-%m-%d)

python3 "$SCRIPT_DIR/_render-guide.py" "$TPL" "$OUTPUT" \
    --skill-name "$SKILL_NAME" \
    --version "$VERSION" \
    --category "$CATEGORY" \
    --skill-command "$SKILL_NAME" \
    --date "$DATE"

echo "✅ 已生成 → $OUTPUT"
