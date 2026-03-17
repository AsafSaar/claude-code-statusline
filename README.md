# claude-code-statusline

A configurable, segment-based status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows git info, context usage, session cost, model name, and more — right in your terminal.

<!-- TODO: Add screenshot here -->
<!-- ![statusline preview](./screenshot.png) -->

## Features

- **Rich icons** — each segment has a dedicated icon (📂 🧠 🔋 💰 ⏱ ✏ ⚠ and more)
- **Git branch** — current branch with nerd font icon
- **Dirty files** — ● count of uncommitted changes (hidden when clean)
- **Ahead/behind** — ↑↓ commits ahead/behind remote tracking branch
- **Model name** — 🧠 which Claude model is active (Opus, Sonnet, Haiku)
- **Node.js version** — ⬢ detected from your shell environment
- **Context usage** — 🔋 color-coded: green (<50%), yellow (50-79%), red (80%+)
- **Session cost** — 💰 real cost from Claude Code (not estimated)
- **Session duration** — ⏱ how long you've been in this session (with seconds)
- **Lines changed** — ✏ lines added/removed this session
- **TypeScript errors** — ⚠ from a cached `tsc` output (non-blocking)
- **Fully configurable** — toggle any segment on/off via a simple array
- **Cross-platform** — works on macOS, Linux, and Windows

## Quick Install

### macOS / Linux

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/install.sh | bash
```

**Manual:**

```bash
# 1. Copy the script
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# 2. Add to ~/.claude/settings.json
# (create the file if it doesn't exist)
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

### Windows (PowerShell)

**One-liner:**

```powershell
irm https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/install.ps1 | iex
```

**Manual:**

```powershell
# 1. Copy the script
Copy-Item statusline.ps1 "$env:USERPROFILE\.claude\statusline.ps1"

# 2. Add to ~/.claude/settings.json
# (create the file if it doesn't exist)
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "pwsh -NoProfile -File C:\\Users\\YourName\\.claude\\statusline.ps1"
  }
}
```

> **Note:** Replace `YourName` with your Windows username, or use the install script which sets the path automatically. Requires [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`). Windows PowerShell 5.1 (`powershell.exe`) also works — replace `pwsh` with `powershell` in the command.

Then restart Claude Code.

## Segments Reference

| Segment | Icon | Color | Visible | Data Source |
|---------|------|-------|---------|-------------|
| `cwd` | 📂 | White | Always | `json.cwd` |
| `git_branch` | `` | Cyan | In git repos | `git symbolic-ref` |
| `dirty` | ● | Yellow | When > 0 | `git status --porcelain` |
| `ahead_behind` | ↑↓ | Yellow | When > 0 | `git rev-list --left-right` |
| `model` | 🧠 | Light purple | When present | `json.model.display_name` |
| `node` | ⬢ | Green | When node is available | `node --version` |
| `context` | 🔋 | Green/Yellow/Red | When present | `json.context_window.used_percentage` |
| `cost` | 💰 | Magenta | When present | `json.cost.total_cost_usd` |
| `duration` | ⏱ | Blue | When > 0s | `json.cost.total_duration_ms` |
| `lines` | ✏ | Green/Red | When > 0 | `json.cost.total_lines_added/removed` |
| `ts_errors` | ⚠ | Red | When > 0 (cached) | `/tmp/tsc-errors-<hash>.txt` |

## Customization

### Toggle Segments

**macOS/Linux** — open `~/.claude/statusline.sh` and edit the `ENABLED_SEGMENTS` array at the top:

```bash
ENABLED_SEGMENTS=(
  "cwd"
  "git_branch"
  # "dirty"         # commented out = disabled
  # "ahead_behind"
  "model"
  # "node"
  "context"
  "cost"
  "duration"
  # "lines"
  # "ts_errors"
)
```

**Windows** — open `~/.claude/statusline.ps1` and edit the `$EnabledSegments` array at the top:

```powershell
$EnabledSegments = @(
    "cwd"
    "git_branch"
    # "dirty"         # commented out = disabled
    # "ahead_behind"
    "model"
    # "node"
    "context"
    "cost"
    "duration"
    # "lines"
    # "ts_errors"
)
```

### Change Separator

The separator between segments defaults to a dimmed `|` pipe. Edit the `SEP` variable at the top of the script:

```bash
SEP=$' \033[90m|\033[0m '   # default: dimmed pipe
SEP="  "                    # two spaces (no separator)
SEP=" | "                   # bright pipe
```

### Customize Icons

Icons are defined as variables in the `ICONS` section near the top of `statusline.sh`:

```bash
ICON_CWD="📂"
ICON_DIRTY="●"
ICON_MODEL="🧠"
ICON_NODE="⬢"
ICON_CONTEXT="🔋"
ICON_COST="💰"
ICON_DURATION="⏱"
ICON_LINES="✏"
ICON_TS_ERRORS="⚠"
```

Replace any icon with your preferred Unicode character or emoji, or set to `""` to remove it.

### Change Colors

Each segment uses ANSI escape codes. Find the `printf` line for any segment and change the color code:

| Code | Color |
|------|-------|
| `\033[31m` | Red |
| `\033[32m` | Green |
| `\033[33m` | Yellow |
| `\033[34m` | Blue |
| `\033[35m` | Magenta |
| `\033[36m` | Cyan |
| `\033[37m` | White |
| `\033[38;5;Nm` | 256-color (replace N) |

### Add Your Own Segment

1. Add a name to `ENABLED_SEGMENTS`
2. Add a section that sets `seg_yourname` (follow the pattern of existing segments)
3. Add `[[ -n "$seg_yourname" ]] && parts+=("$seg_yourname")` in the assembly block

## Claude Code JSON Input

The status line receives a JSON object on stdin from Claude Code. Key fields used:

| Field | Type | Description |
|-------|------|-------------|
| `cwd` | string | Current working directory |
| `model.display_name` | string | Active model (e.g. "Opus", "Sonnet") |
| `context_window.used_percentage` | number | Context window usage (0-100) |
| `cost.total_cost_usd` | number | Cumulative session cost in USD |
| `cost.total_duration_ms` | number | Session duration in milliseconds |
| `cost.total_lines_added` | number | Lines added this session |
| `cost.total_lines_removed` | number | Lines removed this session |

## Examples

Two example variants are included in the `examples/` directory:

**Bash (macOS/Linux):**
- **[`minimal.sh`](examples/minimal.sh)** — Just branch + context + cost. Clean and fast.
- **[`git-focused.sh`](examples/git-focused.sh)** — Branch, dirty, ahead/behind, last commit age, lines changed. Great for active development.

**PowerShell (Windows):**
- **[`minimal.ps1`](examples/minimal.ps1)** — Just branch + context + cost. Clean and fast.
- **[`git-focused.ps1`](examples/git-focused.ps1)** — Branch, dirty, ahead/behind, last commit age, lines changed. Great for active development.

To use an example, copy it to `~/.claude/` and update your `settings.json` command path.

## TypeScript Errors

The `ts_errors` segment reads from a cache file at `/tmp/tsc-errors-<md5-of-cwd>.txt`. It does **not** run `tsc` itself (that would be too slow for a status line).

To populate the cache, run a background watcher:

**macOS/Linux:**

```bash
# In your project directory:
while true; do
  count=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
  if command -v md5sum &>/dev/null; then
    hash=$(echo -n "$(pwd)" | md5sum | awk '{print $1}')
  else
    hash=$(echo -n "$(pwd)" | md5)
  fi
  echo "$count" > "/tmp/tsc-errors-${hash}.txt"
  sleep 60
done &
```

**Windows (PowerShell):**

```powershell
# In your project directory:
while ($true) {
    $count = (npx tsc --noEmit 2>&1 | Select-String "error TS").Count
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes((Get-Location).Path)
    $hash = ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
    $count | Set-Content "$env:TEMP\tsc-errors-$hash.txt"
    Start-Sleep -Seconds 60
}
```

The cache is considered stale after 5 minutes and will be ignored.

## Requirements

**macOS/Linux:**
- **bash** 4.0+
- **jq** — JSON parser ([install](https://jqlang.github.io/jq/download/))
- **git** — for git segments (optional, segments hide gracefully)
- **node** — for the node version segment (optional)

**Windows:**
- **PowerShell** 5.1+ (pre-installed) or [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) (recommended)
- **git** — for git segments (optional, segments hide gracefully)
- **node** — for the node version segment (optional)
- No `jq` dependency — Windows version uses built-in `ConvertFrom-Json`

## Troubleshooting

**Nothing shows up:**
- Restart Claude Code after changing `settings.json`
- macOS/Linux: Check permissions: `chmod +x ~/.claude/statusline.sh`
- macOS/Linux: Test manually: `echo '{}' | bash ~/.claude/statusline.sh`
- Windows: Test manually: `'{}' | pwsh -NoProfile -File ~/.claude/statusline.ps1`

**"jq: command not found" (macOS/Linux only):**
- Install jq: `brew install jq` (macOS) or `apt install jq` (Ubuntu)

**stat errors on Linux:**
- The script handles both macOS (`stat -f`) and Linux (`stat -c`) automatically. If you see errors, please open an issue.

**Windows: "execution of scripts is disabled":**
- Run: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
- Or use the `-ExecutionPolicy Bypass` flag: `pwsh -ExecutionPolicy Bypass -NoProfile -File ~/.claude/statusline.ps1`

**Nerd font icons not showing:**
- The git branch icon (``) requires a [Nerd Font](https://www.nerdfonts.com/). If you don't use one, the icon will display as a missing character — you can remove the `\ue0a0` from the `git_branch` printf line.

## Contributing

PRs welcome. If you add a new segment, please include it in the segments reference table in this README.

## License

MIT
