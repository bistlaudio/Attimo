---
phase: 02-movement-core-follow-camera
plan: 07
subsystem: movement
tags: [platforms, conveyor, slopes, stairs, animatable-body, fall-reset, prototype-bits]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 PlayerController (manual platform carry in _leave_floor, speed-scaled snap in the D-13 band, teleport), Fixtures; 02-03 Primitive_Slope and Primitive_Beam wrappers"
provides:
  - "MovingPlatform (AnimatableBody3D, sync_to_physics, LINEAR ping-pong and CIRCLE) and res://scenes/proto/moving_platform.tscn"
  - "FallReset (Area3D on Hazard, masks Player, deferred teleport and camera snap)"
  - "test_platforms: 40 checks proving MOVE-08 (conveyor, platforms, momentum on leave, ramps, stairs, ledge, fall reset)"
affects: [02-14]

actuals:
  tokens: 5950
  tasks: 2
  commits: 3
plan_head_before: 7e3f89f6c6499c9d7dee00e549c2d790e31f1a7a
plan_head_after: 14accc3c3052a3f23548bae1c0c72467866824aa
commits: 3

tech-stack:
  added: []
  patterns:
    - "Gym helpers live in scripts/gym/ and join a group (moving_platform); motion only in _physics_process with sync_to_physics so the engine reports platform velocity"
    - "Area3D hazards never change a body inside the physics flush: teleport and camera snap through call_deferred (T-02-08)"
    - "Ramp and stair tests sample every tick with a downward World-mask ray, snap band checked per grounded tick, tick rate restored to 60"

key-files:
  created:
    - attimo/scripts/gym/moving_platform.gd
    - attimo/scripts/gym/fall_reset.gd
    - attimo/scenes/proto/moving_platform.tscn
    - attimo/tests/smoke/test_platforms.gd
  modified: []

key-decisions:
  - "No retune was needed: snap_min 0.3, snap_max 0.5, platform_carry 1.0 pass every scenario; movement_default.tres and player_controller.gd are untouched (A23)"
  - "Stairs are Primitive_Beam instances turned 90 degrees about Y (4 m along Z, 1 m deep along X) and sunk so each top is at 0.15 * n, ending in a 0.9 m landing box"

requirements-completed: [MOVE-08]

coverage:
  - id: D1
    description: "Conveyor (3 m/s) carries an idle player 3.0 +/- 0.3 m per second; jumping off keeps 3.0 +/- 0.15 m/s of horizontal momentum"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_platforms"
        status: pass
    human_judgment: false
  - id: D2
    description: "MovingPlatform carries the player (linear 0.000 m drift, vertical worst 0.033 m through the reversal, circular 120 of 120 grounded ticks, 0.068 m drift); jump and walk-off keep the platform speed"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_platforms"
        status: pass
    human_judgment: false
  - id: D3
    description: "45 degree ramp at 10.5 m/s and 60 TPS: 0 airborne ticks, max 0.208 m above the surface, snap inside 0.3-0.5 on every grounded tick; six 0.15 m risers climbed and descended without a jump; 0.25 m ledge blocks"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_platforms,test_ground_movement"
        status: pass
    human_judgment: false
  - id: D4
    description: "FallReset returns a fallen player to the respawn marker with zero velocity (10 ticks after the fall) and snaps the camera rig"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_platforms"
        status: pass
    human_judgment: false
---

# Phase 2 Plan 07: Moving Platforms, Fall Reset and Slope/Stair Proof Summary

**MovingPlatform (AnimatableBody3D, linear and circular) and FallReset building blocks plus a 40-check test_platforms that proves conveyor and platform carry with momentum on leave, 45 degree ramps at 10.5 m/s with zero airborne ticks inside the D-13 snap band, 0.15 m stairs and a blocking 0.25 m ledge, all without touching the controller.**

## Performance

- **Tasks:** 2 of 2
- **Files:** 4 created (plus 2 generated `.uid` files), 0 modified
- **Commits:** d7fed55 (RED test), 6486e9b (platform, reset, scene), 14accc3 (slope and stair scenarios)

## Accomplishments

- `MovingPlatform`: LINEAR ping-pong along `travel`, CIRCLE of `radius` around `start - (radius, 0, 0)`, motion only in `_physics_process` with `sync_to_physics`, joins group `moving_platform`. `moving_platform.tscn` is a World-layer AnimatableBody3D with a 4 x 1 x 4 box and the Primitive_Floor mesh.
- `FallReset`: Hazard layer, masks Player, `body_entered` casts to PlayerController and defers `teleport(respawn)` and `camera_rig.snap_to_target()`.
- Measured results (60 TPS unless noted): conveyor carries 3.00 m in 1 s and launch momentum is exactly 3.000 m/s; linear platform offset drift 0.000 m; vertical platform worst 0.033 m from the top through the reversal; circular platform 120/120 grounded ticks, 0.068 m drift; walk-off at run speed leaves with 10.0 m/s (7 + 3).
- Ramp up/down at 10.5 m/s: 0 airborne ticks, max height above the surface 0.208 m (the capsule's round bottom on a 45 degree face, hence the plan's 0.3 bound), `floor_snap_length` inside [0.3, 0.5] on all 94 and 76 grounded ticks. Stairs: 0.9 m landing reached at y 0.901 with no jumped fact, 0 airborne ticks descending. A 0.25 m ledge holds the player at x 0.916, y 0.000.

## 10 TPS diagnostic numbers (A22, printed not pinned)

| Run | Reached | Ticks | Airborne ticks | Largest gap to surface below | Max y |
|-----|---------|-------|----------------|------------------------------|-------|
| Ramp up, 10 TPS | yes | 17 | 0 | 0.000 m | 4.296 (plateau 4.0) |
| Ramp down, 10 TPS | yes | 13 | 4 | 1.929 m | 4.001 |

The snap band stayed 0.3-0.5 m at 10 TPS (never widened). The down run is airborne for 4 ticks as predicted (1.05 m per tick exceeds the 0.5 m snap); it never rises above the plateau. The up run peaks 0.296 m above the plateau top, just inside the 0.3 m no-launch bound, deterministic over three runs.

## Verification

- `bash attimo/tests/run.sh test_platforms` ended `passed=40 failed=0`, `RUN.SH: PASSED` (three consecutive runs identical).
- Plan gate `bash attimo/tests/run.sh test_platforms,test_ground_movement,test_proto_pieces,test_feedback_guard,test_project_settings`: `tests=5 passed=189 failed=0`, `RUN.SH: PASSED`.
- Acceptance greps all pass (MovingPlatform 1, sync_to_physics 2, moving_platform group, HAZARD 1, call_deferred 2, AnimatableBody3D 1, slope/beam scene references, `duplicate()` 3, tick-rate restore to 60, `floor_snap_length` 3); `snap_min = 0.3`, `snap_max = 0.5` unchanged.
- No commit of this plan touches `attimo/scripts/player/player_controller.gd` (A23 check over all three commits prints nothing).

## Deviations from Plan

None - plan executed exactly as written. RED was real for Task 1 (missing classes, parse errors). Task 2's scenarios needed no production change, so they passed on first run; no snap or carry retune was required and none was made.

## Issues Encountered

- Pre-existing, out of scope (noted in 02-03): `test_proto_pieces` prints `!is_inside_tree()` engine messages for the first wrapper. Not touched.

## Known Stubs

None.

## Threat Flags

None. T-02-08 mitigated: teleport and camera snap are deferred, `teleport()` resets physics interpolation last.

## Next Phase Readiness

02-14 can assemble the gym from `MovingPlatform`, `FallReset`, and the Slope and Beam wrappers. Note for the gym build: stairs need Beam instances rotated 90 degrees about Y, sunk into the floor.

## Self-Check: PASSED

- All four created files exist on disk and are tracked.
- Commits d7fed55, 6486e9b, 14accc3 are ancestors of HEAD on branch `dev`.
