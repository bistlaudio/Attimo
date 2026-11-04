---
phase: 01-foundation-prototype-character
plan: 01
subsystem: foundation
tags: [godot, walking-skeleton, tracer, event-bus, fsm, test-harness]

requires: []
provides:
  - "Pinned Godot 4.7.2 engine installed from a SHA-512-verified archive at $HOME/Applications/Godot_4.7.2"
  - "EventBus autoload with the four D-11 typed fact signals"
  - "Node-based State/StateMachine core (local state_changed + global movement_state_changed)"
  - "PlayerController (CharacterBody3D, never moves, D-09) with timer-driven Idle/Jump states and player.tscn"
  - "Headless harness: tests/run.sh (version gate, import, log grep), run_smoke.gd auto-discovery runner, fixtures.gd"
  - "FOUND-01 guard test (engine build, Jolt, Forward+, interpolation, typed-as-error, script-load sweep)"
  - "Root README.md with engine pin, GODOT env var, test commands, layout, credits"
affects: [01-02, 01-03, 01-04, 01-05, 01-06, 01-07, phase-02-movement, phase-11-juice, phase-14-audio]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Gameplay emits facts on the EventBus autoload; feedback systems connect, gameplay never calls feedback"
    - "Node-based FSM: State children return the next state name from physics_update"
    - "Smoke tests: RefCounted files with run(tree, check) auto-discovered by a SceneTree runner"
    - "run.sh greps logs for SCRIPT ERROR / Parse Error / Failed to load because Godot exits 0 on script errors"

key-files:
  created:
    - attimo/autoload/event_bus.gd
    - attimo/scripts/core/state.gd
    - attimo/scripts/core/state_machine.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/states/idle.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scenes/player/player.tscn
    - attimo/tests/run.sh
    - attimo/tests/run_smoke.gd
    - attimo/tests/fixtures.gd
    - attimo/tests/smoke/test_jump_fact.gd
    - attimo/tests/smoke/test_project_settings.gd
    - README.md
  modified:
    - attimo/project.godot

key-decisions:
  - "Engine installed outside the repo at $HOME/Applications/Godot_4.7.2 (assumption A11); GODOT overrides"
  - "Phase 1 body never moves (D-09 Option A): states are timer-driven (Jump.JUMP_TIME = 0.6 s = Jump_Start clip length)"
  - "Only the jump Input Map action is defined here; the rest arrive in plan 01-04"

patterns-established:
  - "Pattern: every .gd ships with its .gd.uid sidecar; scripts are fully typed (untyped_declaration=2 makes untyped code a parse error)"
  - "Pattern: tests reuse tests/fixtures.gd via preload const"

requirements-completed: [FOUND-01, FOUND-02, FEEL-01]

coverage:
  - id: D1
    description: "Simulated jump action drives FSM Idle -> Jump -> Idle on a timer and emits EventBus.jumped exactly once; body does not move"
    requirement: "FEEL-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_jump_fact"
        status: pass
    human_judgment: false
  - id: D2
    description: "Engine build, Jolt, Forward+, physics interpolation, typed-as-error and script loadability are guarded by a smoke test"
    requirement: "FOUND-01"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_project_settings"
        status: pass
    human_judgment: false
  - id: D3
    description: "run.sh refuses any engine binary that is not 4.7.2.stable.official.ed1daf0bf (exit 3) before importing"
    requirement: "FOUND-01"
    verification:
      - kind: other
        ref: "GODOT=/usr/bin/true bash attimo/tests/run.sh -> exit 3"
        status: pass
    human_judgment: false
  - id: D4
    description: "README documents engine pin, checksum, GODOT, test commands, layout and credits"
    requirement: "FOUND-02"
    verification: []
    human_judgment: true
    rationale: "Documentation adequacy is a reading judgment; only the presence of key strings is grep-checked"

duration: 15min
completed: 2026-11-04
status: complete
plan_head_before: 703e4c0759a67fa5d3914cd3a16dd2f9008f94d4
plan_head_after: 3610fa6c6094ff44b20d81b5600992fa870c8f48
---

# Phase 1 Plan 01: Walking Skeleton Summary

**Pinned Godot 4.7.2 install plus a proven tracer path: Input Map action `jump` -> node-based FSM -> `EventBus.jumped` fact, verified by a headless smoke harness that also guards the engine build, project settings and typed-script loadability.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files modified:** 14 (13 created, 1 modified), plus `.gd.uid` sidecars

## Accomplishments

- Installed Godot 4.7.2 after confirming the `~/Downloads` zip's SHA-512 equals the official value (`38aa16e5...69ca`); `--version` prints `4.7.2.stable.official.ed1daf0bf`.
- Tracer task: `project.godot` now carries the EventBus autoload, `untyped_declaration=2`, physics interpolation and the `jump` action (Jolt and D3D12 keys preserved). Pressing `jump` moves Idle -> Jump, emits `jumped` once, emits `movement_state_changed` on setup and every transition, returns to Idle after 0.6 s, and the Player stays at its spawn with zero velocity.
- `tests/run.sh` gates on the exact engine version (exit 3, verified with `GODOT=/usr/bin/true`), imports, runs the auto-discovering runner and fails on error patterns in the logs.
- `test_project_settings` checks version/build/hash, Jolt, Forward+, interpolation, untyped-as-error, features, autoload and sweeps every `.gd` for loadability. The typing guard was proven to bite: an untyped probe script caused a `FAIL` line naming it and exit 1; the probe was deleted and never committed.
- Root `README.md` documents the pin, checksum, install path, `GODOT`, Windows note, test commands, layout, branching and credits.

## Task Commits

1. **Task 1: Tracer (jump -> FSM -> jumped fact, headless harness)** - `6afede1` (feat)
2. **Task 2: Engine-pin / settings / script-load guard, README** - `3610fa6` (feat)

## Deviations from Plan

None - plan executed exactly as written.

Process notes (not code deviations):
- The task asked for the slice to be committed "on `dev`"; this executor runs in an isolated worktree on branch `worktree-agent-a17bd6100655b17ca`, so commits live there and the orchestrator merges them.
- The phase directory files (PLAN, CONTEXT, RESEARCH) are untracked in the main checkout and absent from the worktree. They were read from the main checkout (read-only); only this SUMMARY is written into the worktree's `.planning/phases/01-foundation-prototype-character/`.

**Total deviations:** 0. **Impact:** none.

## Authentication Gates

None.

## Verification Results

- Task 1 acceptance criteria: all 16 PASS (grep counts as specified, version gate `exit=3` with the expected-version message, `PASS [test_jump_fact]`, `SMOKE SUMMARY: tests=1 passed=9 failed=0`, all `.gd.uid` sidecars present).
- Task 2 acceptance criteria: all PASS (README greps: pin 2, SHA-512 1, `bash attimo/tests/run.sh` 3, `GODOT` 5; preload fixtures 1; `run.sh test_project_settings` -> `tests=1`; typing probe bites and was cleaned up).
- Plan verification: `bash attimo/tests/run.sh` -> `SMOKE SUMMARY: tests=2 passed=20 failed=0`, `RUN.SH: PASSED`; `GODOT=/usr/bin/true` -> exit 3 without import; the working tree was clean after the Task 2 commit (no probe files).
- Tracer feedback gate: `end-of-phase` mode with an automated-only `<verify>`; the tracer `<verify>` was re-run green before expansion (`Tracer verified end-to-end`).

## Known Stubs

None.

## Threat Flags

None. The engine archive was SHA-512-verified before extraction (T-01-01), `run.sh` blocks wrong versions before import (T-01-02), and log grep plus failure counting address false-green runs (T-01-03).

## Issues Encountered

None.

## Next Phase Readiness

Plan 01-02 can instance the Mannequin under the empty `VisualRoot` in `player.tscn` and hook a `MannequinAnimator` to `StateMachine.state_changed`. Plan 01-04 adds the remaining Input Map actions and layer names to `project.godot`; the `run.sh` and `fixtures.gd` interfaces are stable for later smoke tests.

## Self-Check: PASSED

- All 13 created files exist on disk; commits `6afede1` and `3610fa6` are ancestors of HEAD.
