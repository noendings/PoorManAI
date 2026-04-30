#!/usr/bin/env bash
# skill.sh — AI Handover skill installer
# Usage: bash skill.sh [target_dir]
#   target_dir: custom skill directory (default ~/.claude/skills/)
#
# Reads claudeCodeSkill config from package.json and installs the skill.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

PACKAGE_JSON="$REPO_ROOT/package.json"
if [ ! -f "$PACKAGE_JSON" ]; then
    error "package.json not found. Run this script from the repo root."
    exit 1
fi

# Extract JSON fields without jq dependency
extract_json_field() {
    local field="$1"
    grep "\"$field\"" "$PACKAGE_JSON" | head -1 | sed 's/.*": *"\([^"]*\)".*/\1/'
}

SKILL_NAME=$(extract_json_field "skillName")
SKILL_PATH=$(extract_json_field "skillPath")

if [ -z "$SKILL_NAME" ]; then
    SKILL_NAME="ai-handover"
    warn "claudeCodeSkill.skillName not found, using default: $SKILL_NAME"
fi

if [ -z "$SKILL_PATH" ]; then
    SKILL_PATH="skills/$SKILL_NAME"
    warn "claudeCodeSkill.skillPath not found, using default: $SKILL_PATH"
fi

TARGET_BASE="${1:-$HOME/.claude/skills}"
TARGET_DIR="$TARGET_BASE/$SKILL_NAME"

info "Skill name: $SKILL_NAME"
info "Source:      $REPO_ROOT/$SKILL_PATH"
info "Target:      $TARGET_DIR"
echo ""

SRC_DIR="$REPO_ROOT/$SKILL_PATH"
if [ ! -d "$SRC_DIR" ]; then
    error "Source skill directory not found: $SRC_DIR"
    exit 1
fi

if [ ! -f "$SRC_DIR/SKILL.md" ]; then
    error "SKILL.md missing in source: $SRC_DIR"
    exit 1
fi

mkdir -p "$TARGET_BASE"

if [ -d "$TARGET_DIR" ]; then
    warn "Target already exists: $TARGET_DIR"
    printf "Overwrite? [y/N] "
    read -r answer
    case "$answer" in
        [Yy]*) rm -rf "$TARGET_DIR"; info "Removed old version" ;;
        *) info "Installation cancelled"; exit 0 ;;
    esac
fi

cp -r "$SRC_DIR" "$TARGET_DIR"
info "Skill installed to: $TARGET_DIR"

if [ -f "$TARGET_DIR/SKILL.md" ]; then
    info "Installation successful!"
    echo ""
    info "Available commands in Claude Code:"
    echo "  /gzjj        — Generate handover document"
    echo "  /xrtk        — Take over work (new person onboarding)"
    echo "  /ai-handover — Show feature menu"
else
    error "Installation failed: SKILL.md not found in target"
    exit 1
fi
