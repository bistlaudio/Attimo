---
phase: 03-animated-mannequin-aim-mode
plan: 07
subsystem: player-animation
tags: [godot, animation-tree, aim-layer, blendspace2d, strafe, time-scale, dodge, movement-config, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 BlendTree root and MannequinAnimator; 03-02 library with Ranged_1H_Aiming, strafe, backward and Dodge clips; 03-03 PlayerController.aiming, ground_target_speed(), last_dash_direction; 03-06 Pose group and metrics; 03-10 air-dash hold and timing guard
provides:
  - Filtered Aim layer (Blend2 + AimClip hold from 0.6 s, no loop) on the upper body, weight eased over aim_layer_blend_time (MannequinAnimator.P_AIM, aim_weight)
  - Locomotion BlendSpace2D with strafe_l, strafe_r and back points (scaffold triangle_anchor removed); aim-aware blend target in the facing frame
  - clip_scale(): Running_A speed follows ground speed, ground dash plays its Dodge clip in exactly dash_time, air dash and its hold play at 1x
  - Directional aim dashes DashLeft, DashRight, DashBack with dash_node_for(); every dash node counts for clip_scale and the DEV-02 hold
  - MovementConfig "Clip playback" group (5 sliders: run_anim_ref_speed, run_anim_max_scale, aim_layer_blend_time, locomotion_blend_rate, air_dash_hold_time)
  - test_aim_layer (78 checks)
affects: [03-08, 03-09]

actuals:
  tokens: 10700   # chars/4 over the added diff lines (42982 chars): tree tool, animator, config, test, metrics doc
  tasks: 3
  commits: 3
plan_head_before: 8dad8ffe886c4a8a81f24b2804e2e1de1d103116
plan_head_after: 4d70e8bb6a9e9978f746d4155f48b37e2b5c4200
commits: 3

tech-stack:
  added: []
  patterns:
    - "Aim layer = Blend2 with bone filter after the Land overlay; one non-looping AimClip with a custom timeline holds the pose"
    - "One BlendSpace2D for both modes: outside aim x is forced to 0, in aim the velocity in the facing frame divided by ground_target_speed"
    - "One state-machine node per Dodge clip (DASH_CLIPS), chosen by dash_node_for() on the state-change call; clip lengths read once from the AnimationPlayer"
    - "Test recorder connected after the animator's handler captures last_travel, last_travel_frame, holding and the written TimeScale inside each state_changed call"

key-files:
  created:
    - attimo/tests/smoke/test_aim_layer.gd
    - attimo/tests/smoke/test_aim_layer.gd.uid
  modified:
    - attimo/tools/build_mannequin_tree.gd
    - attimo/scenes/player/mannequin_tree.tres
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/scripts/player/movement_config.gd
    - docs/MOVEMENT-METRICS.md

key-decisions:
  - "Dash lengths are read per dash node (DASH_CLIPS) instead of once from Dodge_Forward, so the scale stays exact if a Dodge clip is ever re-cut; all four are 0.4 s today, so the plan's numbers hold"
  - "The strafe blend divisor is ground_target_speed of the flat velocity direction (clamped to 0.01), so the slower aim run and back-pedal still reach the full run and backward clips"
  - "handslot bones are kept in the Aim filter as the plan lists them; the build and the test runs print no warning for the missing bones (A-07-2 did not trigger)"

requirements-completed: []

duration: about 40 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 7: Aim layer, strafe legs, clip speeds and aimed dashes Summary

**While aiming, the Mannequin's spine, chest, head and arms hold the Ranged_1H_Aiming pose through a filtered Blend2 layer (0.15 s blend) while the legs strafe and walk backwards through one BlendSpace2D, Running_A and the Dodge clips play at speeds that match the movement numbers, and aimed dashes pick Dodge_Left, Dodge_Right or Dodge_Backward by direction.**

MOVE-09 and CAM-02 are listed in the plan frontmatter but are deliberately not marked complete: the orchestrator marks MOVE-09, CAM-02 and MOVE-11 at phase end.

## Accomplishments

- **Aim layer (Task 1, tracer):** `build_mannequin_tree.gd` adds `Aim` (Blend2, `filter_enabled`, the 13 upper-body paths from `UPPER_BONES`, never hips or root) and `AimClip` (Ranged_1H_Aiming, custom timeline start 0.6 s, length 0.4 s, `LOOP_NONE`). `MannequinAnimator` gets `P_AIM`, `aim_weight` (eased at `delta / aim_layer_blend_time`) and writes the weight every `_process`. Measured: weight reaches 1.0 in 9 frames (0.15 s); `upperarm.r` is 0.19 degrees from the clip at 0.6 s after ten manual advances; hips, root and both upper legs are not filtered.
- **MovementConfig Clip playback group:** `run_anim_ref_speed` 4.5, `run_anim_max_scale` 2.5, `aim_layer_blend_time` 0.15, `locomotion_blend_rate` 10, `air_dash_hold_time` 0.35; header now says eleven groups, 49 sliders; `docs/MOVEMENT-METRICS.md` regenerated. `LOCO_BLEND_RATE` and `AIR_DASH_HOLD_TIME` are gone from the animator (`air_dash_hold_time()` returns the config value); the DEV-02 hold logic is untouched and `test_animation_timing` still passes on the config value.
- **Strafe and back (Task 2):** `triangle_anchor` replaced by `strafe_l (-1,0)`, `strafe_r (1,0)`, `back (0,-1)`. In aim the blend target is `Vector2(-local.x, local.z) / ground_target_speed(velocity direction)` in the facing frame, clamped to the unit square; outside aim it is `Vector2(0, speed / run_speed)` as before, so x is exactly 0 (measured). Strafe right reaches x 0.89 inside the test window and turns the root bone by -60 degrees; left, back and forward reach the full blend although the aim run is slower than `run_speed`.
- **Clip scale:** `clip_scale()` returns clampf(speed / run_anim_ref_speed, 1, run_anim_max_scale) in Locomotion (1.89 at full run speed, 1.0 idle), Dodge length / dash_time (2.222) for a ground dash on the entry frame, 1.0 for an air dash on the entry frame and on every frame of the DEV-02 hold, and 1.0 for a non-finite result. It is written on the state-change call and every `_process`.
- **Directional dashes (Task 3):** `DashLeft`, `DashRight`, `DashBack` with one direct edge per ordered pair. `dash_node_for(direction)` returns `Dash` outside aim or for a near-zero direction, otherwise the dominant axis in the facing frame (+Z Dash, -Z DashBack, +X DashLeft, -X DashRight). Measured: all five aimed cases and the unaimed `move_right` case pick the expected node with `last_travel_frame` equal to the state-change frame, the visible node follows within 2 process frames, and an aimed air dash with `move_right` holds DashRight past the Dash exit and travels to Locomotion on the landing frame.
- **test_aim_layer:** 78 PASS checks over 9 scenarios (aim layer, strafe/back, unaimed axis, run scale, dash scale, six aimed dash cases, directional air-dash hold).

## Task Commits

1. **Task 1 (tracer): upper-body Aim layer, Clip playback config group** - `e5ac725` (feat). Tracer gate: automated-only `<verify>` re-run end to end and passed before Task 2 started.
2. **Task 2: strafe and backward blend points, run and dash clip time scale** - `4d50526` (feat)
3. **Task 3: directional aim dashes** - `4d70e8b` (feat)

## Verification

- Task 1: `build_mannequin_tree` (`TREE: SAVED`), `measure_movement` (`MEASURE: PASSED`), `test_aim_layer,test_mannequin_animation,test_animation_timing,test_movement_metrics` (plus `test_tuning_panel,test_feedback_guard`): 216 checks, `failed=0`.
- Task 2: `test_aim_layer,test_mannequin_animation,test_movement_facts,test_dash,test_animation_timing`: 186 checks, `failed=0`.
- Task 3 and plan end: full suite `bash attimo/tests/run.sh`: 31 tests, 1359 checks, `failed=0`, `RUN.SH: PASSED`. The log ends with the engine's exit-time notes (`3 ObjectDB instances were leaked`, `1 resources still in use`), which the run.sh error grep does not match.
- Acceptance greps: `Ranged_1H_Aiming`, `AnimationNodeBlend2`, `Running_Strafe_Right`, `Walking_Backwards`, `Dodge_Backward` in the tree are each at least 1; `parameters/Aim/blend_amount` in the animator 1; `AIR_DASH_HOLD_TIME` 0; `func clip_scale` 1; `func dash_node_for` 1; `var aim_layer_blend_time` and `var air_dash_hold_time` 1 each; `P_AIM` in the test; 78 PASS lines in `test_aim_layer` (plan asks for at least 14).

## Deviations from Plan

None - plan executed exactly as written.

Notes, not deviations:
- The test waits two physics frames before building the camera rig (the rig reads global transforms when it snaps and the first frame of the runner is not yet inside a started tree); without it the rig printed engine errors that run.sh does not match but that are noise.
- Per-dash-node clip lengths (`DASH_CLIPS`) go one step beyond "read once from Dodge_Forward"; behaviour is identical for the current clips.
- The plan commit ledger (`gsd-plan-head-before-03-07`) was written before the first task commit; `commits: 3` is measured.

## Judgement left for 03-09 (gym check)

- A-07-1: whether the aimed Dodge_Left/Right/Backward clips look right is a gym judgement; the fallback is `return &"Dash"` in `dash_node_for` (one function).
- A-07-3: diagonal back-left and back-right mixes a 1.067 s and a 0.8 s cycle under CYCLIC_MUTABLE sync; not changed here.
- The whole state machine plays at the run scale in Locomotion, including the aim strafe and backward clips (aim run speed 6.4 m/s gives about 1.42x). Judge in the gym whether strafe and back should have their own reference speeds.
- Until 03-08 lands the `AimPoseModifier`, the arm direction is the raw aim clip: the research measured up to 114 degrees of arm error for strafe right without it.

## Known Stubs

None.

## Threat Flags

None. T-03-11 is mitigated as planned: every divisor read by the animator is clamped (`run_anim_ref_speed`, `dash_time` to 0.001, `aim_layer_blend_time` to 0.001, blend divisor to 0.01), the Clip playback sliders have strictly positive minimums, non-finite scales return 1.0, and `test_aim_layer` asserts a zero reference speed still gives a finite scale inside the band.

## Issues Encountered

None. The unrelated working-tree changes (project.godot, two .png.import files, .planning/state.json) were left unstaged.

## Next

Ready for 03-08.

## Self-Check: PASSED

- Files exist: test_aim_layer.gd, regenerated mannequin_tree.tres, updated build_mannequin_tree.gd, mannequin_animator.gd, movement_config.gd, MOVEMENT-METRICS.md.
- Commits `e5ac725`, `4d50526` and `4d70e8b` are on `dev`.
