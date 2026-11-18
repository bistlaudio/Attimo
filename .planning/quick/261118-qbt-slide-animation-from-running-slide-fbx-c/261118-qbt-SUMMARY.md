---
phase: quick-261118-qbt
plan: 01
subsystem: animation, camera, aim
tags: [godot, retarget, mixamo, animation-tree, camera, crosshair, aim]
status: complete
requires:
  - phase 3 animated Mannequin (AnimationTree, ProceduralPose, AimPoseModifier)
  - phase 2 CameraRig
provides:
  - generic clip retarget path (conform + BoneMap/SkeletonProfileHumanoid retargeter, families mixamo, ual, rig_medium)
  - Running_Slide clip on Rig_Medium and the Slide tree node (unaimed ground dash presentation)
  - Dash.slide presentation hint
  - retuned CameraRig (closer, lower-third, lag clamps, vertical lock)
  - CameraRig.aim_target_point() / aim_direction_from() / aim_ray_start(), PlayerController.camera_rig()
affects: [phase 4 hand beam, later UAL clips (qi3), phase 11 camera kick]
tech-stack:
  added: []
  patterns:
    - "headless conform step: raw FBX/GLB -> mesh-free .scn (Skeleton3D + AnimationPlayer only)"
    - "character-space direction retarget with swing correction and floor-contact hips"
key-files:
  created:
    - attimo/tools/conform_external_clip.gd
    - attimo/tools/clip_retargeter.gd
    - attimo/assets/animations/external/mixamo/running_slide.scn
    - attimo/tests/smoke/test_retarget.gd
    - attimo/tests/smoke/test_aim_target.gd
  modified:
    - attimo/tools/build_animation_library.gd
    - attimo/tools/build_mannequin_tree.gd
    - attimo/assets/animations/rig_medium/rig_medium_library.res
    - attimo/scenes/player/mannequin_tree.tres
    - attimo/scripts/player/states/dash.gd
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/scripts/player/procedural_pose.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/aim_pose_modifier.gd
    - attimo/scripts/camera/camera_rig.gd
    - attimo/scenes/camera/camera_rig.tscn
    - docs/ANIMATION-MAP.md
    - docs/CONVENTIONS.md
    - README.md
    - .gitignore
decisions:
  - "Slide is presentation of the existing Dash state (Dash.slide), no new FSM state; aimed dashes and the air dash are unchanged"
  - "No procedural lean during the slide (it would push the lead foot into the floor); the lean stays on the aimed ground dash"
  - "Retarget baked in code through BoneMap on SkeletonProfileHumanoid, not importer retarget options"
  - "Raw Mixamo FBX is not committed (user decision, option A); only the conformed mesh-free .scn is tracked"
  - "Camera vertical goal is the anchor in every state; the D-15 airborne hold band is removed (DEV-05)"
  - "Crosshair aim target is a query on CameraRig, not an EventBus fact"
metrics:
  estimate_tokens: 130000
  tasks: 3
completed: 2026-11-18
commits: 3
plan_head_before: dc34173db365e6b02371b9ad80eb4529c7c410cf
plan_head_after: 0624af231f8b2454226058c4d2e3c44f5dba1328
actuals:
  tokens: 26000
  tasks: 3
  commits: 3
---

# Phase quick-261118-qbt Plan 01: Slide, camera retune and crosshair aim Summary

The unaimed ground dash now plays a Mixamo "Running Slide" retargeted onto the Mannequin through a documented, generic BoneMap/SkeletonProfileHumanoid pipeline (UAL-ready), the follow camera sits closer with a tight horizontal and vertical lock, and the aimed arm points at the world point under the screen-centre crosshair via reusable `CameraRig` accessors.

## Tasks and commits

| Task | Commit | What |
|---|---|---|
| 1 Slide + retarget pipeline | `be2a6ae` | conform tool, retargeter, Running_Slide in the library (14 clips), `Slide` tree node, `Dash.slide` hint, tests and docs |
| 2 Camera | `6b4b5c8` | arm 3.6 m, pivot 1.4 m, pitch -0.22 (max 0.75), FOV 78, follow 22/12, `max_follow_lag` 0.6, `max_vertical_lag` 0.35, hold band removed |
| 3 Crosshair aim | `0624af2` | `aim_target_point()`, `aim_direction_from()`, `aim_ray_start()`, `camera_rig()`, animator feed, `test_aim_target` |

Tests: full suite `bash attimo/tests/run.sh` ends with `RUN.SH: PASSED`, 35 test files, 1563 checks, 0 failed (pinned Godot 4.7.2). New: `test_retarget` (37 checks), `test_aim_target` (16), extended `test_camera_rig` (56).

## Measurements

- **Slide window** (baked clip, hips height share of rest): SLIDE_START = 0.0667 s (1.019 of rest), minimum 0.300 s (0.480, drop 0.54), window end 0.400 s (0.596 of rest, below 80 %). SLIDE_LENGTH = 0.3333 s, played in `dash_time` 0.18 s: playback scale 1.85 (limit 4). Full clip 1.533 s.
- **Mixamo bone names as Godot imported them** (FBXDocument): `mixamorig_Hips`, `mixamorig_Spine`, `mixamorig_Spine1`, `mixamorig_Spine2`, `mixamorig_Neck`, `mixamorig_Head`, `mixamorig_LeftShoulder`, `mixamorig_LeftArm`, `mixamorig_LeftForeArm`, `mixamorig_LeftHand`, `mixamorig_LeftUpLeg`, `mixamorig_LeftLeg`, `mixamorig_LeftFoot`, `mixamorig_LeftToeBase` (and `Right*`, fingers, `HeadTop_End`, `mixamorig_*Toe_End`). The `:` became `_`; the 65-bone skeleton has no `Hips_skin`. The importer also yields an empty `Take 001` (0 tracks); the real take is `mixamo_com` (52 tracks, 1.533 s, 47 keys at 30 Hz). The clip moves the hips 6.7 m in Z, so the retarget pins hips x/z.
- **Shoulder height and pivot**: Mannequin `upperarm.r` rest joint is at 1.107 m (not about 1.8 m; the 2.2 m height is the large head, 1.10 to 2.20 m, the body ends at 1.24 m). Final `pivot_height` = 1.4 m. At spawn: shoulder ndc -0.10, head top 0.28, feet -0.42.
- **Retarget quality**: round trip Idle_A rotation error 0.237 deg (limit 0.5); limb direction parity 0.000 deg over 47 keys (limit 2); hips x/z error 0.0000 m; deepest hips 0.195 m = 48 % of rest (limit 80 %); worst foot/toes sink 0.032 m (limit 0.041 m).
- **Camera lock**: jump rig rise 1.90 m, vertical lag 0.350 (clamp), long jump horizontal lag 0.589, dash (22 m/s) horizontal lag 0.600 (clamp); head and feet stay inside ndc -0.52 .. 0.41.

## Deviations from Plan

### User decision

**1. [User decision, option A] Raw Mixamo FBX is not committed**
- Instruction from the coordinator (repo is public for now): `KayKit/Mixamo/Running Slide.fbx` stays local; `KayKit/Mixamo/*.fbx` is in the repo-root `.gitignore` (Task 1 commit). Nothing in `run.sh`, `ORIGINALS` or tests expects the raw FBX to be tracked. The conformed mesh-free `running_slide.scn` is committed as planned. A fresh checkout runs everything except `tools/conform_external_clip.gd`, which needs the local raw file (stated in `docs/ANIMATION-MAP.md` and README).
- This also closes the planned licensing flag (T-qbt-04): the raw FBX with the Mixamo Beta mesh never enters git history. The conformed .scn holds skeleton and clip only; the README credits Mixamo and states the terms.

### Auto-fixed Issues

**2. [Rule 1 - Bug] Foot floor margin added to the retarget hips rule**
- **Found during:** Task 1 (r4)
- **Issue:** the pure lowest-joint contact rule pushed the Mannequin ankle 0.117 m below its rest height (limit 0.041 m) because the Mannequin ankle sits much higher above its sole than the Mixamo one.
- **Fix:** `FLOOR_MARGIN_SHARE` = 0.08 of the hips height: the hips are lifted so no foot or toes joint sinks below its rest height by more than that. Slide hips range 0.48 to 0.63 of rest instead of 0.33.
- **Files:** `attimo/tools/clip_retargeter.gd`. **Commit:** `be2a6ae`.

**3. [Rule 2 - Missing critical functionality] Swing correction in the retargeter**
- **Issue:** the plan transfer reproduces bone directions exactly only for direct child tails; across the unmapped Mixamo `Spine1` the spine to chest direction would drift (the r3 guard includes spine to chest within 2 degrees).
- **Fix:** after the rotation transfer a swing correction turns the target bone-to-tail direction onto the source one, keeping the twist. Result: 0.000 deg parity.
- **Files:** `attimo/tools/clip_retargeter.gd`. **Commit:** `be2a6ae`.

**4. [Rule 3 - Blocking] Conform tool source clip and PROFILE_TAIL**
- The FBX importer yields two clips (`Take 001` empty, `mixamo_com`), so the conform row names `source_clip: "mixamo_com"`. `SkeletonProfile.get_bone_tail()` is empty for most bones, so the retargeter owns a `PROFILE_TAIL` chain constant. **Commit:** `be2a6ae`.

**5. [Rule 1 - Assumption wrong] Camera pivot and framing numbers adapted to the measured Mannequin**
- **Issue:** the plan assumed shoulders at about 1.8 m and chest/head ndc bands built on that. Measured shoulder joint: 1.107 m.
- **Fix:** `pivot_height` 1.4 m (plan rule shoulder + 0.2 would give 1.3; 1.4 is inside the test (k) range shoulder + 0.05 .. + 0.4 and keeps the character lower in the frame). Test (k) checks the measured shoulder (ndc -0.45 .. -0.02), head top (0 .. 0.3), feet (at least -0.9) and that the character centre is below the screen centre. Honest note: because the head is huge, the whole 2.2 m character spans ndc -0.42 .. 0.28, so it reads "slightly low", not strictly lower third; a lower look needs a higher pivot or a screen offset, which would break the centre-ray assumption of the aim target. Judge in the gym.
- **Files:** `attimo/scripts/camera/camera_rig.gd`, `attimo/tests/smoke/test_camera_rig.gd`, `docs/CONVENTIONS.md`. **Commit:** `6b4b5c8`.

**6. [Rule 3 - Test method] Lag measured by a LagProbe node**
- `await process_frame` resumes before node `_process` runs, so the test lag would include one frame of target motion (up to 0.37 m at 22 m/s). Tests use a `LagProbe` node with `process_priority` 100 that samples after the rig. **Commit:** `6b4b5c8`.

### Process note

- TDD: Task 1 and Task 2 tests were seen failing first (missing retargeter preload; missing `max_*_lag` exports and old framing values). Task 3 implementation was written before `test_aim_target`, which passed on first run (no separate RED run).
- DEV-04 (external retargeted clip, deviation from FOUND-05 and the D-03 wording, D-03 stays true as "no slide verb/state") is recorded in `docs/ANIMATION-MAP.md` and `docs/CONVENTIONS.md`; DEV-05 (vertical lock supersedes D-15) in `docs/CONVENTIONS.md` and the `CameraRig` header.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None beyond the plan threat model (T-qbt-01 mitigated: the conform tool keeps only Skeleton3D/AnimationPlayer and asserts no mesh, no script after reload, and `test_retarget` r5 re-checks the committed .scn; T-qbt-02 fixed constant paths; T-qbt-03 retarget returns null and the tool exits 1 on a missing bone, missing clip or non-finite key).

## Human gym checks (end-of-phase mode, not blocking)

1. Run and tap Shift: drops into the slide, feet on or just above the floor, pops back into the run; dash + jump leaves the slide into the long jump at once; aimed dash keeps the Dodge clips; air dash keeps the Dodge pose.
2. Camera: closer, character slightly low with the head near the centre, jumps and long jumps keep it framed, dashes do not leave it behind, no judder at 60 and 10 TPS (F6 / 0).
3. Hold RMB, crosshair on a near pillar and a far wall: the arm points at the spot under the crosshair, also while strafing and at steep pitch.

## Notes for the sibling task 261118-qi3

Reuse the retarget pipeline: add the UAL raw file row to `ROWS` in `tools/conform_external_clip.gd` (GLB path through `GLTFDocument`), a `RETARGETED` row with family `ual` in `tools/build_animation_library.gd`, a whitelist entry in `test_asset_hygiene` (currently 34) and the clip count in `test_animation_library`. The `ual` family map is untested against a real file; `test_retarget` r1 only validates it statically.

## Self-Check: PASSED

- Files found: `attimo/tools/conform_external_clip.gd`, `attimo/tools/clip_retargeter.gd`, `attimo/assets/animations/external/mixamo/running_slide.scn`, `attimo/tests/smoke/test_retarget.gd`, `attimo/tests/smoke/test_aim_target.gd`.
- Commits found: `be2a6ae`, `6b4b5c8`, `0624af2`.
- Full suite `RUN.SH: PASSED` (1563 checks).
- Not staged or committed: `attimo/project.godot`, the two `.png.import` modifications, `KayKit/Universal Animation Library[Standard]/`, `KayKit/Mixamo/Running Slide.fbx` (ignored).
