# claude-code-statusline installer (Windows)
# Copies statusline.ps1 to ~/.claude/ and configures settings.json
#
# Usage:
#   irm https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/install.ps1 | iex
#   — or —
#   .\install.ps1

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$ScriptName = "statusline.ps1"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$InstallPath = Join-Path $ClaudeDir $ScriptName

$RemoteUrl = "https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/statusline.ps1"

Write-Host "claude-code-statusline installer (Windows)"
Write-Host "==========================================="
Write-Host ""

# 1. Ensure ~/.claude exists
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

# 2. Try to detect local repo copy, otherwise download
$SourceScript = $null
try {
    $cmdPath = $MyInvocation.MyCommand.Path
    if ($cmdPath -and (Test-Path $cmdPath)) {
        $candidate = Join-Path (Split-Path -Parent $cmdPath) $ScriptName
        if (Test-Path $candidate) {
            $SourceScript = $candidate
        }
    }
} catch {}

if ($SourceScript) {
    Write-Host "Copying statusline.ps1 from local repo..."
    Copy-Item $SourceScript $InstallPath -Force
} else {
    Write-Host "Downloading statusline.ps1 from GitHub..."
    try {
        Invoke-WebRequest -Uri $RemoteUrl -OutFile $InstallPath -UseBasicParsing
    } catch {
        Write-Host "Error: Failed to download statusline.ps1"
        Write-Host "  $_"
        return
    }
}

Write-Host "Installed to $InstallPath"

# 3. Check for git (used by several segments)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Warning: 'git' is not installed or not in PATH. Git segments will be hidden."
    Write-Host "  Install from: https://git-scm.com/download/win"
    Write-Host ""
}

# 4. Configure settings.json
$StatusLineConfig = @{
    type = "command"
    command = "pwsh -NoProfile -File `"$InstallPath`""
}

if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    } catch {
        $settings = $null
    }

    if ($settings -and $settings.statusLine -and $settings.statusLine.command) {
        Write-Host ""
        Write-Host "settings.json already has a statusLine configured:"
        Write-Host "  $($settings.statusLine.command)"
        Write-Host ""
        $answer = Read-Host "Overwrite with claude-code-statusline? [y/N]"
        if ($answer -ne 'y' -and $answer -ne 'Y') {
            Write-Host "Skipped settings.json update. You can manually set:"
            Write-Host "  `"statusLine`": { `"type`": `"command`", `"command`": `"pwsh -NoProfile -File $InstallPath`" }"
            Write-Host ""
            Write-Host "Done! Restart Claude Code to see the status line."
            return
        }
    }

    if ($settings) {
        $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $StatusLineConfig -Force
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    } else {
        @{ statusLine = $StatusLineConfig } | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    }
    Write-Host "Updated $SettingsFile"
} else {
    @{ statusLine = $StatusLineConfig } | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "Created $SettingsFile"
}

Write-Host ""
Write-Host "Done! Restart Claude Code to see the status line."
Write-Host ""
Write-Host "To customize segments, edit: $InstallPath"
Write-Host "Look for the `$EnabledSegments array at the top of the file."
