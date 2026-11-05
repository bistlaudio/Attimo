---
phase: 02-movement-core-follow-camera
plan: 04
subsystem: testing-animation-camera
tags: [godot, gdscript, smoke-tests, test-repair, camera-rig, animator-mapping, test-scene]

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01: real Idle/Run/Jump/Fall, landed with impact speed, CameraRig, Fixtures.spawn_floor and wait_until"
provides:
  - "MannequinAnimator with Sprint, DoubleJump and LongJump mapped before those states exist, one AIRBORNE_STATES constant for the landing check"
  - "test_scene.tscn with the CameraRig as a sibling of the Player (F5 is playable: camera-relative run, jump, mouse look)"
  - "test_jump_fact, test_movement_facts, test_mannequin_animation, test_scene_run rewritten for real physics"
  - "test_dash (renamed from test_dash_fact with history) ready for 02-09 to extend"
  - "Full suite green again: the wave-1 red interval of 02-01 (A36) is closed"
affects: [02-05, 02-09, 02-11, 02-14, phase-03]

actuals:
  tokens: 3500
  tasks: 2
  commits: 2

commits: 2
plan_head_before: a277a21d484f3e0be37fb0115f8fc7c6e467b2dc
plan_head_after: 89d6d1352bbc7358a246b77157cc5d9edc34d28b

tech-stack:
  added: []
  patterns:
    - "Tests that move the player build their own ground (Fixtures.spawn_floor) and free it in teardown"
    - "Animation-tree assertions use wait_until with a tick budget (TREE_TRAVEL_TICKS = 15), the FSM state stays the truth"
    - "Landing is awaited with wait_until on landed + Idle instead of fixed frame counts"

key-files:
  created: []
  modified:
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/scenes/test/test_scene.tscn
    - attimo/tests/smoke/test_jump_fact.gd
    - attimo/tests/smoke/test_movement_facts.gd
    - attimo/tests/smoke/test_mannequin_animation.gd
    - attimo/tests/smoke/test_scene_run.gd
    - attimo/tests/smoke/test_dash.gd
    - attimo/tests/smoke/test_dash.gd.uid

key-decisions:
  - "The animator gets RUNNING_STATES (Run, Sprint) next to AIRBORNE_STATES so the Locomotion blend of 1.0 is one constant, not a second inline comparison"
  - "Animation travel assertions allow 15 physics ticks because the tree reaches a state only after its 0.1 s crossfade"

patterns-established:
  - "Rewriting a Phase 1 guard: drop only the 'body never moves' assertions, keep every still-valid fact check (Idle start, setup transition, one jumped per press, dash_started payload, sanctioned meshes, no particles, environment flags, event-log facts)"

requirements-completed: [MOVE-01, CAM-01]

coverage:
  - id: D1
    description: "Animator maps Sprint to Locomotion (blend 1.0), DoubleJump and LongJump to Jump, and uses AIRBORNE_STATES for the landing check"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump_fact,test_movement_facts,test_mannequin_animation,test_feedback_guard"
        status: pass
    human_judgment: false
  - id: D2
    description: "Held jump peaks within 0.1 m of config.jump_height and ends with exactly one landed (impact speed above 0) in Idle; running moves toward -Z on the ground and in the air"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump_fact,test_movement_facts"
        status: pass
    human_judgment: false
  - id: D3
    description: "Test scene carries a top-level, interpolation-off CameraRig that is a sibling of the Player and targets it"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_scene_run (camera block)"
        status: pass
    human_judgment: false
  - id: D4
    description: "test_dash_fact renamed to test_dash with git mv and still checks Dash travel and the dash_started payload on a real floor"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash"
        status: pass
    human_judgment: false
  - id: D5
    description: "Full suite is the gate again (14 tests, 577 checks, no failure)"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh"
        status: pass
    human_judgment: false
  - id: D6
    description: "F5 feel of the test scene: centered mouse-look camera, acceleration and skid, jump weight, mouse capture and release"
    requirement: "CAM-01"
    verification: []
    human_judgment: true
    rationale: "The plan's human-check (F5 for one minute) judges feel and camera follow, which headless asserts cannot; the 02-14 gym sign-off covers it as well"

duration: ~25min
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 4: Test Repair and Test-Scene Camera Summary

**The five Phase 1 tests that encoded "the body never moves" now assert real physics (apex within 0.1 m of jump_height, one landed with a real impact speed, travel toward -Z), the animator knows every Phase 2 state name, and the test scene carries the CameraRig so F5 is playable; the full suite is green again.**

## Performance

- **Duration:** about 25 min
- **Completed:** 2026-11-05
- **Tasks:** 2 (both `auto`)
- **Files:** 8 modified (one renamed with history), 0 created

## Accomplishments

- `MannequinAnimator`: `STATE_TO_ANIM` gains Sprint -> Locomotion, DoubleJump -> Jump, LongJump -> Jump; `AIRBORNE_STATES` (Jump, Fall, DoubleJump, LongJump) drives the landing check; `RUNNING_STATES` (Run, Sprint) sets Locomotion blend 1.0 (RESEARCH Pitfall 7).
- `test_jump_fact`, `test_movement_facts`, `test_mannequin_animation` spawn a floor and assert held apex 2.000 m, landed impact speed 14.67 m/s, Idle at y 0.001, -Z travel on the ground (2.83 m) and in the air, and the Land -> Locomotion return after a jump (RESEARCH Pitfall 6).
- `test_scene.tscn`: static Camera removed, `CameraRig` instanced after the Player with `target = NodePath("../Player")`. `test_scene_run` asserts exactly one Camera3D, current, in a CameraRig that is top-level, interpolation-off, a sibling of the Player (not in its subtree) and targets it; the play-through checks 2.94 m camera-relative travel in 30 ticks, a real landing, the Dash travel and the event-log facts.
- `test_dash_fact` -> `test_dash` via `git mv` (uid sidecar moved, `git log --follow` lists 2 commits); floor spawned, the "no displacement" guard and all Phase 1 decision-id mentions removed, the air-dash scenario awaits landed + Idle with `wait_until`.

## Task Commits

1. **Task 1: animator state names; jump, movement and animation tests on real physics** - `4ca4118` (feat)
2. **Task 2: test scene follow camera; scene run and dash tests** - `89d6d13` (feat)

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Task 1 gate: `run.sh test_jump_fact,test_movement_facts,test_mannequin_animation,test_feedback_guard` -> `tests=4 passed=67 failed=0`, `RUN.SH: PASSED`.
- Task 2 gate: `run.sh test_scene_run,test_dash,test_feedback_guard` -> `tests=3 passed=136 failed=0`, `RUN.SH: PASSED`.
- Plan-end wave-2 gate: full `bash attimo/tests/run.sh` -> `tests=14 passed=577 failed=0`, `RUN.SH: PASSED`.
- Every committed `.gd` has its `.uid` sidecar (loop prints nothing).
- All acceptance criteria re-run: AIRBORNE_STATES 2 hits, Sprint/DoubleJump/LongJump 5 lines, `D-09: position unchanged` 0, `spawn_floor` in all three files, `camera_rig.tscn` 1, `type="Camera3D"` 0, `the camera has no script` 0, `PHYSICS_INTERPOLATION_MODE_OFF` 1, `test_dash_fact.gd` gone, `test_dash.gd.uid` present, `D-09` in test_dash 0, history kept.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Dash-to-tree assertion was timing-fragile on real physics**
- **Found during:** Task 2 (test_dash scenario 1)
- **Issue:** The Phase 1 check allowed 3 ticks after the dash press for the AnimationTree to report `Dash`. From Run (blend 1.0) the crossfade (0.1 s) takes about 6 ticks, so the check failed deterministically (got Locomotion) although the FSM was in Dash and the tree reached Dash at tick 6.
- **Fix:** `test_dash` and `test_scene_run` now wait up to `TREE_TRAVEL_TICKS = 15` ticks with `Fixtures.wait_until`. The assertion still requires the tree to reach Dash; only the tick budget changed.
- **Files modified:** `attimo/tests/smoke/test_dash.gd`, `attimo/tests/smoke/test_scene_run.gd`
- **Commit:** `89d6d13`

**Total deviations:** 1 auto-fixed (test timing). **Impact:** none on game behavior; the guard is as strong as before.

## Known Stubs

None.

## Threat Flags

None. No network, auth or file access added. T-02-22 holds: only the "never moves" guards were removed, every still-valid Phase 1 guard stays asserted.

## Issues Encountered

None. The human-check (F5 playthrough of the test scene) is not run by the executor; it is recorded as `human_judgment: true` in the coverage block for the verifier.

## Next Phase Readiness

Ready for the remaining wave-2 plans (02-05, 02-06, 02-07) and 02-09, which extends `test_dash` with the real dash scenarios. 02-14 later makes the movement gym the main scene and rewrites `test_scene_run` again (A12).

## Self-Check: PASSED

- Modified files exist: mannequin_animator.gd, test_scene.tscn, test_jump_fact.gd, test_movement_facts.gd, test_mannequin_animation.gd, test_scene_run.gd, test_dash.gd, test_dash.gd.uid (all FOUND).
- Commits `4ca4118`, `89d6d13` are ancestors of HEAD (FOUND).
