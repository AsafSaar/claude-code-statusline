#!/usr/bin/env bash
# claude-code-statusline — A rich status line for Claude Code
# https://github.com/AsafSaar/claude-code-statusline
#
# Reads JSON from stdin (provided by Claude Code) and outputs a
# colorized, segment-based status line.
#
# Segments can be toggled by commenting out entries in ENABLED_SEGMENTS below.

set -euo pipefail

# ============================================================================
# CONFIGURATION — comment out any segment you don't want
# ============================================================================
ENABLED_SEGMENTS=(
  "cwd"           # Current directory basename
  "git_branch"    # Git branch name
  "dirty"         # Uncommitted file count
  "ahead_behind"  # Commits ahead/behind remote
  "model"         # Active model name
  "node"          # Node.js version
  "context"       # Context window usage %
  "cost"          # Session cost (from Claude Code)
  "duration"      # Session duration (from Claude Code)
  "lines"         # Lines added/removed this session
  "ts_errors"     # TypeScript errors (cached)
  "last_commit"   # Time since last git commit (green/yellow/red)
  "stash"         # Number of stashed changesets
  "effort"        # Reasoning effort level (low/medium/high/xhigh/max)
  "rate_limits"   # Claude.ai 5h/7d rate-limit usage %
)

# Separator between segments (dimmed pipe)
SEP=$' \033[90m|\033[0m '

# ============================================================================
# ICONS — Unicode characters for each segment
# ============================================================================
ICON_CWD="📂"
ICON_DIRTY="●"
ICON_MODEL="🧠"
ICON_NODE="⬢"
ICON_CONTEXT="🔋"
ICON_COST="💰"
ICON_DURATION="⏱"
ICON_LINES="✏"
ICON_TS_ERRORS="⚠"
ICON_LAST_COMMIT="⏰"
ICON_STASH="📦"
ICON_EFFORT="🎚"
ICON_RATE_LIMIT="⏳"

# ============================================================================
# HELPERS
# ============================================================================
segment_enabled() {
  local name="$1"
  for s in "${ENABLED_SEGMENTS[@]}"; do
    [[ "$s" == "$name" ]] && return 0
  done
  return 1
}

# Cross-platform file mtime (seconds since epoch)
file_mtime() {
  if stat -c %Y "$1" &>/dev/null; then
    stat -c %Y "$1"  # Linux / GNU stat
  else
    stat -f %m "$1" 2>/dev/null  # macOS / BSD stat
  fi
}

# Cross-platform md5 hash
portable_md5() {
  if command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | awk '{print $1}'
  else
    echo -n "$1" | md5
  fi
}

# ============================================================================
# READ INPUT
# ============================================================================
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')

# ============================================================================
# SEGMENT: cwd
# ============================================================================
seg_cwd=""
if segment_enabled "cwd" && [[ -n "${cwd:-}" ]]; then
  seg_cwd=$(printf '\033[37m%s %s\033[0m' "$ICON_CWD" "$(basename "$cwd")")
fi

# ============================================================================
# SEGMENT: git_branch
# ============================================================================
seg_git_branch=""
git_branch=""
if segment_enabled "git_branch" && [[ -n "${cwd:-}" ]]; then
  git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
  if [[ -n "$git_branch" ]]; then
    seg_git_branch=$(printf '\033[36m\xee\x82\xa0 %s\033[0m' "$git_branch")
  fi
fi

# ============================================================================
# SEGMENT: dirty
# ============================================================================
seg_dirty=""
if segment_enabled "dirty" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  dirty_count=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$dirty_count" -gt 0 ]]; then
    seg_dirty=$(printf '\033[33m%s %s dirty\033[0m' "$ICON_DIRTY" "$dirty_count")
  fi
fi

# ============================================================================
# SEGMENT: ahead_behind
# ============================================================================
seg_ahead_behind=""
if segment_enabled "ahead_behind" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  ab=$(git --no-optional-locks -C "$cwd" rev-list --count --left-right HEAD...@{u} 2>/dev/null || true)
  if [[ -n "$ab" ]]; then
    ahead=$(echo "$ab" | awk '{print $1}')
    behind=$(echo "$ab" | awk '{print $2}')
    if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
      seg_ahead_behind=$(printf '\033[33m\xe2\x86\x91%s \xe2\x86\x93%s\033[0m' "$ahead" "$behind")
    fi
  fi
fi

# ============================================================================
# SEGMENT: model
# ============================================================================
seg_model=""
if segment_enabled "model"; then
  model_name=$(echo "$input" | jq -r '.model.display_name // empty')
  if [[ -n "${model_name:-}" ]]; then
    seg_model=$(printf '\033[38;5;147m%s %s\033[0m' "$ICON_MODEL" "$model_name")
  fi
fi

# ============================================================================
# SEGMENT: node
# ============================================================================
seg_node=""
if segment_enabled "node"; then
  raw_node=$(node --version 2>/dev/null || true)
  if [[ -n "${raw_node:-}" ]]; then
    seg_node=$(printf '\033[32m%s %s\033[0m' "$ICON_NODE" "${raw_node#v}")
  fi
fi

# ============================================================================
# SEGMENT: context
# ============================================================================
seg_context=""
if segment_enabled "context"; then
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  if [[ -n "${used_pct:-}" ]]; then
    pct_int=$(printf '%.0f' "$used_pct")
    if [[ "$pct_int" -ge 80 ]]; then
      ctx_color='\033[31m'   # red
    elif [[ "$pct_int" -ge 50 ]]; then
      ctx_color='\033[33m'   # yellow
    else
      ctx_color='\033[32m'   # green
    fi
    # Build 10-char progress bar (filled=█ U+2588, empty=▒ U+2592)
    bar_width=10
    filled=$(( pct_int * bar_width / 100 ))
    empty=$(( bar_width - filled ))
    filled_bar=""
    empty_bar=""
    for ((i=0; i<filled; i++)); do filled_bar+=$(printf '\xe2\x96\x88'); done
    for ((i=0; i<empty; i++)); do empty_bar+=$(printf '\xe2\x96\x92'); done
    seg_context=$(printf "${ctx_color}%s %s\033[90m%s${ctx_color} %s%%\033[0m" "$ICON_CONTEXT" "$filled_bar" "$empty_bar" "$pct_int")
  fi
fi

# ============================================================================
# SEGMENT: cost (native from Claude Code JSON)
# ============================================================================
seg_cost=""
if segment_enabled "cost"; then
  total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
  if [[ -n "${total_cost:-}" ]]; then
    formatted_cost=$(awk -v c="$total_cost" 'BEGIN { printf "%.3f", c }')
    seg_cost=$(printf '\033[35m%s $%s\033[0m' "$ICON_COST" "$formatted_cost")
  fi
fi

# ============================================================================
# SEGMENT: duration (native from Claude Code JSON)
# ============================================================================
seg_duration=""
if segment_enabled "duration"; then
  duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
  if [[ -n "${duration_ms:-}" ]]; then
    elapsed=$(( ${duration_ms%.*} / 1000 ))
    h=$(( elapsed / 3600 ))
    m=$(( (elapsed % 3600) / 60 ))
    s=$(( elapsed % 60 ))
    if [[ "$h" -gt 0 ]]; then
      seg_duration=$(printf '\033[34m%s %sh%sm\033[0m' "$ICON_DURATION" "$h" "$m")
    elif [[ "$m" -gt 0 ]]; then
      seg_duration=$(printf '\033[34m%s %sm%ss\033[0m' "$ICON_DURATION" "$m" "$s")
    elif [[ "$s" -gt 0 ]]; then
      seg_duration=$(printf '\033[34m%s %ss\033[0m' "$ICON_DURATION" "$s")
    fi
  fi
fi

# ============================================================================
# SEGMENT: lines added/removed
# ============================================================================
seg_lines=""
if segment_enabled "lines"; then
  lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
  lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
  if [[ "$lines_added" -gt 0 ]] || [[ "$lines_removed" -gt 0 ]]; then
    seg_lines=$(printf '\033[32m%s +%s\033[0m/\033[31m-%s\033[0m' "$ICON_LINES" "$lines_added" "$lines_removed")
  fi
fi

# ============================================================================
# SEGMENT: ts_errors (cached, non-blocking)
# ============================================================================
seg_ts_errors=""
if segment_enabled "ts_errors" && [[ -n "${cwd:-}" ]]; then
  cwd_hash=$(portable_md5 "$cwd")
  cache_file="/tmp/tsc-errors-${cwd_hash}.txt"
  if [[ -f "$cache_file" ]]; then
    cache_mtime=$(file_mtime "$cache_file")
    now_ts=$(date +%s)
    age=$(( now_ts - cache_mtime ))
    if [[ "$age" -le 300 ]]; then
      ts_err=$(head -1 "$cache_file" 2>/dev/null | tr -d ' ')
      if [[ -n "${ts_err:-}" ]] && [[ "$ts_err" -gt 0 ]] 2>/dev/null; then
        seg_ts_errors=$(printf '\033[31m%s TS:%s\033[0m' "$ICON_TS_ERRORS" "$ts_err")
      fi
    fi
  fi
fi

# ============================================================================
# SEGMENT: last_commit
# ============================================================================
seg_last_commit=""
if segment_enabled "last_commit" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  last_ts=$(git --no-optional-locks -C "$cwd" log -1 --format=%ct 2>/dev/null || true)
  if [[ -n "${last_ts:-}" ]]; then
    now_ts=$(date +%s)
    age=$(( now_ts - last_ts ))
    if [[ "$age" -lt 60 ]]; then
      age_str="${age}s ago"
    elif [[ "$age" -lt 3600 ]]; then
      age_str="$(( age / 60 ))m ago"
    elif [[ "$age" -lt 86400 ]]; then
      age_str="$(( age / 3600 ))h ago"
    else
      age_str="$(( age / 86400 ))d ago"
    fi
    if [[ "$age" -ge 7200 ]]; then
      lc_color='\033[31m'   # red   > 2h
    elif [[ "$age" -ge 1800 ]]; then
      lc_color='\033[33m'   # yellow > 30min
    else
      lc_color='\033[32m'   # green
    fi
    seg_last_commit=$(printf "${lc_color}%s %s\033[0m" "$ICON_LAST_COMMIT" "$age_str")
  fi
fi

# ============================================================================
# SEGMENT: stash
# ============================================================================
seg_stash=""
if segment_enabled "stash" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  stash_count=$(git --no-optional-locks -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$stash_count" -gt 0 ]]; then
    seg_stash=$(printf '\033[33m%s %s\033[0m' "$ICON_STASH" "$stash_count")
  fi
fi

# ============================================================================
# SEGMENT: effort
# ============================================================================
seg_effort=""
if segment_enabled "effort"; then
  effort_level=$(echo "$input" | jq -r '.effort.level // empty')
  if [[ -n "${effort_level:-}" ]]; then
    case "$effort_level" in
      low)    eff_color='\033[32m' ;;  # green
      medium) eff_color='\033[36m' ;;  # cyan
      high)   eff_color='\033[33m' ;;  # yellow
      xhigh)  eff_color='\033[35m' ;;  # magenta
      max)    eff_color='\033[31m' ;;  # red
      *)      eff_color='\033[37m' ;;
    esac
    seg_effort=$(printf "${eff_color}%s %s\033[0m" "$ICON_EFFORT" "$effort_level")
  fi
fi

# ============================================================================
# SEGMENT: rate_limits
# ============================================================================
seg_rate_limits=""
if segment_enabled "rate_limits"; then
  five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  if [[ -n "${five_h:-}" ]] || [[ -n "${seven_d:-}" ]]; then
    rl_parts=()
    for pair in "5h:$five_h" "7d:$seven_d"; do
      label="${pair%%:*}"
      val="${pair#*:}"
      [[ -z "$val" ]] && continue
      val_int=$(printf '%.0f' "$val")
      if [[ "$val_int" -ge 80 ]]; then
        rl_color='\033[31m'
      elif [[ "$val_int" -ge 50 ]]; then
        rl_color='\033[33m'
      else
        rl_color='\033[32m'
      fi
      rl_parts+=("$(printf "${rl_color}%s %s%%\033[0m" "$label" "$val_int")")
    done
    if [[ ${#rl_parts[@]} -gt 0 ]]; then
      joined=""
      for i in "${!rl_parts[@]}"; do
        [[ "$i" -gt 0 ]] && joined+=" "
        joined+="${rl_parts[$i]}"
      done
      seg_rate_limits=$(printf '\033[37m%s\033[0m %s' "$ICON_RATE_LIMIT" "$joined")
    fi
  fi
fi

# ============================================================================
# ASSEMBLE OUTPUT
# ============================================================================
parts=()

[[ -n "$seg_cwd" ]]          && parts+=("$seg_cwd")
[[ -n "$seg_git_branch" ]]   && parts+=("$seg_git_branch")
[[ -n "$seg_dirty" ]]        && parts+=("$seg_dirty")
[[ -n "$seg_ahead_behind" ]] && parts+=("$seg_ahead_behind")
[[ -n "$seg_model" ]]        && parts+=("$seg_model")
[[ -n "$seg_node" ]]         && parts+=("$seg_node")
[[ -n "$seg_context" ]]      && parts+=("$seg_context")
[[ -n "$seg_cost" ]]         && parts+=("$seg_cost")
[[ -n "$seg_duration" ]]     && parts+=("$seg_duration")
[[ -n "$seg_lines" ]]        && parts+=("$seg_lines")
[[ -n "$seg_ts_errors" ]]    && parts+=("$seg_ts_errors")
[[ -n "$seg_last_commit" ]]  && parts+=("$seg_last_commit")
[[ -n "$seg_stash" ]]        && parts+=("$seg_stash")
[[ -n "$seg_effort" ]]       && parts+=("$seg_effort")
[[ -n "$seg_rate_limits" ]]  && parts+=("$seg_rate_limits")

# Join with separator
output=""
for i in "${!parts[@]}"; do
  if [[ "$i" -gt 0 ]]; then
    output+="$SEP"
  fi
  output+="${parts[$i]}"
done

printf '%s' "$output"
