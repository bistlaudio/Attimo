---
phase: 05-energy-arm-loader
plan: 01
subsystem: player-loader
tags: [loader, time-scale, aim-removal, tracer, input]
requires: []
provides:
  - TimeFx autoload (sole writer of Engine.time_scale)
  - LoaderMath, LoaderState, minimal ArmEnergy
  - Input action `loader` (RMB), aim mode fully removed
  - Glow stage SHOT_READY driven by EventBus.shot_ready_changed
affects: [05-02, 05-03, 05-04, 05-05]
tech-stack:
  added: []
  patterns: [single time owner autoload, real-time camera via TimeFx.unscaled]
key-files:
  created:
    - attimo/autoload/time_fx.gd
    - attimo/scripts/player/loader_math.gd
    - attimo/scripts/player/arm_energy.gd
    - attimo/scripts/player/states/loader.gd
    - attimo/tests/smoke/test_time_fx.gd
    - attimo/tests/smoke/test_loader.gd
    - attimo/tests/smoke/test_loader_math.gd
    - attimo/tests/smoke/test_aim_removed.gd
  modified:
    - attimo/project.godot
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/camera/camera_rig.gd
    - attimo/scripts/hand/hand_controller.gd
    - attimo/scripts/mechanisms/interactable.gd
    - attimo/scripts/ui/crosshair.gd
    - attimo/tests/smoke/test_event_log.gd
    - docs/CONVENTIONS.md
    - .claude/CLAUDE.md
key-decisions:
  - "Loader discharge direction is the camera forward; bonus decided at release and costs one full core"
  - "Glow stage AIM renamed SHOT_READY, glow_aim.tres renamed glow_shot_ready.tres"
metrics:
  duration: "interrupted and resumed"
  completed: 2026-11-24
---

# Phase 5 Plan 01: Loader tracer and aim-mode removal Summary

Right-click Loader (hold slows the world to 0.25 via the TimeFx single time owner, release discharges along the camera view with a one-core bonus) and complete removal of aim mode (flag, fact, goggle HUD, aim camera, sticky slowdown, wheel zoom).

## Commits

- 20fb078 test(05-01): failing tests for TimeFx, LoaderMath, Loader (RED)
- f099a85 feat(05-01): Loader tracer (Task 1)
- fb8afe4 refactor(05-01): aim removal part A (Task 2)
- 70efbf7 wip(05-01): aim removal part B, executor was stopped mid-task
- 742f692 refactor(05-01): finish aim removal B (Task 3)

## Deviations from Plan

**1. Interruption and resume (process).** The executor was stopped during Task 3. Its partial work was committed as WIP commit 70efbf7 (camera, crosshair, hand, targeting, glow stage, F2, gym sign, docs, test_aim_removed and tests already migrated). The resumed run audited that commit against Task 3's action and acceptance criteria, found everything present, and only needed the fix below plus verification. The WIP commit stays in history. The WIP commit also contains an unrelated `.DS_Store` and `.planning/STATE.md` / `state.json` changes.

**2. [Rule 1 - Bug] test_event_log asserted EventBus was the only autoload.** Task 1 added the TimeFx autoload, so the assertion failed in the full suite. Updated it to expect EventBus and TimeFx. Commit 742f692.

## Verification

- Gym tool: `GYM: WRITTEN`, no drift in movement_gym.tscn.
- Full suite `bash attimo/tests/run.sh`: tests=64, passed=3055 checks, failed=0, `RUN.SH: PASSED`; no SCRIPT ERROR in the log.
- Acceptance greps: no `Engine.time_scale =` outside time_fx.gd, no `.aiming` references, no `aim_changed`, no `^aim=` in project.godot, goggle_lens.gdshader and glow_aim.tres gone, `RMB halten` gone, CLAUDE.md has the `loader` (hold) row, 3 test_aim_*.gd files remain.
- Note: Phase 04.1 human UAT is still partial; the gym sign change belongs to a station that UAT covers.

## Known Stubs

None. ArmEnergy is intentionally minimal (extended in 05-03); shot_ready energy gate arrives in 05-04.

## Self-Check: PASSED
