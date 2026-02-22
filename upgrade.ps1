# UDO Upgrade Tool - PowerShell Version
# Downloads latest UDO and safely merges with existing installation

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/carderel/UDO-No-Script-Complete"
$MANIFEST_URL = "https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/MANIFEST.json"

Write-Host ""
Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║       UDO Upgrade Tool v1.0           ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Find UDO folder
$UDO_PATH = $null
if (Test-Path "./UDO") {
    $UDO_PATH = "./UDO"
} elseif ((Test-Path "./START_HERE.md") -and (Test-Path "./ORCHESTRATOR.md")) {
    $UDO_PATH = "."
    Write-Host "Detected legacy install (files at root level)" -ForegroundColor Yellow
} else {
    Write-Host "No UDO installation found in current directory." -ForegroundColor Red
    Write-Host "Run this script from your project folder containing UDO/"
    exit 1
}

Write-Host "Found UDO at: $UDO_PATH" -ForegroundColor Blue

# Get current version
$CURRENT_VERSION = "unknown"
if (Test-Path "$UDO_PATH/VERSION") {
    $CURRENT_VERSION = (Get-Content "$UDO_PATH/VERSION" -Raw).Trim()
}
Write-Host "Current version: $CURRENT_VERSION" -ForegroundColor Blue

# Download latest
Write-Host ""
Write-Host "Downloading latest version..."
$TEMP_DIR = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "udo-upgrade-$(Get-Random)")
$zipPath = Join-Path $TEMP_DIR "latest.zip"
Invoke-WebRequest -Uri "$REPO_URL/archive/refs/heads/main.zip" -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $TEMP_DIR

$LATEST_PATH = Join-Path $TEMP_DIR "UDO-No-Script-Complete-main/UDO"
if (-not (Test-Path $LATEST_PATH)) {
    Write-Host "Error: Could not find UDO folder in downloaded archive" -ForegroundColor Red
    Remove-Item -Recurse -Force $TEMP_DIR
    exit 1
}

$LATEST_VERSION = if (Test-Path "$LATEST_PATH/VERSION") { (Get-Content "$LATEST_PATH/VERSION" -Raw).Trim() } else { "unknown" }
Write-Host "Latest version:  $LATEST_VERSION" -ForegroundColor Blue

if ($CURRENT_VERSION -eq $LATEST_VERSION) {
    Write-Host ""
    Write-Host "You're already on the latest version!" -ForegroundColor Green
    Remove-Item -Recurse -Force $TEMP_DIR
    exit 0
}

Write-Host ""
Write-Host "Analyzing differences..."
Write-Host ""

# System files to always update
$SYSTEM_FILES = @(
    "ORCHESTRATOR.md", "COMMANDS.md", "START_HERE.md",
    "REASONING_CONTRACT.md", "DEVILS_ADVOCATE.md", "AUDIENCE_ANTICIPATION.md",
    "EVIDENCE_PROTOCOL.md", "TEACH_BACK_PROTOCOL.md", "HANDOFF_PROMPT.md",
    "OVERSIGHT_DASHBOARD.md", "CAPABILITIES.json", "VERSION", "README.md"
)

# Data files to preserve
$DATA_FILES = @(
    "PROJECT_STATE.json", "PROJECT_META.json",
    "LESSONS_LEARNED.md", "HARD_STOPS.md", "NON_GOALS.md"
)

# Data folders - never touch
$DATA_FOLDERS = @(
    ".memory/canonical", ".memory/working", ".memory/disposable",
    ".project-catalog/sessions", ".project-catalog/decisions",
    ".project-catalog/agents", ".project-catalog/errors",
    ".project-catalog/handoffs", ".project-catalog/archive",
    ".outputs", ".checkpoints", ".agents"
)

$ADDED = @()
$UPDATED = @()

foreach ($file in $SYSTEM_FILES) {
    if (Test-Path "$LATEST_PATH/$file") {
        if (Test-Path "$UDO_PATH/$file") {
            $UPDATED += $file
        } else {
            $ADDED += $file
        }
    }
}

Write-Host "Will ADD (new files):" -ForegroundColor Green
if ($ADDED.Count -eq 0) { Write-Host "  (none)" } else { $ADDED | ForEach-Object { Write-Host "  + $_" } }

Write-Host ""
Write-Host "Will UPDATE (system files):" -ForegroundColor Yellow
$UPDATED | ForEach-Object { Write-Host "  ~ $_" }

Write-Host ""
Write-Host "Will PRESERVE (your data):" -ForegroundColor Blue
foreach ($folder in $DATA_FOLDERS) {
    if (Test-Path "$UDO_PATH/$folder") {
        $count = (Get-ChildItem -Path "$UDO_PATH/$folder" -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($count -gt 0) { Write-Host "  ✓ $folder ($count files)" }
    }
}
foreach ($file in $DATA_FILES) {
    if (Test-Path "$UDO_PATH/$file") { Write-Host "  ✓ $file" }
}

Write-Host ""
$response = Read-Host "Proceed with upgrade? [y/N]"
if ($response -notmatch "^[Yy]$") {
    Write-Host "Upgrade cancelled."
    Remove-Item -Recurse -Force $TEMP_DIR
    exit 0
}

# Create backup
$BACKUP_DIR = ".udo-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host ""
Write-Host "Creating backup at $BACKUP_DIR..."
Copy-Item -Recurse -Path $UDO_PATH -Destination $BACKUP_DIR

# Perform upgrade
Write-Host "Upgrading..."

# Update system files
foreach ($file in $SYSTEM_FILES) {
    if (Test-Path "$LATEST_PATH/$file") {
        Copy-Item -Force "$LATEST_PATH/$file" "$UDO_PATH/$file"
    }
}

# Update README files in subfolders
Get-ChildItem -Path $LATEST_PATH -Filter "README.md" -Recurse | ForEach-Object {
    $relPath = $_.FullName.Substring($LATEST_PATH.Length + 1)
    $targetPath = Join-Path $UDO_PATH $relPath
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    Copy-Item -Force $_.FullName $targetPath
}

# Update .templates folder
if (Test-Path "$LATEST_PATH/.templates") {
    if (-not (Test-Path "$UDO_PATH/.templates")) { New-Item -ItemType Directory -Path "$UDO_PATH/.templates" -Force | Out-Null }
    Copy-Item -Force -Recurse "$LATEST_PATH/.templates/*" "$UDO_PATH/.templates/"
}

# Update .takeover/agent-templates
if (Test-Path "$LATEST_PATH/.takeover/agent-templates") {
    New-Item -ItemType Directory -Path "$UDO_PATH/.takeover/agent-templates" -Force | Out-Null
    Copy-Item -Force -Recurse "$LATEST_PATH/.takeover/agent-templates/*" "$UDO_PATH/.takeover/agent-templates/"
}

# Update .rules (only add missing, keep user customizations)
if (Test-Path "$LATEST_PATH/.rules") {
    if (-not (Test-Path "$UDO_PATH/.rules")) { New-Item -ItemType Directory -Path "$UDO_PATH/.rules" -Force | Out-Null }
    Get-ChildItem -Path "$LATEST_PATH/.rules" -Filter "*.md" | ForEach-Object {
        if (-not (Test-Path "$UDO_PATH/.rules/$($_.Name)")) {
            Copy-Item -Force $_.FullName "$UDO_PATH/.rules/"
        }
    }
    if (Test-Path "$LATEST_PATH/.rules/README.md") {
        Copy-Item -Force "$LATEST_PATH/.rules/README.md" "$UDO_PATH/.rules/README.md"
    }
}

# Create new folders if missing
@(".outputs/.evidence", ".takeover", ".tools", ".inputs") | ForEach-Object {
    if ((Test-Path "$LATEST_PATH/$_") -and (-not (Test-Path "$UDO_PATH/$_"))) {
        New-Item -ItemType Directory -Path "$UDO_PATH/$_" -Force | Out-Null
        Copy-Item -Force -Recurse "$LATEST_PATH/$_/*" "$UDO_PATH/$_/" -ErrorAction SilentlyContinue
    }
}

# Cleanup
Remove-Item -Recurse -Force $TEMP_DIR

Write-Host ""
Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Upgrade Complete!               ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Upgraded from $CURRENT_VERSION to $LATEST_VERSION" -ForegroundColor Blue
Write-Host "Backup saved to: $BACKUP_DIR" -ForegroundColor Blue
Write-Host ""
Write-Host "If something went wrong, restore from backup:"
Write-Host "  Remove-Item -Recurse $UDO_PATH; Move-Item $BACKUP_DIR $UDO_PATH"
