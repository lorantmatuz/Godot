
#!/usr/bin/env bash
set -euo pipefail

game="${1:?Usage: validate-project.sh <game-directory>}"

errors=0

check_file() {
    if [[ ! -f "$game/$1" ]]; then
        echo "::error file=$game::$1 is missing"
        errors=$((errors + 1))
    fi
}

check_dir() {
    if [[ ! -d "$game/$1" ]]; then
        echo "::error file=$game::$1::$1 directory is missing"
        errors=$((errors + 1))
    fi
}

echo "Validating $game"

# Required files
check_file project.godot
check_file icon.svg
check_file README.md

# Required directories
check_dir scenes
check_dir scripts
check_dir assets
check_dir tests

# GDScript UID sidecars
while IFS= read -r -d '' script; do
    if [[ ! -f "${script}.uid" ]]; then
        echo "::error file=$script::Missing UID sidecar"
        errors=$((errors + 1))
    fi
done < <(find "$game" -name '*.gd' -not -path '*/.godot/*' -print0)

if (( errors > 0 )); then
    echo "::error::$game has $errors validation error(s)"
    exit 1
fi

echo "Validation passed: $game"
