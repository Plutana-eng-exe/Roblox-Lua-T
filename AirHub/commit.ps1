##############################################################
# commit.ps1 — AirHub version snapshot + GitHub push helper
#
# Usage:
#   .\commit.ps1 -Version "v1.2.0" -Message "fix ESP tracer"
#
# Requirements:
#   git must be installed and on PATH.
#   On first run the repo + remote are set up automatically.
##############################################################

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

$RepoRoot    = Split-Path $PSScriptRoot -Parent   # …/Roblox-Lua-T-main
$AirHubDir   = $PSScriptRoot                      # …/AirHub
$VersionsDir = Join-Path $AirHubDir "versions"
$Remote      = "https://github.com/Plutana-eng-exe/Roblox-Lua-T.git"

# ── 1. Snapshot current sources into versions/<Version>/ ─────────────────────
$Snapshot = Join-Path $VersionsDir $Version
if (Test-Path $Snapshot) {
    Write-Host "⚠  versions\$Version already exists — overwriting." -ForegroundColor Yellow
    Remove-Item $Snapshot -Recurse -Force
}
New-Item -ItemType Directory -Path $Snapshot | Out-Null

Copy-Item (Join-Path $AirHubDir "main.lua")         $Snapshot
Copy-Item (Join-Path $AirHubDir "UI Library.lua")   $Snapshot
Copy-Item (Join-Path $AirHubDir "Depo") (Join-Path $Snapshot "Depo") -Recurse

Write-Host "✔  Snapshot saved to versions\$Version" -ForegroundColor Green

# ── 2. Init git repo at the project root if needed ───────────────────────────
Push-Location $RepoRoot

if (-not (Test-Path ".git")) {
    git init
    git remote add origin $Remote
    Write-Host "✔  Git repo initialised and remote set." -ForegroundColor Green
} elseif (-not (git remote | Select-String "origin")) {
    git remote add origin $Remote
    Write-Host "✔  Remote 'origin' added." -ForegroundColor Green
}

# ── 3. Stage, commit and push ─────────────────────────────────────────────────
git add -A
git commit -m "[$Version] $Message"
git push -u origin HEAD

Pop-Location

Write-Host "✔  Pushed to GitHub as [$Version] $Message" -ForegroundColor Cyan
