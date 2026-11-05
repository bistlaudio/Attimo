---
phase: 02-movement-core-follow-camera
plan: 11
subsystem: movement
tags: [godot, gdscript, jump-chain, long-jump, dash-jump, state-machine]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 MovementConfig chain and long-jump rows, 02-02 long_jumped / chain_stage_changed facts, 02-05 Jump/DoubleJump and jump buffer, 02-09 Dash with start_dash() and last_dash_direction"
provides:
  - "Ground-jump chain in PlayerController: chain_stage, chain_timer, advance_chain_for_ground_jump(), take_chain_for_long_jump(), refresh_chain_window(), chain_stage_changed emission (D-05, D-07)"
  - "Jump 2 inside the landing window peaks at chain_jump_height (2.6 m); the release cut still applies (D-04)"
  - "LongJump state: takes the dash speed, min(max(carried, stage row), long_jump_speed_cap), arc height from the stage row, consumes the chain, emits long_jumped(stage) (D-06, Pitfall 12)"
  - "Dash -> LongJump hand-off for ground dashes (coyote included, A30); GroundState -> LongJump inside dash_jump_grace; air dash + jump stays DoubleJump (A1)"
  - "test_long_jump: 41 checks for the chain, the long jump, the grace, the cap and the air-dash case"
affects: [02-12, 02-13, 02-14]

actuals:
  tokens: 16000
  tasks: 2
  commits: 4

commits: 4
plan_head_before: f4f5c8d9c9b0a2d1bd48b7a575f8a1ef0eb9d3d1
plan_head_after: bb2f28d8d52ecc65f6b53763f767869da8eb5828

tech-stack:
  added: []
  patterns:
    - "The chain is controller state (stage plus a window that counts down only on the ground); states only call advance/take/refresh, the controller emits the fact on change"
    - "LongJump reads the live velocity (move_velocity.dot(direction)) instead of a stored speed, so one code path serves the jump during the dash and the grace jump after it"

key-files:
  created:
    - attimo/scripts/player/states/long_jump.gd
    - attimo/scripts/player/states/long_jump.gd.uid
    - attimo/tests/smoke/test_long_jump.gd
    - attimo/tests/smoke/test_long_jump.gd.uid
  modified:
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scripts/player/states/dash.gd
    - attimo/scripts/player/states/ground_state.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/smoke/test_dash.gd

key-decisions:
  - "A ground dash that ends on the ground also holds an open chain window alive for at least dash_jump_grace (PlayerController.hold_chain_through_grace). Refreshing the window only at dash start leaves 0.17 s after the 0.18 s dash, barely above the 0.15 s grace, so a late-grace jump could have lost its stage."
  - "Dash no longer applies the exit carry before leaving for a ground jump: LongJump reads the live dash speed itself and bounds it, so the carry is the full 22 m/s with defaults. The air-dash double jump keeps the exit carry."
  - "LongJump sets air_speed_cap to max(run_speed, take-off speed) so air steering cannot exceed the carry and works for the coyote take-off where _leave_floor does not run."
  - "LongJump emits long_jumped only (not jumped), as the plan specifies; the jumped fact stays for Jump."

patterns-established:
  - "Test helper _dash_jump(): dash and jump pressed on the same tick, long jump followed to its landing, returns stage, distance, apex, first-tick speed and max speed"

requirements-completed: [MOVE-07]

coverage:
  - id: D1
    description: "Jump 1 -> land -> Jump 2 inside chain_window: held Jump 2 peaks at chain_jump_height (2.600 m) and above Jump 1 (1.999 m); stages 1 then 2; a tapped Jump 2 is stage 2 but cut to jump_min_height (0.800 m); a buffered press before landing also gives stage 2"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_long_jump (c1, c2, c3)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Chain resets: stage 0 when the landing window runs out, within 2 ticks after a standing landing, and a third ground jump inside the window is Jump 1 again"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_long_jump (c4, c5, c6)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A jump during a plain ground dash is a stage 0 long jump that carries the dash speed (22.00 m/s), lands farther (10.63 m vs 4.90 m for a normal run jump) and flatter (apex 1.00 m vs 2.00 m); the chain is consumed"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_long_jump (l1, l2)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Grace: a jump early and in the last tick of dash_jump_grace is a long jump, the late one takes off at long_jump_speed(0) = 14.00 m/s; after the grace it is a normal Jump"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_long_jump (l3, l4, l5)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Stages 0, 1, 2 order in distance (10.63 < 11.73 < 12.47 m) and apex (1.0 < 1.2 < 1.4 m); the take-off speed is capped (dash_speed 30 with cap 24 takes off at 24.00 m/s and never exceeds it); an air dash followed by a jump is double_jumped with no long_jumped"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_long_jump (l6, l7, l8)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Whether the combo (Jump 1 -> Jump 2 -> Dash -> Jump) feels original, readable and rewarding, and whether the long jump distances (about 10.6 / 11.7 / 12.5 m) fit the gym"
    requirement: "MOVE-07"
    verification: []
    human_judgment: true
    rationale: "Feel judgment (D-05); the plan's human-check (F5 playtest) was not run by the executor"

duration: 9 min
completed: 2026-11-05
---

# Phase 2 Plan 11: Ground-Jump Chain and Long Jump Summary

**Jump 1 -> Jump 2 chain with a landing window, and a LongJump state that carries the dash speed (capped) and grows with the chain stage, up to Jump 1 -> Jump 2 -> Dash -> Jump as the maximum.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-11-05T21:55:20Z
- **Completed:** 2026-11-05T22:04Z
- **Tasks:** 2
- **Files modified:** 10 (4 created, 6 modified)

## Accomplishments

- Chain logic lives in PlayerController: a landing with stage > 0 opens `chain_window`, the window counts down on the ground only, and the stage resets on timeout or when the player stands still on the ground outside a dash (D-07). `chain_stage_changed` fires once per change.
- Jump 2 uses `chain_jump_height`; a held Jump 2 peaked at 2.600 m against 1.999 m for Jump 1, and a tapped one is cut to 0.800 m (D-04 holds).
- LongJump: take-off speed `min(max(carried, long_jump_speed(stage)), long_jump_speed_cap)`, set not added. Measured: 22.00 m/s for a jump during the dash, 14.00 m/s for a jump in the last grace tick, 24.00 m/s with dash_speed 30 and cap 24 (never above the cap during the whole airtime).
- With defaults the three long jumps measure 10.63 / 11.73 / 12.47 m with apexes 1.0 / 1.2 / 1.4 m, a normal running jump 4.90 m / 2.0 m.

## Task Commits

1. **Task 1 RED: chain scenarios** - `a789a98` (test)
2. **Task 1 GREEN: chain, Jump 2, resets** - `3a4018d` (feat)
3. **Task 2 RED: long jump scenarios** - `5c61a02` (test)
4. **Task 2 GREEN: LongJump, hand-offs, scene node** - `bb2f28d` (feat)

## Decisions Made

See key-decisions in the frontmatter. In short: the chain window is held through the grace after a ground dash, the dash passes its live speed to LongJump instead of applying the exit carry first, and LongJump sets the air speed cap itself.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Chain window could expire inside the dash grace**
- **Found during:** Task 2 (design of the dash/grace timing)
- **Issue:** `refresh_chain_window()` at dash start leaves 0.35 - 0.18 = 0.17 s after the dash, only 0.02 s (1.2 ticks) above the 0.15 s grace; a late-grace jump at stage 1 or 2 could find the stage already reset to 0.
- **Fix:** Added `PlayerController.hold_chain_through_grace()`, called when a ground dash ends on the ground; it keeps an open window at least `dash_jump_grace` long. The interface block lists only three chain functions, this is a fourth.
- **Files modified:** attimo/scripts/player/player_controller.gd, attimo/scripts/player/states/dash.gd
- **Verification:** stage 1 and 2 dash jumps in test_long_jump (l6) pass; full suite passes
- **Commit:** bb2f28d (function in 3a4018d)

**2. [Rule 3 - Blocking] test_dash scenario (8) expected the state Jump**
- **Found during:** Task 2
- **Issue:** The 02-09 check "a jump press during the dash leaves Dash into Jump" fails once the ground-dash hand-off returns LongJump (02-09 summary already announced this widening).
- **Fix:** The state check accepts `Jump` or `LongJump`; the rising and speed checks are unchanged.
- **Files modified:** attimo/tests/smoke/test_dash.gd
- **Commit:** bb2f28d

**Total deviations:** 2 auto-fixed (1 bug-prevention, 1 blocking test update). **Impact:** none on scope.

## Issues Encountered

None. The first RED run of Task 1 hit a GDScript precedence error in the test (`== [..] as Array[int]` parses as a cast of the comparison); fixed with a `_stages_are()` helper before the RED commit.

## Known Stubs

None.

## Threat Flags

None. T-02-17 is mitigated as planned: the take-off speed is set to the carried dash speed, floored by the stage row, clamped to `long_jump_speed_cap`, and the chain is consumed by each long jump; test (l7) pins the cap.

## Next Phase Readiness

Ready for 02-12 (tuning panel): the chain and long-jump rows (`chain_window`, `dash_jump_grace`, `chain_reset_speed`, `long_jump_*`) are the tunables it should expose. 02-13 can measure the three long-jump distances (about 10.6 / 11.7 / 12.5 m) for the metrics table. The F5 playtest from the plan's human-check is still open (feel judgment, coverage D6).

## Self-Check: PASSED

- Files: long_jump.gd, long_jump.gd.uid, test_long_jump.gd, test_long_jump.gd.uid, 02-11 edits all present on disk
- Commits a789a98, 3a4018d, 5c61a02, bb2f28d are ancestors of HEAD
- `bash attimo/tests/run.sh` (full suite): tests=21 passed=861 failed=0, `RUN.SH: PASSED`
- All acceptance greps of both tasks returned the required counts
