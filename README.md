# UDO-Upgrade-Kit

Smart upgrade tool for UDO installations. Safely updates system files while preserving your project data.

## What It Does

1. Downloads the latest UDO from UDO-No-Script repo
2. Compares your local files with the latest version
3. Shows you exactly what will be added, updated, or preserved
4. Creates a backup before making changes
5. Merges updates while keeping your data intact

## Usage

### Mac / Linux / WSL / Git Bash

```bash
curl -fsSL https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/upgrade.sh | bash
```

Or download and run:
```bash
curl -O https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/upgrade.sh
chmod +x upgrade.sh
./upgrade.sh
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/upgrade.ps1 | iex
```

Or download and run:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/upgrade.ps1" -OutFile upgrade.ps1
.\upgrade.ps1
```

## What Gets Updated

**REPLACED (system files):**
- Core files: ORCHESTRATOR.md, COMMANDS.md, START_HERE.md, etc.
- Protocol files: REASONING_CONTRACT.md, EVIDENCE_PROTOCOL.md, etc.
- All README.md files in subfolders
- All templates in .templates/
- Takeover agent templates in .takeover/agent-templates/

**PRESERVED (your data):**
- PROJECT_STATE.json (your current project)
- PROJECT_META.json (your project info)
- LESSONS_LEARNED.md, HARD_STOPS.md, NON_GOALS.md (if customized)
- Everything in .memory/ (your facts)
- Everything in .project-catalog/ (your history)
- Everything in .outputs/ (your deliverables)
- Everything in .checkpoints/ (your saves)
- Everything in .agents/ (your custom agents)

## Backup

Before any changes, the tool creates a backup at:
```
.udo-backup-YYYYMMDD-HHMMSS/
```

If something goes wrong, restore with:
```bash
rm -rf UDO && mv .udo-backup-* UDO
```

## Requirements

- curl (Mac/Linux) or PowerShell 5+ (Windows)
- Internet connection to download latest version
- Run from your project directory (the one containing UDO/)

## License

MIT
