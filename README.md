# git_commit_version

**English** | [简体中文](README.zh-CN.md)

Auto-update a `.version` file in your project root before push and amend it into the **latest commit** on the current branch—no standalone version commit.

## Overview

### Background

Typical workflow:

1. Edit code
2. `git add`
3. `git commit`
4. push

This tool runs **before step 4**, updates `.version`, and amends it into the last commit.

### Important: use `git pushv`, not `git push`

`push` is a Git **built-in** subcommand; `alias.push` **does not apply** (verified on Git 2.x, including 2.50).

| Command | Updates `.version` |
|---------|-------------------|
| `git pushv` | Yes |
| `git ggpushv` | Yes (push `origin` + current branch) |
| `git push` | No — built-in push, wrapper skipped |

After install, `pushv` and `ggpushv` aliases are registered. If you use oh-my-zsh:

```bash
alias ggpush='git push origin $(git_current_branch)'
```

Change `push` to `pushv`:

```bash
alias ggpush='git pushv origin $(git_current_branch)'
```

Or: `alias ggpush='git ggpushv'`.

### Why not amend only in a pre-push hook?

When `pre-push` runs, Git has already fixed which commit SHA to push. Amending inside the hook causes:

1. Local HEAD gets a new commit (with `.version`)
2. The outer `git push` still pushes the **old** commit
3. Local and remote diverge → conflicts on the next push

Version updates must happen **before push negotiation**, via the `git pushv` wrapper.

### `.version` format

```
yyyyMMdd.HHmmss.sequence_no
```

Example: `20260630.143025.12`

| Field | Description |
|-------|-------------|
| `yyyyMMdd.HHmmss` | Timestamp at push time |
| `sequence_no` | Global increment from `0`, **never resets** |

### What happens on push

1. `git fetch` for the target branch
2. `git rebase origin/<branch>` if local is behind
3. Update `.version` **only when there are unpushed commits** (skip if local matches remote)
4. Take max `sequence_no` from HEAD / remote / working tree, then `git commit --amend`
5. Run `git push`; on failure, **restore the pre-amend commit**

### Conflict handling

- **`.version` only**: auto-resolve with max(sequence)+1, continue rebase
- **Other files**: abort; resolve manually

### Existing pre-push hooks

- Your hook is kept as `.git/hooks/pre-push.user`
- `.git/hooks/pre-push` runs **only** `pre-push.user` (version logic is not in pre-push)

## Layout

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

After install in a project:

```
your-project/.git/git-version/   # copied wrapper + lib
your-project/.git/config         # alias.pushv / alias.ggpushv
your-project/.git/hooks/pre-push # user hook only
```

## Usage

### Install

```bash
# 1. Clone this tool
git clone https://github.com/GaloisZhou/git_commit_version.git

# 2. Go to your project repo
cd /path/to/your-project

# 3. Install (adjust path to your clone)
~/git_commit_version/install.sh
```

Scripts are copied into **your project’s** `.git/git-version/`; `alias.pushv` points there. **You may delete the clone** after install—it is only needed again when upgrading (re-run `install.sh` from a fresh clone).

Verify:

```bash
git config --local --get alias.pushv
GIT_VERSION_DEBUG=1 git pushv
# Expected: git-version: wrapper ran, push args=...
```

### Daily use

In your **project repo**:

```bash
git add .
git commit -m "your message"
git pushv
# or
git ggpushv
```

On success:

```
git-version: .version -> 20260630.143025.12
```

When already up to date:

```
git-version: no unpushed commits, skipping .version update
Everything up-to-date
```

### Run tests

From this tool’s repo root:

```bash
./test_version.sh
```

### Skip version maintenance

```bash
git push              # native push, no .version update
git pushv --no-verify # update .version, skip pre-push.user
```

### `grep usage` errors

Often from a tag-cleanup script in `pre-push.user` (`grep -v ${1}` with empty args when there are no tags). Unrelated to `.version`; safe to ignore.

### Fix divergence from older installs

```bash
git fetch origin
git reset --hard origin/main
git pushv
```

### Uninstall

In your project repo:

```bash
git config --local --unset alias.pushv
git config --local --unset alias.ggpushv
git config --local --unset alias.push 2>/dev/null   # legacy
rm -rf .git/git-version
rm .git/hooks/pre-push
```

## Flow

```
git pushv / ggpushv
    │
    ▼
git-push-with-version.sh
    ├─► fetch / rebase (if behind)
    ├─► no new commits? → skip .version, push
    ├─► has new commits? → write .version + amend
    ▼
git push (built-in, alias disabled)
    ├─► failed? → restore pre-amend
    ├─► pre-push.user (if any)
    ▼
remote updated
```

## License

[MIT](LICENSE)
