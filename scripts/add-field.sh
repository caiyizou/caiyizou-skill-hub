#!/usr/bin/env bash
# caiyizou-skill-hub 添加飞书字段脚本（v1.6 用 jq + type 白名单）
# 用法：source ~/.config/caiyizou-skill-hub/env
#       bash add-field.sh <field-name> <type>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
require_deps jq lark-cli

ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

FIELD_NAME="${1:?用法: bash add-field.sh <field-name> <type>  (type: text|number|select|url|date)}"
FIELD_TYPE="${2:-text}"

# 类型白名单验证（防送非法 type 给 lark-cli）
case "$FIELD_TYPE" in
    text|number|select|url|date|datetime|checkbox|attachment|formula|link_record|created_time|modified_time|created_user|modified_user|auto_number|count)
        ;;
    *)
        echo "❌ 非法 type: $FIELD_TYPE"
        echo "   允许值：text / number / select / url / date / datetime / checkbox / attachment / formula"
        exit 1
        ;;
esac

if [ -z "$CAIYIZOU_BASE_TOKEN" ] || [ -z "$CAIYIZOU_TABLE_ID" ]; then
    echo "❌ 飞书未配置。请先运行 /caiyizou-skill-hub setup"
    exit 1
fi

echo "➕ 添加字段：$FIELD_NAME ($FIELD_TYPE)"

# 用 jq 拼 JSON（避免字符串拼接注入 + 转义问题）
JSON_PAYLOAD=$(jq -n \
    --arg name "$FIELD_NAME" \
    --arg type "$FIELD_TYPE" \
    '{name: $name, type: $type}')

lark-cli base +field-create \
    --base-token "$CAIYIZOU_BASE_TOKEN" \
    --table-id "$CAIYIZOU_TABLE_ID" \
    --json "$JSON_PAYLOAD"
