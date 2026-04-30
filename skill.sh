#!/usr/bin/env bash
# skill.sh — AI Handover skill installer
# Usage: bash skill.sh [target_dir]
#   target_dir: custom skill directory (default ~/.claude/skills/)
#
# Reads claudeCodeSkill config from package.json and installs the skill.
# Also creates gzjj and xrtk command aliases.

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

# Install main skill
if [ -d "$TARGET_DIR" ]; then
    warn "Target already exists: $TARGET_DIR"
    printf "Overwrite? [y/N] "
    read -r answer
    case "$answer" in
        [Yy]*) rm -rf "$TARGET_DIR"; info "Removed old version" ;;
        *) info "Installation of $SKILL_NAME skipped"; exit 0 ;;
    esac
fi

cp -r "$SRC_DIR" "$TARGET_DIR"
info "Main skill installed: $TARGET_DIR"

# ---------------------------------------------------------------------------
# Create /gzjj and /xrtk command aliases
# ---------------------------------------------------------------------------
ALIAS_WRAPPER='---
name: %s
description: "%s 命令别名，实际执行 ai-handover skill 的工作流程。触发后请按照 ai-handover skill 的 SKILL.md 执行。"
---

# %s

> 此命令是 **ai-handover** skill 的别名。

请调用 ai-handover skill，执行对应的功能。'

create_alias() {
    local alias_name="$1"
    local alias_label="$2"
    local alias_dir="$TARGET_BASE/$alias_name"

    # Remove old alias if it exists (but not if it's a real skill, not a symlink/wrapper)
    if [ -L "$alias_dir" ]; then
        rm -f "$alias_dir"
        info "Removed old symlink alias: $alias_name"
    elif [ -d "$alias_dir" ] && [ -f "$alias_dir/SKILL.md" ]; then
        # Check if it's our wrapper (contains "ai-handover" reference)
        if grep -q "ai-handover" "$alias_dir/SKILL.md" 2>/dev/null; then
            rm -rf "$alias_dir"
            info "Removed old wrapper alias: $alias_name"
        else
            warn "$alias_name already exists as a separate skill, skipping alias creation"
            return
        fi
    fi

    # Try symlink first (cleanest approach)
    if ln -s "$SKILL_NAME" "$alias_dir" 2>/dev/null; then
        info "Alias created (symlink): /$alias_name -> $SKILL_NAME"
    else
        # Fallback: create minimal wrapper SKILL.md
        mkdir -p "$alias_dir"
        printf "$ALIAS_WRAPPER" "$alias_name" "$alias_label" "$alias_name" > "$alias_dir/SKILL.md"
        info "Alias created (wrapper): /$alias_name -> $SKILL_NAME"
    fi
}

create_alias "gzjj" "工作交接"
create_alias "xrtk" "新人填坑"

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo ""
if [ -f "$TARGET_DIR/SKILL.md" ]; then
    info "Installation successful!"
    echo ""
    info "Available commands in Claude Code:"
    echo "  /gzjj        — 工作交接（生成交接文档）"
    echo "  /xrtk        — 新人填坑（接手工作）"
    echo "  /ai-handover — 显示功能菜单"
else
    error "Installation failed: SKILL.md not found in target"
    exit 1
fi
