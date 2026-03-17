# claude-code-statusline

A configurable, segment-based status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows git info, context usage, session cost, model name, and more — right in your terminal.

<!-- TODO: Add screenshot here -->
<!-- ![statusline preview](./screenshot.png) -->

## Features

- **Git branch** — current branch with nerd font icon
- **Dirty files** — count of uncommitted changes (hidden when clean)
- **Ahead/behind** — commits ahead/behind remote tracking branch
- **Model name** — which Claude model is active (Opus, Sonnet, Haiku)
- **Node.js version** — detected from your shell environment
- **Context usage** — color-coded: green (<50%), yellow (50-79%), red (80%+)
- **Session cost** — real cost from Claude Code (not estimated)
- **Session duration** — how long you've been in this session
- **Lines changed** — lines added/removed this session
- **TypeScript errors** — from a cached `tsc` output (non-blocking)
- **Fully configurable** — toggle any segment on/off via a simple array
- **Cross-platform** — works on macOS and Linux

## Quick Install

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

Then restart Claude Code.

## Segments Reference

| Segment | Color | Visible | Data Source |
|---------|-------|---------|-------------|
| `cwd` | White | Always | `json.cwd` |
| `git_branch` | Cyan | In git repos | `git symbolic-ref` |
| `dirty` | Yellow | When > 0 | `git status --porcelain` |
| `ahead_behind` | Yellow | When > 0 | `git rev-list --left-right` |
| `model` | Light purple | When present | `json.model.display_name` |
| `node` | Green | When node is available | `node --version` |
| `context` | Green/Yellow/Red | When present | `json.context_window.used_percentage` |
| `cost` | Magenta | When present | `json.cost.total_cost_usd` |
| `duration` | Blue | When > 0m | `json.cost.total_duration_ms` |
| `lines` | Green/Red | When > 0 | `json.cost.total_lines_added/removed` |
| `ts_errors` | Red | When > 0 (cached) | `/tmp/tsc-errors-<hash>.txt` |

## Customization

### Toggle Segments

Open `~/.claude/statusline.sh` and edit the `ENABLED_SEGMENTS` array at the top:

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

- **[`minimal.sh`](examples/minimal.sh)** — Just branch + context + cost. Clean and fast.
- **[`git-focused.sh`](examples/git-focused.sh)** — Branch, dirty, ahead/behind, last commit age, lines changed. Great for active development.

To use an example, copy it to `~/.claude/` and update your `settings.json` command path.

## TypeScript Errors

The `ts_errors` segment reads from a cache file at `/tmp/tsc-errors-<md5-of-cwd>.txt`. It does **not** run `tsc` itself (that would be too slow for a status line).

To populate the cache, run a background watcher:

```bash
# In your project directory:
while true; do
  count=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
  hash=$(echo -n "$(pwd)" | md5sum 2>/dev/null | awk '{print $1}' || echo -n "$(pwd)" | md5)
  echo "$count" > "/tmp/tsc-errors-${hash}.txt"
  sleep 60
done &
```

The cache is considered stale after 5 minutes and will be ignored.

## Requirements

- **bash** 4.0+
- **jq** — JSON parser ([install](https://jqlang.github.io/jq/download/))
- **git** — for git segments (optional, segments hide gracefully)
- **node** — for the node version segment (optional)

## Troubleshooting

**Nothing shows up:**
- Restart Claude Code after changing `settings.json`
- Check permissions: `chmod +x ~/.claude/statusline.sh`
- Test manually: `echo '{}' | bash ~/.claude/statusline.sh`

**"jq: command not found":**
- Install jq: `brew install jq` (macOS) or `apt install jq` (Ubuntu)

**stat errors on Linux:**
- The script handles both macOS (`stat -f`) and Linux (`stat -c`) automatically. If you see errors, please open an issue.

**Nerd font icons not showing:**
- The git branch icon (``) requires a [Nerd Font](https://www.nerdfonts.com/). If you don't use one, the icon will display as a missing character — you can remove the `\ue0a0` from the `git_branch` printf line.

## License

MIT
