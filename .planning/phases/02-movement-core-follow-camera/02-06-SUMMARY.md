---
phase: 02-movement-core-follow-camera
plan: 06
subsystem: camera
tags: [godot, gdscript, camera, physics-interpolation, spring-arm, additive-fov, wall-safety]

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 CameraRig tracer (top-level interpolation-off rig, mouse look, snap_to_target), Fixtures.spawn_camera_rig"
provides:
  - "D-15 vertical follow band: airborne rig holds the last grounded height, follows falls and rises beyond air_rise_band"
  - "D-18 additive channels: set_fov_offset / clear_fov_offset / get_fov_total and set_offset / clear_offset (SpringArm3D origin), centered defaults"
  - "Pitch clamp every frame and after every mouse event; summed FOV clamped to 1..179"
  - "Wall-safe arm at 10 and 60 TPS via a per-frame sphere cast inside the rig (A3 fallback)"
  - "test_camera_rig: 38 checks (structure, channels, pitch, jitter proxy, vertical follow, wall pull-in, corridor orbit)"
affects: [02-10, 02-14, phase-03, phase-11]

actuals:
  tokens: 5700
  tasks: 2
  commits: 4

commits: 4
plan_head_before: 0be214abe5187c74832cc5f4dfa677f2ac7c4c2a
plan_head_after: 592d0564074a14b3e16b196e523ce0463ea139ca

tech-stack:
  added: []
  patterns:
    - "Rig sums named per-source contributions (typed Dictionary, keys sorted) every _process; Phase 3 and 11 only register sources"
    - "Vertical goal = last grounded anchor height while airborne; duck-typed target.is_grounded()"
    - "Wall safety: cast_motion with the arm's SphereShape3D from _process, instant pull-in, exp-eased extension; SpringArm3D node mask zeroed so it never disagrees"

key-files:
  created:
    - attimo/tests/smoke/test_camera_rig.gd
  modified:
    - attimo/scripts/camera/camera_rig.gd

key-decisions:
  - "A3 triggered: SpringArm3D alone clipped the lens in 32 of 289 frames in the 10-TPS corridor orbit, so the rig casts per frame itself (SpringArm3D node kept in the scene, mask 0, spring_length driven by the rig)"
  - "The rig keeps the World mask in a private field and exposes arm_collision_mask(); the node's own collision_mask is 0 by design"
  - "Margin handling: a hit shortens the arm to max_length * safe_fraction - margin (floored at 0); no hit gives exactly spring_length, so open space is 5.000 m"

patterns-established:
  - "Per-frame checks of rendered state read the rig at the start of a process_frame continuation (before the next rig update), set yaw there, and query direct_space_state from _process (A20 held)"

requirements-completed: [CAM-01]

coverage:
  - id: D1
    description: "Jitter proxy: 0.0 % of about 217 process frames leave the rig unmoved at 10 TPS and at 60 TPS with Engine.max_fps 144"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_rig (scenario d)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Vertical follow: 2 m jump varies rig height by 0.000 m, 1 m step landing settles within 0.001 m of step top + pivot_height, 3 m ledge drop follows down 2.93 m by 0.5 s after landing"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_rig (scenarios e, f, g)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Additive FOV and offset sources: +5 and -2 give base_fov + 3, clearing one removes only its share, offset moves the arm origin exactly, centered defaults, FOV clamped 1..179, pitch clamped"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_rig (scenarios b, c)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Wall safety: wall 2 m behind pulls the lens to 1.73 m, open space gives 5.000 m, a pi rad/s orbit in a 3 m corridor has 0 of 289 frames with a wall between pivot and lens or the lens inside a collider at 10 and at 60 TPS"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_rig (scenarios h, i, j)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Real 144 Hz display judder and the felt quality of the follow, band and pull-in"
    verification: []
    human_judgment: true
    rationale: "The headless jitter check is a proxy; the display judgment is a mandatory human sign-off item in 02-14 (CAM-01)"

duration: ~15min (start was recorded at the first commit step; reading of the plan context before that is estimated)
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 6: Follow Camera Hardening Summary

**CameraRig now has the D-15 vertical follow band, additive FOV and arm-offset sources for Phases 3 and 11, a pitch clamp, and a per-frame sphere cast that keeps walls out of the lens at 10 and 60 TPS because SpringArm3D alone failed the 10-TPS corridor test.**

## Performance

- **Duration:** about 15 min
- **Completed:** 2026-11-05
- **Tasks:** 2 (both `auto`, `tdd="true"`: RED test commit, then GREEN feature commit per task)
- **Files:** 1 created, 1 modified (plus the test's `.gd.uid` sidecar)

## Accomplishments

- **Vertical follow (D-15):** `_vertical_goal()` tracks the anchor height while the target is grounded (targets without `is_grounded()` count as always grounded). Airborne it holds the last grounded height, trails by `air_rise_band` (2.5 m) once the target rises beyond it, and follows the target down when it falls below it. Measured: 2 m held jump varies the rig height by 0.000 m, a 1 m step landing settles at 2.599 m (expected 2.600), a 3 m ledge drop moves the rig 2.93 m down within 0.5 s of landing.
- **Additive channels (D-18):** `set_fov_offset` / `clear_fov_offset` / `get_fov_total` and `set_offset` / `clear_offset`, backed by typed `Dictionary[StringName, float]` and `Dictionary[StringName, Vector3]`, summed with sorted keys each `_process`. `Camera3D.fov = clampf(base_fov + sum, 1, 179)`, `SpringArm3D.position = sum of offsets` (so the cast origin includes the offset). With no source the arm sits at `Vector3.ZERO` and `fov == base_fov` (75).
- **Pitch clamp:** clamped after every mouse event and again each frame.
- **Jitter proxy:** 0.0 % of about 217 frames unchanged at 10 TPS and at 60 TPS with `Engine.max_fps = 144`; the tick rate and frame cap are always restored.
- **Wall safety:** see Collision path below.

## Collision path taken (A3)

**The per-frame cast fallback is in use; SpringArm3D alone is not.** Against the 02-01 SpringArm3D, the wall-pull-in (h), open-space (i) and 60-TPS corridor (j) scenarios passed, but the 10-TPS corridor orbit failed: 32 of 289 rendered frames had a World collider between pivot and lens and the lens inside a collider, because the node only casts on physics ticks (100 ms of stale length at 10 TPS while the arm turns 0.31 rad per tick). The RED test is commit `5a5bcae`.

The fix, inside CameraRig with the node layout and public API unchanged: at `_ready` the rig stores the SpringArm3D's mask and spring length and sets the node's own mask to 0. Every `_process`, after rotation and offsets, `direct_space_state.cast_motion` runs with the arm's `SphereShape3D` along the arm's +Z axis; a hit gives `max_length * safe_fraction - margin` (floored at 0), no hit gives the full length; the arm shortens instantly and lengthens with `1 - exp(-arm_extend_rate * delta)` (`arm_extend_rate` default 8.0); the length is written into `spring_arm.spring_length` and `Camera3D.position.z` in the same frame. Result: 0 of 289 frames clipped at both 10 and 60 TPS, wall 2 m behind gives 1.73 m, open space 5.000 m. `camera_rig.tscn` did not change (`type="SpringArm3D"` count stays 1). Assumption A20 held: querying `direct_space_state` from `_process` works with default threading.

## Task Commits

1. **Task 1 RED:** `6176dfa` (test) - channels, pitch clamp, jitter, jump/step/ledge scenarios (bob check failed at 1.683 m)
2. **Task 1 GREEN:** `b6709e8` (feat) - vertical follow band, additive FOV/offset sources, pitch clamp
3. **Task 2 RED:** `5a5bcae` (test) - wall pull-in, open space and corridor orbit; SpringArm3D fails at 10 TPS
4. **Task 2 GREEN:** `592d056` (feat) - per-frame wall-safe camera arm

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Plan-end gate: `bash attimo/tests/run.sh test_camera_rig,test_ground_movement,test_feedback_guard,test_project_settings` -> `tests=4 passed=89 failed=0`, `RUN.SH: PASSED`.
- `bash attimo/tests/run.sh test_camera_rig` prints 38 `PASS [test_camera_rig]` lines (criteria: at least 8 and 12), `failed=0`; repeated twice with the same result.
- Acceptance greps: `func set_fov_offset` 1, `func set_offset` 1, `air_rise_band` 4, `Engine.max_fps` 2 in the test, `physics_ticks_per_second ... 60` 1, `intersect_ray` 1, `intersect_point` 1, `physics_ticks_per_second ... 10` 1, `type="SpringArm3D"` 1.
- Full suite (informational): 16 tests, 642 passed, 0 failed.

## Deviations from Plan

### Planned fallback triggered

**1. [Plan A3 - fallback path] SpringArm3D replaced by a per-frame cast inside the rig**
- **Found during:** Task 2 (RED run of the 10-TPS corridor scenario)
- **Issue:** 32 of 289 frames at 10 TPS had a wall between pivot and lens.
- **Fix:** As specified by the plan's fallback; see Collision path taken.
- **Files modified:** `attimo/scripts/camera/camera_rig.gd`
- **Commit:** `592d056`

### Auto-fixed Issues

**2. [Rule 1 - test/implementation mismatch] Structure check read the node mask**
- **Found during:** Task 2 GREEN run
- **Issue:** Scenario (a) asserted that `spring_arm.collision_mask` includes World, which the fallback zeroes by design.
- **Fix:** Added `CameraRig.arm_collision_mask()` (the cast mask, World only) and the test now asserts that mask plus the node mask being 0.
- **Files modified:** `attimo/scripts/camera/camera_rig.gd`, `attimo/tests/smoke/test_camera_rig.gd`
- **Commit:** `592d056`

**Total deviations:** 1 planned fallback, 1 auto-fixed (test fallout). **Impact:** none on the public interface; `arm_collision_mask()` and `arm_extend_rate` are additions.

## Known Stubs

None.

## Threat Flags

None. T-02-06 holds: the summed FOV is clamped to 1..179 and pitch is clamped after every event and every frame (scenarios b and c).

## Issues Encountered

None. Note for later plans: `spring_arm.spring_length` now holds the current (pulled-in) length; the configured maximum is the scene's value captured in `_ready`. Phase 3 aim blending should move the arm through `set_offset` / `set_fov_offset`, not by editing `spring_length`.

## Next Phase Readiness

Ready for 02-10 (settings, auto-follow, recenter) and 02-14 (gym; the 144 Hz display judder check stays a mandatory human item there). The rig interface for Phases 3 and 11 is in place.

## Self-Check: PASSED

- Created file exists: `attimo/tests/smoke/test_camera_rig.gd` (FOUND).
- Commits `6176dfa`, `b6709e8`, `5a5bcae`, `592d056` are ancestors of HEAD (FOUND).
