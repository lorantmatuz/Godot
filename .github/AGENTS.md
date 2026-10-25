# CI

One workflow, one job: `workflows/godot-tests.yml`, on every push and pull request.

- Installs Godot once (`4.7.2`), then finds every `*/project.godot`.
- Each game's suite runs in a background subshell, so games run in parallel.
- Per game: import the project, then run every `*.gd` under `<game>/tests/`
  (recursive). Tests within a game run sequentially because they share `.godot/`.
- Per-game output goes to a temp log and is printed at the end inside a
  `::group::<game>` block, so logs neither interleave nor lose attribution.
- Each discovered project is echoed as `Found game: <name>` before tests start.
- A failed test marks the run as failed only after every game has finished. A
  game without a `tests/` folder logs a warning and is skipped.

Commands per game:

```sh
godot --headless --editor --path <game> --quit
godot --headless --path <game> --script res://tests/<file>.gd
```

- New games and test files are picked up automatically.
- The pinned Godot version must match every `<game>/project.godot`
  (`config/features`). Bump them together.
- `--path` is the game folder; `res://` in `--script` is relative to that project,
  not the repository root.
- `--editor --quit` is required on a fresh checkout; it creates `.godot/`, which
  is gitignored.
- Tests must exit non-zero on failure (see `SceneTree.quit(1)`); CI does not scan
  logs.
