---
quick_id: 261120-dik
description: Dash lockouts, blocked-dash feedback, no dash in aim, softer dash blends
status: complete
completed: 2026-11-20
commits: 4
plan_head_before: 3a78149e7bb48d5a82ec052ef4f883d2bc992e47
plan_head_after: 6ea364e1f906c58e0c29178e87d2aa4c2c8d80c4
actuals:
  tokens: 26000
  tasks: 5
  commits: 4
key-files:
  created:
    - attimo/tests/smoke/test_dash_lockout.gd
  modified:
    - attimo/autoload/event_bus.gd
    - attimo/scripts/player/movement_config.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/procedural_pose.gd
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/scripts/player/states/ground_state.gd
    - attimo/scripts/player/states/air_state.gd
    - attimo/scripts/player/states/dash.gd
    - docs/CONVENTIONS.md
    - docs/ANIMATION-MAP.md
    - docs/MOVEMENT-METRICS.md
---
# Quick 261120-dik: Dash lockouts and blocked-dash feedback Summary

One shared `PlayerController.dash_locked_reason()` locks the dash while aiming, during the Jump 3 / long jump stage 3 pirouette, in the 0.1 s after touchdown and in the 0.1 s after a jump take-off; a refused press emits `EventBus.dash_blocked`, kicks a 6 degree forward twitch and is consumed (no buffer, no cooldown, no air dash spent).

## What changed

- `PlayerController`: `dash_locked_reason()` (reasons `aim`, `pirouette`, `landing`, `takeoff`), `can_dash()` uses it, `dash_press_starts_dash()` is the press check of `GroundState` and `AirState` (one emission per press, frame-guarded). `dash_landing_lock_timer`, `dash_takeoff_lock_timer` and `dash_twitch_timer` tick in `_tick_timers`; landing sets the landing timer in `_land`, a jump (upward speed on leaving the floor, not a ledge walk-off) sets the take-off timer in `_leave_floor`. Pirouette state is read from `ProceduralPose.spinning`.
- `EventBus.dash_blocked(position, reason)`.
- `ProceduralPose.twitch_angle`: half sine of `dash_blocked_twitch_deg` over `dash_blocked_twitch_time`, added to the Mannequin lean via `total_lean()` (the eased `lean_angle` keeps its meaning). No dash clip, no velocity.
- `MannequinAnimator.blend_time_for()` and `apply_blend()` write `dash_in_blend` (0.06 s from Locomotion), `dash_in_blend_air` (0.08 s from Jump, Jump2, LongJump, Fall) and `dash_out_blend` (0.15 s out of a dash node) to the matching state-machine edge just before each `travel`, so they are live-tunable and the generated `mannequin_tree.tres` is untouched. Slide edges keep their own values. The same-frame travel guard is unchanged.
- New MovementConfig exports (7, F2 panel now 56 sliders): `dash_block_takeoff` 0.1, `dash_block_landing` 0.1 (Timing windows), `dash_blocked_twitch_deg` 6.0, `dash_blocked_twitch_time` 0.1 (Pose), `dash_in_blend` 0.06, `dash_in_blend_air` 0.08, `dash_out_blend` 0.15 (Clip playback).
- Aim: `can_dash()` is false while aiming. `DashLeft`, `DashRight`, `DashBack` and `dash_node_for` stay in place, unreachable; documented in `docs/ANIMATION-MAP.md` and `docs/CONVENTIONS.md`; D-12 amended in `03-CONTEXT.md` (uncommitted planning file, see below).

## Tests

- New `test_dash_lockout` (55 checks): each lockout blocks and emits once with its reason, no cooldown or air dash spent, no buffering (a key held through the window does not fire later), aim blocks on ground and in air, a refused press does not reset a running cooldown, twitch peak, direction, no motion or dash clip, decays to exactly 0, normal dash outside lockouts unchanged, cooldown refusal emits nothing, blend rows and live edge values, Land and IdleBreak fade-out times above 0.
- Updated for the new rule: `test_aim_layer` (aimed dash cases assert a refused press, dormant node mapping, aimed air dash blocked), `test_aim_mode` (d, h), `test_procedural_pose` (aimed lean checks now run on a mid-dash aim press, air-dash-in-pirouette is now a blocked press), `test_long_jump` (c7 pirouette press refused; hops dash after the landing lockout).
- `test_latency`, `test_animation_timing` and `tools/movement_metrics.gd` wait out the landing and take-off windows (`Fixtures.lock_ticks`). Latency rows stay "Target met" and the committed latency numbers in `docs/MOVEMENT-METRICS.md` were left as they were (latency-only noise reverted); the config snapshot rows and two hop-note strings were regenerated.
- `bash attimo/tests/run.sh`: tests=39 passed=1884 failed=0, `RUN.SH: PASSED`.

## Deviations from Plan

- [Rule 3 - Blocking] The hop stack scenarios (dash + jump on the landing tick) and latency / measurement dash loops press right after touchdown, which the landing lockout now refuses by design. The tests and the measure tool now dash after the lockout (still inside the 0.35 s landing window, so the stack logic is unchanged). Gameplay consequence for the developer: a dash-hop chain needs the dash press 0.1 s or later after landing, not on the landing tick.
- Cooldown refusals and a spent air dash give no blocked feedback: the decisions name lockouts only. One line to change in `dash_press_starts_dash()` if the developer wants feedback there too.
- Landing overlay and idle break: both OneShots already fade out (0.1 s) and the animator requests FADE_OUT, so nothing was changed there; `test_dash_lockout` (b6) guards that the fade-out times stay above 0.
- A walk off a ledge does not start the take-off lockout (only a jump with upward speed does), so a dash right after walking off still works.
- `.planning/phases/03-animated-mannequin-aim-mode/03-CONTEXT.md` D-12 was edited (amended wording) and is left uncommitted for the orchestrator.

## Known Stubs

None.

## Notes

- `test_aim_layer (h6)` (aim layer reaches 0 within Exit length plus blend) failed once in a loaded full run (7 + 13 frames against a limit of 19) and passed in an isolated rerun and in the final full run; it depends on wall-clock animation time and is not touched by this change.
- Not staged by instruction: `attimo/project.godot`, the two `*.png.import` files, `.planning/state.json`.

## Self-Check: PASSED

- Commits cb22ec8, 8f10123, 983e502, 6ea364e exist on `dev`; `test_dash_lockout.gd` exists; full suite passed.
