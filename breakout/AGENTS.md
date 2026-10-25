# Breakout

Brick-breaker. Main scene: `scenes/levels/main.tscn`.

## Structure

- `scenes/` — entity scenes (`ball`, `paddle`, `bricks`, `walls`);
  `bricks.tscn` is a single brick.
- `scenes/levels/main.tscn` — the level; `Main/Bricks` is the brick container.
- `scripts/` — one script per scene plus `main.gd` for level state and scoring.

## Behaviour notes

- Fixed 1080x720 viewport (`stretch/mode=canvas_items`, `aspect=keep`); walls and
  bricks are laid out once in `_ready`.
- HUD lives under `Main/UI`; don't parent it under `Bricks`.
- `Main/_end_game()` stops the ball and paddle; freeze any new gameplay nodes there.
- The kill zone sits below the walls; `_on_ball_lost` ignores non-ball bodies.
- Paddle: top hits use position steering plus `PADDLE_MOTION_BIAS`; side hits use
  physical reflection with `PADDLE_IMPACT`. `Paddle.motion_velocity` is the actual
  per-frame displacement (0 against a wall) and is read by the ball on impact.
- Input actions use `device: 16` (Godot 4.7's `DEVICE_ID_KEYBOARD`); that is correct.
