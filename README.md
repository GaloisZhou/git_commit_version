# git_commit_version

**English** | [简体中文](README.zh-CN.md)

Auto-update a `.version` file before push and amend it into the latest commit (no extra version commit).

---

## Quick start

### 1. Clone this tool

```bash
git clone https://github.com/GaloisZhou/git_commit_version.git
```

### 2. Install into your project

```bash
cd /path/to/your-project
~/git_commit_version/install.sh
```

You can delete the clone after install. Re-clone and re-run `install.sh` only when upgrading.

### 3. Daily push

Works immediately after install (no extra setup):

```bash
git add .
git commit -m "your message"

git pushv              # like git push (needs upstream)
# or
git ggpushv            # like git push origin $(current branch)
```

Success looks like:

```
git-version: .version -> 20260630.143025.12
```

### 4. (Optional) Use plain `git push`

If you prefer `git push` instead of `git pushv`:

```bash
cd ~/git_commit_version   # or wherever you cloned
./install-shim.sh
```

Add this line to **your shell config file** (pick one, not both):

```bash
# Check your shell first: echo $SHELL
# contains zsh → edit ~/.zshrc
# contains bash → edit ~/.bashrc

export PATH="$HOME/.git-commit-version/bin:$PATH"
```

Reload (pick one):

```bash
# zsh
source ~/.zshrc

# bash
source ~/.bashrc
```

Open a new terminal, then **`git push` works** in any repo where step 2 was done.

For Git GUI apps, set **Git executable** to `~/.git-commit-version/bin/git`.

### Verify

```bash
git config --local --get alias.pushv
GIT_VERSION_DEBUG=1 git pushv    # or: git push (if shim installed)
```

Expected: `git-version: wrapper ran, push args=...`

### 5. (Optional) Keep using oh-my-zsh `ggpush`

If you already use `ggpush`, update **zsh** `~/.zshrc`:

```bash
alias ggpush='git pushv origin $(git_current_branch)'
# or: alias ggpush='git ggpushv'
```

Run `source ~/.zshrc`, then use `ggpush`. bash users: stick to step 3 commands.

---

## Details

<details>
<summary><b>What is <code>.version</code>?</b></summary>

Format: `yyyyMMdd.HHmmss.sequence_no` (example: `20260630.143025.12`)

| Field | Description |
|-------|-------------|
| `yyyyMMdd.HHmmss` | Timestamp at push time |
| `sequence_no` | Global increment from `0`, never resets |

</details>

<details>
<summary><b>What happens on push?</b></summary>

1. `git fetch` for the target branch
2. `git rebase` if local is behind remote
3. Update `.version` only when there are **unpushed commits**
4. `git commit --amend` to include `.version` in the last commit
5. `git push`; on failure, restore the pre-amend commit

</details>

<details>
<summary><b>Why <code>git pushv</code> instead of <code>git push</code>?</b></summary>

`push` is a Git **built-in** subcommand; `alias.push` does not apply (Git 2.x+).

Amending inside a `pre-push` hook also fails: Git already fixed the SHA to push, so the outer push would still send the old commit and cause divergence.

Version updates must run **before push negotiation** — via `git pushv` or the optional git shim.

</details>

<details>
<summary><b>Other ways to invoke push</b></summary>

| Command | Updates `.version` |
|---------|-------------------|
| `git pushv` | Yes |
| `git ggpushv` | Yes (`origin` + current branch) |
| `git push` | Only with shim (step 4) |
| `git push` (no shim) | No |

Shell wrapper alternative (terminal only, no PATH change):

```bash
git() {
  if [ "${1:-}" = "push" ]; then shift; command git pushv "$@"; else command git "$@"; fi
}
```

</details>

<details>
<summary><b>Existing pre-push hooks</b></summary>

Your hook is kept as `.git/hooks/pre-push.user`. The installed `.git/hooks/pre-push` runs only `pre-push.user`.

</details>

<details>
<summary><b>Conflict handling</b></summary>

- **`.version` only**: auto max(sequence)+1, continue rebase
- **Other files**: abort; resolve manually

</details>

<details>
<summary><b>Troubleshooting</b></summary>

**Skip version update on purpose**

```bash
git push              # native push, no .version
git pushv --no-verify # update .version, skip pre-push.user
```

**`grep usage` errors** — often from a tag script in `pre-push.user`; unrelated to `.version`.

**Fix divergence from older installs**

```bash
git fetch origin && git reset --hard origin/main && git pushv
```

</details>

<details>
<summary><b>Uninstall</b></summary>

In your project repo:

```bash
git config --local --unset alias.pushv
git config --local --unset alias.ggpushv
git config --local --unset alias.push 2>/dev/null
rm -rf .git/git-version
rm .git/hooks/pre-push
```

</details>

<details>
<summary><b>Project layout</b></summary>

```
git_commit_version/
├── install.sh          # run in each project repo
├── install-shim.sh     # optional, for plain git push
├── bin/
└── lib/
```

After install in a project:

```
your-project/.git/git-version/   # copied scripts
your-project/.git/config         # alias.pushv / alias.ggpushv
```

</details>

## License

[MIT](LICENSE)
