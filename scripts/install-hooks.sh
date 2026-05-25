#!/bin/bash
# Install Claude git hooks from scripts/hooks/ into .git/hooks/
# Run once after cloning, and again whenever hooks are updated.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DEST="$REPO_ROOT/.git/hooks"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    exit 1
fi

if [ ! -d "$HOOKS_SRC" ]; then
    echo "Hook source directory not found: $HOOKS_SRC"
    exit 1
fi

INSTALLED=0
for hook in "$HOOKS_SRC"/*; do
    name=$(basename "$hook")
    dest="$HOOKS_DEST/$name"

    if [ -f "$dest" ] && ! diff -q "$hook" "$dest" >/dev/null 2>&1; then
        echo "Updating:  $name (changed)"
    elif [ ! -f "$dest" ]; then
        echo "Installing: $name"
    else
        echo "Up to date: $name"
        continue
    fi

    cp "$hook" "$dest"
    chmod +x "$dest"
    ((INSTALLED++))
done

if [[ $INSTALLED -gt 0 ]]; then
    echo ""
    echo "$INSTALLED hook(s) installed."
else
    echo ""
    echo "All hooks already up to date."
fi
