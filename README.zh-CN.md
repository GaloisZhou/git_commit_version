# git_commit_version

[English](README.md) | **简体中文**

在 push 前自动维护 `.version` 并 amend 进最后一次 commit（不单独产生 version commit）。

---

## 快速上手

### 1. 克隆本工具

```bash
git clone https://github.com/GaloisZhou/git_commit_version.git
```

### 2. 安装到业务仓库

```bash
cd /path/to/your-project
~/git_commit_version/install.sh
```

安装完可删除克隆目录；升级时再 clone 并重新执行 `install.sh`。

### 3. 日常 push

安装完成后直接用（无需额外配置）：

```bash
git add .
git commit -m "your message"

git pushv              # 等同 git push（需已设 upstream）
# 或
git ggpushv            # 等同 git push origin $(当前分支)
```

成功时会看到：

```
git-version: .version -> 20260630.143025.12
```

### 4.（可选）继续用 `git push`

若习惯 `git push` 而不是 `git pushv`：

```bash
cd ~/git_commit_version   # 克隆目录
./install-shim.sh
```

把下面一行加入 **你正在用的 shell 配置文件**（不要两个都改，选一个）：

```bash
# 先确认 shell：echo $SHELL
# 输出含 zsh → 改 ~/.zshrc
# 输出含 bash → 改 ~/.bashrc

export PATH="$HOME/.git-commit-version/bin:$PATH"
```

生效方式（二选一）：

```bash
# zsh 用户
source ~/.zshrc

# bash 用户
source ~/.bashrc
```

然后重新打开终端，在**已安装的业务仓库**里 **`git push` 即可**。

Git 图形客户端：将 **Git 可执行文件** 设为 `~/.git-commit-version/bin/git`。

### 验证

```bash
git config --local --get alias.pushv
GIT_VERSION_DEBUG=1 git pushv    # 若装了 shim，也可用 git push
```

应看到：`git-version: wrapper ran, push args=...`

### 5.（可选）oh-my-zsh 继续用 `ggpush`

若你本来用 `ggpush`，可在 **zsh** 的 `~/.zshrc` 里改成：

```bash
alias ggpush='git pushv origin $(git_current_branch)'
# 或: alias ggpush='git ggpushv'
```

改完后 `source ~/.zshrc`，之后用 `ggpush` 即可。bash 用户请直接用步骤 3 的命令。

---

## 详细说明

<details>
<summary><b><code>.version</code> 是什么？</b></summary>

格式：`yyyyMMdd.HHmmss.sequence_no`（例：`20260630.143025.12`）

| 字段 | 说明 |
|------|------|
| `yyyyMMdd.HHmmss` | push 时刻的时间戳 |
| `sequence_no` | 全局递增，从 `0` 开始，不重置 |

</details>

<details>
<summary><b>push 时做了什么？</b></summary>

1. `git fetch` 拉取远端分支
2. 若本地落后，自动 `git rebase`
3. **仅有未 push 的 commit 时**才更新 `.version`
4. `git commit --amend` 把 `.version` 并入最后一次 commit
5. 执行 `git push`；失败则恢复 amend 前的 commit

</details>

<details>
<summary><b>为什么用 <code>git pushv</code> 而不是 <code>git push</code>？</b></summary>

`push` 是 Git **内置子命令**，`alias.push` 不生效（Git 2.x+）。

在 `pre-push` hook 里 amend 也不行：Git 已确定要推的 SHA，外层 push 仍会推旧 commit，导致分叉。

版本更新必须在 **push 协商之前** 完成——通过 `git pushv` 或可选的 git shim。

</details>

<details>
<summary><b>其他 push 方式</b></summary>

| 命令 | 是否维护 .version |
|------|-------------------|
| `git pushv` | ✅ |
| `git ggpushv` | ✅ |
| `git push` | 仅装了 shim 后 ✅ |
| `git push`（无 shim） | ❌ |

终端专用替代（不改 PATH）：

```bash
git() {
  if [ "${1:-}" = "push" ]; then shift; command git pushv "$@"; else command git "$@"; fi
}
```

</details>

<details>
<summary><b>与已有 pre-push hook 的关系</b></summary>

原有 hook 保留为 `.git/hooks/pre-push.user`；安装的 `.git/hooks/pre-push` 只执行 `pre-push.user`。

</details>

<details>
<summary><b>冲突处理</b></summary>

- **同分支 push 前 rebase，仅 `.version` 冲突**：自动取 max(sequence)+1 后继续
- **跨分支 merge（如 `dev` ↔ `qa`），仅 `.version` 冲突**：由 merge driver 自动取 max(sequence)+1
- **其他文件冲突**：仍需手动解决

`install.sh` 会：

1. 把 merge driver 拷到 `.git/git-version/lib/merge-version.sh`
2. 配置本地 `merge.version-max.driver`
3. 写入 / 补全仓库根目录 `.gitattributes`：`.version merge=version-max`

**注意**：`.gitattributes` 需要提交并推送；每位协作者仍需在该仓库执行一次 `install.sh`（driver 脚本和 `git config` 只在本机 `.git` 里）。

</details>

<details>
<summary><b>常见问题</b></summary>

**故意跳过版本维护**

```bash
git push                       # 原生 push
git pushv --no-verify          # 跳过 pre-push.user
```

**`grep usage` 报错** — 多来自 `pre-push.user` 的 tag 脚本，与 `.version` 无关。

**修复旧版导致的分叉**

```bash
git fetch origin && git reset --hard origin/main && git pushv
```

</details>

<details>
<summary><b>卸载</b></summary>

在业务仓库中：

```bash
git config --local --unset alias.pushv
git config --local --unset alias.ggpushv
git config --local --unset alias.push 2>/dev/null
git config --local --unset merge.version-max.name
git config --local --unset merge.version-max.driver
rm -rf .git/git-version
rm .git/hooks/pre-push
# 可选：从 .gitattributes 删掉「.version merge=version-max」那一行
```

</details>

<details>
<summary><b>目录结构</b></summary>

```
git_commit_version/
├── install.sh          # 每个业务仓库执行一次
├── install-shim.sh     # 可选，支持 git push
├── bin/
└── lib/
```

安装后在业务仓库：

```
your-project/.git/git-version/
your-project/.git/config         # alias.pushv
```

</details>

## 许可证

[MIT](LICENSE)
