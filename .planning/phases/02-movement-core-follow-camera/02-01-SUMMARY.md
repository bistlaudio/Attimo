---
phase: 02-movement-core-follow-camera
plan: 01
subsystem: gameplay-movement
tags: [godot, gdscript, tracer, character-body, movement-config, camera-rig, physics-interpolation, jolt]

requires:
  - phase: 01-foundation
    provides: "State/StateMachine, PlayerController scaffold, EventBus facts, Fixtures and the headless smoke runner"
provides:
  - "MovementConfig resource (class_name MovementConfig) with every movement number and derived gravity/jump speeds"
  - "PlayerController that owns move_velocity and vertical_speed, with half-step gravity, one move_and_slide(), speed-scaled floor snap in the D-13 band, manual platform carry, camera-relative input"
  - "GroundState and AirState bases with real Idle, Run, Jump and Fall states"
  - "CameraRig (top-level sibling, interpolated follow, mouse look, steering_yaw() hook)"
  - "EventBus.landed emitted from floor contact with a real impact speed"
  - "Fixtures: spawn_floor, spawn_box, wait_until, spawn_camera_rig, send_action_event, send_mouse_motion"
affects: [02-02, 02-03, 02-04, 02-05, 02-06, 02-07, 02-08, 02-09, 02-10, 02-11, 02-12, 02-13, 02-14, phase-03, phase-05, phase-11]

actuals:
  tokens: 9650
  tasks: 3
  commits: 3

commits: 3
plan_head_before: 73639518dfbdb5ee84eb5e5e915ae36ff967d49a
plan_head_after: 177e92278e2de61230ca617d98c36ce29d0b5096

tech-stack:
  added: []
  patterns:
    - "Own-velocity controller: states write move_velocity/vertical_speed, the controller composes velocity and calls move_and_slide() once"
    - "Half-step (Verlet) gravity around the move for tick-rate independent jump height"
    - "Top-level interpolation-off camera rig reading get_global_transform_interpolated() in _process"
    - "Camera-relative input through CameraRig.steering_yaw(), bare-camera yaw fallback, world-axis fallback"
    - "Tests derive expectations from player.config and duplicate the config before mutating it"

key-files:
  created:
    - attimo/scripts/player/movement_config.gd
    - attimo/resources/player/movement_default.tres
    - attimo/scripts/player/states/ground_state.gd
    - attimo/scripts/player/states/air_state.gd
    - attimo/scripts/camera/camera_rig.gd
    - attimo/scenes/camera/camera_rig.tscn
    - attimo/tests/smoke/test_ground_movement.gd
  modified:
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/idle.gd
    - attimo/scripts/player/states/run.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scripts/player/states/fall.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/fixtures.gd

key-decisions:
  - "Idle accelerates on the tick it hands over to Run so no input tick is lost"
  - "Run stays in Run while braking and returns to Idle only below 0.01 m/s, so the run animation plays through the stop"
  - "Camera yaw for a bare camera is read with get_euler(EULER_ORDER_YXZ).y, robust against pitch"
  - "Dash.gd stays on its Phase 1 timer until 02-09 (A18)"

patterns-established:
  - "State bases: GroundState._ground_update and AirState._air_update are the only hooks subclasses override"
  - "One kinematic move call: grep -rn move_and_slide in scripts/ and autoload/ lists exactly one line"
  - "No feedback tokens (Tween, shake, particles, audio) anywhere under scripts/core, scripts/player, autoload"

requirements-completed: [MOVE-01, MOVE-10, CAM-01]

coverage:
  - id: D1
    description: "Camera-relative run with perceptible acceleration, release braking and a harder skid on reversal"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_ground_movement (scenarios a, b, c, d)"
        status: pass
    human_judgment: false
  - id: D2
    description: "MovementConfig holds every movement number; PlayerController owns velocity and makes the single move call; snap length stays in the 0.3-0.5 m band up to dash speed"
    requirement: "MOVE-10"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_ground_movement (scenario f) and grep -rn move_and_slide attimo/scripts attimo/autoload"
        status: pass
    human_judgment: false
  - id: D3
    description: "CameraRig as top-level interpolation-off sibling that trails the player under 1 m and turns with the mouse"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_ground_movement (scenario d)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real jump on shared gravity: held apex at jump_height, one jumped and one landed fact with real impact speed, lands in Idle"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_ground_movement,test_feedback_guard (scenario e)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Run and jump feel (Mario-like weight, camera smoothness at the monitor refresh rate)"
    verification: []
    human_judgment: true
    rationale: "Feel and visual smoothness cannot be asserted headless; the 02-14 gym sign-off covers it"

duration: ~30min (start time was not recorded, estimated)
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 1: Movement Tracer Summary

**Camera-relative run, skid and a real held-apex jump on an own-velocity CharacterBody3D (half-step gravity, one move_and_slide) driven by a shared MovementConfig resource, followed by a top-level interpolation-off CameraRig that supplies the steering yaw.**

## Performance

- **Duration:** about 30 min (estimated, start time was not recorded)
- **Completed:** 2026-11-05
- **Tasks:** 3 (all `auto`; Task 1 is the phase tracer, verified by the same `<verify>` end to end before expansion)
- **Files:** 7 created, 7 modified (plus .gd.uid sidecars)

## Accomplishments

- `MovementConfig` (`attimo/scripts/player/movement_config.gd`, default instance `attimo/resources/player/movement_default.tres`) with all start values, strictly positive divisor ranges, `snap_min`/`snap_max` limited to D-13's 0.3-0.5 m band, and derived `gravity()`, `jump_speed()`, `cut_speed()`, `long_jump_height()`, `long_jump_speed()`.
- `PlayerController` rewritten: own `move_velocity`/`vertical_speed`, half-step gravity with fall multiplier and terminal clamp, speed-scaled snap clamp, wall/ceiling fix-up, landing and leave-floor detection, manual platform carry (`PLATFORM_ON_LEAVE_DO_NOTHING`), `teleport()` that resets interpolation, and the single `move_and_slide()` in the whole codebase.
- States: `GroundState`/`AirState` bases; real `Idle`, `Run`, `Jump`, `Fall`. `EventBus.landed` now comes from floor contact in the controller with a real impact speed (14.67 m/s for the 2 m jump).
- `CameraRig` scene (`CameraRig > Pitch > SpringArm3D > Camera3D`, sphere shape 0.25, World-only mask) follows `get_global_transform_interpolated()`; 0.52 m trailing distance at run speed; `steering_yaw()` is the A40 hook that `input_direction()` reads.
- `test_ground_movement`: 29 checks covering accel, decel, skid (4.50 m/s drop vs 4.05 required), bare-camera and rig-steered heading (dot 1.000), snap band including the clamp at dash speed, rig topology/follow/mouse look, held jump apex 2.000 m.

## Task Commits

1. **Task 1: camera-relative run through MovementConfig and the single kinematic move** - `c51a0fd` (feat)
2. **Task 2: CameraRig follows the interpolated player and supplies the steering yaw** - `da60b2c` (feat)
3. **Task 3: real jump and fall on the shared AirState, landed from floor contact** - `177e922` (feat)

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Plan-end gate: `bash attimo/tests/run.sh test_ground_movement,test_feedback_guard` -> `tests=2 passed=40 failed=0`, `RUN.SH: PASSED`.
- `grep -rn move_and_slide attimo/scripts attimo/autoload` -> exactly one line, in `player_controller.gd`.
- All task acceptance criteria re-run: pass (PASS count 29, above the 6/10/13 minimums; no `attimo/addons` folder).
- No untracked `.gd.uid` sidecars after the commits.
- Full suite (informational, not this plan's gate): 14 tests, 449 passed, 44 failed. All 44 failures are in the five Phase 1 tests the plan names as known red (`test_dash_fact`, `test_jump_fact`, `test_mannequin_animation`, `test_movement_facts`, `test_scene_run`, A36). 02-04 (wave 2) repairs them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Snap-band test threshold of 15 m/s cannot be met by the specified formula**
- **Found during:** Task 1 (scenario f)
- **Issue:** The plan asks for `floor_snap_length == snap_max` "once the horizontal speed is above 15 m/s". The specified formula `speed * dt * tan(50 deg) + 0.1` only reaches 0.5 at about 20.1 m/s (0.40 m at 15 m/s), so the assertion as written would fail on correct code.
- **Fix:** The test waits for speed above 21 m/s (dash speed is 22) before asserting the clamp to exactly `snap_max`. The controller formula is unchanged and matches RESEARCH Pattern 6 and A35.
- **Files modified:** `attimo/tests/smoke/test_ground_movement.gd`
- **Commit:** `c51a0fd`

**2. [Rule 3 - Blocking] Doc comment contained the literal `move_and_slide`**
- **Found during:** Task 1 acceptance criteria
- **Issue:** The criterion `grep -rn 'move_and_slide' attimo/scripts attimo/autoload | wc -l == 1` counted a class doc comment as a second hit.
- **Fix:** Reworded the comment ("the one kinematic move call").
- **Files modified:** `attimo/scripts/player/player_controller.gd`
- **Commit:** `c51a0fd`

**Total deviations:** 2 auto-fixed (1 bug in a test threshold, 1 blocking wording). **Impact:** none on behavior.

Small judgment calls inside the plan's freedom: Idle accelerates on its hand-over tick, Run holds until speed is under 0.01 m/s, bare-camera yaw uses `get_euler(EULER_ORDER_YXZ)`.

## Known Stubs

None. `_tick_timers()` is an intentionally empty, documented hook for 02-05 (coyote, buffer, cooldown, chain timers).

## Threat Flags

None. No network, auth or file access added. T-02-01 holds (config only from `res://`), T-02-02 holds (positive range minimums, terminal clamp).

## Issues Encountered

None blocking. The five Phase 1 tests stay red until 02-04, as planned (A36).

## Next Phase Readiness

Ready for 02-02 and 02-03 (wave 1, independent of this plan's files) and for 02-04, which repairs the five Phase 1 tests, wires the animator mapping and adds the CameraRig to the test scene.

## Self-Check: PASSED

- Created files exist: movement_config.gd, movement_default.tres, ground_state.gd, air_state.gd, camera_rig.gd, camera_rig.tscn, test_ground_movement.gd (all FOUND).
- Commits `c51a0fd`, `da60b2c`, `177e922` are ancestors of HEAD (FOUND).
