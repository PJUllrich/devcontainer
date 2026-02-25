#!/bin/bash
# Protects sensitive files and sets up Claude project settings.
#
# 1. Bind-mounts empty files over paths listed in protected-paths.txt
#    so the container sees empty files while the host is unaffected.
# 2. Creates Claude project-level settings with deny rules as a
#    secondary safeguard.
#
# Must run as root (for mount --bind).

set -euo pipefail

# --- Protect sensitive files ---
shadow_path() {
    [ -e "$1" ] || return 0
    local target="/tmp/protected-$(echo "$1" | tr '/' '-')"
    if [ -f "$1" ]; then
        touch "$target"
    elif [ -d "$1" ]; then
        mkdir -p "$target"
    fi
    mount --bind "$target" "$1"
    echo "  Protected: $1"
}

PROTECTED_PATHS="/etc/devcontainer/protected-paths.txt"
if [ -f "$PROTECTED_PATHS" ]; then
    while IFS= read -r pattern; do
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${pattern// }" ]] && continue

        if [[ "$pattern" == *"**"* ]]; then
            find /workspace -name "${pattern##*\*\*/}" 2>/dev/null | while IFS= read -r match; do
                shadow_path "$match"
            done
        else
            for match in /workspace/$pattern; do
                shadow_path "$match"
            done
        fi
    done < "$PROTECTED_PATHS"
else
    echo "No protected-paths.txt found, skipping"
fi

# --- Set up Claude project settings ---
DEV_HOME="/home/dev"
PROJECT_DIR="${DEV_HOME}/.claude/projects/-workspace"
SETTINGS_FILE="${PROJECT_DIR}/settings.json"

mkdir -p "$PROJECT_DIR"
chown -R dev:dev "$PROJECT_DIR"

DENY_RULES=""
if [ -f "$PROTECTED_PATHS" ]; then
    while IFS= read -r pattern; do
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${pattern// }" ]] && continue
        # Ensure patterns match at any depth
        if [[ "$pattern" != **"**"** ]]; then
            pattern="**/$pattern"
        fi
        [ -n "$DENY_RULES" ] && DENY_RULES="${DENY_RULES},"$'\n'
        DENY_RULES="${DENY_RULES}      \"Read(path:${pattern})\""
    done < "$PROTECTED_PATHS"
fi

if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    "deny": [
${DENY_RULES}
    ]
  }
}
EOF
    chown dev:dev "$SETTINGS_FILE"
    echo "Created Claude settings: $SETTINGS_FILE"
else
    echo "Claude settings already exists, skipping"
fi
