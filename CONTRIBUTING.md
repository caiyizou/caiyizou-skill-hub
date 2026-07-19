# Contributing

感谢考虑为 **caiyizou-skill-hub** 做贡献。本 skill 是供自己用+分享给朋友的小型工具，规则很简单。

## 三步开始

1. **Fork** 本仓库到你自己的 GitHub 账号
2. **Clone** fork 后的仓库到本地
3. **改**你 fork 后仓库里的内容

提交 PR 前必看：§改完必跑

---

## 🍴 Fork 后必改

如果你 fork 了再发到自己的 GitHub，**全局替换 3 处**：

| 占位符 | 你的值 |
|--------|--------|
| `https://github.com/caiyizou/caiyizou-skill-hub` | 你 fork 后的仓库 URL |
| `Caiyi zou <caiyizou@...>` | 你的 git config user.name + user.email |
| skill 名称 `caiyizou-skill-hub` | 你自己的标识符（建议 `<you>-skill-hub`） |

最简单：VSCode / Cursor 全局搜索 `caiyizou` 替换。

---

## 改完必跑

PR / merge 前请执行：

```bash
# 1. 检测脚本语法
bash -n scripts/setup.sh
bash -n scripts/archive.sh
bash -n scripts/uninstall.sh
bash -n scripts/pre-publish-clean.sh
bash -n scripts/add-field.sh

# 2. 扫描个人配置（防误推 token）
bash scripts/pre-publish-clean.sh . --apply

# 3. pre-publish-clean 会自动备份 *.bak.* —— 提交前确保这些 *.bak.* 没进 git
ls *.bak.* 2>/dev/null && rm *.bak.* 2>/dev/null
```

如果扫描出 ⚠️ 项未处理，**git push 前一定要手动删干净**。

---

## 提交规范

- commit message 用中文 + Conventional Commits 风格：
  - `feat: xxx`
  - `fix: xxx`
  - `docs: xxx`
  - `refactor: xxx`
- 每次 release 在 `CHANGELOG.md` 顶部加条目（按 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式）
- PR 标题：`[vX.Y.Z] 一句话改动`（与 CHANGELOG 同步）

---

## 不要做的事

- ❌ 不要把 base-token / table-id / wiki URL / 邮箱硬编码进 skill 文件
- ❌ 不要把 `~/.config/caiyizou-skill-hub/env` 的内容 commit
- ❌ 不要把 `*.bak.*` 备份文件 commit
- ❌ 不要 fork 后忘记替换 `caiyizou` 标识符再发自己 GitHub

---

## 报告 bug

GitHub Issue 写 3 件事：
1. 你用什么 AI agent（Claude Code / Codex / Cursor / Gemini CLI）
2. 你跑哪条命令挂了（setup / install / create / archive / uninstall）
3. 完整报错输出（不要只贴第一行）
