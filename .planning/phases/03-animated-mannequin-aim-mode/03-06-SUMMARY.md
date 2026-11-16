---
phase: 03-animated-mannequin-aim-mode
plan: 06
subsystem: player-presentation
tags: [godot, procedural-pose, lean, pirouette, movement-config, metrics, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 Mannequin under VisualRoot, DEV-01/DEV-03 decisions; 03-03 PlayerController.aiming
provides:
  - ProceduralPose node (class ProceduralPose): pivoted lean and spin written on the Mannequin child every physics tick
  - MovementConfig "Pose" group, 8 F2 sliders (dash_lean_deg, stretch_lean_deg, aim_lean_scale, lean_in_time, lean_out_time, pirouette_lead_time, pirouette_finish_time, pose_pivot_height)
  - Jump 3 and long jump stage 3 pirouette with the DEV-03 aim gate and finish cut
  - Metrics output, test and config comment name Jump 3 "the pirouette jump"
  - test_procedural_pose (53 checks)
affects: [03-07, 03-08, 03-09]

actuals:
  tokens: 9600   # chars/4 over the added diff lines (38527 chars): code, tests, regenerated metrics doc
  tasks: 3
  commits: 3
plan_head_before: 65089821f0d01806ae4dbf5885ab75be5dfa5631
plan_head_after: 483510ef1686b39cec075480622e3ce71b01abe3
commits: 3

tech-stack:
  added: []
  patterns:
    - "Visual-only pose = child node of Player, listens to StateMachine.state_changed, writes the Mannequin transform in _physics_process only (DEV-01)"
    - "Pivoted rotation: Transform3D(R, p - R*p) with p at hip height, exactly IDENTITY when upright"
    - "Hand-written move_toward easing and a closed-loop spin rate, no tween classes (feedback guard)"

key-files:
  created:
    - attimo/scripts/player/procedural_pose.gd
    - attimo/scripts/player/procedural_pose.gd.uid
    - attimo/tests/smoke/test_procedural_pose.gd
    - attimo/tests/smoke/test_procedural_pose.gd.uid
  modified:
    - attimo/scenes/player/player.tscn
    - attimo/scripts/player/movement_config.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/tools/movement_metrics.gd
    - attimo/tests/smoke/test_movement_metrics.gd
    - docs/MOVEMENT-METRICS.md

key-decisions:
  - "ProceduralPose finds the StateMachine with get_node (not player.state_machine): the Player's @onready is set after its children are ready, and the pose must connect state_changed before the initial Idle emission"
  - "pose_basis() is public so the nesting switch (spin_about_body_axis) can be compared in a test for the same lean and spin"
  - "A spin within 0.02 rad (about 1 degree) of a full turn counts as complete, so the closed-loop tail (0.05 s divisor clamp) ends cleanly"

requirements-completed: []

duration: about 35 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 6: Procedural Pose Summary

**ProceduralPose leans the Mannequin about its hips on a ground dash, holds a 60 degree stretch through the whole long jump without a dip, spins it once on Jump 3 and long jump stage 3 (finished before touchdown), keeps the air dash upright, and follows DEV-03: no pirouette with aim held at take-off, and an aim press or air dash mid-spin finishes the turn within 0.1 s.**

MOVE-09 is listed in the plan frontmatter but is deliberately not marked complete: the orchestrator marks MOVE-09, CAM-02 and MOVE-11 at phase end.

## Accomplishments

- `ProceduralPose` (`scripts/player/procedural_pose.gd`), child of Player after MannequinAnimator, node_paths `player` and `mannequin` (`VisualRoot/Mannequin`). Written in `_physics_process` only; `VisualRoot` yaw, rotation x and z are never touched (DEV-01). Public: `lean_angle`, `lean_axis`, `spin_angle`, `spinning`, `pose_basis()`, exports `spin_about_body_axis` (true, corkscrew) and `pirouette_clockwise` (true).
- Lean: ground dash `dash_lean_deg` (20), long jump and the flight after it `stretch_lean_deg` (60) until landing, air dash and everything else 0 (D-02); eased with `move_toward` from where it is, so Dash into LongJump never dips (D-04). Axis is up x travel direction in VisualRoot space; the last axis is kept while easing out. `aim_lean_scale` (0.5) applies while aiming.
- Pirouette: starts on the Jump (chain stage 3) or LongJump (stage 3) entry tick when aim is not held. Closed-loop rate `remaining / max(predicted_time_left - pirouette_lead_time, 0.05)` from vertical speed, height above take-off and the config gravities; copes with a released (cut) jump. Finish mode (landing, aim press, air dash): remaining angle over `pirouette_finish_time`, forward only (DEV-03). Measured: a held Jump 3 (50 ticks of flight) finishes its spin 2 ticks before the touchdown sample.
- `MovementConfig` Pose group (8 `@export_range` rows with doc comments, positive minimums on every divisor); header now says ten groups, 44 sliders. `docs/MOVEMENT-METRICS.md` regenerated (twice).
- Jump 3 is named "Jump 3 (pirouette)" in the metrics tool, `test_movement_metrics`, the generated doc and the `jump_3_height` comment; `jump.gd` header reworded (no "salto").
- `test_procedural_pose`: 53 PASS checks over 10 scenarios (rest identity, dash lean and pivot, stretch continuity and hold, air dash upright, Jump 1/2 no spin, held and cut Jump 3, long jump stages 1/2/3, aim gate for both pirouettes, aim lean peak, air dash finish, aim press finish, finite bases, nesting switch).

## Task Commits

1. **Task 1 (tracer): ground dash lean on the Mannequin, Pose config group** - `051e864` (feat)
2. **Task 2: long-jump stretch, Jump 3 / stage 3 pirouette, aim behaviour** - `0a53581` (feat)
3. **Task 3: Jump 3 named the pirouette jump in the metrics output** - `483510e` (docs)

Tracer gate: `<verify>` for Task 1 (`measure_movement` plus `test_procedural_pose,test_feedback_guard,test_movement_metrics,test_dash`) passed end to end before Task 2 started.

## Verification

- `bash attimo/tests/run.sh test_procedural_pose,test_long_jump,test_jump,test_feedback_guard`: 178 checks, `failed=0`.
- `bash attimo/tests/run.sh test_movement_metrics,test_tuning_panel`: 110 checks, `failed=0`; `MEASURE: PASSED`.
- Full suite `bash attimo/tests/run.sh`: 30 tests, 1276 checks, `failed=0`, `RUN.SH: PASSED`.
- Acceptance: `class_name ProceduralPose` 1, `procedural_pose.gd` in player.tscn 1, `func _process` 0, `var stretch_lean_deg` 1, `dash_lean_deg` in MOVEMENT-METRICS 1, `pirouette_finish_time` in the script (several), `salto` 0 in jump.gd / movement_metrics.gd / test_movement_metrics.gd / movement_config.gd / MOVEMENT-METRICS.md, `Jump 3 (pirouette)` 1 per file, `DEV-03` in both procedural_pose.gd and its test.

## Deviations from Plan

None - plan executed exactly as written.

Notes, not deviations:
- The plan's `player.state_machine.state_changed` is realised as `player.get_node(^"StateMachine")` (see key-decisions); same signal, same timing.
- The per-plan commit ledger (`gsd-plan-head-before-03-06`) was written right after the first task commit instead of before it; the base recorded is the true parent of that commit (`6508982`), so `plan_head_before` and `commits` are exact.
- Left untouched on purpose (outside this plan's file list): the word "salto" still appears in `scripts/debug/hit_puffs.gd`, `tests/smoke/test_hit_puffs.gd` and `tests/smoke/test_long_jump.gd` comments and check messages. A later wording pass (03-09) can sweep them.

## Known Stubs

None.

## Threat Flags

None. T-03-10 is mitigated as planned: the divisor fields (`lean_in_time`, `lean_out_time`, `pirouette_finish_time`) have strictly positive minimums, the spin rate divisor is clamped to 0.05 s, a non-finite prediction falls back to finish mode, non-finite angles reset the pose, and every scenario of `test_procedural_pose` asserts finite bases.

## Issues Encountered

None. The unrelated working-tree changes (project.godot, two .png.import files, .planning/state.json) were left unstaged.

## Judgement left for 03-09 (gym check)

- Pirouette direction (clockwise) and the corkscrew versus tilted-top nesting (`spin_about_body_axis`) are visual choices; the numbers are all F2-tunable.
- The dash lean reaches 20 degrees in a single tick because the ease rate is derived from `stretch_lean_deg / lean_in_time` (1200 deg/s) as the plan specifies.

## Next

Ready for 03-07.

## Self-Check: PASSED

- Files exist: procedural_pose.gd, test_procedural_pose.gd, player.tscn with the ProceduralPose node, regenerated MOVEMENT-METRICS.md.
- Commits `051e864`, `0a53581` and `483510e` are on `dev`.
