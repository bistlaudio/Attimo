---
phase: 01-foundation-prototype-character
plan: 06
subsystem: debug-tooling
tags: [godot, debug-overlay, event-bus, guard, feel-01]

requires:
  - phase: 01-01
    provides: "EventBus autoload with the D-11 facts, smoke harness"
  - phase: 01-04
    provides: "debug_event_log Input Map action (F3, QuoteLeft)"
provides:
  - "EventLog CanvasLayer overlay (res://scenes/debug/event_log.tscn) that auto-connects to every EventBus signal"
  - "test_event_log: auto-connect, content, 14-line cap, toggle, not-an-autoload"
  - "test_feedback_guard: FEEL-01 guard (no feedback tokens in gameplay, no particle nodes in scenes, bus holds only signals)"
affects: [01-03, 01-07, phase-02-movement, juice-phases]

actuals:
  tokens: 5500
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Generic fact listener: iterate EventBus.get_script().get_script_signal_list() and bind the signal name to a variadic handler"
    - "Source-scan guards run as smoke tests and include comments on purpose, so plain substring matching stays reliable"

key-files:
  created:
    - attimo/scripts/debug/event_log.gd
    - attimo/scenes/debug/event_log.tscn
    - attimo/tests/smoke/test_event_log.gd
    - attimo/tests/smoke/test_feedback_guard.gd
  modified: []

key-decisions:
  - "Added class_name EventLog to event_log.gd so tests can reference EventLog.MAX_LINES and the typed instance"

requirements-completed: [FEEL-01]

coverage:
  - id: D1
    description: "Overlay lists every EventBus fact with timestamp and payload, newest last, capped at 14 lines"
    requirement: "FEEL-01"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_event_log"
        status: pass
    human_judgment: false
  - id: D2
    description: "Log connects to every EventBus script signal (future facts appear with no edit)"
    requirement: "FEEL-01"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_event_log (per-signal connection check)"
        status: pass
    human_judgment: false
  - id: D3
    description: "debug_event_log toggles the overlay, which starts hidden; the log is not an autoload"
    requirement: "FEEL-01"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_event_log"
        status: pass
    human_judgment: false
  - id: D4
    description: "Guard fails on feedback tokens in gameplay scripts, particle nodes in scenes, or non-signal content in the EventBus"
    requirement: "FEEL-01"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_feedback_guard (plus two mutation probes that failed as required)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Overlay look (translucent top-left panel, readable text) and F3 feel in the running game"
    requirement: "FEEL-01"
    verification: []
    human_judgment: true
    rationale: "Visual check during the end-of-phase play-through in plan 01-07, where the log is instanced in the test scene"

duration: 12min
completed: 2026-11-04
status: complete
commits: 2
plan_head_before: cba8144
plan_head_after: db55a590004fb9b9a42801f3fcfe9be317d5e2ff
---

# Phase 1 Plan 06: Debug Event Log and FEEL-01 Guard Summary

**A hidden-by-default CanvasLayer overlay that auto-connects to every EventBus signal and logs timestamped facts (14-line cap, F3 toggle), plus a smoke guard that fails if gameplay calls feedback directly, a scene holds a particle node, or the bus holds anything but signals.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files:** 4 created (plus `.gd.uid` sidecars), 0 modified

## Accomplishments

- `event_log.gd` loops over `EventBus.get_script().get_script_signal_list()` and connects each signal to a variadic `_on_fact` handler with the signal name bound. Lines look like `[  12.34] jumped [(0.0, 0.0, 0.0)]`. The label text is the lines joined by newlines.
- `event_log.tscn` is a hand-written format=3 scene: `CanvasLayer` (layer 100), a `PanelContainer` (520 px minimum width, black at 0.6 alpha) and a `%Lines` `RichTextLabel`. No tweens, animation, audio or particles. It is not registered as an autoload.
- `test_event_log` (20 checks): starts hidden, one connection per bus signal targets the log node, the four facts appear in order with payload, 20 extra emits cap at 14 and drop the oldest, the label equals the joined lines, the toggle press shows and hides it, and `autoload/EventBus` is the only autoload.
- `test_feedback_guard` (10 checks): scans 8 gameplay scripts under `scripts/core`, `scripts/player`, `autoload` for 7 forbidden tokens, scans 7 scenes for particle node types, checks the bus has only `extends` and `signal` lines and declares the four D-11 facts, and checks `jump.gd` and `state_machine.gd` emit their facts.
- Mutation probes (copy-and-restore): appending `var _probe_tween: Tween = null` to `state.gd` produced `FAIL ... state.gd:19 uses forbidden feedback token 'Tween'` and a non-zero exit. Appending `var probe: int = 0` to `event_bus.gd` produced `FAIL ... is not a signal` and a non-zero exit. Both files were restored byte-identical (`cmp` clean).

## Task Commits

1. **Task 1: Debug event log overlay and tests** - `b3ddf92` (feat)
2. **Task 2: FEEL-01 feedback guard** - `db55a59` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree HEAD lacked the wave base commit**
- **Found during:** startup
- **Issue:** `git merge-base --is-ancestor cba8144 HEAD` failed
- **Fix:** tree was clean, so `git reset --hard cba8144` in my own worktree branch as instructed
- **Files modified:** none

**2. [Rule 1 - Bug] Payload assertion in my own test used the wrong Vector3 format**
- **Found during:** Task 1 first run
- **Issue:** `Vector3(1, 2, 3)` stringifies as `(1.0, 2.0, 3.0)`, not `(1, 2, 3)`
- **Fix:** the assertion now matches `1.0, 2.0, 3.0`
- **Files modified:** `attimo/tests/smoke/test_event_log.gd`
- **Commit:** `b3ddf92` (fixed before the commit)

**Plan interpretation:** the plan's interface section does not name a `class_name`; I added `class_name EventLog` so the test can use `EventLog.MAX_LINES` and a typed instance. Nothing else references it.

## Authentication Gates

None.

## Verification Results

- `bash attimo/tests/run.sh` -> `SMOKE SUMMARY: tests=9 passed=303 failed=0`, `RUN.SH: PASSED`, no `FAIL [` lines.
- Acceptance greps satisfied: `get_script_signal_list` and `debug_event_log` present in `event_log.gd`, one `type="CanvasLayer"` and a `unique_name_in_owner = true` in the scene.
- The guard scans only 8 gameplay scripts today. Plan 01-03's `run.gd`, `fall.gd`, `dash.gd` will be covered automatically once merged (wave-end full run re-checks the merged tree).

## Known Stubs

None.

## Threat Flags

None. T-01-10 is mitigated: the log is a scene, not an autoload (asserted), starts hidden and is bound to a `debug_`-prefixed action. T-01-11: the guard only reads fixed `res://` folders.

## Next Phase Readiness

Plan 01-07 instances `res://scenes/debug/event_log.tscn` in the test scene. The visual check of the overlay is part of its play-through.

## Self-Check: PASSED

- Created files exist: `event_log.gd`, `event_log.tscn`, `test_event_log.gd`, `test_feedback_guard.gd`.
- Commits `b3ddf92` and `db55a59` are ancestors of HEAD.
