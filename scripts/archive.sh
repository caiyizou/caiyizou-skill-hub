#!/usr/bin/env bash
# caiyizou-skill-hub 归档脚本（从环境变量读配置，不硬编码）
# 用法：
#   source ~/.config/caiyizou-skill-hub/env
#   bash archive.sh <skill-name> <version> <category> <source> <install-source> <guide-url>

set -e

# 从 env 文件读取配置
ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

SKILL_NAME="${1:?用法: bash archive.sh <skill-name> <version> <category> <source> <install-source> <guide-url>}"
VERSION="${2:-1.0.0}"
CATEGORY="${3:-开发工具}"
SOURCE="${4:-自制}"            # 自制 / 安装
INSTALL_SOURCE="${5:-}"        # 自制时留空
GUIDE_URL="${6:-}"

if [ -z "$CAIYIZOU_BASE_TOKEN" ] || [ -z "$CAIYIZOU_TABLE_ID" ]; then
    echo "❌ 飞书未配置。请先运行 /caiyizou-skill-hub setup"
    exit 1
fi

BASE_TOKEN="$CAIYIZOU_BASE_TOKEN"
TABLE_ID="$CAIYIZOU_TABLE_ID"

echo "📦 归档 Skill：$SKILL_NAME v$VERSION → $TABLE_ID"

# 1. 检查是否已存在
existing=$(lark-cli base +record-list \
    --base-token "$BASE_TOKEN" \
    --table-id "$TABLE_ID" \
    --filter-json "{\"logic\":\"and\",\"conditions\":[[\"技能名称\",\"==\",\"$SKILL_NAME\"]]}" \
    --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'].get('record_id_list', [''])[0])")

if [ -n "$existing" ]; then
    echo "   ⚠️ Skill 已存在（record_id=$existing），跳过归档"
    exit 0
fi

# 2. 确保「使用指南」字段存在
if ! lark-cli base +field-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --format json 2>/dev/null | grep -q "使用指南"; then
    echo "   ➕ 新增「使用指南」字段..."
    lark-cli base +field-create \
        --base-token "$BASE_TOKEN" \
        --table-id "$TABLE_ID" \
        --json '{"name":"使用指南","type":"url","description":"小白使用指南飞书文档链接"}' >/dev/null
fi

# 3. 写入记录
echo "   ➕ 写入飞书表格..."
lark-cli base +record-batch-create \
    --base-token "$BASE_TOKEN" \
    --table-id "$TABLE_ID" \
    --json "{
      \"fields\": [\"技能名称\",\"GIthub地址\",\"本地SKILL.MD路径\",\"状态\",\"简介\",\"版本\",\"功能分类\",\"调用命令\",\"安装来源\",\"来源\",\"更新日志\",\"使用指南\"],
      \"rows\": [[
        \"$SKILL_NAME\",
        \"\",
        \"$HOME/.agents/skills/$SKILL_NAME/SKILL.md\",
        \"启用\",
        \"\",
        \"$VERSION\",
        \"$CATEGORY\",
        \"/$SKILL_NAME\",
        \"$INSTALL_SOURCE\",
        \"$SOURCE\",
        \"v$VERSION ($(date +%Y-%m-%d)): 通过 caiyizou-skill-hub 归档\",
        \"$GUIDE_URL\"
      ]]
    }"

echo "   ✅ 归档完成"
