#!/usr/bin/env python3
"""caiyizou-skill-hub 模板渲染（v1.6 智能检测）

按模板内容自动决定剥离项：
- 若模板里含 HTML 注释（<!-- ... -->）→ 全部剥离
- 若模板里含「## 📚 附录」段        → 剥离到文件末尾
- 占位符 {skill-name} / {version} / {category} / {skill-command} / {日期} / {时间} 等全替换

用法：python3 _render-guide.py <tpl_path> <output_path> --skill-name X --version Y ...
"""

import argparse
import re
import sys
from pathlib import Path


def render(template: str, values: dict) -> str:
    # 占位符替换（{xxx} 形式 + 中文键名）
    for key, val in values.items():
        template = template.replace("{" + key + "}", val)

    # 智能判断：只在含 HTML 注释时才剥离
    if re.search(r"<!--.*?-->", template, flags=re.DOTALL):
        template = re.sub(r"<!--.*?-->", "", template, flags=re.DOTALL)

    # 智能判断：只在含「附录：章节更新方式速查」段时才剥离
    if "附录：章节更新方式速查" in template:
        template = re.sub(r"\n## 📚 附录.*$", "", template, flags=re.DOTALL)

    # 多余空行压缩（最多连续 2 个换行）
    template = re.sub(r"\n{3,}", "\n\n", template)

    return template.strip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tpl", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--skill-name", required=True)
    parser.add_argument("--skill-command", default="")
    parser.add_argument("--version", default="1.0.0")
    parser.add_argument("--category", default="开发工具")
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args()

    if not args.tpl.exists():
        print(f"❌ 模板不存在：{args.tpl}", file=sys.stderr)
        return 1

    content = args.tpl.read_text(encoding="utf-8")

    values = {
        "skill-name": args.skill_name,
        "skill-command": args.skill_command or args.skill_name,
        "version": args.version,
        "当前版本": args.version,
        "category": args.category,
        "分类": args.category,
        "功能分类": args.category,
        "created": args.date,
        "updated": args.date,
        "创建日期": args.date,
        "最后更新": args.date,
        "YYYY-MM-DD": args.date,
        "YYYY-MM-DD HH:mm": f"{args.date} 00:00",
    }

    rendered = render(content, values)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"   📝 {len(content)} → {len(rendered)} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
