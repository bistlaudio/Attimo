---
phase: 03-animated-mannequin-aim-mode
plan: 03
subsystem: player-control
tags: [godot, aim-mode, facing, event-bus, movement-config, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 confirmed aim decisions (items 4 and 6), 03-10 timing guard over the animator
provides:
  - PlayerController.aiming, _tick_aim(), _apply_aim_facing() and ground_target_speed(direction)
  - EventBus.aim_changed(active: bool), emitted once per hold start and end
  - MovementConfig "Aim" group with aim_speed_factor 0.75 and aim_back_speed_factor 0.6 (F2 rows generated)
  - test_aim_mode with 33 checks (flag, bus fact, camera-locked facing, strafe, dash, release, no camera, speeds, jump and dash)
affects: [03-04, 03-05, 03-06, 03-07, 03-08, 03-09]

actuals:
  tokens: 4400   # chars/4 over the added diff lines in attimo/ (17742 chars)
  tasks: 2
  commits: 2
plan_head_before: 0a1389c788ad3365d1e0ee69fe514c1c92f58782
plan_head_after: 18982a89e73300944b605c1b152dbc57de088754
commits: 2

tech-stack:
  added: []
  patterns:
    - "Aim facing is applied in PlayerController._tick_aim before the state machine, so state fallbacks (Dash with no input) read the crosshair facing"
    - "While aiming, face() and face_now() return at once and input_direction() reads rig.yaw instead of steering_yaw()"
    - "Tests that need one full physics tick await two physics frames: SceneTree.physics_frame fires before that tick's _physics_process"

key-files:
  created:
    - attimo/tests/smoke/test_aim_mode.gd
    - attimo/tests/smoke/test_aim_mode.gd.uid
  modified:
    - attimo/autoload/event_bus.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/movement_config.gd
    - attimo/scripts/player/states/idle.gd
    - attimo/scripts/player/states/run.gd
    - docs/CONVENTIONS.md
    - docs/MOVEMENT-METRICS.md

key-decisions:
  - "Aim facing with no CameraRig uses the viewport camera's flattened -Z; with no camera at all it changes nothing and raises no error"
  - "A zero move direction while aiming returns the aim forward speed (no back penalty), as the plan specifies"
  - "No reset_physics_interpolation on aim enter (A-03-2): one interpolated tick of turn is the accepted cost of no smoothing delay"

requirements-completed: []

duration: about 35 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 3: Aim hold, camera-locked facing and aim speed Summary

**Holding `aim` sets PlayerController.aiming on the same physics tick, announces EventBus.aim_changed once, pins the figure's yaw to the camera with no smoothing, steers by the rig's true yaw, and slows the ground run by tunable MovementConfig factors (0.75, and 0.6 more for backward) while jump and dash stay untouched.**

CAM-02 is listed in the plan frontmatter but is deliberately not marked complete: it spans the whole phase and the orchestrator marks it at phase end.

## Accomplishments

- `EventBus.aim_changed(active: bool)` with a doc comment naming the emitter; the old Jump 3 nickname in the bus comment and the `chain_stage` comment is now "the pirouette jump" (D-07).
- `PlayerController._tick_aim()` runs after `_tick_timers` and before the state machine. It reads `Input.is_action_pressed(&"aim")`, sets `aiming` and emits only on a change. `_apply_aim_facing()` sets `visual_root.rotation.y` to the flat camera forward (`rig.yaw` under a CameraRig, else the camera's flattened -Z) every tick.
- `face()` and `face_now()` return at once while aiming, so `Dash.enter` and `LongJump.enter` cannot turn the figure away from the crosshair; Dash's no-input fallback reads the already-applied camera facing (Pitfalls 9 and 10).
- `input_direction()` uses `rig.yaw` while aiming: W runs exactly along the crosshair, A and D strafe.
- `MovementConfig` gains the "Aim" group (`aim_speed_factor` 0.75 and `aim_back_speed_factor` 0.6, both `@export_range(0.1, 1.0, 0.05)`); header now says nine groups, 36 live sliders. F2 rows come from the resource (`test_tuning_panel` passes with no panel code).
- `PlayerController.ground_target_speed(direction)` feeds `Idle` and `Run`: `run_speed` normally, `run_speed * aim_speed_factor * lerpf(1, aim_back_speed_factor, backness)` while aiming, with backness from the input direction against the flat facing.
- `docs/CONVENTIONS.md`: `aim_changed` row in the event bus table, `jumped` row reworded, new aim rule under "Player scene" (facing ownership, true-yaw steering, aim speed). `docs/MOVEMENT-METRICS.md` regenerated (`MEASURE: PASSED`) and lists both new config rows.
- `test_aim_mode` (33 checks): (a) flag and exactly one `aim_changed(true)` on the first tick; (b) facing within 1 degree of the camera, and of a 1 rad camera turn after one tick; (c) strafe along the camera's left with the facing kept; (d) dash along the camera's right with the facing unchanged; (e) one `aim_changed(false)` and facing handed back to `face()`; (f) no camera: no facing change, no error, hand-back on release; (g) settled speeds 8.500 / 6.375 forward / 6.375 strafe / 3.825 back, plus a diagonal back step between and a zero direction; (h) jump enters Jump and dash enters Dash at `dash_speed` (22.0) while aiming.

## Task Commits

1. Task 1 (tracer): aim hold, camera-locked facing, aim_changed fact - `ea6e694`
2. Task 2: aim ground speed factors in MovementConfig and the states - `18982a8`

Tracer gate: the `<verify>` was automated-only, re-run end to end after the commit (`SMOKE SUMMARY: tests=5 passed=236 failed=0`, `RUN.SH: PASSED`) before expanding.

## Verification

- Task 1: `bash attimo/tests/run.sh test_aim_mode,test_input_map,test_conventions,test_feedback_guard,test_event_log` - 236 checks, 0 failed, `RUN.SH: PASSED`. Acceptance greps: `signal aim_changed(active: bool)` 1, `aim_changed.emit` 1, `aim_changed` in CONVENTIONS.md 1, `salto` in event_bus.gd and player_controller.gd 0 and 0.
- Task 2: `MEASURE: PASSED`; `bash attimo/tests/run.sh test_aim_mode,test_ground_movement,test_movement_metrics,test_tuning_panel,test_dash,test_long_jump` - 291 checks, 0 failed. Acceptance greps: both config vars 1, `ground_target_speed(` in idle.gd and run.gd 1 each, `aim_speed_factor` in MOVEMENT-METRICS.md 1.
- Full suite: 27 tests, 1168 checks, 0 failed, `RUN.SH: PASSED`.

## Deviations from Plan

None - plan executed exactly as written.

One test-authoring note, not a code deviation: `SceneTree.physics_frame` fires before the tick's `_physics_process`, so the plan's "one physics frame" assertions await two frames (`TICK_FRAMES`) to cover exactly one full tick. The first run also needed one `process_frame` before spawning the rig, because `snap_to_target` ran before the root was in the tree.

## Issues Encountered

None blocking. The shoulder swap is dropped by the developer (no `aim_shoulder_swap` action, Q unbound); this plan never referenced it.

## Hand-off notes

- `MannequinAnimator` still derives the run blend as `horizontal_speed / run_speed`, so while aiming the blend tops out at 0.75. 03-07 replaces it with the aim 2D blend target, so nothing was changed here.
- `docs/MOVEMENT-METRICS.md` still labels the row "Jump 3 (salto)" and `test_movement_metrics` checks that label; 03-06 owns that rename.
- `movement_config.gd`, `jump.gd`, `hit_puffs.gd` and tests still say "salto" in comments; only the bus and controller comments were in this plan's scope.
- Unrelated working-tree changes (`attimo/project.godot`, two `*.png.import` files, `.planning/state.json`) were never staged.

## Known Stubs

None.

## Threat Flags

None. T-03-05: both factors have a 0.1 minimum, so no slider value zeroes the aim target speed. T-03-06: `face()`/`face_now()` return early while aiming and `test_aim_mode` asserts that dash and strafe keep the crosshair facing and that release hands facing back.

## Self-Check: PASSED

Files verified present: attimo/tests/smoke/test_aim_mode.gd, attimo/autoload/event_bus.gd, attimo/scripts/player/player_controller.gd, attimo/scripts/player/movement_config.gd. Commits ea6e694 and 18982a8 are ancestors of HEAD.
