#!/usr/bin/env bash
# caiyizou-skill-hub 归档脚本（v1.2 从 env 读配置 + 同名保护 + jq 拼 JSON）
# 用法：
#   source ~/.config/caiyizou-skill-hub/env
#   bash archive.sh <skill-name> <version> <category> <source> <install-source> <guide-url>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
require_deps python3 jq lark-cli

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

# ===== 1. 读表格已有字段 + 别名映射 + 确保「使用指南」类字段存在 =====
FIELD_LIST_JSON=$(lark-cli base +field-list \
    --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
    --format json 2>/dev/null || echo '{"data":{"items":[]}}')

# 已有字段名（每行一个）
EXISTING_FIELDS=$(echo "$FIELD_LIST_JSON" | jq -r '.data.items[]?.field_name // empty' 2>/dev/null)

# pick_field <alias1> <alias2>...  返回第一个匹配 EXISTING_FIELDS 的，否则空
pick_field() {
    local alias
    for alias in "$@"; do
        if echo "$EXISTING_FIELDS" | grep -Fxq "$alias"; then
            echo "$alias"
            return 0
        fi
    done
    return 1
}

# 别名映射（按优先级排）
F_NAME=$(pick_field "技能名称" "name" || echo "")
F_GITHUB=$(pick_field "GitHub地址" "github" "GitHub" || echo "")
F_SKILLPATH=$(pick_field "本地SKILL.MD路径" "本地路径" "SKILL路径" || echo "")
F_STATUS=$(pick_field "状态" "status" || echo "")
F_DESC=$(pick_field "简介" "描述" "description" || echo "")
F_VERSION=$(pick_field "版本" "version" || echo "")
F_CATEGORY=$(pick_field "功能分类" "分类" "category" || echo "")
F_CMD=$(pick_field "调用命令" "命令" "command" || echo "")
F_INSTALL_SRC=$(pick_field "安装来源" "install_source" || echo "")
F_SOURCE=$(pick_field "来源" "source" || echo "")
F_LOG=$(pick_field "更新日志" "changelog" || echo "")
F_GUIDE=$(pick_field "使用指南" "guide" "指南" || echo "")

# 必须有「使用指南」类字段，没有则自动新建
if [ -z "$F_GUIDE" ]; then
    echo "   ➕ 新增「使用指南」字段..."
    lark-cli base +field-create \
        --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
        --json '{"name":"使用指南","type":"url","description":"小白使用指南飞书文档链接"}' >/dev/null
    F_GUIDE="使用指南"
fi

if [ -z "$F_NAME" ]; then
    echo "   ❌ 飞书表格无「技能名称」字段，请先在表格里建一个 text 类型主键列"
    exit 1
fi

# ===== 2. 检查是否已存在同名记录（不依赖 --filter 语法，先全 list 再本地过滤）=====
echo "   🔍 查重..."
RAW_JSON=$(lark-cli base +record-list \
    --base-token "$BASE_TOKEN" \
    --table-id "$TABLE_ID" \
    --format json 2>/dev/null || echo '{}')

EXISTING_RECORD_ID=$(echo "$RAW_JSON" | SKILL_NAME="$SKILL_NAME" F_NAME="$F_NAME" python3 -c "
import sys, json, os
target = os.environ.get('SKILL_NAME', '')
name_field = os.environ.get('F_NAME', '技能名称')
try:
    d = json.load(sys.stdin)
    items = d.get('data', {}).get('items', [])
    if not items:
        # 兼容某些版本返回 record_id_list
        items = [{'record_id': rid, 'fields': {}} for rid in d.get('data', {}).get('record_id_list', [])]
    for it in items:
        fields = it.get('fields', {})
        name = fields.get(name_field, '')
        if name == target:
            print(it.get('record_id', ''))
            sys.exit(0)
    print('')
except Exception:
    print('')
" 2>/dev/null || echo "")

ACTION="create"
RENAME_PATH_FROM=""
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
            # 改名 case：路径仍指原目录（实际文件在那），新记录只是飞书表格里共存
            RENAME_PATH_FROM="$SKILL_NAME"
            SKILL_NAME="${SKILL_NAME}-v2"
            echo "   → 重命名为 $SKILL_NAME（路径仍指原 ${RENAME_PATH_FROM}）"
            ACTION="create"
            ;;
        *)
            echo "   ⏭️  跳过"
            exit 0
            ;;
    esac
fi

# ===== 3. 用 jq 拼 JSON（按表格实际存在的字段写，跳过不存在的）=====
JSON_FILE="/tmp/caiyizou-archive-$SKILL_NAME-$(date +%s).json"

case "$ACTION" in
    create)
        # 改名 case：路径仍指原目录，新记录只占用飞书表格一格
        PATH_NAME="${RENAME_PATH_FROM:-$SKILL_NAME}"
        # 按 F_* 顺序入动态 fields + rows（空字段跳过）
        ROW_JSON=$(jq -n \
            --arg f_name "$F_NAME" --arg name "$SKILL_NAME" \
            --arg f_github "$F_GITHUB" \
            --arg f_skillpath "$F_SKILLPATH" --arg path "$HOME/.agents/skills/$PATH_NAME/SKILL.md" \
            --arg f_status "$F_STATUS" \
            --arg f_desc "$F_DESC" \
            --arg f_version "$F_VERSION" --arg version "$VERSION" \
            --arg f_category "$F_CATEGORY" --arg category "$CATEGORY" \
            --arg f_cmd "$F_CMD" \
            --arg f_install_src "$F_INSTALL_SRC" --arg install_source "$INSTALL_SOURCE" \
            --arg f_source "$F_SOURCE" --arg source "$SOURCE" \
            --arg f_log "$F_LOG" --arg log "v$VERSION ($(date +%Y-%m-%d)): 通过 caiyizou-skill-hub 归档" \
            --arg f_guide "$F_GUIDE" --arg guide "$GUIDE_URL" \
            '
              [
                (if $f_name      != "" then {($f_name):      $name}                else empty end),
                (if $f_github    != "" then {($f_github):    ""}                   else empty end),
                (if $f_skillpath != "" then {($f_skillpath): $path}               else empty end),
                (if $f_status    != "" then {($f_status):    "启用"}              else empty end),
                (if $f_desc      != "" then {($f_desc):      ""}                   else empty end),
                (if $f_version   != "" then {($f_version):   $version}             else empty end),
                (if $f_category  != "" then {($f_category):  $category}            else empty end),
                (if $f_cmd       != "" then {($f_cmd):       ("/" + $name)}       else empty end),
                (if $f_install_src != "" then {($f_install_src): $install_source} else empty end),
                (if $f_source    != "" then {($f_source):    $source}             else empty end),
                (if $f_log       != "" then {($f_log):       $log}                 else empty end),
                (if $f_guide     != "" then {($f_guide):     $guide}              else empty end)
              ] | add
            ')
        # ROW_JSON 现在是一个对象 {field_name: value}，转成 [field_name,...] + [val,...]
        jq -n \
            --argjson row "$ROW_JSON" \
            '{
              fields: ($row | keys),
              rows: [[$row | to_entries[] | .value]]
            }' > "$JSON_FILE"
        ;;

    update:*)
        RECORD_ID="${ACTION#update:}"
        # 读取旧日志（用动态 F_LOG）
        OLD_LOG=""
        if [ -n "$F_LOG" ]; then
            OLD_LOG=$(lark-cli base +record-get \
                --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
                --record-id "$RECORD_ID" --format json 2>/dev/null \
                | EXISTING_LOG_FIELD="$F_LOG" python3 -c "
import sys, json, os
target = os.environ.get('EXISTING_LOG_FIELD', '更新日志')
try:
    d = json.load(sys.stdin)
    fields = d.get('data',{}).get('fields',{})
    val = fields.get(target, '')
    print(val if val else '')
except Exception:
    print('')
" 2>/dev/null || echo "")
        fi
        NEW_LOG="v$VERSION ($(date +%Y-%m-%d)): 通过 caiyizou-skill-hub 归档"
        if [ -n "$OLD_LOG" ] && [ "$OLD_LOG" != "None" ]; then
            COMBINED_LOG="$NEW_LOG
$OLD_LOG"
        else
            COMBINED_LOG="$NEW_LOG"
        fi

        # update 路径：只更新存在的字段
        UPD_JSON=$(jq -n \
            --arg f_version "$F_VERSION" --arg version "$VERSION" \
            --arg f_log "$F_LOG" --arg log "$COMBINED_LOG" \
            --arg f_guide "$F_GUIDE" --arg guide "$GUIDE_URL" \
            '
              reduce (
                (if $f_version != "" then {key:$f_version, val:$version} else empty end),
                (if $f_log    != "" then {key:$f_log,    val:$log}    else empty end),
                (if $f_guide  != "" then {key:$f_guide,  val:$guide}  else empty end)
              ) as $x ({}; .[$x.key] = $x.val)
            ')
        jq -n \
            --arg record_id "$RECORD_ID" \
            --argjson upd "$UPD_JSON" \
            '{record_id: $record_id, fields: $upd}' > "$JSON_FILE"
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
