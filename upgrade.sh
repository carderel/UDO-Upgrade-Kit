#!/bin/bash
# UDO Upgrade Tool
# Downloads latest UDO and safely merges with existing installation

set -e

REPO_URL="https://github.com/carderel/UDO-No-Script-Complete"
MANIFEST_URL="https://raw.githubusercontent.com/carderel/UDO-Upgrade-Kit/main/MANIFEST.json"
TEMP_DIR=$(mktemp -d)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       UDO Upgrade Tool v1.0           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Find UDO folder
UDO_PATH=""
if [ -d "./UDO" ]; then
    UDO_PATH="./UDO"
elif [ -f "./START_HERE.md" ] && [ -f "./ORCHESTRATOR.md" ]; then
    UDO_PATH="."
    echo -e "${YELLOW}Detected legacy install (files at root level)${NC}"
else
    echo -e "${RED}No UDO installation found in current directory.${NC}"
    echo "Run this script from your project folder containing UDO/"
    exit 1
fi

echo -e "Found UDO at: ${BLUE}$UDO_PATH${NC}"

# Get current version
CURRENT_VERSION="unknown"
if [ -f "$UDO_PATH/VERSION" ]; then
    CURRENT_VERSION=$(cat "$UDO_PATH/VERSION")
fi
echo -e "Current version: ${BLUE}$CURRENT_VERSION${NC}"

# Download latest
echo ""
echo "Downloading latest version..."
cd "$TEMP_DIR"
curl -fsSL "$REPO_URL/archive/refs/heads/main.zip" -o latest.zip
unzip -q latest.zip
LATEST_PATH="$TEMP_DIR/UDO-No-Script-Complete-main/UDO"

if [ ! -d "$LATEST_PATH" ]; then
    echo -e "${RED}Error: Could not find UDO folder in downloaded archive${NC}"
    exit 1
fi

LATEST_VERSION=$(cat "$LATEST_PATH/VERSION" 2>/dev/null || echo "unknown")
echo -e "Latest version:  ${BLUE}$LATEST_VERSION${NC}"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo ""
    echo -e "${GREEN}You're already on the latest version!${NC}"
    exit 0
fi

# Download manifest
curl -fsSL "$MANIFEST_URL" -o manifest.json 2>/dev/null || {
    echo -e "${YELLOW}Could not download manifest, using built-in rules${NC}"
}

# Back to original directory
cd - > /dev/null
ORIG_DIR=$(pwd)

echo ""
echo "Analyzing differences..."
echo ""

# Track changes
ADDED=()
UPDATED=()
PRESERVED=()

# System files to always update
SYSTEM_FILES=(
    "ORCHESTRATOR.md" "COMMANDS.md" "START_HERE.md"
    "REASONING_CONTRACT.md" "DEVILS_ADVOCATE.md" "AUDIENCE_ANTICIPATION.md"
    "EVIDENCE_PROTOCOL.md" "TEACH_BACK_PROTOCOL.md" "HANDOFF_PROMPT.md"
    "OVERSIGHT_DASHBOARD.md" "CAPABILITIES.json" "VERSION" "README.md"
)

# Data files to preserve if modified
DATA_FILES=(
    "PROJECT_STATE.json" "PROJECT_META.json"
    "LESSONS_LEARNED.md" "HARD_STOPS.md" "NON_GOALS.md"
)

# Data folders - never touch contents
DATA_FOLDERS=(
    ".memory/canonical" ".memory/working" ".memory/disposable"
    ".project-catalog/sessions" ".project-catalog/decisions"
    ".project-catalog/agents" ".project-catalog/errors"
    ".project-catalog/handoffs" ".project-catalog/archive"
    ".outputs" ".checkpoints" ".agents"
)

# Check system files
for file in "${SYSTEM_FILES[@]}"; do
    if [ -f "$LATEST_PATH/$file" ]; then
        if [ -f "$UDO_PATH/$file" ]; then
            UPDATED+=("$file")
        else
            ADDED+=("$file")
        fi
    fi
done

# Check for new folders/files in latest
echo -e "${GREEN}Will ADD (new files):${NC}"
for file in "${ADDED[@]}"; do
    echo "  + $file"
done
[ ${#ADDED[@]} -eq 0 ] && echo "  (none)"

echo ""
echo -e "${YELLOW}Will UPDATE (system files):${NC}"
for file in "${UPDATED[@]}"; do
    echo "  ~ $file"
done

echo ""
echo -e "${BLUE}Will PRESERVE (your data):${NC}"
for folder in "${DATA_FOLDERS[@]}"; do
    if [ -d "$UDO_PATH/$folder" ]; then
        count=$(find "$UDO_PATH/$folder" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            echo "  ✓ $folder ($count files)"
        fi
    fi
done
for file in "${DATA_FILES[@]}"; do
    if [ -f "$UDO_PATH/$file" ]; then
        echo "  ✓ $file"
    fi
done

echo ""
echo -e "${YELLOW}Proceed with upgrade? [y/N]${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Upgrade cancelled."
    exit 0
fi

# Create backup
BACKUP_DIR="$ORIG_DIR/.udo-backup-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "Creating backup at $BACKUP_DIR..."
cp -R "$UDO_PATH" "$BACKUP_DIR"

# Perform upgrade
echo "Upgrading..."

# Update system files
for file in "${SYSTEM_FILES[@]}"; do
    if [ -f "$LATEST_PATH/$file" ]; then
        cp "$LATEST_PATH/$file" "$UDO_PATH/$file"
    fi
done

# Update README files in subfolders
find "$LATEST_PATH" -name "README.md" -type f | while read -r readme; do
    rel_path=${readme#$LATEST_PATH/}
    target_dir=$(dirname "$UDO_PATH/$rel_path")
    mkdir -p "$target_dir"
    cp "$readme" "$UDO_PATH/$rel_path"
done

# Update .templates folder (entire contents)
if [ -d "$LATEST_PATH/.templates" ]; then
    mkdir -p "$UDO_PATH/.templates"
    cp -R "$LATEST_PATH/.templates/"* "$UDO_PATH/.templates/"
fi

# Update .takeover/agent-templates
if [ -d "$LATEST_PATH/.takeover/agent-templates" ]; then
    mkdir -p "$UDO_PATH/.takeover/agent-templates"
    cp -R "$LATEST_PATH/.takeover/agent-templates/"* "$UDO_PATH/.takeover/agent-templates/"
fi

# Update .rules (but not if user has custom rules)
if [ -d "$LATEST_PATH/.rules" ]; then
    mkdir -p "$UDO_PATH/.rules"
    for rule in "$LATEST_PATH/.rules/"*.md; do
        rulename=$(basename "$rule")
        if [ ! -f "$UDO_PATH/.rules/$rulename" ]; then
            cp "$rule" "$UDO_PATH/.rules/$rulename"
        fi
    done
    # Always update README
    cp "$LATEST_PATH/.rules/README.md" "$UDO_PATH/.rules/README.md" 2>/dev/null || true
fi

# Create new folders if missing
for folder in ".outputs/.evidence" ".takeover" ".tools" ".inputs"; do
    if [ -d "$LATEST_PATH/$folder" ] && [ ! -d "$UDO_PATH/$folder" ]; then
        mkdir -p "$UDO_PATH/$folder"
        cp -R "$LATEST_PATH/$folder/"* "$UDO_PATH/$folder/" 2>/dev/null || true
    fi
done

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Upgrade Complete!               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "Upgraded from ${BLUE}$CURRENT_VERSION${NC} to ${BLUE}$LATEST_VERSION${NC}"
echo -e "Backup saved to: ${BLUE}$BACKUP_DIR${NC}"
echo ""
echo "If something went wrong, restore from backup:"
echo "  rm -rf $UDO_PATH && mv $BACKUP_DIR $UDO_PATH"
