---
phase: 02-movement-core-follow-camera
plan: 09
subsystem: gameplay-movement
tags: [godot, gdscript, sprint, dash, air-dash, cooldown, tunnelling, exit-carry]

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-05 jump rules (wants_jump, air_jump_available, DoubleJump), 02-04 test_dash and animator state names, 02-01 PlayerController/MovementConfig, 02-07 snap band retune"
provides:
  - "Sprint state: hold-to-sprint to run_speed * sprint_multiplier on its own slower curve above run speed (A26)"
  - "Real ground and air dash as a velocity override through the single move_and_slide, with cooldown, one air dash per airtime and landing refill"
  - "PlayerController.can_dash(), start_dash(), dash_cooldown_timer, air_dash_available, last_dash_direction"
  - "Bounded exit carry (dash_carry, dash_exit_cap) with air control kept, dash-to-jump and air-dash-to-double-jump hand-off"
  - "test_dash: 52 checks including D-08 combos, 10 and 60 TPS tunnelling and the 45 degree slope dash"
affects: [02-11, 02-12, 02-13, 02-14, phase-03]

actuals:
  tokens: 9900
  tasks: 2
  commits: 4

commits: 4
plan_head_before: 2ae77623a1319c131e0a55b1df36f0971a2a110b
plan_head_after: b03840f07da9cbe1c824f7640b2fb29bbe7685dc

tech-stack:
  added: []
  patterns:
    - "Dash is a state that overwrites move_velocity every tick; the controller's one move_and_slide sweeps it (no custom tunnel guard)"
    - "Dash gate lives in the controller (can_dash) and is read by GroundState and AirState; the state only reads and emits"
    - "Exit carry has one helper in Dash (_exit_speed / _apply_exit_carry) used for the timeout and for both jump hand-offs"
    - "Tests that must prove a single refusal reason duplicate the config (dash_cooldown 0) so only the per-airtime flag can refuse"

key-files:
  created:
    - attimo/scripts/player/states/sprint.gd
    - attimo/scripts/player/states/sprint.gd.uid
  modified:
    - attimo/scripts/player/states/run.gd
    - attimo/scripts/player/states/dash.gd
    - attimo/scripts/player/states/ground_state.gd
    - attimo/scripts/player/states/air_state.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/smoke/test_ground_movement.gd
    - attimo/tests/smoke/test_dash.gd

key-decisions:
  - "Sprint without input hands over to Run (which brakes and then enters Idle) instead of Idle, so the running pose is kept while the figure slides to a stop; the plan allowed Idle, nothing pins it"
  - "The jump hand-off out of a dash applies the bounded exit carry first (12 m/s with defaults), not the raw 22 m/s dash speed, so an interim normal jump cannot super-jump (Pitfall 12); 02-11 replaces the ground branch with LongJump, which sets its own bounded speed"
  - "After an air dash the air control target speed (air_speed_cap) is set to the exit carry, not max'ed with the old cap, so holding a direction cannot push past dash_exit_cap"
  - "Dash exit state is decided by is_grounded() at the end of the dash, not by in_air, so an air dash that ends on a floor and a ground dash that runs off a ledge both pick the right state"

patterns-established:
  - "test_dash._dash_stats(): presses dash for two ticks and samples the Dash stretch (travel, altitude, airborne ticks, snap band, exit speed and state) for any scenario"
  - "Direction and facing for the dash are read on the first Dash tick, so a test can release the direction key one tick after the press and prove that only the dash moved the body"

requirements-completed: [MOVE-02, MOVE-06, MOVE-07]

coverage:
  - id: D1
    description: "Hold-to-sprint: Idle -> Run -> Sprint within 2 ticks, 1.5x run speed within the computed tick budget, still below sprint speed on the first run-speed ticks, release returns to Run at run_speed, a sprint jump keeps >= 0.98 x sprint speed"
    requirement: "MOVE-02"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_ground_movement (scenarios g, h, i)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ground dash covers dash_speed * dash_time (within dash_speed/60 + 0.1 m), goes in the input or facing direction, snaps the facing, hands over to Run/Idle with a bounded exit speed"
    requirement: "MOVE-06"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenarios 1, 2, 3)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Dash cooldown: a press at half the cooldown is refused, a press after it dashes again"
    requirement: "MOVE-06"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenario 4)"
        status: pass
    human_judgment: false
  - id: D4
    description: "One air dash per airtime holds altitude (< 0.05 m), a second is refused, landing refills it; jump->air dash->double jump and jump->double jump->air dash each give one double_jumped and one airborne dash_started"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenarios 5, 6a, 6b)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Exit carry between run_speed and dash_exit_cap with air control kept; a jump during a ground dash leaves Dash on that tick into a rising jump at >= run speed"
    requirement: "MOVE-07"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenarios 7, 8)"
        status: pass
    human_judgment: false
  - id: D6
    description: "A 60 m/s dash into a 0.1 m wall never ends on the far side at 10 and at 60 TPS"
    requirement: "MOVE-06"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenario 9)"
        status: pass
    human_judgment: false
  - id: D7
    description: "A ground dash down the 45 degree Primitive_Slope at 60 TPS has 0 airborne ticks, stays within 0.3 m of the surface and keeps floor_snap_length in [0.3, 0.5]"
    requirement: "MOVE-06"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash (scenario 10)"
        status: pass
    human_judgment: false
  - id: D8
    description: "Sprint build-up, dash punch, carry length and which dash key (Q or Left Ctrl) feels right (A5)"
    verification: []
    human_judgment: true
    rationale: "Feel judgments; the plan's human-check (F5 in the test scene) and the 02-14 gym sign-off cover them"

duration: ~12min
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 9: Sprint and Real Dash Summary

**Hold-to-sprint to 1.5x run speed on its own slower curve, and a velocity-override dash for ground and air with cooldown, one air dash per airtime, a bounded exit carry and a jump hand-off, proven by 52 dash checks including 10 and 60 TPS wall tunnelling and a 45 degree slope dash.**

## Performance

- **Duration:** about 12 min (first RED commit 22:25, last task commit 22:33)
- **Completed:** 2026-11-05
- **Tasks:** 2 (both `auto`, `tdd="true"`: RED test commit, then GREEN feature commit per task)
- **Files:** 2 created (sprint.gd and its uid), 8 modified

## Accomplishments

- `Sprint` (extends `GroundState`): `ground_accel` up to `run_speed`, `sprint_accel` above it, target `run_speed * sprint_multiplier`. `Run` enters it on the next tick while the sprint action is held; the one Run tick changes nothing in the speed curve. Idle is untouched.
- `PlayerController`: `dash_cooldown_timer` (counted down in `_tick_timers`), `air_dash_available` (refilled in `_land`), `last_dash_direction`, `can_dash()` (cooldown elapsed and grounded or air dash unspent) and `start_dash()`. `GroundState` and `AirState` take the dash branch only when `can_dash()` is true.
- `Dash` rewritten: direction is the normalized input, else the VisualRoot forward; facing snaps on enter; each tick sets `move_velocity = direction * dash_speed`, and the controller's single `move_and_slide` integrates it (still exactly one call in `scripts/` and `autoload/`). The air dash zeroes `vertical_speed` and sets `gravity_scale` to `air_dash_gravity_scale`, restored in `exit()`. The Phase 1 timer constant is gone.
- Exit: `direction * minf(lerpf(run_speed, dash_speed, dash_carry), dash_exit_cap)`, `air_speed_cap` follows it in the air, then Fall, Sprint, Run or Idle. A jump press during a ground dash leaves Dash into `Jump`, during an air dash into `DoubleJump` when the air jump is unspent (A27); both apply the bounded carry first.
- Measured: ground dash 3.87 m (target 3.96), air dash altitude change 0.015 m, exit speed 12.0 m/s (cap), sprint reaches 10.50 m/s on its own curve (still 8.58 m/s at 14 ticks), 60 m/s dash stops at the wall at z -4.449 at both 10 and 60 TPS, slope dash 0 airborne ticks with a max height of 0.209 m above the surface and snap in band on every grounded sample.

## Task Commits

1. **Task 1 RED:** `ecbbe3f` (test) - sprint scenarios g, h, i fail
2. **Task 1 GREEN:** `b26f59d` (feat) - hold-to-sprint with its own acceleration above run speed
3. **Task 2 RED:** `b8f6b9e` (test) - real dash scenarios fail (12 of the new checks)
4. **Task 2 GREEN:** `b03840f` (feat) - real ground and air dash with cooldown, altitude hold and exit carry

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Task 1 gate: `run.sh test_ground_movement,test_movement_facts,test_mannequin_animation` -> `tests=3 passed=85 failed=0`; `test_ground_movement` alone prints 40 PASS lines (criterion: at least 17).
- Task 2 gate: `run.sh test_dash,test_ground_movement,test_jump.gd,test_feedback_guard` -> `tests=4 passed=129 failed=0`, `RUN.SH: PASSED`; `test_dash` prints 52 PASS lines (criterion: at least 15), stable over three runs.
- Plan-end gate: full `bash attimo/tests/run.sh` -> `tests=19 passed=761 failed=0`, `RUN.SH: PASSED`.
- Acceptance greps: `extends GroundState` 1, `name="Sprint"` 1, `sprint_accel` 2, `sprint_multiplier` 2, `idle.gd` not in either task commit, `func can_dash() -> bool` 1, `air_dash_available = true` 1, `can_dash()` in ground_state and air_state 1 each, `start_dash` 2, `DASH_TIME` 0, `physics_ticks_per_second = 10` 1, `move_and_slide` one line in `player_controller.gd`, `primitive_slope.tscn` 1, `floor_snap_length` 3.

## Deviations from Plan

None - plan executed exactly as written.

Choices inside the plan's latitude (no behavior the plan pinned was changed):

- Sprint without input returns `Run` rather than `Idle`, so Run owns the braking and the running pose is kept until the figure stops.
- Both jump hand-offs apply the bounded exit carry before leaving Dash. The plan only pinned "at least run speed"; clamping keeps the interim normal jump from carrying the raw 22 m/s dash speed (Pitfall 12, T-02-11). 02-11 reads the carried speed itself in `LongJump`, so it only needs to replace the ground branch in `Dash.physics_update`.
- The tunnelling test releases the direction and dash keys on the second tick, so the body can only reach the wall through the dash (with the keys held a plain run reaches the wall too and the check would prove nothing).

## Known Stubs

None.

## Threat Flags

None. T-02-11 holds: `can_dash()` needs the cooldown and the per-airtime flag, the exit carry and the air control target are clamped to `dash_exit_cap`, and `test_dash` pins the cooldown, the refused second air dash and the exit speed. T-02-12 holds: the dash is velocity through the single swept `move_and_slide`, and the 60 m/s case stops at the wall at 10 and 60 TPS. No MOVE-06 prohibition was crossed: nothing sets `position` or animates the body for the dash.

## Issues Encountered

None. The D-13 slope risk named in the plan did not materialise: the 22 m/s ground dash down the 45 degree wedge stayed grounded on every tick with the default 0.3 to 0.5 m snap band, so neither `snap_max` nor `movement_default.tres` was touched.

The human-check (F5: sprint with Shift, dash with Q and Left Ctrl, air dash plus double jump in both orders, a refused second air dash) is not run by the executor; it is recorded as `human_judgment: true` (D8) for the verifier and the 02-14 gym sign-off. Dash key choice stays open until then (A5).

## Next Phase Readiness

Ready for 02-11 (chain and long jump): `Dash.direction`, `Dash.in_air`, `PlayerController.last_dash_direction`, `can_dash()` and `start_dash()` exist, and the ground jump hand-off in `Dash.physics_update` is the single line 02-11 replaces with `LongJump`. `test_dash`'s state-agnostic dash-into-jump check (state Jump, rising, at least run speed) will need the `Jump` expectation widened to `Jump` or `LongJump` there.

## Self-Check: PASSED

- Created files exist: sprint.gd, sprint.gd.uid (FOUND).
- Commits `ecbbe3f`, `b26f59d`, `b8f6b9e`, `b03840f` are ancestors of HEAD (FOUND).
