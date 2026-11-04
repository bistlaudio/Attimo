---
phase: 01-foundation-prototype-character
plan: 03
subsystem: gameplay
tags: [godot, fsm, player, event-bus, demo-verbs]

requires:
  - phase: 01-01
    provides: "StateMachine/State, EventBus facts, PlayerController, run.sh and fixtures"
  - phase: 01-02
    provides: "MannequinAnimator and AnimationTree (Locomotion/Jump/Fall/Land/Dash)"
  - phase: 01-04
    provides: "Input Map actions move_*, jump, dash"
provides:
  - "PlayerController.input_direction() and face() (VisualRoot yaw only, no velocity)"
  - "Run, Fall and Dash states; Idle/Run/Jump/Fall all transition to Dash on the dash action"
  - "All four D-11 facts (jumped, landed, dash_started, movement_state_changed) emitted from gameplay"
  - "test_movement_facts and test_dash_fact smoke tests"
affects: [01-06, 01-07, phase-02-movement]

requirements-completed: [FOUND-05, FEEL-01, FOUND-02]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "States never write velocity or position in Phase 1 (D-09); airborne is a state fact (Jump/Fall), not a floor check"
    - "Smoke-test recorders connect lambdas to EventBus and clear the stored Callables at scenario end to avoid a RefCounted cycle"

key-files:
  created:
    - attimo/scripts/player/states/run.gd
    - attimo/scripts/player/states/fall.gd
    - attimo/scripts/player/states/dash.gd
    - attimo/tests/smoke/test_movement_facts.gd
    - attimo/tests/smoke/test_dash_fact.gd
  modified:
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/idle.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/smoke/test_jump_fact.gd

key-decisions:
  - "Dash from Jump/Fall returns to Fall (not Idle) so the airborne stretch still ends in exactly one landed fact"
  - "Dash with no input falls back to the VisualRoot forward axis (y zeroed, normalized), snapping the yaw instead of lerping"

patterns-established:
  - "Dash/jump transitions are checked before timer-driven transitions so a press wins over a timer ending in the same tick"

coverage:
  - id: D1
    description: "Holding move_* enters Run, VisualRoot turns to the input direction, Locomotion blend 1.0; release returns to Idle with blend 0.0"
    requirement: "FEEL-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_facts"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every jump runs Jump -> Fall -> Idle/Run on timers and emits landed exactly once; no landed without a jump"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_facts"
        status: pass
    human_judgment: false
  - id: D3
    description: "dash plays Dodge_Forward in place from Idle, Run, Jump and emits dash_started once with direction and in_air"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_dash_fact"
        status: pass
    human_judgment: false
  - id: D4
    description: "Player position and velocity stay unchanged through every verb (D-09)"
    requirement: "FOUND-02"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_facts,test_dash_fact"
        status: pass
    human_judgment: false
  - id: D5
    description: "Visual quality of run facing, dodge root-bone slide and transitions"
    requirement: "FEEL-01"
    verification: []
    human_judgment: true
    rationale: "Headless tests prove states, facts and tree nodes; how it looks needs eyes in the plan 01-07 test scene"

duration: 15min
completed: 2026-11-04
status: complete
plan_head_before: cba8144
plan_head_after: 3306c358f976b90cff6c63d19627f2472bd20455
---

# Phase 1 Plan 03: Demo Verbs Summary

**WASD runs the Mannequin in place and turns VisualRoot toward the input, every jump ends in a timer-driven Fall that emits one `landed`, and Q / Left Ctrl plays Dodge_Forward from grounded and airborne states with one `dash_started`, all without ever moving the Player (D-09).**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files:** 5 created (plus `.gd.uid` sidecars), 5 modified

## Accomplishments

- `PlayerController.input_direction()` reads `Input.get_vector` over the move actions (world axes, W = -Z, A14) and `face()` lerps `visual_root.rotation.y` toward `atan2(x, z)` inside the physics tick. The body's position and velocity are never written.
- Run, Fall and Dash states added as `State` nodes under `StateMachine` in `player.tscn`. Jump now hands over to Fall after `JUMP_TIME` (0.6 s); Fall emits `EventBus.landed(position, 0.0)` once after `FALL_TIME` (0.3 s) and continues to Run (input held) or Idle.
- Dash (`DASH_TIME` 0.4 s) emits `dash_started(position, direction, in_air)` on enter; `in_air` is true when the previous state was Jump or Fall. An airborne dash returns to Fall, so the landing fact still fires once.
- Full suite: `SMOKE SUMMARY: tests=9 passed=319 failed=0`, `RUN.SH: PASSED`, including `test_jump_fact`, `test_mannequin_animation`, `test_input_map` (raw-input scan covers the new scripts).

## Task Commits

1. **Task 1: Run in place with facing; timer-driven Fall emits landed** - `84a4517` (feat)
2. **Task 2: Dash plays Dodge_Forward in place and emits dash_started** - `3306c35` (feat)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Existing tracer test broke when Jump started handing over to Fall**
- **Found during:** Task 1
- **Issue:** `test_jump_fact` expected Idle 45 physics frames after the jump tap. With Jump -> Fall -> Idle the chain takes about 54 frames, so the state was still Fall.
- **Fix:** Wait 70 frames and update the header/label text to the Jump -> Fall -> Idle chain. Assertions are otherwise unchanged.
- **Files modified:** `attimo/tests/smoke/test_jump_fact.gd` (not listed in the plan's `files_modified`)
- **Commit:** `84a4517`

**2. [Rule 1 - Bug] Test object kept alive by a Callable cycle**
- **Found during:** Task 1
- **Issue:** First run of `test_movement_facts` printed `1 resources still in use at exit` because the recorder lambdas stored in member variables captured `self`.
- **Fix:** Clear the stored Callables in `_end()`; the same pattern is used in `test_dash_fact`.
- **Commit:** `84a4517`

**Total deviations:** 2 (both test-only). **Impact:** none on gameplay code.

Process note: the worktree HEAD did not contain `cba8144`, so it was reset to it as instructed (tree was clean, nothing lost).

## Authentication Gates

None.

## Known Stubs

None. `landed.impact_speed` is a fixed 0.0 by design (no vertical motion in Phase 1, D-09); the signal shape is final and Phase 2 supplies the real value.

## Threat Flags

None. Input is read only through named Input Map actions (T-01-06); `test_input_map` passes with the new scripts included in its scan.

## Issues Encountered

None.

## Next Phase Readiness

Plan 01-06 (event log) can observe all four facts from real gameplay. Plan 01-07 (test scene) gets the full Idle/Run/Jump/Fall/Dash demo verbs for the visual check. Phase 2 replaces the timers with velocity, gravity and floor contact in these same states, reintroduces the MIN_AIR_TIME spawn guard, and adds dash speed, air-dash limit and cooldown (MOVE-06/07). The Dodge_Forward root-bone slide (Pitfall 12) is left as is for Phase 3.

## Self-Check: PASSED

- Created files exist: run.gd, fall.gd, dash.gd, test_movement_facts.gd, test_dash_fact.gd. Commits `84a4517` and `3306c35` are ancestors of HEAD.
