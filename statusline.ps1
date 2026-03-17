# claude-code-statusline — A rich status line for Claude Code (Windows)
# https://github.com/AsafSaar/claude-code-statusline
#
# Reads JSON from stdin (provided by Claude Code) and outputs a
# colorized, segment-based status line.
#
# Segments can be toggled by commenting out entries in $EnabledSegments below.

$ErrorActionPreference = 'SilentlyContinue'

# ============================================================================
# CONFIGURATION — comment out any segment you don't want
# ============================================================================
$EnabledSegments = @(
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
)

# Separator between segments
$Sep = "  "

# ============================================================================
# HELPERS
# ============================================================================
function Test-SegmentEnabled($name) {
    return $EnabledSegments -contains $name
}

$ESC = [char]27

# ============================================================================
# READ INPUT
# ============================================================================
$input = $input = @($Input) -join "`n"
try {
    $json = $input | ConvertFrom-Json
} catch {
    Write-Host ""
    exit 0
}

$cwd = if ($json.cwd) { $json.cwd } else { "" }

# ============================================================================
# SEGMENT: cwd
# ============================================================================
$seg_cwd = ""
if ((Test-SegmentEnabled "cwd") -and $cwd) {
    $basename = Split-Path $cwd -Leaf
    $seg_cwd = "$ESC[37m$basename$ESC[0m"
}

# ============================================================================
# SEGMENT: git_branch
# ============================================================================
$seg_git_branch = ""
$git_branch = ""
if ((Test-SegmentEnabled "git_branch") -and $cwd) {
    try {
        $git_branch = & git --no-optional-locks -C $cwd symbolic-ref --short HEAD 2>$null
        if ($git_branch) {
            $icon = [char]0xe0a0
            $seg_git_branch = "$ESC[36m$icon $git_branch$ESC[0m"
        }
    } catch {}
}

# ============================================================================
# SEGMENT: dirty
# ============================================================================
$seg_dirty = ""
if ((Test-SegmentEnabled "dirty") -and $cwd -and $git_branch) {
    try {
        $dirty_output = & git --no-optional-locks -C $cwd status --porcelain 2>$null
        $dirty_count = if ($dirty_output) { @($dirty_output).Count } else { 0 }
        if ($dirty_count -gt 0) {
            $seg_dirty = "$ESC[33m$dirty_count dirty$ESC[0m"
        }
    } catch {}
}

# ============================================================================
# SEGMENT: ahead_behind
# ============================================================================
$seg_ahead_behind = ""
if ((Test-SegmentEnabled "ahead_behind") -and $cwd -and $git_branch) {
    try {
        $ab = & git --no-optional-locks -C $cwd rev-list --count --left-right "HEAD...@{u}" 2>$null
        if ($ab) {
            $parts_ab = $ab -split '\s+'
            $ahead = [int]$parts_ab[0]
            $behind = [int]$parts_ab[1]
            if ($ahead -gt 0 -or $behind -gt 0) {
                $up = [char]0x2191
                $down = [char]0x2193
                $seg_ahead_behind = "$ESC[33m$up$ahead $down$behind$ESC[0m"
            }
        }
    } catch {}
}

# ============================================================================
# SEGMENT: model
# ============================================================================
$seg_model = ""
if (Test-SegmentEnabled "model") {
    $model_name = $json.model.display_name
    if ($model_name) {
        $seg_model = "$ESC[38;5;147m$model_name$ESC[0m"
    }
}

# ============================================================================
# SEGMENT: node
# ============================================================================
$seg_node = ""
if (Test-SegmentEnabled "node") {
    try {
        $raw_node = & node --version 2>$null
        if ($raw_node) {
            $node_ver = $raw_node -replace '^v', ''
            $seg_node = "$ESC[32mnode $node_ver$ESC[0m"
        }
    } catch {}
}

# ============================================================================
# SEGMENT: context
# ============================================================================
$seg_context = ""
if (Test-SegmentEnabled "context") {
    $used_pct = $json.context_window.used_percentage
    if ($null -ne $used_pct) {
        $pct_int = [math]::Round($used_pct)
        if ($pct_int -ge 80) {
            $ctx_color = "$ESC[31m"    # red
        } elseif ($pct_int -ge 50) {
            $ctx_color = "$ESC[33m"    # yellow
        } else {
            $ctx_color = "$ESC[32m"    # green
        }
        $seg_context = "${ctx_color}ctx ${pct_int}%$ESC[0m"
    }
}

# ============================================================================
# SEGMENT: cost (native from Claude Code JSON)
# ============================================================================
$seg_cost = ""
if (Test-SegmentEnabled "cost") {
    $total_cost = $json.cost.total_cost_usd
    if ($null -ne $total_cost) {
        $formatted_cost = "{0:F3}" -f [double]$total_cost
        $seg_cost = "$ESC[35m`$$formatted_cost$ESC[0m"
    }
}

# ============================================================================
# SEGMENT: duration (native from Claude Code JSON)
# ============================================================================
$seg_duration = ""
if (Test-SegmentEnabled "duration") {
    $duration_ms = $json.cost.total_duration_ms
    if ($null -ne $duration_ms) {
        $elapsed = [math]::Floor([double]$duration_ms / 1000)
        $h = [math]::Floor($elapsed / 3600)
        $m = [math]::Floor(($elapsed % 3600) / 60)
        if ($h -gt 0) {
            $seg_duration = "$ESC[34m${h}h${m}m$ESC[0m"
        } elseif ($m -gt 0) {
            $seg_duration = "$ESC[34m${m}m$ESC[0m"
        }
    }
}

# ============================================================================
# SEGMENT: lines added/removed
# ============================================================================
$seg_lines = ""
if (Test-SegmentEnabled "lines") {
    $lines_added = if ($json.cost.total_lines_added) { $json.cost.total_lines_added } else { 0 }
    $lines_removed = if ($json.cost.total_lines_removed) { $json.cost.total_lines_removed } else { 0 }
    if ($lines_added -gt 0 -or $lines_removed -gt 0) {
        $seg_lines = "$ESC[32m+$lines_added$ESC[0m/$ESC[31m-$lines_removed$ESC[0m"
    }
}

# ============================================================================
# SEGMENT: ts_errors (cached, non-blocking)
# ============================================================================
$seg_ts_errors = ""
if ((Test-SegmentEnabled "ts_errors") -and $cwd) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($cwd)
    $hash = ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
    $cache_file = Join-Path $env:TEMP "tsc-errors-$hash.txt"
    if (Test-Path $cache_file) {
        $file_info = Get-Item $cache_file
        $age = (Get-Date) - $file_info.LastWriteTime
        if ($age.TotalSeconds -le 300) {
            $ts_err = (Get-Content $cache_file -First 1).Trim()
            if ($ts_err -and [int]$ts_err -gt 0) {
                $seg_ts_errors = "$ESC[31mTS:$ts_err$ESC[0m"
            }
        }
    }
}

# ============================================================================
# ASSEMBLE OUTPUT
# ============================================================================
$parts = @()

if ($seg_cwd)          { $parts += $seg_cwd }
if ($seg_git_branch)   { $parts += $seg_git_branch }
if ($seg_dirty)        { $parts += $seg_dirty }
if ($seg_ahead_behind) { $parts += $seg_ahead_behind }
if ($seg_model)        { $parts += $seg_model }
if ($seg_node)         { $parts += $seg_node }
if ($seg_context)      { $parts += $seg_context }
if ($seg_cost)         { $parts += $seg_cost }
if ($seg_duration)     { $parts += $seg_duration }
if ($seg_lines)        { $parts += $seg_lines }
if ($seg_ts_errors)    { $parts += $seg_ts_errors }

$output = $parts -join $Sep
Write-Host -NoNewline $output
