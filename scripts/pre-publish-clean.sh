#!/usr/bin/env bash
# caiyizou-skill-hub 发布前清理脚本（v1.3 精确 regex + --apply）
# 用法：
#   bash pre-publish-clean.sh <skill-dir>                       # 只报告
#   bash pre-publish-clean.sh <skill-dir> --apply               # 自动替换 + 备份

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
require_deps python3

SKILL_DIR="${1:?用法: bash pre-publish-clean.sh <skill-dir> [--apply]}"
APPLY="false"
[ "${2:-}" = "--apply" ] && APPLY="true"

if [ ! -d "$SKILL_DIR" ]; then
    echo "❌ 目录不存在：$SKILL_DIR"
    exit 1
fi

echo "🔍 扫描 $SKILL_DIR 中的个人配置..."
echo "   模式: $([ "$APPLY" = "true" ] && echo 'AUTO-APPLY' || echo 'REPORT-ONLY')"
echo ""

REPORT_FOUND=0

scan_file() {
    local f="$1"
    local found_in_file=0

    # 1. 飞书 base-token
    if grep -qE '\bbascn[A-Za-z0-9]{10,}\b' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '\bbascn[A-Za-z0-9]{10,}\b' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  base-token  →  YOUR_BASE_TOKEN_HERE  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    # 2. 飞书 table-id
    if grep -qE '\btbl[A-Za-z0-9]{8,}\b' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '\btbl[A-Za-z0-9]{8,}\b' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  table-id    →  YOUR_TABLE_ID_HERE  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    # 3. 飞书 wiki node-token
    if grep -qE '\bwiki[A-Za-z0-9]{15,}\b' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '\bwiki[A-Za-z0-9]{15,}\b' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  wiki-token  →  YOUR_WIKI_TOKEN_HERE  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    # 4. 飞书租户标识
    if grep -qE '\b[a-z0-9]{8,20}\.feishu\.cn\b' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '\b[a-z0-9]{8,20}\.feishu\.cn\b' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  feishu租户  →  YOUR_TENANT.feishu.cn  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    # 5. 邮箱
    if grep -qE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  邮箱        →  YOUR_EMAIL_HERE  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    # 6. 个人绝对路径（排除通用 skill 目录）
    if grep -qE '/Users/[a-z][a-z0-9_-]+/' "$f" 2>/dev/null; then
        local personal_paths
        personal_paths=$(grep -nE '/Users/[a-z][a-z0-9_-]+/' "$f" 2>/dev/null | grep -vE '/Users/[a-z][a-z0-9_-]+/(\.agents|\.claude|\.codex|\.cursor|\.gemini)/skills/' | wc -l | tr -d ' ')
        if [ "$personal_paths" -gt 0 ]; then
            echo "   ⚠️  个人路径    →  \$HOME/...  ($personal_paths 处)"
            REPORT_FOUND=$((REPORT_FOUND + personal_paths))
            found_in_file=$((found_in_file + 1))
        fi
    fi

    # 7. 疑似 secret（变量赋值形式 + >= 32 字符）
    if grep -qE '^[[:space:]]*(export[[:space:]]+)?[A-Z_][A-Z0-9_]*(TOKEN|SECRET|API_KEY|PASSWORD)[[:space:]]*=[[:space:]]*["\x27]?[A-Za-z0-9+/=_-]{32,}["\x27]?' "$f" 2>/dev/null; then
        local n
        n=$(grep -cE '^[[:space:]]*(export[[:space:]]+)?[A-Z_][A-Z0-9_]*(TOKEN|SECRET|API_KEY|PASSWORD)[[:space:]]*=[[:space:]]*["\x27]?[A-Za-z0-9+/=_-]{32,}["\x27]?' "$f" 2>/dev/null || echo 0)
        echo "   ⚠️  疑似 secret  →  YOUR_SECRET_HERE  ($n 处)"
        REPORT_FOUND=$((REPORT_FOUND + n))
        found_in_file=$((found_in_file + 1))
    fi

    if [ "$found_in_file" -gt 0 ]; then
        echo "📄 $f"
    fi
}

while IFS= read -r -d '' f; do
    scan_file "$f"
done < <(find "$SKILL_DIR" -type f \( -name "*.sh" -o -name "*.md" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" -print0)

echo "═══════════════════════════════════════════════════════"

if [ "$REPORT_FOUND" -eq 0 ]; then
    echo "✅ 未发现个人配置——可以直接 git push"
    exit 0
fi

echo "⚠️  共发现 $REPORT_FOUND 处需要处理"
echo ""

if [ "$APPLY" = "true" ]; then
    echo "🔧 自动替换模式..."
    while IFS= read -r -d '' f; do
        local_backup="${f}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$f" "$local_backup"
        python3 - "$f" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as fh:
    content = fh.read()
original = content
content = re.sub(r'\bbascn[A-Za-z0-9]{10,}\b', 'YOUR_BASE_TOKEN_HERE', content)
content = re.sub(r'\btbl[A-Za-z0-9]{8,}\b', 'YOUR_TABLE_ID_HERE', content)
content = re.sub(r'\bwiki[A-Za-z0-9]{15,}\b', 'YOUR_WIKI_TOKEN_HERE', content)
content = re.sub(r'\b[a-z0-9]{8,20}\.feishu\.cn\b', 'YOUR_TENANT.feishu.cn', content)
content = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', 'YOUR_EMAIL_HERE', content)
def repl_path(m):
    s = m.group(0)
    if re.search(r'/\.(agents|claude|codex|cursor|gemini)/skills/', s):
        return s
    return '$HOME/'
content = re.sub(r'/Users/[a-z][a-z0-9_-]+/', repl_path, content)
content = re.sub(r'(?<==\s*["\x27])([A-Za-z0-9+/=_-]{32,})(?=["\x27])', 'YOUR_SECRET_HERE', content)
if content != original:
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(content)
    print(f'  ✓ {path}')
PYEOF
        echo "   📦 备份: $local_backup"
    done < <(find "$SKILL_DIR" -type f \( -name "*.sh" -o -name "*.md" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \) \
        ! -path "*/.git/*" ! -name "*.bak.*" -print0)
    echo ""
    echo "✅ 已自动替换完成（git diff 检查后再 git push）"
else
    echo "📋 处理方法（3 选 1）："
    echo "   A) 自动替换（推荐）："
    echo "      bash $SKILL_DIR/scripts/pre-publish-clean.sh '$SKILL_DIR' --apply"
    echo ""
    echo "   B) 手动替换为："
    echo "      base-token → \$CAIYIZOU_BASE_TOKEN（env 读取）"
    echo "      table-id   → \$CAIYIZOU_TABLE_ID"
    echo "      wiki URL   → YOUR_FEISHU_URL（README 说明）"
    echo "      邮箱       → YOUR_EMAIL_HERE"
    echo "      个人路径   → \$HOME/..."
    echo ""
    echo "   C) 跳过——确认这些 ⚠️ 项都不会进 git"
fi
