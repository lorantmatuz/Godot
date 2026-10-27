# Repo notes

Small collection of Godot games. The repo root is **not** a Godot project; each
game folder is a self-contained one.

## Games

- `breakout/` — brick-breaker. See [`breakout/AGENTS.md`](breakout/AGENTS.md).
- `root&realm/` — top-down settlement builder. See
  [`root&realm/README.md`](root&realm/README.md).

## CI

GitHub Actions auto-discovers every game and runs each game's tests in parallel;
see [`.github/AGENTS.md`](.github/AGENTS.md).

## Layout (per game)

```text
<game>/
├── project.godot
├── icon.svg
├── README.md
├── scenes/            # entity scenes + levels/
├── scripts/           # GDScript (+ committed .uid files)
├── assets/            # sprites/, audio/, fonts/
├── addons/
└── tests/             # headless smoke tests
```

`.godot/` is generated and ignored by the root `.gitignore`; do not commit it.

## Running and testing

Requires Godot 4.7 or newer as `godot` on `PATH` (or pass the full binary path).
Keep machine-specific paths in your global agent config, not in this file.

```sh
godot --headless --path breakout --quit-after 300
godot --headless --path breakout --script res://tests/smoke_test.gd
```

Run the smoke test after changing game logic; it exits non-zero on failure.

## Conventions

- GDScript, tabs, `snake_case` for variables/functions, PascalCase for node names.
- Use `res://` paths relative to the game project.
- Update the per-game `README.md` when controls or structure change.
- Do not commit, push, or rewrite history unless asked.
- Keep game-specific notes in that game's `AGENTS.md`, not here.
