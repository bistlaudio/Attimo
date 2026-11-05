---
phase: 02-movement-core-follow-camera
plan: 05
subsystem: gameplay-movement
tags: [godot, gdscript, jump, coyote-time, jump-buffer, double-jump, variable-height]

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 PlayerController/MovementConfig/AirState tracer, 02-02 EventBus.double_jumped"
provides:
  - "Variable jump height: a released button cuts the rise to jump_min_height (AirState.apply_jump_cut), tap vs hold, heavier fall"
  - "Coyote time and jump buffer on PlayerController (coyote_timer, jump_buffer_timer, wants_jump, consume_jump, can_coyote_jump, will_land_within)"
  - "Buffered landing jump that fires on the landing tick and keeps the horizontal speed"
  - "DoubleJump state: exactly one air jump per airtime, refilled on landing, announced as double_jumped"
  - "test_jump: 27 checks pinning every edge of the jump rule set"
affects: [02-09, 02-11, 02-13, phase-03, phase-05]

actuals:
  tokens: 5700
  tasks: 2
  commits: 4

commits: 4
plan_head_before: 7624cc7ccb6acc783da3148c188aba4af1ffbf6d
plan_head_after: f68c3b0a4ec7bbdbe3eb4d5b22e686f3fb7e33d3

tech-stack:
  added: []
  patterns:
    - "Jump rule set lives in AirState._airborne_jump_decision (coyote, landing window, double jump, expiry); states only return state names"
    - "Timers decrement in PlayerController._tick_timers before the states run; just_pressed is polled in the physics tick"
    - "Release cut is one shared AirState.apply_jump_cut(), called from every rising state's enter and update"
    - "Landing prediction with test_move over horizontal velocity plus fall drop, accepted only on a walkable floor normal"

key-files:
  created:
    - attimo/scripts/player/states/double_jump.gd
    - attimo/tests/smoke/test_jump.gd
  modified:
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/ground_state.gd
    - attimo/scripts/player/states/air_state.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/smoke/test_dash.gd
    - attimo/tests/smoke/test_mannequin_animation.gd

key-decisions:
  - "A6/A7/A19 held as flagged: a press past coyote is the double jump, a press about to land is a buffered ground jump, the double jump sets the rise and obeys the release cut"
  - "coyote_timer is also zeroed on landing, so a stale window never leaks into the next airtime"
  - "will_land_within is capped by floor_max_angle, so a steep wall never counts as a landing"

patterns-established:
  - "Tests send jump presses through Fixtures.send_action_event; a press and release between two ticks still arrives as just_pressed"
  - "Harness latency: a press sent from a physics_frame continuation is first seen two frames later, so tests wait with wait_until instead of a fixed single frame"

requirements-completed: [MOVE-03, MOVE-04, MOVE-05]

coverage:
  - id: D1
    description: "Tap vs hold: held apex within 0.1 m of jump_height, one-tick tap within 0.15 m of jump_min_height, fall shorter than rise"
    requirement: "MOVE-03"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump.gd (scenario a)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Held apex is tick-rate independent within g*dt^2/8 + 0.03 m at 10, 60 and 120 TPS"
    requirement: "MOVE-03"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump.gd (scenario b)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Coyote edge: a jump coyote_time - 2 ticks after walking off is a ground jump, coyote_time + 3 ticks is not"
    requirement: "MOVE-04"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump.gd (scenario c)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Buffer edge: a near-landing press jumps on the landing tick, keeps the horizontal speed, a released press gives the tap height, a press far above the floor expires"
    requirement: "MOVE-04"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump.gd (scenarios d, e, j, k)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Exactly one double jump per airtime, refilled on landing, usable after walking off a ledge, held height about double_jump_height and tapped height about jump_min_height"
    requirement: "MOVE-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump.gd (scenarios f, g, h, i)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Jump timing and weight feel (forgiveness of the 0.1 s coyote and 0.12 s buffer, double jump readability)"
    verification: []
    human_judgment: true
    rationale: "Feel cannot be asserted headless; the 02-13 metrics and the 02-14 gym sign-off cover it"

duration: ~25min (start time was not recorded, estimated)
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 5: Jump Rules Summary

**Variable-height jump with release cut, coyote time, a jump buffer that fires on the landing tick without losing speed, and exactly one refilling double jump, all decided in AirState and pinned by 27 headless checks including 10/60/120 TPS apex independence.**

## Performance

- **Duration:** about 25 min (estimated, start time was not recorded)
- **Completed:** 2026-11-05
- **Tasks:** 2 (both `auto`, `tdd="true"`: RED test commit, then GREEN feature commit per task)
- **Files:** 2 created, 7 modified (plus .gd.uid sidecars)

## Accomplishments

- `PlayerController` gained `coyote_timer`, `jump_buffer_timer`, `air_jump_available`, `wants_jump()`, `consume_jump()`, `can_coyote_jump()` and `will_land_within(seconds)` (a `test_move` prediction accepted only on a walkable floor normal). `_tick_timers` decrements first, then arms the buffer from `is_action_just_pressed`. Coyote starts only when the body leaves the floor without upward speed; landing refills the air jump.
- `AirState` owns the rule set: landing branch fires a buffered `Jump` with no ground deceleration tick; airborne coyote -> `Jump`; falling inside the landing window keeps the buffer; otherwise an unspent air jump -> `DoubleJump`; else the press expires. `apply_jump_cut()` gives variable height to every rising state.
- `Jump.enter` consumes the press, sets the take-off speed and applies the cut at once when the button is already up (tap height at every tick rate). New `DoubleJump` state (node in `player.tscn`) sets the rise to `jump_speed(double_jump_height)`, keeps horizontal momentum, obeys the cut and emits `EventBus.double_jumped`.
- Measured: held apex 2.000 m, tap apex 0.801 m, fall 18 ticks vs rise 22 ticks, apex error at 10/60/120 TPS 0.008/0.000/0.001 m, buffered landing jump 1 tick after `landed` at 7.00 -> 7.00 m/s, held double jump 1.999 m, tapped double jump 0.800 m.

## Task Commits

1. **Task 1 RED:** `19fff19` (test) - jump height, tick rate, coyote and buffer scenarios fail
2. **Task 1 GREEN:** `ce66bc1` (feat) - variable jump height, coyote time and jump buffer
3. **Task 2 RED:** `65aae86` (test) - double jump scenarios fail
4. **Task 2 GREEN:** `f68c3b0` (feat) - one double jump per airtime with the double_jumped fact

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Plan-end gate: `bash attimo/tests/run.sh test_jump.gd,test_ground_movement,test_feedback_guard,test_project_settings` -> `tests=4 passed=78 failed=0`, `RUN.SH: PASSED`.
- `bash attimo/tests/run.sh test_jump.gd` prints 27 `PASS [test_jump]` lines (criteria: at least 7 and 13), `failed=0`.
- Task 1 and 2 acceptance greps all met (`wants_jump` 1, `will_land_within` 1, `test_move(` 1, `actor.wants_jump()` 1, `apply_jump_cut` 1, `consume_jump()` 1, tick rate restored to 60, `name="DoubleJump"` 1, `double_jumped.emit` 1, `air_jump_available` 2, `double_jumped` in the test 11).
- Full suite (informational): 15 tests, 604 passed, 0 failed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Two existing tests tapped jump for two frames and broke under the release cut**
- **Found during:** Task 2 full-suite run
- **Issue:** `test_dash` scenario 3 and `test_mannequin_animation` used `Fixtures.tap_action(jump)`, which releases the button after two frames. With variable height (D-04) that cuts the rise to 0.8 m, so the air dash no longer ended in Fall and the animation tree never showed Fall.
- **Fix:** Both tests hold the jump through the airtime (`Input.action_press`) and release it at the end, restoring the full-height jump they were written for.
- **Files modified:** `attimo/tests/smoke/test_dash.gd`, `attimo/tests/smoke/test_mannequin_animation.gd`
- **Commit:** `f68c3b0`

**Total deviations:** 1 auto-fixed (blocking test fallout of the planned cut). **Impact:** none on behavior; the plan-level verification list did not name these tests (they belong to 02-04), but the full suite is green.

Test-design notes (no behavior change): a press sent from a `physics_frame` continuation is first seen two ticks later in this harness, so the double jump scenarios use `wait_until` for the fact instead of a fixed single-frame wait. The "far above the floor" scenario uses a held double jump (apex about 4 m) because a tapped one never gets 0.36 s of fall above the floor.

## Known Stubs

None.

## Threat Flags

None. T-02-05 holds: `consume_jump()` clears buffer and coyote on every jump, coyote is granted only on a walk-off (`vertical_speed <= 0`), the air jump flag is refilled only in `_land`, and `test_jump` pins one double jump per airtime. No landing-based triple jump, glide, dive or ground-pound was added (MOVE-05 prohibition).

## Issues Encountered

None. Known limitation, rare edge case: a buffered press that arrives while the state is `Jump` and the body is already grounded with non-positive speed (jumping against a ceiling onto a rising platform) cannot re-enter `Jump` from `Jump`; the buffer simply expires after 0.12 s. Not reachable in the current geometry.

## Next Phase Readiness

Ready for 02-06 and 02-07 (wave 2) and 02-09 / 02-11, which extend `_tick_timers`, `AirState.apply_jump_cut()` and the jump decision with the dash and long-jump rules.

## Self-Check: PASSED

- Created files exist: double_jump.gd, test_jump.gd (FOUND).
- Commits `19fff19`, `ce66bc1`, `65aae86`, `f68c3b0` are ancestors of HEAD (FOUND).
