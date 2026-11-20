---
quick_id: 261120-ef9
description: Remove dash lockouts for pirouette, landing, takeoff; keep aim block and soft blends
status: complete
completed: 2026-11-20
commits: 3
plan_head_before: 5ba6af2e6f7adc7a36f9790e56f37d56e5849e92
plan_head_after: 3b532798e5ddf228cf47f7f5bc6dac42a7c17ae1
actuals:
  tokens: 14000
  tasks: 3
  commits: 3
key-files:
  modified:
    - attimo/autoload/event_bus.gd
    - attimo/scripts/player/movement_config.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/dash.gd
    - attimo/tests/fixtures.gd
    - attimo/tests/smoke/test_dash_lockout.gd
    - attimo/tests/smoke/test_aim_layer.gd
    - attimo/tests/smoke/test_animation_timing.gd
    - attimo/tests/smoke/test_latency.gd
    - attimo/tests/smoke/test_long_jump.gd
    - attimo/tests/smoke/test_procedural_pose.gd
    - attimo/tools/movement_metrics.gd
    - docs/CONVENTIONS.md
    - docs/ANIMATION-MAP.md
    - docs/MOVEMENT-METRICS.md
---
# Quick 261120-ef9: Remove the pirouette, landing and take-off dash lockouts Summary

Aim is the only dash lockout again: `PlayerController.dash_locked_reason()` returns `aim` or nothing, so a dash press during the Jump 3 / long jump stage 3 pirouette, on the landing tick (dash-hop chain) and right after a jump take-off starts a dash as before quick 261120-dik. The blocked-press twitch, `EventBus.dash_blocked(position, reason)` (reason `aim` only) and the softer dash blends stay.

## What changed

- `PlayerController`: removed `dash_landing_lock_timer`, `dash_takeoff_lock_timer`, `DASH_LOCK_PIROUETTE`, `DASH_LOCK_LANDING`, `DASH_LOCK_TAKEOFF`, the `_pose` reference, the timer ticks and the sets in `_land`, `_leave_floor` and `teleport`. `dash_press_starts_dash()`, `_block_dash()` and `dash_twitch_timer` are unchanged. The 0.35 s landing window (`combo_timer`, `landing_window`) stack logic is untouched.
- Removed `MovementConfig` exports: `dash_block_takeoff` and `dash_block_landing` (F2 panel back to 54 sliders). `dash_blocked_twitch_deg`, `dash_blocked_twitch_time`, `dash_in_blend`, `dash_in_blend_air`, `dash_out_blend` stay.
- Tests: `test_dash_lockout` now asserts aim blocks (existing aim, twitch, open-dash and blend scenarios) and that a press on take-off, on the landing tick and inside the Jump 3 pirouette starts a dash with no `dash_blocked`. `test_long_jump` (c7 one air dash after Jump 3) and `test_procedural_pose` (d1 air dash finishes the spin, hop waits) are back to their pre-261120-dik form; the aimed-hop and aimed-lean reworks stay because aim still blocks the dash. `Fixtures.lock_ticks` and its waits in `test_latency`, `test_animation_timing`, `test_aim_layer` and `tools/movement_metrics.gd` are gone; the hop measurement presses on the landing tick again.
- Docs: `CONVENTIONS.md` (lockout rule, `dash_blocked` reason), `ANIMATION-MAP.md` (blocked dash row), `MOVEMENT-METRICS.md` (two config rows removed, hop notes say landing tick). The latency rows were not touched and read Target met.

## Verification

`bash attimo/tests/run.sh`: tests=39 passed=1871 failed=0, `RUN.SH: PASSED` (run twice, the second after the docs edits). The count is lower than the 1884 of 261120-dik because the removed lockout scenarios had fewer checks than the new reduced ones.

## Deviations from Plan

None. The plan was one line of scope; the choice to restore the pre-dik test scenarios (c7, d1, landing-tick hop) rather than only delete waits follows from "the dash behaves again as before".

## Known Stubs

None.

## Notes

- Not staged by instruction: `attimo/project.godot`, the two `*.png.import` files, `.planning/state.json`. Planning artifacts (this file, the plan) are left uncommitted for the orchestrator.

## Self-Check: PASSED

- Commits 1bfeef9, 1c2722e, 3b53279 exist on `dev`; full suite passed.
