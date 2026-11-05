---
phase: 02-movement-core-follow-camera
plan: 02
subsystem: conventions
tags: [conventions, input-map, event-bus, docs, camera-decision]
status: complete

requires:
  - phase: 01-project-foundation
    provides: EventBus autoload, Input Map, CONVENTIONS.md, test_input_map and test_conventions guards
provides:
  - Input Map actions camera_recenter, debug_tuning, debug_metrics, debug_tick_rate (KB+M only)
  - EventBus facts double_jumped, long_jumped, chain_stage_changed
  - Phase 2 contracts in docs/CONVENTIONS.md (folders, groups, actions, facts, player rules, Camera and Settings sections)
  - Doc/bus/Input Map drift guards in test_input_map and test_conventions
  - CLAUDE.md and research/STACK.md name the hand-built CameraRig; Phantom Camera no longer adopted
affects: [02-05, 02-06, 02-08, 02-10, 02-11, 02-12, phase-3, phase-11]

actuals:
  tokens: 3750
  tasks: 2
  commits: 2
plan_head_before: 41e4bd2ad1f2b21d0141ff5374f5b3500dc914a0
plan_head_after: b5893fd1ba2b5ee35d12c68c550fef9482a761bf
commits: 2

tech-stack:
  added: []
  patterns:
    - "Interface-first plan: actions and facts are declared before their emitters exist, so parallel waves never touch project.godot or the bus"
    - "test_conventions reads EventBus.get_script().get_script_signal_list() and fails if a signal is missing from the doc"

key-files:
  created: []
  modified:
    - attimo/project.godot
    - attimo/autoload/event_bus.gd
    - docs/CONVENTIONS.md
    - attimo/tests/smoke/test_input_map.gd
    - attimo/tests/smoke/test_conventions.gd
    - .claude/CLAUDE.md
    - .planning/research/STACK.md

key-decisions:
  - "Camera decision D-18 recorded in CLAUDE.md and STACK.md: hand-built CameraRig, Phantom Camera dropped; a per-frame shape cast is the fallback if SpringArm3D fails the 10-TPS corridor test"
  - "Debug Draw 3D marked deferred (A39) in both docs"
  - "Debug keys: F-row plus top-row digits 8/9/0 as Mac alternates (A9); digits 1-3 stay free for Phase 5 module slots"

requirements-completed: [CAM-01]

coverage:
  - id: D1
    description: "camera_recenter (middle mouse) and debug_tuning/debug_metrics/debug_tick_rate bound for KB+M only, no gamepad event"
    requirement: CAM-01
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_input_map#camera_recenter maps to the middle mouse button"
        status: pass
    human_judgment: false
  - id: D2
    description: "EventBus declares double_jumped, long_jumped, chain_stage_changed and still holds only signal lines"
    requirement: CAM-01
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_feedback_guard,test_conventions"
        status: pass
    human_judgment: false
  - id: D3
    description: "docs/CONVENTIONS.md documents every action, every bus signal with its emitter, new folders, moving_platform group in use, and the Phase 2 player and camera rules"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_conventions#doc lists EventBus signal"
        status: pass
    human_judgment: true
    rationale: "Prose accuracy of the player and camera rules is not asserted by a test; the drift guard only checks names"
  - id: D4
    description: "CLAUDE.md and STACK.md name the hand-built CameraRig as the camera and no longer adopt Phantom Camera"
    requirement: CAM-01
    verification:
      - kind: other
        ref: "task 2 verify command prints DOCS-OK"
        status: pass
    human_judgment: false
---

# Phase 2 Plan 02: Conventions, Input Map and Bus Facts Summary

**Four new Input Map actions, three new EventBus facts and the Phase 2 conventions in docs/CONVENTIONS.md, guarded against drift by two smoke tests, plus the hand-built CameraRig decision (D-18) recorded in CLAUDE.md and STACK.md.**

## Performance

- **Duration:** about 6 min
- **Started:** 2026-11-05T14:34:00Z (approx.)
- **Completed:** 2026-11-05T14:40:12Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- `project.godot` has `camera_recenter` (middle mouse button, button_index 3) and `debug_tuning` (F2, 8), `debug_metrics` (F4, 9), `debug_tick_rate` (F6, 0), serialised like the existing entries; no gamepad events.
- `event_bus.gd` declares `double_jumped(position)`, `long_jumped(position, stage)` and `chain_stage_changed(stage)` with doc comments; still only `extends` and `signal` lines (7 signals).
- `docs/CONVENTIONS.md` gains the new folders (`scripts/camera/`, `scenes/camera/`, `scripts/gym/`, `resources/`), `moving_platform` as in use, the four action rows, the extended bus table (landed now emitted by `PlayerController._land`), the Phase 2 player rules (replacing the Phase 1 "no movement physics" bullet), a Camera section and a Settings and debug section.
- `test_input_map` checks the new bindings; `test_conventions` checks the new folders, the terms MovementConfig / CameraRig / `user://settings.cfg`, and that every `EventBus` signal (read through `get_script_signal_list()`) appears in the doc.
- CLAUDE.md and STACK.md: Phantom Camera row replaced by the `CameraRig` row, fallback note for a shape cast, camera specifics (centered framing, shoulder offset aim-only, additive FOV/offset API), addon row, download line and open item removed or resolved, Debug Draw 3D deferred.

## Task Commits

1. **Task 1: Input Map actions, EventBus facts, Phase 2 conventions and guards** - `564ca5c` (feat)
2. **Task 2: Hand-built camera (D-18) and centered framing (D-14) in CLAUDE.md and STACK.md** - `b5893fd` (docs)

## Verification

- `bash attimo/tests/run.sh test_input_map,test_conventions,test_feedback_guard,test_event_log`: `SMOKE SUMMARY: tests=4 passed=217 failed=0`, `RUN.SH: PASSED`.
- All Task 1 acceptance greps hit the expected counts (4, 1, 7, 1, doc mentions >= 1, reserved-moving_platform row 0, MOUSE_BUTTON_MIDDLE 1, get_script_signal_list 1).
- Task 2 verify prints `DOCS-OK`; stack markers still present once each; the Task 2 commit touches none of STATE.md, REQUIREMENTS.md, ROADMAP.md.

## Deviations from Plan

None - plan executed exactly as written. Two small notes: the CLAUDE.md stack block contains no "Camera specifics" paragraph or open-items list (only STACK.md does), so those two edits applied to STACK.md only; the working tree held no uncommitted editor reformat of the dash / debug_event_log entries, so nothing needed preserving.

## Known Stubs

None.

## Threat Flags

None. T-02-04 mitigated (Phantom Camera no longer listed as adopted); T-02-03 transferred as planned (`debug_` prefix, stripped in Phase 15).

## Self-Check: PASSED

- Modified files all exist; commits `564ca5c` and `b5893fd` are ancestors of HEAD.
