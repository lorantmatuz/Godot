#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r project; do
    dirname "$project"
done < <(
    find . -mindepth 2 -name project.godot \
        -not -path '*/.godot/*' |
    sort
)