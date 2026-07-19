#!/usr/bin/env bash
# caiyizou-skill-hub 归档脚本（v1.2 从 env 读配置 + 同名保护 + jq 拼 JSON）
# 用法：
#   source ~/.config/caiyizou-skill-hub/env
#   bash archive.sh <skill-name> <version> <category> <source> <install-source> <guide-url>

set -e

ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

SKILL_NAME="${1:?用法: bash archive.sh <skill-name> <version> <category> <source> <install-source> <guide-url>}"
VERSION="${2:-1.0.0}"
CATEGORY="${3:-开发工具}"
SOURCE="${4:-自制}"
INSTALL_SOURCE="${5:-}"
GUIDE_URL="${6:-}"

if [ -z "$CAIYIZOU_BASE_TOKEN" ] || [ -z "$CAIYIZOU_TABLE_ID" ]; then
    echo "❌ 飞书未配置。请先运行 /caiyizou-skill-hub setup"
    exit 1
fi

BASE_TOKEN="$CAIYIZOU_BASE_TOKEN"
TABLE_ID="$CAIYIZOU_TABLE_ID"

echo "📦 归档 Skill：$SKILL_NAME v$VERSION → $TABLE_ID"

# ===== 1. 确保「使用指南」字段存在 =====
if ! lark-cli base +field-list \
        --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
        --format json 2>/dev/null | grep -q '"name":"使用指南"'; then
    echo "   ➕ 新增「使用指南」字段..."
    lark-cli base +field-create \
        --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
        --json '{"name":"使用指南","type":"url","description":"小白使用指南飞书文档链接"}' >/dev/null
fi

# ===== 2. 检查是否已存在同名记录 =====
EXISTING_RECORD_ID=$(lark-cli base +record-list \
    --base-token "$BASE_TOKEN" \
    --table-id "$TABLE_ID" \
    --filter "{\"conditions\":[{\"field_name\":\"技能名称\",\"operator\":\"==\",\"value\":\"$SKILL_NAME\"}]}" \
    --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('record_id_list',[''])[0])" 2>/dev/null || echo "")

ACTION="create"
if [ -n "$EXISTING_RECORD_ID" ] && [ "$EXISTING_RECORD_ID" != "None" ]; then
    # 同名记录已存在 → 同名保护（3 选 1）
    echo ""
    echo "   ⚠️  飞书表格里已有同名 Skill：$SKILL_NAME (record_id=$EXISTING_RECORD_ID)"
    echo "      1) 更新现有记录（升级版本号 + 追加日志）— 推荐"
    echo "      2) 创建副本（rename 为 ${SKILL_NAME}-v2）"
    echo "      3) 取消"
    read -p "      选择 [1-3]（默认 1）: " choice
    choice="${choice:-1}"
    echo ""

    case "$choice" in
        1)
            ACTION="update:$EXISTING_RECORD_ID"
            ;;
        2)
            SKILL_NAME="${SKILL_NAME}-v2"
            echo "   → 重命名为 $SKILL_NAME"
            ACTION="create"
            ;;
        *)
            echo "   ⏭️  跳过"
            exit 0
            ;;
    esac
fi

# ===== 3. 用 jq 拼 JSON（避免转义陷阱）=====
JSON_FILE="/tmp/caiyizou-archive-$SKILL_NAME-$(date +%s).json"

case "$ACTION" in
    create)
        jq -n \
            --arg name "$SKILL_NAME" \
            --arg version "$VERSION" \
            --arg category "$CATEGORY" \
            --arg source "$SOURCE" \
            --arg install_source "$INSTALL_SOURCE" \
            --arg guide "$GUIDE_URL" \
            --arg log "v$VERSION ($(date +%Y-%m-%d)): 通过 caiyizou-skill-hub 归档" \
            --arg path "$HOME/.agents/skills/$SKILL_NAME/SKILL.md" \
            '{
              fields: ["技能名称","GitHub地址","本地SKILL.MD路径","状态","简介","版本","功能分类","调用命令","安装来源","来源","更新日志","使用指南"],
              rows: [[
                $name, "", $path, "启用", "", $version, $category,
                ("/" + $name), $install_source, $source, $log, $guide
              ]]
            }' > "$JSON_FILE"
        ;;

    update:*)
        RECORD_ID="${ACTION#update:}"
        # 读取旧日志，追加新日志
        OLD_LOG=$(lark-cli base +record-get \
            --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
            --record-id "$RECORD_ID" --format json 2>/dev/null \
            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('fields',{}).get('更新日志',''))" 2>/dev/null || echo "")
        NEW_LOG="v$VERSION ($(date +%Y-%m-%d)): 通过 caiyizou-skill-hub 归档"
        if [ -n "$OLD_LOG" ] && [ "$OLD_LOG" != "None" ]; then
            COMBINED_LOG="$NEW_LOG
$OLD_LOG"
        else
            COMBINED_LOG="$NEW_LOG"
        fi

        jq -n \
            --arg version "$VERSION" \
            --arg guide "$GUIDE_URL" \
            --arg log "$COMBINED_LOG" \
            '{
              record_id: "'"$RECORD_ID"'",
              fields: {
                "版本": $version,
                "使用指南": $guide,
                "更新日志": $log
              }
            }' > "$JSON_FILE"
        ;;
esac

# ===== 4. 写入飞书 =====
if [[ "$ACTION" == create ]]; then
    echo "   ➕ 写入新记录..."
    lark-cli base +record-batch-create \
        --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
        --json @"$JSON_FILE"
else
    echo "   ✏️  更新现有记录 $RECORD_ID..."
    lark-cli base +record-upsert \
        --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
        --json @"$JSON_FILE"
fi

# ===== 5. 清理 =====
rm -f "$JSON_FILE"

echo "   ✅ 归档完成"
