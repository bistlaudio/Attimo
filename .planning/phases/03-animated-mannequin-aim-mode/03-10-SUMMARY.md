---
phase: 03-animated-mannequin-aim-mode
plan: 10
subsystem: animation
tags: [godot, animation-timing, air-dash, landing, latency-guard, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 BlendTree root, MannequinAnimator with last_travel and last_travel_frame, Land overlay, animation fixtures; 03-02 library with Dodge clips
provides:
  - Air-dash pose hold in MannequinAnimator (DEV-02): air_dash_holding, air_dash_hold_time(), AIR_DASH_HOLD_TIME 0.35 s
  - test_animation_timing, the headless guard for same-frame travel, visible Jump -> Fall, landing without lock, 2-frame anticipation and the hold rules
affects: [03-03, 03-07, 03-09]

actuals:
  tokens: 5000   # chars/4 over the added diff lines in attimo/ (20071 chars)
  tasks: 2
  commits: 2
plan_head_before: f9d4b8b4eedc204a41b737b0eae53b76909935e0
plan_head_after: 46cc14ac9b2edc738422803bef3cd381ae4d8a07
commits: 2

tech-stack:
  added: []
  patterns:
    - "Timing guard records the animator's view inside a state_changed call from a recorder connected after the animator's own handler"
    - "Scenarios that count animation time run the AnimationTree in manual mode and advance it once per physics frame (Pitfall 12)"
    - "Presentation delay is a hold in the animator that reads the Dash node's in_air and writes only AnimationTree parameters"

key-files:
  created:
    - attimo/tests/smoke/test_animation_timing.gd
    - attimo/tests/smoke/test_animation_timing.gd.uid
  modified:
    - attimo/scripts/player/mannequin_animator.gd

key-decisions:
  - "The hold start value AIR_DASH_HOLD_TIME is 0.35 s behind air_dash_hold_time(), so 03-07 swaps the source without touching callers or the test"
  - "A ground dash that ends airborne (in_air false) never holds; Fall is travelled on the exit call"

requirements-completed: []

duration: about 25 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 10: Air-dash pose hold and animation timing guard Summary

**MannequinAnimator holds the Dodge pose after an air dash until landing or 0.35 s (DEV-02), and test_animation_timing proves headless that every travelling state change travels on its own physics frame, the visible Jump -> Fall switch is immediate, landing never locks control and a jump shows at most 2 frames of anticipation.**

## Accomplishments

- `mannequin_animator.gd`: on `Dash -> Fall` with the Dash node's `in_air` true the animator keeps the dash node (`air_dash_holding`, `_hold_left`), so the non-looping Dodge clip plays on at 1x and holds its last frame. Any other state change clears the hold first and travels on the same call. `_physics_process` counts the hold down and travels to Fall once `air_dash_hold_time()` has passed. A ground dash off a ledge does not hold. A private `_travel_to()` records `last_travel` and `last_travel_frame` for every travel. The DEV-02 rule is written into the class doc comment.
- `test_animation_timing` (43 checks): same-frame travel for Idle -> Jump and Run -> Dash with the visible node following within 2 process frames; tap-jump Jump -> Fall 15 ticks after the jump (cut clip is 21 ticks) with the node already Fall at the first manual advance; Land overlay fires on landing into Idle and a move input fades it within 10 ticks (measured 7); no Land node in the state machine; Jump_Start crouch bottom at 0.267 s against the 0.283 s limit; hold scenario (Dash -> Fall holds, node still Dash 2 process frames later, landing travels on the landing frame, Land overlay fires); long fall from 30 m (hold ends 21 ticks after the exit, equal to `round(air_dash_hold_time() * 60)`); FSM Fall entry 11 ticks after Dash entry, unchanged by the hold; `move_left` during the hold adds 0.53 m/s along the camera's left within 10 ticks; ledge dash travels to Fall on the exit call without a hold.
- Verification: the plan command `test_animation_timing,test_mannequin_animation,test_movement_facts,test_dash,test_long_jump,test_latency` passes (6 tests, 241 checks), `test_latency` alone passes (18 checks), `test_feedback_guard` passes, full suite `RUN.SH: PASSED` (26 tests, 1131 checks, 0 failed). `test_animation_timing` ran three times with identical results.

## Task Commits

1. Task 1 (tracer): air-dash hold and hold scenario - `a744be9`. Tracer gate: automated-only verify re-run end to end, passed, expansion continued.
2. Task 2: full timing guard - `46cc14a`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Recorder and first jump need a settled scene**
- **Found during:** Task 1 and Task 2
- **Issue:** `player.state_machine` is `@onready`, so it is still null when the scenario runs right after `add_child` in the first frame. Separately, a jump pressed within the first frames after spawn is seen late by the tree (it was still on Locomotion 2 process frames after the Idle -> Jump call), which broke the "visible node follows within 2 process frames" check.
- **Fix:** `_begin()` waits 2 physics frames before connecting the recorder, and the same-frame scenario waits 30 physics frames before the first jump. The in-call same-frame assertions were never affected; only the visible-node follow-up needed the settled tree. This is a test-sequencing note, not a product bug: the first frames after spawn are not a gameplay situation.
- **Files modified:** attimo/tests/smoke/test_animation_timing.gd
- **Commits:** a744be9, 46cc14a

**Total deviations:** 1 auto-fixed (1 blocking, test setup). **Impact:** none on scope or production code.

## Auth gates

None.

## Known Stubs

None. `AIR_DASH_HOLD_TIME` is a constant by design until 03-07 moves it into MovementConfig.

## Threat Flags

None. T-03-14 (hold presentation only: the Fall entry tick, steering, landing-frame travel and tick-count timeout are asserted) and T-03-15 (Land overlay faded within 10 ticks after a move input) are mitigated as planned. test_feedback_guard passes over the new animator code.

## Notes for later plans

- 03-07: move `AIR_DASH_HOLD_TIME` into MovementConfig as `air_dash_hold_time` and change `air_dash_hold_time()` to read it; the test reads the method, never a literal. The hold must also cover the directional aim dashes there.
- 03-09: the gym check item 2 judges the held Dodge pose by eye (A-10-1: the engine holds the last frame of a non-looping clip in a state machine node; the tree stays on the dash node, confirmed headless, the look is not).
- The Godot harness again rewrote `attimo/project.godot` and two `*.png.import` files; they were never staged.

## Self-Check: PASSED

Files verified present: mannequin_animator.gd (air_dash_holding 6 matches, AIR_DASH_HOLD_TIME 1, `_physics_process` 1), test_animation_timing.gd and its .uid. Acceptance criteria: `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` 2, `air_dash_hold_time()` 2, hips track path 1, `_scenario_jump_fall_visible` 2, 43 PASS lines and `failed=0`. Commits a744be9 and 46cc14a are ancestors of HEAD.
