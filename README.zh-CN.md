# git_commit_version

[English](README.md) | **简体中文**

在 push 前自动维护业务仓库根目录的 `.version` 文件，并将变更并入**当前分支最后一个 commit**（不单独产生 version commit）。

## 说明

### 背景

正常开发流程：

1. 修改代码
2. `git add`
3. `git commit`
4. push

本工具在 **第 4 步 push 之前** 自动更新 `.version` 并 amend 进最后一次 commit。

### 重要：请用 `git pushv`，不要用 `git push`

`push` 是 Git **内置子命令**，`alias.push` **不会生效**（Git 2.x 实测，含 2.50）。因此：

| 命令 | 是否维护 .version |
|------|-------------------|
| `git pushv` | ✅ |
| `git ggpushv` | ✅（push origin 当前分支） |
| `git push` | ❌ 走内置 push，wrapper 不执行 |

安装后会注册 `pushv` / `ggpushv` 两个 alias。若你原来用 oh-my-zsh 的：

```bash
alias ggpush='git push origin $(git_current_branch)'
```

请改成（只把 `push` 换成 `pushv`）：

```bash
alias ggpush='git pushv origin $(git_current_branch)'
```

这样习惯不变，但会走版本 wrapper。也可用 `alias ggpush='git ggpushv'`。

### 为什么不能只在 pre-push hook 里 amend？

`pre-push` 运行时 Git 已确定要推送的 commit SHA。在 hook 里 amend 会导致：

1. 本地 HEAD 含 `.version`（新 commit）
2. 外层 push 仍推旧 commit
3. 本地与远端分叉 → 下次必冲突

因此版本更新必须在 **push 协商之前** 完成，由 `git pushv` 调用 wrapper 实现。

### `.version` 格式

```
yyyyMMdd.HHmmss.sequence_no
```

示例：`20260630.143025.12`

| 字段 | 说明 |
|------|------|
| `yyyyMMdd.HHmmss` | push 时刻的时间戳 |
| `sequence_no` | 全局递增，从 `0` 开始，**不重置** |

### push 时做了什么

1. `git fetch` 拉取远端当前分支
2. 若本地落后，`git rebase origin/<branch>`
3. **仅当本地有尚未 push 的 commit 时**才更新 `.version`（本地已与远端一致则跳过）
4. 取 HEAD / 远端 / 工作区 `.version` 的最大 `sequence_no + 1`，`git commit --amend`
5. 执行 `git push`；若 push 失败，**自动恢复 amend 前**的 commit

### 冲突处理

- **仅 `.version` 冲突**：自动取 max(sequence)+1 后继续 rebase
- **其他文件冲突**：中止，需手动解决

### 与已有 pre-push hook 的关系

- 已有 hook 保留为 `.git/hooks/pre-push.user`
- `.git/hooks/pre-push` **仅**执行 `pre-push.user`（版本维护不在 pre-push 中）

## 目录结构

```
git_commit_version/
├── LICENSE
├── README.md
├── README.zh-CN.md
├── install.sh
├── test_version.sh
├── bin/git-push-with-version.sh
├── lib/version.sh
└── lib/push_prepare.sh
```

安装到业务仓库后：

```
your-project/.git/git-version/   # wrapper 与 lib（由 install 复制）
your-project/.git/config         # alias.pushv / alias.ggpushv
your-project/.git/hooks/pre-push # 仅用户 hook
```

## 使用

### 安装

```bash
# 1. 克隆本工具
git clone https://github.com/GaloisZhou/git_commit_version.git

# 2. 进入你的业务仓库
cd /path/to/your-project

# 3. 安装（将 ~/git_commit_version 换成实际克隆路径）
~/git_commit_version/install.sh
```

脚本会复制到**业务仓库**的 `.git/git-version/`，`alias.pushv` 也指向该目录。**安装完成后可以删除克隆目录**；只有升级本工具时才需要重新克隆并再执行一次 `install.sh`。

验证：

```bash
git config --local --get alias.pushv
GIT_VERSION_DEBUG=1 git pushv
# 应看到: git-version: wrapper ran, push args=...
```

### 日常使用

在**业务仓库**中：

```bash
git add .
git commit -m "your message"
git pushv
# 或
git ggpushv
```

成功时输出：

```
git-version: .version -> 20260630.143025.12
```

本地已与远端一致、无新提交时：

```
git-version: no unpushed commits, skipping .version update
Everything up-to-date
```

### 运行测试

在本工具仓库根目录：

```bash
./test_version.sh
```

### 跳过版本维护

```bash
git push                       # 原生 push，不更新 .version
git pushv --no-verify          # 更新 .version，跳过 pre-push.user
```

### grep usage 报错

来自 `pre-push.user` 的 tag 清理脚本（`grep -v ${1}` 在 tag 为空时报错），**与 .version 无关**，可忽略。

### 修复旧版导致的分叉

```bash
git fetch origin
git reset --hard origin/main
git pushv
```

### 卸载

在业务仓库中执行：

```bash
git config --local --unset alias.pushv
git config --local --unset alias.ggpushv
git config --local --unset alias.push 2>/dev/null   # 旧版残留
rm -rf .git/git-version
rm .git/hooks/pre-push
```

## 流程示意

```
git pushv / ggpushv
    │
    ▼
git-push-with-version.sh
    ├─► fetch / rebase（若落后）
    ├─► 无新提交？→ 跳过 .version，直接 push
    ├─► 有新提交？→ 写入 .version + amend
    ▼
git push（内置，alias 已禁用）
    ├─► 失败？→ 恢复 amend 前
    ├─► pre-push.user（若有）
    ▼
推送到远端
```

## 许可证

[MIT](LICENSE)
