---
phase: 02-movement-core-follow-camera
plan: 14
subsystem: movement-gym
tags: [godot, gdscript, movement-gym, prototype-bits, main-scene, sign-off, headless-tool]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-03 Prototype Bits wrappers (Slope, Beam), 02-07 MovingPlatform and FallReset, 02-12 tuning panel, 02-13 MOVEMENT-METRICS.md"
provides:
  - "tools/build_movement_gym.gd (launcher) and tools/movement_gym_builder.gd (worker): one command regenerates scenes/test/movement_gym.tscn byte-identically"
  - "scenes/test/movement_gym.tscn: the Phase 2 main scene, an 84 x 84 m Prototype Bits hall with measurement lane, ramps/stairs/ledges, gap course (2..12 m), three moving platforms, two conveyors, passage with low ceiling, pillar forest, two fall resets, 51 Label3D markings"
  - "test_movement_gym: 54 checks (composition and play)"
  - "run/main_scene switched to the gym; test_scene_run loads test_scene.tscn directly"
affects: [phase-2-verification, movement-tuning-follow-up, 03-wall-run]

actuals:
  tokens: 45000
  tasks: 2
  commits: 2

commits: 2
plan_head_before: 9373a79686ba01097f4012c3f98c1e995e903707
plan_head_after: 6b1ae33461b9486b97dff93c32b4a2dfe6a1576a

tech-stack:
  added: []
  patterns:
    - "Launcher plus worker for -s tools that instance scenes touching autoloads (same as measure_movement.gd)"
    - "PackedScene.pack() random unique_id values are stripped after saving so generated scenes stay reproducible"

key-files:
  created:
    - attimo/tools/build_movement_gym.gd
    - attimo/tools/movement_gym_builder.gd
    - attimo/scenes/test/movement_gym.tscn
    - attimo/tests/smoke/test_movement_gym.gd
  modified:
    - attimo/project.godot
    - attimo/tests/smoke/test_scene_run.gd

key-decisions:
  - "The gym tool is split into a launcher (pack, save, strip unique_id) and a worker (typed node construction), because a -s script compiles before the autoloads exist."
  - "Generated scene stays reproducible by stripping the random unique_id values after ResourceSaver.save."
  - "Linear and circular moving platforms float with their bottom flush on the floor and are boarded with a jump, so they need no pits."

requirements-completed: [MOVE-01, MOVE-08]
requirements-open: [CAM-01]

coverage:
  - id: D1
    description: "The movement gym is generated from Prototype Bits only, is the main scene, and has every D-20 zone and the markings"
    requirement: "MOVE-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_gym (54 PASS)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Gym play: grounded spawn, camera-relative run, moving platforms in motion, fall into the gap pit returns to the course respawn"
    requirement: "MOVE-08"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_gym"
        status: pass
    human_judgment: false
  - id: D3
    description: "Movement and camera feel signed off in the gym without juice (items 1-6, 10)"
    requirement: "MOVE-01"
    verification: []
    human_judgment: true
    rationale: "Feel cannot be judged headless; the developer played the gym and passed items 1, 2, 3, 5, 6 and 10, and item 4 on label/metric match"
  - id: D4
    description: "Camera judder on a real 144 Hz display (CAM-01, success criterion 1)"
    requirement: "CAM-01"
    verification: []
    human_judgment: true
    rationale: "144 Hz not verified. The developer only has a Mac and could not check it. The headless jitter test of 02-06 is only a proxy, so this stays an open human-verification gap (human_needed)."

duration: 35 min
completed: 2026-11-06
---

# Phase 2 Plan 14: Movement Gym Summary

**A reproducible, generated 84 x 84 m movement gym from Prototype Bits (lane, ramps and stairs, gap course 2..12 m, three moving platforms, conveyors, passage, pillar forest, fall resets) is now the main scene and plays end to end in the smoke test; the developer passed the feel sign-off except for the mandatory 144 Hz item, which is not verified.**

## Accomplishments

- `tools/build_movement_gym.gd` plus `tools/movement_gym_builder.gd` write `scenes/test/movement_gym.tscn`. Re-running leaves the file byte-identical.
- All D-20 zones exist, with Label3D markings for distances every 2 m, heights 1 to 4 m, gap widths, riser and ledge heights. There are no particles, glow or fog, every mesh sits under a `scenes/proto` wrapper or the Mannequin, and every static body is on the World layer.
- `run/main_scene` points at the gym. `test_scene_run` loads `test_scene.tscn` directly and no longer asserts the main scene (A12).
- `test_movement_gym` has 54 checks: composition (contract nodes, one Player, one Camera3D in a sibling CameraRig, three platforms, conveyors, fall resets, 0.15 m riser steps, hidden overlays) and play (grounded spawn, camera-relative run, platforms move, a fall into the pit returns to the gap course respawn).
- The full suite ends with `RUN.SH: PASSED` (24 tests, 1009 checks, 0 failed).

## Task Commits

1. **Task 1: Generated gym and main scene** - `f18792e` (feat)
2. **Task 2: Gym play smoke test, test_scene_run no longer owns the main scene** - `6b1ae33` (test)

## Human Sign-off (recorded as reported, nothing upgraded)

| Item | Result |
|---|---|
| 1 Run, sprint, skid, stop | pass |
| 2 Jump heights, coyote, buffer, one double jump | pass |
| 3 Dash and dash keys | pass (see dash key follow-up below) |
| 4 Long jump chain, gap labels vs MOVEMENT-METRICS.md and F4 overlay | pass on label and metric match. The developer wants the long-jump arc higher. This is feedback, not a failure, and goes to follow-up tuning. |
| 5 Platforms, conveyors, ramps, stairs, ledges | pass |
| 6 Camera (centered, no jitter at 60/120/10 TPS, no wall clipping, recenter, auto-follow, persistence) | pass |
| **7 MANDATORY 144 Hz judder (CAM-01, success criterion 1)** | **144 Hz not verified.** The developer only has a Mac and cannot check it. This is an **open human-verification gap (human_needed)**. CAM-01 is not marked complete on the strength of this plan, and the phase is not signed off for success criterion 1. |
| 8 Latency (FEEL-06) | Provisionally OK ("ja an sich"), to be re-checked by the developer later. The asserted software latency from MOVEMENT-METRICS.md stands (medians 6.5 to 14.8 ms against the 66 ms target, max 20.3 ms). Display, compositor and USB latency are unmeasured (D-22 caveat). |
| 9 Capsule fits the Mannequin in the low-ceiling passage (A2) | **Pending, not yet checked.** The passage is west of the spawn at z -2, x -26..-10, with the low ceiling at x -20..-12. |
| 10 Nothing glows, no particles, no camera effects | pass |

## Open Decisions and Follow-ups (no code or tuning changed in this plan)

- **Dash key (A5 / item 3):** the developer wants dash on **Left Shift (tap)**. Sprint is on Shift today, so sprint would move to another hold key (proposed: Left Alt). Follow-up, to be decided. The hold-versus-tap discussion for sprint and dash is for later.
- **Long-jump arc:** the developer wants it higher (follow-up tuning).
- **General feel feedback:** movement feels too heavy and not light enough. The developer wants it more input-responsive (input lag or speed maybe too long or slow, to be discussed) and wants to change the double-jump logic.
- **Capsule height (A2):** pending the passage check.
- **144 Hz check:** still needs a 144 Hz display. Until it is recorded, CAM-01 stays open.
- `movement_default.tres` and all gameplay code are unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Gym tool split into launcher and worker**
- **Found during:** Task 1
- **Issue:** `-s` scripts compile before the autoloads exist, so naming `PlayerController` and friends failed with `Identifier not found: EventBus`.
- **Fix:** The typed construction code lives in `tools/movement_gym_builder.gd`, loaded at run time. The launcher keeps pack, `ResourceSaver.save` and the `GYM:` output.
- **Files modified:** attimo/tools/build_movement_gym.gd, attimo/tools/movement_gym_builder.gd
- **Commit:** f18792e

**2. [Rule 1 - Bug] Generated scene was not reproducible**
- **Found during:** Task 1
- **Issue:** `PackedScene.pack()` stamps random `unique_id` values, so every run differed.
- **Fix:** The launcher strips `unique_id=` values after saving. Two consecutive runs are now identical.
- **Files modified:** attimo/tools/build_movement_gym.gd
- **Commit:** f18792e

**Other choices within the plan's latitude:**
- The hall is 84 x 84 m instead of about 64 x 72 m (A34 allows executor coordinates), because the 40 m lane and the 86 m gap course with one turn needed the room.
- The pillar forest staggers alternate rows by 1 m, to stay on the 1 m grid.
- Running the suite made the engine rewrite `project.godot` formatting and two texture `.import` files. These side effects were reverted and not committed.

**Total deviations:** 2 auto-fixed (1 blocker, 1 bug). **Impact:** none on scope; both were needed for the tool to run and to be reproducible.

## Known Stubs

None.

## Threat Flags

None. The tool writes only the constant gym path (T-02-20), and the debug overlays start hidden (T-02-21).

## Next Phase Readiness

Phase 2 is functionally complete and playable. Phase verification should treat CAM-01 success criterion 1 as `human_needed` until the 144 Hz check is recorded. A follow-up tuning round is expected for the long-jump arc, general lightness and responsiveness, the double-jump logic, and the dash key and sprint key remap.

## Self-Check: PASSED

- Files found: build_movement_gym.gd, movement_gym_builder.gd, movement_gym.tscn, test_movement_gym.gd.
- Commits f18792e and 6b1ae33 are ancestors of HEAD.
- Full suite: `RUN.SH: PASSED`, 0 `FAIL [` lines.
