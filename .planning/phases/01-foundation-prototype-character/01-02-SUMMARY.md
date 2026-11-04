---
phase: 01-foundation-prototype-character
plan: 02
subsystem: animation
tags: [godot, animation, animationtree, kaykit, gltf, mannequin]

requires:
  - phase: 01-01
    provides: "StateMachine local state_changed signal, PlayerController/VisualRoot, tests/run.sh and fixtures"
provides:
  - "Mannequin_Medium + three Rig_Medium GLBs copied into attimo/assets (KayKit originals untouched)"
  - "rig_medium_library.res: six demo clips (Idle_A, Running_A, Jump_Start, Jump_Idle, Jump_Land, Dodge_Forward) with loop modes, rebuilt by one command"
  - "mannequin_state_machine.tres: Locomotion (BlendSpace1D) / Jump / Fall / Land / Dash, rebuilt by one command"
  - "mannequin.tscn wrapper (GLB + AnimationPlayer + AnimationTree) instanced under Player/VisualRoot"
  - "MannequinAnimator: local state_changed -> AnimationTree travel and blend, Land on airborne -> Idle"
affects: [01-03, 01-07, phase-03-animation, phase-09-hero]

actuals:
  tokens: 14000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Editor-time build scripts in attimo/tools run through run.sh --tool; the generated resource is committed, the script is the reviewable source"
    - "Imported GLB is wrapped in its own scene (D-07), never edited"
    - "Hand-written .tscn needs node_paths= on nodes whose scripts have Node-typed exports"
    - "AnimationTree auto-advance edges use AUTO + SWITCH_MODE_AT_END; every travel() pair gets a direct edge"

key-files:
  created:
    - attimo/assets/characters/mannequin/Mannequin_Medium.glb
    - attimo/assets/characters/mannequin/Mannequin_Medium_mannequin_texture.png
    - attimo/assets/animations/rig_medium/Rig_Medium_General.glb
    - attimo/assets/animations/rig_medium/Rig_Medium_MovementBasic.glb
    - attimo/assets/animations/rig_medium/Rig_Medium_MovementAdvanced.glb
    - attimo/assets/animations/rig_medium/rig_medium_library.res
    - attimo/tools/build_animation_library.gd
    - attimo/tools/build_mannequin_state_machine.gd
    - attimo/scenes/player/mannequin_state_machine.tres
    - attimo/scenes/player/mannequin.tscn
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/tests/smoke/test_animation_library.gd
    - attimo/tests/smoke/test_mannequin_animation.gd
  modified:
    - attimo/scenes/player/player.tscn

key-decisions:
  - "Land only plays when the FSM leaves Jump/Fall into Idle; a landing into Run goes straight to Locomotion (A13, no airtime threshold)"
  - "Rig_Medium library is committed as binary .res (A9); the builder script is the source of truth"

patterns-established:
  - "Pattern: the animator listens only to the local StateMachine.state_changed, never the global fact bus"

requirements-completed: [FOUND-05, FOUND-04]

coverage:
  - id: D1
    description: "One command rebuilds a library of exactly six clips with Idle_A, Running_A, Jump_Idle looping and the right lengths"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_animation_library"
        status: pass
    human_judgment: false
  - id: D2
    description: "KayKit clips bind to Mannequin_Medium with no retargeting (Rig_Medium/Skeleton3D: track paths)"
    requirement: "FOUND-05"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_animation_library"
        status: pass
    human_judgment: false
  - id: D3
    description: "Mannequin under VisualRoot idles with looping Idle_A; jump press travels the tree to Jump; the end of the jump plays Land and returns to Locomotion; the Player does not move"
    requirement: "FOUND-04"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_mannequin_animation"
        status: pass
    human_judgment: false
  - id: D4
    description: "Visual quality of the idle/jump pose and crossfades"
    requirement: "FOUND-04"
    verification: []
    human_judgment: true
    rationale: "Headless tests prove bone poses change and states travel; whether it looks right needs eyes (plan 01-07 test scene)"

duration: 20min
completed: 2026-11-04
status: complete
plan_head_before: d6c3e7b7103eb0277dbbd98c3775339ad6b5fd10
plan_head_after: 86daf6f7ff4fe7f376db31d7f153bec838c8da7f
---

# Phase 1 Plan 02: Mannequin Animation Summary

**KayKit Mannequin_Medium under the Player's VisualRoot, idling with a looping Idle_A and driven by the FSM's local state_changed signal through an AnimationTree (Locomotion / Jump / Fall / Land / Dash), with both the clip library and the tree rebuilt reproducibly by tool scripts.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files:** 13 created (plus import sidecars and .gd.uid files), 1 modified

## Accomplishments

- Copied only the Mannequin GLB and three of the eight Rig_Medium GLBs with `cp`; byte-identical to the tracked KayKit originals, which remain in place (D-04, T-01-04).
- `bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd` prints `saved ... (6 clips) err=0`; the importer extracted exactly `Mannequin_Medium_mannequin_texture.png` (+ `.import`), the file name expected by plan 01-07's whitelist.
- `build_mannequin_state_machine.gd` produces a text `.tres`; both builders were run twice and the outputs are byte-identical (`cmp`).
- The Mannequin wrapper scene never touches the GLB (D-07). `MannequinAnimator` is wired via `node_paths=` (Pitfall 1) and contains no reference to the global fact bus.
- `test_mannequin_animation` shows Locomotion at start, changing poses past one Idle_A length, `jump` -> Jump within the window, then Jump -> Fall/Land -> Locomotion after the FSM returns to Idle, and the body never moves.
- Full suite: `SMOKE SUMMARY: tests=4 passed=63 failed=0`, `RUN.SH: PASSED` (tracer `test_jump_fact` still green).

## Task Commits

1. **Task 1: Rig_Medium clip library builder and Mannequin assets** - `8c9efd4` (feat)
2. **Task 2: Mannequin under VisualRoot driven by the FSM through an AnimationTree** - `86daf6f` (feat)

## Deviations from Plan

None - plan executed exactly as written.

Process notes (not code deviations):
- The worktree HEAD did not contain `d6c3e7b`, so it was reset to it as instructed (no work lost; the tree was clean).
- The seen-node trace in the jump test is `Jump, Fall, Land, Locomotion`: the tree's AT_END Jump -> Fall edge fires at 0.6 s, the same instant the 0.6 s FSM timer returns to Idle, so Fall is sometimes visited for a frame before `travel(Land)`. Land is still reached via the direct Fall -> Land edge. This is expected behaviour of the timer-driven Phase 1 states and revisited when real physics lands (A13).

**Total deviations:** 0. **Impact:** none.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. Copies were verified byte-identical with `cmp` (T-01-04); the builders read and write fixed `res://` paths only and run through the version-gated `run.sh` (T-01-05).

## Issues Encountered

None.

## Next Phase Readiness

Plan 01-03 can add Run, Fall and Dash states; the animator's `STATE_TO_ANIM` map and the tree already contain those targets. The AnimationTree path from Player is `VisualRoot/Mannequin/AnimationTree`. Plan 01-07's asset whitelist matches the produced file names.

## Self-Check: PASSED

- All created files exist on disk; commits `8c9efd4` and `86daf6f` are ancestors of HEAD.
