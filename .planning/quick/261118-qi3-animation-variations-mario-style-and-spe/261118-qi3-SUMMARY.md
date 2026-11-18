---
phase: quick-261118-qi3
plan: 01
subsystem: animation
tags: [godot, animation-tree, retarget, ual, variant-picker, idle-break, landing, sprint-blend]
status: complete
requires:
  - quick 261118-qbt retarget pipeline (clip_retargeter.gd ual family, conform_external_clip.gd, RETARGETED table)
provides:
  - headless bone-sanity gate test_retarget_sanity (S1-S7) and the UAL_DROPPED drop rule
  - VariantPicker (reusable, no globals)
  - idle breaks, sprint blend, Jump2 and LongJump takes, soft/hard/roll landing overlay
  - spell hand aim-layer structure (Enter/Hold/Exit + Shoot OneShot) on the Ranged_1H_Aiming fallback
  - reserved hit/death/interact pools (pick_reaction)
affects: [phase 4 hand and hit/death states, phase 5 push, phase 6 interact]
tech-stack:
  added: []
  patterns:
    - "UAL clip -> conform -> retarget -> sanity gate -> keep or drop to UAL_DROPPED, tree builds FALLBACK"
    - "presentation variants through VariantPicker pools filtered to the library"
key-files:
  created:
    - attimo/scripts/player/variant_picker.gd
    - attimo/tests/smoke/test_retarget_sanity.gd
    - attimo/tests/smoke/test_variant_picker.gd
    - attimo/tests/smoke/test_clip_variants.gd
    - attimo/assets/animations/external/ual/ (idle_loop, sprint_loop, hit_chest, hit_head, death01 .scn)
  modified:
    - attimo/tools/conform_external_clip.gd
    - attimo/tools/build_animation_library.gd
    - attimo/tools/build_mannequin_tree.gd
    - attimo/assets/animations/rig_medium/rig_medium_library.res
    - attimo/scenes/player/mannequin_tree.tres
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/scripts/player/movement_config.gd
    - attimo/tests/run.sh
    - attimo/tests/smoke/test_aim_layer.gd
    - attimo/tests/smoke/test_animation_library.gd
    - attimo/tests/smoke/test_asset_hygiene.gd
    - attimo/tests/smoke/test_animation_map.gd
    - docs/ANIMATION-MAP.md
    - docs/MOVEMENT-METRICS.md
decisions:
  - "The four UAL Spell_Simple clips are dropped: the source is a left-handed cast that twists the chest 57 deg away from the right (prosthetic) arm; the aim layer keeps the Enter/Hold/Exit/Shoot structure on the Ranged_1H_Aiming fallback"
  - "Exit fallback is a 0.1 s hold, the layer fade lowers the arm (PLAY_MODE_BACKWARD with a custom timeline froze at the window end on 4.7.2)"
  - "Gate gained S7 (hips, chest, head above the floor): the feet-only retarget floor rule pushed the inverted Roll body through the floor"
  - "hard_landing_speed 24 m/s (plan 20): the orchestrator's 4.0 m Jump 3 lands at about 21 m/s and must not read as a hard landing"
  - "Jump 2 stays on Jump_Full_Short although its takeoff differs from Jump_Start by at most 5.4 deg; UAL Jump_Start (the documented alternative) failed S4"
metrics:
  estimate_tokens: 190000
  tasks: 3
completed: 2026-11-18
commits: 9
plan_head_before: 11fe6cc3a08fe5d5b4029172c95d2c3ba5bd2fb5
plan_head_after: fe559fea474b15d5a67525d583c0444d401e8c8c
actuals:
  tokens: 52000
  tasks: 3
  commits: 9
---

# Phase quick-261118-qi3 Plan 01: Animation variations and spell hand layer Summary

The Mannequin now has idle breaks (5-8 s, never repeating, cancelled on the same frame), a sprint blend toward UAL Sprint_Loop above run speed, its own Jump 2 and long jump takes, and soft/hard/roll landing overlays. All of it runs through a reusable VariantPicker. Every UAL clip passes a headless bone-sanity gate or is dropped with its reason. The aim layer has the spell hand structure (Enter, Hold, Exit, Shoot), but it plays the KayKit Ranged_1H_Aiming fallback because the UAL Spell clips are left-handed.

## Gate

QBT_GATE_OK: the qbt pipeline (feat commits, clip_retargeter.gd, conform_external_clip.gd, RETARGETED) was committed before this run started. The resumed executor found Task 1 mostly done in the working tree; generated files were regenerated with the tools, not hand-merged.

## Commits

`commits: 9` is measured over `11fe6cc..HEAD`. It includes 4 orchestrator commits on dev in the same window (17cfdc1 camera zoom, 41d8625 aim torso yaw-only, f852297 slide presentation off, 9689831 tuning). The 6 qi3 commits:

| Task | Commit | What |
|---|---|---|
| 1 | `d2a225a` | UAL pack tracked, 5 UAL clips + 8 KayKit clips in the library, bone-sanity gate, spell hand layer structure, orchestrator slide edits in the shared files |
| 2 RED | `cf08b16` | test_variant_picker (P1-P6), test_clip_variants (I1-I3, R1) |
| 2 GREEN | `a9544cf` | VariantPicker, IdleBreak/IdleBreakPick, idle break logic, reaction pools |
| 3 RED | `2812386` | S1/S2, J1/J2, L1/L2 in test_clip_variants, M1 in test_animation_map |
| 3 GREEN | `fe559fe` | sprint blend, Jump2/LongJump nodes, LandPick soft/hard/roll, config fields, docs |

Note: the two Task 2 MovementConfig fields (`idle_break_delay_min/max`) and their MOVEMENT-METRICS rows were swept into the orchestrator's 9689831 (whole-file staging). HEAD is consistent.

## Dropped clips (UAL_DROPPED, with reasons)

| Clip | Check | Measured | Fallback |
|---|---|---|---|
| `UAL_Push_Loop` | S3 arm clearance | 0.241 m (limit 0.266) | none (Phase 5) |
| `UAL_Jump_Land` | S4 hips height | 41 % of rest (limit 60 %) | `Jump_Land` (hard landing) |
| `UAL_Interact` | S3 arm clearance | 0.263 m (limit 0.266) | KayKit `Interact` |
| `UAL_Roll` | S7 (new) body below floor | head -0.27 m, hips -0.09 m at 0.70-0.80 s | `Jump_Land` (roll landing) |
| `UAL_Spell_Simple_Enter/Idle_Loop/Shoot/Exit` | presentation review | left-handed source (`hand_l` 0.72 m in front of `spine_03`), chest twisted -57 deg (KayKit aim +36 deg); test_aim_pose (z) torso twist 0.079 failed with them | `Ranged_1H_Aiming` |
| `UAL_Jump_Start` (extra, tried as the Jump 2 alternative) | S4 hips height | 49 % of rest | Jump 2 stays `Jump_Full_Short` |

Kept and gated: `UAL_Idle_Loop`, `UAL_Sprint_Loop`, `UAL_Hit_Chest`, `UAL_Hit_Head`, `UAL_Death01`. The library has 27 clips (14 + 8 KayKit + 5 UAL). The native baselines: clearance minimum 0.316 m, foot minimum 0.060 m.

## Measured windows

- **Jump2** (`Jump_Full_Short`): start 0.25 s, length 0.25 s. Crouch bottom 0.274 m at 0.267 s, apex pose 0.506 m from 0.400 to 0.500 s, landing crouch from 0.533 s. Its takeoff differs from `Jump_Start` by at most 5.4 deg on any bone (upperarm.l).
- **LongJump** (`Jump_Full_Long`): start 0.25 s, length 1.4167 s. Same takeoff (0.1 deg from Jump_Start), then an airborne leg tuck (up to 29.8 deg from Jump_Idle on lowerleg.l) until 1.667 s, landing crouch from 1.700 s.
- Landing variants: soft = Jump_Land in 0.3 s, hard = Jump_Land in 0.5 s, roll = Jump_Land in 0.6 s (both UAL sources dropped).
- Measured landing speeds (L2): hop into Idle 9.4 m/s impact; 30 m drop 40 m/s (terminal); stage 1 long jump 14.0 m/s horizontal.

## FALLBACKs used by the tree tool

`TREE: fallback` lines: UAL_Spell_Simple_Enter, _Idle_Loop, _Shoot, _Exit -> Ranged_1H_Aiming; UAL_Jump_Land -> Jump_Land; UAL_Roll -> Jump_Land.

## Tests

- Task suites: test_variant_picker, test_clip_variants (76 checks), test_retarget_sanity, test_animation_library, test_aim_layer, test_animation_map, test_asset_hygiene are all green.
- Full suite after the Task 2 commit: `RUN.SH: PASSED`, 38 tests, 1732 checks.
- Full suite before the Task 3 commit: 38 tests, 1816 passed, 2 failed. `test_aim_mode (f)` passed on re-run. `test_aim_target (t5) the crosshair ray hits the wall` follows the orchestrator's uncommitted `camera_rig.gd` `pivot_height` 1.4 -> 1.2 edit; it is not caused by this plan's files, which do not touch the camera. **The final RUN.SH: PASSED could not be confirmed while that camera edit is in the working tree.**

## Deviations from Plan

### Developer-feedback and orchestrator-applied changes

**1. [Orchestrator-applied fix] Slide: slower, crossfades, hold, then dormant.** The orchestrator applied these to shared files and they were committed with Task 1 (`d2a225a`): SLIDE_DROP_LENGTH metadata, Slide xfades 0.1 s in and 0.15 s out, slide hold 0.3 s, SLIDE_PLAYBACK_SCALE 1.6, and `UNAIMED_DASH` in test_aim_layer. Afterwards the developer dropped the slide look (`Dash.SLIDE_PRESENTATION` false, f852297). The map documents the ground dash as Dodge_Forward plus lean, with Slide dormant.

**2. [Developer feedback, "the aim pose looks weird"] Spell clips dropped, Ranged_1H_Aiming fallback.** The bow was the solver (fixed by the orchestrator in 41d8625), but the probe showed an independent clip problem: a left-handed cast with the chest twisted away from the right arm. Enter, Exit and Shoot share that twist, so none of them could be kept against a right-handed hold. The structure stays, so a right-handed spell set later only needs library and tree-tool changes.

### Auto-fixed issues

**3. [Rule 2] Gate S7 added.** S1-S6 exempt Roll from the floor checks, but its retarget sank the head 0.27 m into the floor. S7 checks hips, chest and head against the floor on every clip. Commit `d2a225a`.

**4. [Rule 1] Exit fallback.** A backwards raise froze at the window end on 4.7.2 (measured: play position advanced, pose stayed at the hold to within 0.1 deg). Exit now plays a 0.1 s hold and the layer fade lowers the arm. Commit `d2a225a`.

**5. [Rule 1] Idle break cancel overwritten.** The OneShot reports `active` while it fades, so the next tick re-requested FADE_OUT. A `_idle_break_fading` flag fixes it. Commit `a9544cf`.

**6. [Rule 1] hard_landing_speed 24 instead of 20.** With the new 4.0 m Jump 3 (about 21 m/s impact), 20 would have made every Jump 3 landing hard. Commit `fe559fe`.

**7. [Rule 3, test] J1 runs the chain with move held.** Standing jumps reset the combo (`combo_reset_speed`). Commit `fe559fe`.

**8. Extra clip tried.** UAL Jump_Start (the plan's documented Jump 2 alternative) was tried because Jump_Full_Short is nearly identical to Jump 1. It failed S4 and is recorded in UAL_DROPPED; the gate's total became 14.

## Known Stubs

- `Shoot` (use_hand while aiming) plays the static Ranged hold window, so it shows no motion until Phase 4 or a right-handed spell clip (documented in the map).
- Hard and roll landings are Jump_Land at a different timing (both UAL sources dropped), so they differ from soft only in timing.
- Hit, death and interact pools are library and picker only (planned, Phase 4/6).

## Threat Flags

None. Only tool-time file writes at fixed paths and a CC0 pack in the reference library (T-qi3-01 mitigated through the whitelist and the ORIGINALS check).

## Developer gym check list

1. Hold RMB: the arm rises (Ranged raise), holds on the crosshair, and lowers via the fade on release. LMB while aiming shows nothing extra yet. Decide whether a right-handed spell clip is wanted.
2. Stand still for 5-8 s: Idle_B or UAL_Idle_Loop plays and never repeats; any key cancels it at once.
3. Run, then dash: right after the dash the run blends toward UAL_Sprint_Loop, then back. Watch for foot sliding.
4. Jump chain: is Jump 2 visibly different from Jump 1? It probably is not (5.4 deg). If not, decide on another Jump 2 take.
5. Long jump: Jump_Full_Long takes off without a wind-up and tucks the legs until the apex.
6. Landings: hop (soft), long jump at full speed (roll, timing only), drop from about 5 m or more (hard). A jump or dash right after a landing must never wait.

## Self-Check: PASSED

- Files found: attimo/scripts/player/variant_picker.gd, attimo/tests/smoke/test_retarget_sanity.gd, test_variant_picker.gd, test_clip_variants.gd, attimo/assets/animations/external/ual/*.scn (5).
- Commits found: d2a225a, cf08b16, a9544cf, 2812386, fe559fe.
- Not staged or committed by this executor: attimo/project.godot, the two .png.import files, .gsd/, the orchestrator's camera_rig.gd and mannequin.tscn edits.
