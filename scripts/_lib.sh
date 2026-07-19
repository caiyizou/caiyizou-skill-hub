#!/usr/bin/env bash
# caiyizou-skill-hub 共享工具函数（v1.6）
# 用法：source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# ===== require_deps <cmd1> [cmd2...] =====
# 检查依赖工具是否存在，缺失时打印安装方法并 exit 1
require_deps() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ 缺少必要工具: ${missing[*]}"
        echo ""
        echo "   安装方法："
        for cmd in "${missing[@]}"; do
            case "$cmd" in
                python3)
                    echo "     python3   → brew install python3    或   macOS 自带 / https://python.org"
                    ;;
                jq)
                    echo "     jq         → brew install jq"
                    ;;
                lark-cli)
                    echo "     lark-cli   → brew install lark-cli   或   npm install -g @larksuite/cli"
                    ;;
                git)
                    echo "     git        → brew install git"
                    ;;
                *)
                    echo "     $cmd        → brew install $cmd"
                    ;;
            esac
        done
        echo ""
        echo "   装完再重新运行本脚本"
        exit 1
    fi
}
