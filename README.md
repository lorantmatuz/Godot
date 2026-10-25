This is a collection of [Godot](https://godotengine.org/) games, developed just for fun.

## Games

- [Breakout](breakout/) — a small brick-breaker.

## Project layout

Each game is a self-contained Godot project inside its own folder. The repository
has a single root `.git`; game folders are not separate repositories.

```text
<game>/
├── project.godot
├── icon.svg
├── README.md
├── scenes/
│   ├── *.tscn          # entity scenes
│   └── levels/         # level / main scenes
├── scripts/            # GDScript files (+ .uid)
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── addons/
└── tests/              # headless smoke tests
```

`.godot/` is a generated cache and is ignored. Commit `.uid` files alongside their
scripts and scenes. Add a short `README.md` in each game folder with run
instructions, controls, and how to run its tests.
