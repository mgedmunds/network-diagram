# Claude Code Permissions Guide

This document explains every permission in `.claude/settings.local.json` in plain English.
Each permission tells Claude Code what it can do **without asking you first**.

Review this file periodically — especially after a session where you approved new permissions.

Last reviewed: 2026-06-20

---

## Two-tier structure

Permissions are split across two files:

- **`~/.claude/settings.json`** — global baseline, applies to every project automatically
- **`<project>/.claude/settings.local.json`** — project-specific additions, not committed to git

When Claude Code runs in a project folder, both files are active. Starting a new project means the global baseline is already in place — only project-specific things need to be added.

---

## How to read this document

- **Risk: Low** — read-only, or scoped to a specific known file
- **Risk: Medium** — can run code or modify files in a limited area
- **Risk: High** — broad access; worth reviewing whether still needed

---

## Global baseline (`~/.claude/settings.json`) — all projects

### Search and utilities

| Permission | Plain English | Risk |
|---|---|---|
| `WebSearch` | Search the web | Low |
| `Bash(grep *)` | Search for text within files (read-only) | Low |
| `Bash(apt list *)` | List installed Linux packages (read-only) | Low |

### Git — read-only and safe operations

| Permission | Plain English | Risk |
|---|---|---|
| `Bash(git init *)` | Create a new git repository | Low |
| `Bash(git status)` / `Bash(git status *)` | Show working tree status | Low |
| `Bash(git diff)` / `Bash(git diff *)` | Show file differences | Low |
| `Bash(git log *)` | Show commit history | Low |
| `Bash(git fetch *)` | Download latest changes from GitHub (read-only) | Low |
| `Bash(git pull *)` | Download and apply changes from GitHub | Low |
| `Bash(git merge *)` | Merge branches | Low |
| `Bash(git branch *)` | Create, list, or rename branches | Low |
| `Bash(git remote *)` | View or configure remote connections | Low |

**Not permitted without asking (any project):** `git push`, `git add`, `git commit`, `git reset`, `git checkout --`, force-push, branch delete.

---

## Project-specific (`network-diagram/.claude/settings.local.json`)

### Git — write operations (kept project-specific by choice)

| Permission | Plain English | Risk |
|---|---|---|
| `Bash(git add *)` | Stage files for a commit | Low |
| `Bash(git commit *)` | Save a commit locally | Low |

---

## File reading — Linux (WSL) side

| Permission | Plain English | Risk |
|---|---|---|
| `Read(//usr/**)` | Read R system files and Linux system libraries | Low — system files, read-only |
| `Read(//usr/lib/R/**)` | Read R's built-in package files | Low — redundant with above |
| `Read(//home/claude-dev/.claude/**)` | Read Claude Code's own config and memory files | Low — own config |

---

## File reading — Windows side (via /mnt/c/)

These permissions let Claude read files on your Windows drive from inside WSL.

| Permission | Plain English | Risk |
|---|---|---|
| `Read(//mnt/c/Users/mgedmunds/projects/**)` | Read any file in your Windows projects folder | Medium — covers all projects, but not personal files |
| `Read(//mnt/c/Users/mgedmunds/projects/network-diagram/**)` | Read files in the network-diagram Windows copy | Low — scoped to this project |
| `Read(//mnt/c/Users/mgedmunds/projects/network-diagram/.obsidian/**)` | Read Obsidian config files for this project | Low — scoped to one folder |
| `Read(//mnt/c/Users/mgedmunds/AppData/Local/R/**)` | Read R's package cache on Windows | Low — read-only, R packages only |
| `Read(//mnt/c/Users/mgedmunds/Documents/R/**)` | Read user-installed R packages | Low — read-only, R packages only |

**Not permitted:** Reading OneDrive, Desktop, Downloads, or any other personal Windows folders.

---

## Running code

| Permission | Plain English | Risk |
|---|---|---|
| `Bash(Rscript *)` | Run any R script | Medium — R can read/write files, but scoped to WSL environment |
| `Bash(Rscript -e "source('app.R')")` | Run the Shiny app's R source file specifically | Low — specific command |
| `Bash(Rscript tools/make_template.R)` | Run the template-generation script | Low — specific script |
| `Bash(/usr/bin/env R *)` | Run R via the system path | Medium — same as Rscript |
| `Bash(/mnt/c/Program Files/R/R-4.6.0/bin/Rscript.exe *)` | Run R on the Windows side | Medium — runs as your Windows user |
| `Bash(cmd.exe /c '...')` | Run a specific R check command via Windows CMD | Medium — the full command is locked to a specific R invocation |
| `Bash(python3 *)` | Run any Python script | Medium — Python can read/write files in WSL |
| `Bash(python3 -m json.tool)` | Validate JSON formatting (read-only utility) | Low — specific safe command |

---

## File system operations

| Permission | Plain English | Risk |
|---|---|---|
| `Bash(grep *)` | Search for text within files (read-only) | Low |
| `Bash(chmod +x *)` | Make a file executable | Medium — applies to any file path |
| `Bash(chmod u+w /mnt/c/Users/mgedmunds/projects/network-diagram/.obsidian/community-plugins.json)` | Make one specific Obsidian file writable | Low — locked to one file |
| `Bash(attrib.exe -R "C:\\Users\\mgedmunds\\...")` | Remove read-only flag from one specific Obsidian file on Windows | Low — locked to one file |
| `Bash(mkdir -p /home/claude-dev/projects/network-diagram/poc)` | Create a specific folder in the project | Low — scoped path |
| `Bash(mkdir -p /home/claude-dev/projects/network-diagram/.github/workflows)` | Create the GitHub Actions folder | Low — scoped path |
| `Bash(awk '{print $2}')` | Extract the second column from text output | Low — specific command |
| `Bash(xargs '-I{}' python3 -c ' *)` | Run Python snippets passed through a pipe | Medium — allows arbitrary Python via pipe |
| `Bash(apt list *)` | List installed Linux packages (read-only) | Low |

---

## External and GitHub

| Permission | Plain English | Risk |
|---|---|---|
| `WebSearch` | Search the web | Low — read-only |
| `Bash(gh run *)` | View GitHub Actions run status | Low — read-only GitHub CLI command |
| `Skill(run)` | Use the built-in `/run` skill to launch the app | Low — invokes a defined skill |

---

## Explicit deny list — blocked globally, always

These are hard-blocked in `~/.claude/settings.json` and cannot run without your approval, even if accidentally added to an allow list in future:

| Denied command | Why |
|---|---|
| ~~`git push *`~~ | Removed from deny list — push will prompt for approval but is not hard-blocked |
| `git reset *` | Prevents discarding commits or unstaging all files |
| `git checkout -- *` | Prevents discarding uncommitted file changes |
| `git clean *` | Prevents deleting untracked files |
| `git rebase *` | Prevents rewriting commit history |

## What Claude cannot do without asking

- Push to GitHub
- Reset, rebase, or discard git history (all hard-blocked above)
- Delete any file
- Run PowerShell (removed 2026-06-20)
- Read personal Windows folders outside projects/ (OneDrive, Desktop, Documents outside R — removed 2026-06-20)
- Install packages
- Create or modify files outside the project folder (except the specific Windows paths above)
- Make network requests other than web search

---

## Review checklist

When reviewing this file, ask for each permission:
1. Is this still needed, or was it added for a one-off task?
2. Is the scope as narrow as it can be?
3. Would I be comfortable if this ran without me noticing?
