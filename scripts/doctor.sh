#!/usr/bin/env bash
# caiyizou-skill-hub 自检脚本（v1.7 检查依赖/env/软链/模板/lark-cli 授权/飞书表格/wiki 通达）
# 用法：bash doctor.sh
# 退出码：0=全通 / 1=有 ❌

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

SKILL_NAME="caiyizou-skill-hub"
ENV_FILE="$HOME/.config/caiyizou-skill-hub/env"

echo "🩺 caiyizou-skill-hub 自检"
echo ""

PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS+1)); echo "   ✅ $*"; }
bad()  { FAIL=$((FAIL+1)); echo "   ❌ $*"; }
warn() { WARN=$((WARN+1)); echo "   ⚠️  $*"; }

# ===== 1. 依赖工具 =====
echo "1️⃣  依赖工具"
for cmd in python3 jq lark-cli git; do
    if command -v "$cmd" >/dev/null 2>&1; then
        local_ver=$("$cmd" --version 2>&1 | head -1 || echo "已安装")
        ok "$cmd：$local_ver"
    else
        bad "$cmd：未安装"
    fi
done
echo ""

# ===== 2. env 配置文件 =====
echo "2️⃣  env 配置"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    ok "env 文件存在：$ENV_FILE"
    # 版本检查（如 setup 早于 1.8 写的 env，会提示升级）
    if [ -z "$CAIYIZOU_HUB_VERSION" ]; then
        warn "HUB_VERSION 未记录（env 是 v1.7 及之前写的），建议重跑 setup"
    elif [ "$CAIYIZOU_HUB_VERSION" != "1.8.0" ]; then
        warn "HUB_VERSION=$CAIYIZOU_HUB_VERSION（当前 1.8.0），考虑重跑 setup 升级"
    else
        ok "HUB_VERSION=$CAIYIZOU_HUB_VERSION"
    fi
    [ -n "$CAIYIZOU_AGENT_NAME" ]      && ok "AGENT_NAME=$CAIYIZOU_AGENT_NAME"      || warn "AGENT_NAME 为空"
    [ -n "$CAIYIZOU_AGENT_SKILLS_DIR" ] && ok "AGENT_SKILLS_DIR=$CAIYIZOU_AGENT_SKILLS_DIR" || warn "AGENT_SKILLS_DIR 为空"
    [ -n "$CAIYIZOU_NEED_SYMLINK" ]     && ok "NEED_SYMLINK=$CAIYIZOU_NEED_SYMLINK"  || warn "NEED_SYMLINK 为空"
    [ -n "$CAIYIZOU_BASE_TOKEN" ]       && ok "BASE_TOKEN=${CAIYIZOU_BASE_TOKEN:0:8}..." || warn "BASE_TOKEN 为空（归档不到飞书）"
    [ -n "$CAIYIZOU_TABLE_ID" ]         && ok "TABLE_ID=$CAIYIZOU_TABLE_ID"            || warn "TABLE_ID 为空（归档不到飞书）"
    [ -n "$CAIYIZOU_CREATE_WIKI_NODE" ] && ok "CREATE_WIKI_NODE=${CAIYIZOU_CREATE_WIKI_NODE:0:8}..." || warn "CREATE_WIKI_NODE 为空（创建类指南无处放）"
    [ -n "$CAIYIZOU_INSTALL_WIKI_NODE" ] && ok "INSTALL_WIKI_NODE=${CAIYIZOU_INSTALL_WIKI_NODE:0:8}..." || warn "INSTALL_WIKI_NODE 为空（安装类指南无处放）"
else
    bad "env 文件不存在：$ENV_FILE — 请跑 /caiyizou-skill-hub setup"
fi
echo ""

# ===== 3. 软链 =====
echo "3️⃣  软链（${CAIYIZOU_AGENT_NAME:-未知 agent}）"
if [ -n "$CAIYIZOU_AGENT_SKILLS_DIR" ]; then
    link="$CAIYIZOU_AGENT_SKILLS_DIR/$SKILL_NAME"
    main_dir="$HOME/.agents/skills/$SKILL_NAME"
    if [ -L "$link" ] && [ -d "$main_dir" ]; then
        ok "软链 $link → 主目录存在"
    elif [ -L "$link" ]; then
        bad "软链存在但主目录不在：$link → $main_dir（可能手动删了？）"
    elif [ "$CAIYIZOU_NEED_SYMLINK" = "no" ]; then
        ok "NEED_SYMLINK=no — 不需要软链"
    else
        bad "软链缺失：$link（NEED_SYMLINK=$CAIYIZOU_NEED_SYMLINK）"
    fi
else
    warn "AGENT_SKILLS_DIR 未配置 — 跳过软链检查"
fi
echo ""

# ===== 4. 模板 =====
echo "4️⃣  使用指南模板"
for tpl in skill-guide-create.md skill-guide-install.md; do
    p="$HOME/.claude/templates/$tpl"
    if [ -f "$p" ]; then
        ok "$p"
    else
        bad "$p 缺失（请跑 setup 重建）"
    fi
done
echo ""

# ===== 5. lark-cli 授权 =====
echo "5️⃣  lark-cli 授权"
if command -v lark-cli >/dev/null 2>&1; then
    if lark-cli auth whoami --format json 2>/dev/null | jq -e '.data.user_id // .data.open_id // .data.union_id' >/dev/null 2>&1; then
        ok "已授权"
    else
        bad "未授权——跑 \`lark-cli auth login\` 后再使用"
    fi
else
    warn "lark-cli 未装 — 跳过授权检查"
fi
echo ""

# ===== 6. 飞书表格可达 =====
echo "6️⃣  飞书表格"
if [ -n "$CAIYIZOU_BASE_TOKEN" ] && [ -n "$CAIYIZOU_TABLE_ID" ] && command -v lark-cli >/dev/null 2>&1; then
    RAW=$(lark-cli base +table-get --base-token "$CAIYIZOU_BASE_TOKEN" --table-id "$CAIYIZOU_TABLE_ID" --format json 2>/dev/null || echo "")
    if [ -n "$RAW" ] && echo "$RAW" | jq -e '.data.table_id' >/dev/null 2>&1; then
        ok "表格可达：$(echo "$RAW" | jq -r '.data.name // "<无名称>"')"
    else
        bad "表格不可达（token / table-id 错？权限被回收？）"
    fi
else
    warn "飞书未配置 — 跳过表格检查"
fi
echo ""

# ===== 7. 父 wiki 通达 =====
echo "7️⃣  父 wiki 通达"
for label_node in "CREATE:$CAIYIZOU_CREATE_WIKI_NODE" "INSTALL:$CAIYIZOU_INSTALL_WIKI_NODE"; do
    label="${label_node%%:*}"
    node="${label_node#*:}"
    label_cn=$([ "$label" = "CREATE" ] && echo "创建" || echo "安装")
    if [ -z "$node" ]; then
        warn "${label_cn}类 wiki 未配置 — 使用指南无处放"
    elif command -v lark-cli >/dev/null 2>&1; then
        RAW=$(lark-cli wiki +node-get --node-token "$node" --format json 2>/dev/null || echo "")
        if [ -n "$RAW" ] && echo "$RAW" | jq -e '.data.node_token' >/dev/null 2>&1; then
            ok "${label_cn}类 wiki 可达：$(echo "$RAW" | jq -r '.data.title // "<无标题>"')"
        else
            bad "${label_cn}类 wiki 不可达（node-token 失效？文档被删？）"
        fi
    fi
done
echo ""

# ===== 汇总 =====
echo "════════════════════════════════════════════════════════════"
TOTAL=$((PASS+FAIL+WARN))
echo "🩺 自检结果：✅ $PASS 通  ❌ $FAIL 败  ⚠️  $WARN 警告（合计 $TOTAL 项）"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "💡 修复建议："
    [ ! -f "$ENV_FILE" ] && echo "   • 未 setup：跑 /caiyizou-skill-hub setup"
    ! command -v python3 >/dev/null 2>&1 && echo "   • 装 python3：brew install python3"
    ! command -v jq       >/dev/null 2>&1 && echo "   • 装 jq：brew install jq"
    ! command -v lark-cli >/dev/null 2>&1 && echo "   • 装 lark-cli：brew install lark-cli"
    exit 1
fi
exit 0
