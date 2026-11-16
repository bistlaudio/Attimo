---
phase: 03-animated-mannequin-aim-mode
plan: 02
subsystem: animation
tags: [godot, animation-library, kaykit, asset-whitelist, root-drift]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 BlendTree root and parameter-path fixtures (test_mannequin_animation migrated)
provides:
  - Rig_Medium_CombatRanged.glb copied byte-identical under the asset whitelist (33 entries) and listed in run.sh ORIGINALS
  - rig_medium_library.res with 13 clips (Ranged_1H_Aiming, strafe left/right, Walking_Backwards, Dodge left/right/backward added)
  - ROOT_PINNED in the library tool: Dodge root position pinned to key 0, root rotation untouched
  - Dodge root decision recorded in docs/CONVENTIONS.md
affects: [03-07, 03-08, 03-09]

actuals:
  tokens: 1400   # chars/4 over the added diff lines in attimo/tools, attimo/tests and docs (5655 chars); binary GLB and library excluded
  tasks: 2
  commits: 2
plan_head_before: 703cd2e52dbb3454f8496c6a46e2fde58969921a
plan_head_after: 4d45252e67179fd0c1c1b444f2af42f9384acaf8
commits: 2

tech-stack:
  added: []
  patterns:
    - "A new kit asset is a deliberate edit of the whitelist, run.sh ORIGINALS and the asset in the same change"
    - "Root-drift removal happens at the source (library tool), not via AnimationTree root motion, which also strips root rotation"

key-files:
  created:
    - attimo/assets/animations/rig_medium/Rig_Medium_CombatRanged.glb
    - attimo/assets/animations/rig_medium/Rig_Medium_CombatRanged.glb.import
  modified:
    - attimo/tools/build_animation_library.gd
    - attimo/assets/animations/rig_medium/rig_medium_library.res
    - attimo/tests/smoke/test_asset_hygiene.gd
    - attimo/tests/smoke/test_animation_library.gd
    - attimo/tests/run.sh
    - docs/CONVENTIONS.md

key-decisions:
  - "Dodge root position is pinned to the first key by the library tool (ROOT_PINNED); root rotation is kept because the strafe clips carry their direction in the root yaw"
  - "Ranged_1H_Aiming is not in LOOPING; 03-07 holds the aim pose with its own timeline"

requirements-completed: []

duration: about 15 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 2: Animation library extension and Dodge root pin Summary

**The animation library now holds all 13 kit clips the phase needs (aim pose, strafes, backward walk, directional dodges), with the four Dodge clips root-pinned so a dash no longer slides the visual by up to 0.65 m.**

## Accomplishments

- `Rig_Medium_CombatRanged.glb` is copied byte-identical (`cmp` exits 0) from the tracked KayKit pack; its `.import` matches the sibling `MovementAdvanced.glb.import` apart from uid and paths, so no extra `[params]` lines were needed. The whitelist is 33 entries and `run.sh` ORIGINALS lists the pack original.
- `tools/build_animation_library.gd` adds the CombatRanged source and six more wanted clips. Strafe left/right and Walking_Backwards loop; Ranged_1H_Aiming and every Dodge clip do not.
- `ROOT_PINNED` (Dodge_Forward, Dodge_Left, Dodge_Right, Dodge_Backward) sets every key of the `Rig_Medium/Skeleton3D:root` position track to key 0; a pinned clip without that track quits 1 with an error. Root rotation and all other bones are untouched.
- `test_animation_library` asserts 13 clips, loop modes, lengths (strafes 0.8 s, Walking_Backwards 1.067 s, Dodges 0.4 s, Ranged_1H_Aiming 1.067 s), pinned keys within 0.001 m of key 0 with a horizontal key 0 length below 0.01 m, and a root yaw between 45 and 75 degrees at half length for both strafes.
- `docs/CONVENTIONS.md` replaces the open "Phase 3 decides" sentence with the decision.
- Verification: tool prints `(13 clips) err=0`; the four named tests pass (166 checks); full suite `RUN.SH: PASSED` (25 tests, 1088 checks, 0 failed).

## Task Commits

1. Task 1 (tracer): Ranged_1H_Aiming through the whitelist into the library - `2b98bd6`. Tracer gate: automated-only verify re-run end to end, passed, expansion continued.
2. Task 2 (TDD, test written first and seen failing on 13 clip checks and the Dodge_Forward drift of 0.25 m): strafe, backward, dodge clips and ROOT_PINNED - `4d45252`

## Deviations from Plan

None - plan executed exactly as written. The strafe yaw check also covers Running_Strafe_Left (the plan named only Right); it passed.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. T-03-03 (byte-identical copy, exact-count whitelist) and T-03-04 (pin limited to four named clips, rotation survival asserted) are mitigated as planned.

## Notes for later plans

- 03-07 replaces the `triangle_anchor` scaffold in the Locomotion BlendSpace2D with the strafe and backward clips, which now exist in the library. `build_mannequin_tree.gd` validates clip names against it.
- The Godot harness again rewrote `attimo/project.godot` and two `*.png.import` files; they were never staged.

## Self-Check: PASSED

Files verified present: Rig_Medium_CombatRanged.glb, its .import, build_animation_library.gd, rig_medium_library.res, test_animation_library.gd. Commits 2b98bd6 and 4d45252 are ancestors of HEAD. Acceptance criteria: ROOT_PINNED count 3 (tool) and 1 (CONVENTIONS), `root_motion_track` count 0 in both files, `Phase 3 decides` count 0, whitelist assertion 33, CombatRanged in run.sh once, Ranged_1H_Aiming in the tool.
