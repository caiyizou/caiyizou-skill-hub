#!/usr/bin/env bash
# caiyizou-skill-hub 添加飞书字段脚本（从环境变量读配置）
# 用法：
#   source ~/.config/caiyizou-skill-hub/env
#   bash add-field.sh <field-name> <type>
# type: text | number | select | url | date

set -e

ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

FIELD_NAME="${1:?用法: bash add-field.sh <field-name> <type>}"
FIELD_TYPE="${2:-text}"

if [ -z "$CAIYIZOU_BASE_TOKEN" ] || [ -z "$CAIYIZOU_TABLE_ID" ]; then
    echo "❌ 飞书未配置。请先运行 /caiyizou-skill-hub setup"
    exit 1
fi

lark-cli base +field-create \
    --base-token "$CAIYIZOU_BASE_TOKEN" \
    --table-id "$CAIYIZOU_TABLE_ID" \
    --json "{\"name\":\"$FIELD_NAME\",\"type\":\"$FIELD_TYPE\"}"
