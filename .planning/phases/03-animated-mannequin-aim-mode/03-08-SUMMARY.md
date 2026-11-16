---
phase: 03-animated-mannequin-aim-mode
plan: 08
subsystem: player-animation
tags: [godot, skeleton-modifier, aim-pose, arm-solver, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-07 Aim layer and MannequinAnimator.aim_weight; 03-04 CameraRig with pitch clamps; 03-01 mannequin.tscn layout
provides:
  - AimPoseModifier (SkeletonModifier3D) under Rig_Medium/Skeleton3D, solver for the right arm direction run after the AnimationMixer
  - set_aim_point(), static rotation_between() (opposite-vector safe), exports spine_share, max_twist_deg, converge_distance, records last_error_deg, last_twist_deg, last_target_dir
  - MannequinAnimator feed: modifier influence = aim_weight, aim point = camera origin + camera forward * converge_distance
  - test_aim_pose (51 checks)
affects: [03-09]

actuals:
  tokens: 4500   # chars/4 over the added diff lines (17894 chars): modifier, scene node, animator feed, test
  tasks: 2
  commits: 2
plan_head_before: b44a7a83fffa498cf5ae120a17598ef497e26a5a
plan_head_after: d7d518a50e98240d05d7fc8aa13882b69f01f2d5
commits: 2

tech-stack:
  added: []
  patterns:
    - "Solver runs in skeleton space with quaternion math: new_local = parent_q.inverse * R * parent_q * local; the aim direction is recomputed from the current shoulder after every bone write"
    - "Torso budget: spine takes spine_share of min(needed, max_twist), chest the rest of the budget, upperarm.r the remainder"
    - "Tests assert on values the modifier records (last_error_deg, last_twist_deg, last_target_dir), never on bones read from outside (Pitfall 11)"

key-files:
  created:
    - attimo/scripts/player/aim_pose_modifier.gd
    - attimo/scripts/player/aim_pose_modifier.gd.uid
    - attimo/tests/smoke/test_aim_pose.gd
    - attimo/tests/smoke/test_aim_pose.gd.uid
  modified:
    - attimo/scenes/player/mannequin.tscn
    - attimo/scripts/player/mannequin_animator.gd

key-decisions:
  - "The shoulder-to-target direction is re-read after the spine and chest writes (the shoulder moves with the torso); the last step rotates upperarm.r about the shoulder, so the residual is exactly closed and last_error_deg measures 0.000 in every tested case"
  - "last_twist_deg is the sum of the spine and chest rotation angles; the chest limit is budget minus the spine angle, so the sum never exceeds max_twist_deg"
  - "The modifier node sits at index 0 under Skeleton3D in mannequin.tscn with influence 0.0; no player.tscn change, the animator resolves it by relative path"

requirements-completed: []

duration: about 25 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 8: AimPoseModifier arm solver Summary

**While aiming, a SkeletonModifier3D rotates spine, chest and (for any remainder) the right upper arm so the shoulder-to-hand direction points at the camera convergence point 15 m ahead, faded by the animator's aim weight, with the torso twist clamped at 70 degrees.**

CAM-02 is listed in the plan frontmatter but is deliberately not marked complete: the orchestrator marks MOVE-09, CAM-02 and MOVE-11 at phase end.

## Accomplishments

- **Tracer (Task 1):** `aim_pose_modifier.gd` (`class_name AimPoseModifier`, typed) with `_process_modification_with_delta`, `set_aim_point()`, the three exports and the three records; node added to `mannequin.tscn` (influence 0.0); `MannequinAnimator` resolves it once in `_ready` (`AIM_MODIFIER_PATH`, a missing node disables the feed) and `_feed_aim_modifier()` sets `influence = aim_weight` and the aim point every `_process`. Idle arm error measured 0.26 degrees with the torso-only solver (shoulder shift), the tracer gate re-ran the automated verify and passed before Task 2.
- **Upper-arm residual (Task 2):** after the chest the solver re-reads the arm and rotates `upperarm.r` by `rotation_between(arm, want)`. Measured with the real rig, arm error 0.000 degrees in every case.
- **Measured torso twist (max_twist_deg 70):** idle 47.3, run forward 53.8, strafe left 9.7, strafe right 70.0 (clamp active, upper arm takes about 44 degrees of the roughly 114 needed), walking backwards 52.2, idle at pitch_min 65.2, at pitch_max 63.9. An aim point directly behind the character gives twist 70.0 and error 0.000. With `max_twist_deg` 0 the twist is 0.0 and the arm still reaches the target through the upper arm alone.
- **Guards (T-03-12):** `rotation_between` rotates PI about a perpendicular axis for dot below -0.9999 (checked for +Z/-Z, UP/DOWN, RIGHT/LEFT and a skew pair, all within 0.0001 degrees), returns the identity for equal or zero-length inputs; a near-zero shoulder-to-target length skips the frame; `set_aim_point` ignores non-finite points; no non-finite quaternion is written.
- **test_aim_pose:** 51 PASS checks (plan asks for at least 12).

## Task Commits

1. **Task 1 (tracer): AimPoseModifier, scene node, animator feed, idle test** - `f5a46e9` (feat)
2. **Task 2: upper-arm residual, twist clamp, locomotion, pitch and guard tests** - `d7d518a` (feat)

## Verification

- Task 1: `test_aim_pose,test_aim_layer,test_mannequin_animation`: 109 checks, `failed=0`.
- Task 2 / plan end: full suite `bash attimo/tests/run.sh`: 32 tests, 1410 checks, `failed=0`, `RUN.SH: PASSED`. The log ends with the engine's exit-time notes (`3 ObjectDB instances were leaked`, `1 resources still in use`), unchanged from 03-07.
- Acceptance greps: `class_name AimPoseModifier` 1, `_process_modification_with_delta` 1, `aim_pose_modifier.gd` in mannequin.tscn 1, `set_aim_point(` in the animator 1, `static func rotation_between` 1, `upperarm.r` in the modifier at least 2.

## Deviations from Plan

None - plan executed exactly as written.

Notes, not deviations:
- The modifier is built on quaternion math (parent rotation quaternion) instead of Basis; it is the same formula as the research solver.
- The shoulder-to-target direction is recomputed after each bone write, which the plan's text implies ("re-read the arm") but does not spell out for the target; it is what takes the error from 0.26 to 0.000 degrees.
- `test_aim_pose` freezes the animator feed (`set_process(false)`) in the "behind" scenario to place the aim point by hand; the other scenarios use the real camera feed.

## Judgement left for the 03-09 gym check

- A-08-1: how the torso looks at 47-70 degrees of twist. The solver reaches the target in every case, but whether the pose reads well is a human judgement, strafe right first (twist at the 70 clamp, upper arm about 44 degrees on top) and low pitch (65 degrees). Fallbacks from research Open Question 1: raise `spine_share`, lower `max_twist_deg` (arm then carries more), arms-only, or reduce the strafe blend in aim. The numbers are exports on the node (A-08-2), editable in the inspector at runtime.
- Whether the arm should point at the camera convergence point (15 m) or at the ray hit is Phase 4 (`set_aim_point()` is the seam).
- Head and left arm are not corrected: they follow the spine and chest twist, so the left arm and head turn with the torso. Check this in the gym.

## Known Stubs

None.

## Threat Flags

None. T-03-12 is mitigated as planned (opposite vectors, near-zero length, non-finite quaternions and points), asserted by `test_aim_pose`.

## Issues Encountered

None. The unrelated working-tree changes (project.godot, two .png.import files, .planning/state.json) were left unstaged.

## Next

Ready for 03-09.

## Self-Check: PASSED

- Files exist: aim_pose_modifier.gd, test_aim_pose.gd, updated mannequin.tscn and mannequin_animator.gd.
- Commits `f5a46e9` and `d7d518a` are on `dev`.
