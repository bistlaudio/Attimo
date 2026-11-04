---
phase: 01-foundation-prototype-character
plan: 04
subsystem: foundation
tags: [godot, input-map, collision-layers, conventions, docs]

requires:
  - phase: 01-01
    provides: "project.godot baseline, player.tscn, smoke harness (run.sh, fixtures.gd)"
provides:
  - "Full D-15 Input Map (18 actions) bound for keyboard and mouse, no gamepad events"
  - "Collision layers 1-6 named in project.godot (World, Player, Interactable, Enemy, Projectile/Beam, Hazard)"
  - "PhysicsLayers bitmask constants (class_name, res://scripts/core/physics_layers.gd)"
  - "docs/CONVENTIONS.md (D-13): folders, naming, layers, groups, Input Map, event bus, player-scene rules"
  - "Smoke guards test_input_map (incl. raw-polling scan) and test_conventions (doc/settings/constants sync)"
affects: [01-03, 01-06, 01-07, phase-02-movement, phase-04-interaction, phase-13-gamepad]

actuals:
  tokens: 14000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Input only via Input Map actions; a source scan fails on raw key/mouse/joypad polling in autoload/, scripts/, scenes/"
    - "Layer bitmask constants in PhysicsLayers; .tscn stores bitmasks, code never uses magic numbers"
    - "Doc-mirrors-settings: test_conventions asserts layer names, action names, folders in CONVENTIONS.md"

key-files:
  created:
    - attimo/scripts/core/physics_layers.gd
    - attimo/tests/smoke/test_input_map.gd
    - attimo/tests/smoke/test_conventions.gd
    - docs/CONVENTIONS.md
  modified:
    - attimo/project.godot

key-decisions:
  - "Layer 5 named Projectile/Beam verbatim from D-14 (A2); constant is PROJECTILE"
  - "dash bound to Q and Left Ctrl (A4); debug_event_log to F3 and QuoteLeft (A5)"
  - "look_* actions defined with empty events; gamepad slots reserved as a documentation column only"
  - "[input] written in alphabetical order so a later editor save produces no diff"

patterns-established:
  - "Pattern: every new .gd ships with its .gd.uid sidecar"
  - "Pattern: new layers/groups/actions are added to project.godot, constants, CONVENTIONS.md and tests in one commit"

requirements-completed: [FOUND-02, FOUND-03]

coverage:
  - id: D1
    description: "All 18 D-15 actions exist; non-look actions bound to key or mouse events with device -1; look_* empty; no gamepad events; specific bindings (Space, F3, dash x2, etc.)"
    requirement: "FOUND-02"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_input_map"
        status: pass
    human_judgment: false
  - id: D2
    description: "No game script under autoload/, scripts/ or scenes/ polls raw keys, mouse buttons or joypads"
    requirement: "FOUND-02"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_input_map (source scan)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Layers 1-6 carry D-14 names, 7-32 unnamed; PhysicsLayers equals 1,2,4,8,16,32; Player layer/mask/group match"
    requirement: "FOUND-03"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_conventions"
        status: pass
    human_judgment: false
  - id: D4
    description: "docs/CONVENTIONS.md covers layers, groups, folders, naming, actions with reserved gamepad column, bus rule and player-scene rules"
    requirement: "FOUND-03"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_conventions (doc coverage asserts)"
        status: pass
    human_judgment: true
    rationale: "String presence is asserted; the adequacy of the prose is a reading judgment"
  - id: D5
    description: "Layer names visible in the editor's layer grid"
    requirement: "FOUND-03"
    verification: []
    human_judgment: true
    rationale: "Checked visually during the end-of-phase play-through in plan 01-07"

duration: 10min
completed: 2026-11-04
status: complete
commits: 2
plan_head_before: d6c3e7b7103eb0277dbbd98c3775339ad6b5fd10
plan_head_after: 07f1de1
---

# Phase 1 Plan 04: Input Map, Collision Layers, Conventions Summary

**Complete D-15 Input Map (18 actions, keyboard/mouse bound, gamepad slots reserved), six named D-14 collision layers with `PhysicsLayers` constants, and `docs/CONVENTIONS.md`, all guarded by smoke tests that fail on drift or raw input polling.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files:** 4 created (plus `.gd.uid` sidecars), 1 modified

## Accomplishments

- `project.godot` `[input]` now holds all 18 actions in alphabetical order with the exact Godot serialisation (physical keys, device -1). `look_*` have empty event lists, `dash` has Q and Left Ctrl, `debug_event_log` has F3 and QuoteLeft, `module_next/prev` use the wheel. `jump` is unchanged. No joypad event exists.
- `[layer_names]` names 3d_physics layers 1-6; 7-32 stay unnamed and reserved.
- `PhysicsLayers` provides the six bitmask constants.
- `docs/CONVENTIONS.md` has 10 sections covering the items required by D-13.
- `test_input_map` checks existence, bindings, device -1, absence of gamepad events (project actions only, so built-in `ui_*` are excluded) and scans `autoload/`, `scripts/`, `scenes/` for raw polling tokens. `test_conventions` checks layer names, constants, the Player's layer/mask/group and doc coverage.

## Task Commits

1. **Task 1: Input Map for keyboard and mouse, raw-polling guard** - `7e8e420` (feat)
2. **Task 2: Layer names, PhysicsLayers, CONVENTIONS.md** - `07f1de1` (feat)

## Deviations from Plan

None - plan executed exactly as written.

Process notes (not code deviations):
- The worktree HEAD did not contain `d6c3e7b` at start, so it was reset to it as instructed (no work was lost; the tree was clean).
- The Input Map block was generated by a throwaway script kept in the scratchpad (not committed), then verified by the headless engine run.

## Authentication Gates

None.

## Verification Results

- `bash attimo/tests/run.sh` -> `SMOKE SUMMARY: tests=4 passed=162 failed=0`, `RUN.SH: PASSED`; no `FAIL [` lines.
- Task 1 greps: 18 action header lines, 0 `InputEventJoypad`, 16 `"device":-1`.
- Task 2 greps: `layer_5="Projectile/Beam"` 1, layers 1-6 count 6, layers 7-32 count 0, 10 `## ` sections in CONVENTIONS.md, `reserved` 11.
- The engine run did not rewrite `project.godot` (git status showed only the intended changes).
- Not verified here: the editor layer grid display (deferred to plan 01-07 play-through).

## Known Stubs

None.

## Threat Flags

None. T-01-07 (raw input polling) and T-01-08 (config/doc drift) are mitigated by `test_input_map` and `test_conventions`.

## Next Phase Readiness

Later plans can mask layers via `PhysicsLayers` and read the documented action names. Plan 01-06 can bind `debug_event_log`. Phase 13 binds gamepad events to the existing action names.

## Self-Check: PASSED

- Created files exist: `physics_layers.gd`, `test_input_map.gd`, `test_conventions.gd`, `docs/CONVENTIONS.md`.
- Commits `7e8e420` and `07f1de1` are ancestors of HEAD.
