#!/usr/bin/env bash
# caiyizou-skill-hub 发布前自动清理脚本
# 用法：bash pre-publish-clean.sh <skill-directory>
# 自动扫描所有硬编码的个人信息并报告，留给 agent 决定如何替换

set -e

SKILL_DIR="${1:?用法: bash pre-publish-clean.sh <skill-directory>}"

if [ ! -d "$SKILL_DIR" ]; then
    echo "❌ 目录不存在：$SKILL_DIR"
    exit 1
fi

echo "🔍 扫描 $SKILL_DIR 中的个人配置..."
echo ""

find "$SKILL_DIR" -type f \( -name "*.sh" -o -name "*.md" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \) | while read f; do
    echo "📄 $f"

    # 飞书 base-token (一般是 bascn 开头的 18 位字符串)
    grep -nE 'bascn[A-Za-z0-9]{10,}' "$f" 2>/dev/null | sed 's/^/   ⚠️  base-token: /'

    # 飞书 table-id
    grep -nE 'tbl[A-Za-z0-9]{10,}' "$f" 2>/dev/null | sed 's/^/   ⚠️  table-id: /'

    # 飞书 wiki node-token
    grep -nE 'wiki[A-Za-z0-9]{10,}|[a-zA-Z0-9]{20,}\b' "$f" 2>/dev/null | grep -E 'feishu' | sed 's/^/   ⚠️  wiki token: /'

    # 飞书租户标识
    grep -nE '[a-z0-9]{8,15}\.feishu\.cn' "$f" 2>/dev/null | sed 's/^/   ⚠️  feishu tenant: /'

    # 飞书完整 URL
    grep -nE 'https?://[a-z0-9.-]+\.feishu\.cn/(wiki|base|docs)/[A-Za-z0-9?=&\-]+' "$f" 2>/dev/null | sed 's/^/   ⚠️  feishu url: /'

    # 邮箱
    grep -nE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' "$f" 2>/dev/null | sed 's/^/   ⚠️  email: /'

    # 个人绝对路径（mac 风格）
    grep -nE '/Users/[a-z][a-z0-9_-]+/' "$f" 2>/dev/null | grep -v "\.agents/skills\|\.claude/skills" | sed 's/^/   ⚠️  personal path: /'

    # 可能的 API key / secret
    grep -nEi '(api[_-]?key|secret|token|password|passwd)\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{16,}' "$f" 2>/dev/null | sed 's/^/   ⚠️  possible secret: /'
done

echo ""
echo "✨ 扫描完成"
echo ""
echo "下一步："
echo "  1. 把上面所有 ⚠️ 项替换成："
echo "     - 环境变量（从 ~/.config/caiyizou-skill-hub/env 读）"
echo "     - 占位符（如 YOUR_BASE_TOKEN_HERE）"
echo "     - setup 时让用户填入"
echo "  2. 替换完后再 git push"
