---
phase: quick-261118-qbt
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - KayKit/Mixamo/Running Slide.fbx
  - attimo/tools/conform_external_clip.gd
  - attimo/tools/clip_retargeter.gd
  - attimo/tools/build_animation_library.gd
  - attimo/tools/build_mannequin_tree.gd
  - attimo/assets/animations/external/mixamo/running_slide.scn
  - attimo/assets/animations/rig_medium/rig_medium_library.res
  - attimo/scenes/player/mannequin_tree.tres
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/procedural_pose.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/aim_pose_modifier.gd
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scenes/camera/camera_rig.tscn
  - attimo/tests/smoke/test_retarget.gd
  - attimo/tests/smoke/test_animation_library.gd
  - attimo/tests/smoke/test_asset_hygiene.gd
  - attimo/tests/smoke/test_animation_timing.gd
  - attimo/tests/smoke/test_aim_layer.gd
  - attimo/tests/smoke/test_dash.gd
  - attimo/tests/smoke/test_scene_run.gd
  - attimo/tests/smoke/test_procedural_pose.gd
  - attimo/tests/smoke/test_camera_rig.gd
  - attimo/tests/smoke/test_aim_target.gd
  - docs/ANIMATION-MAP.md
  - docs/CONVENTIONS.md
  - README.md
autonomous: true
requirements: [MOVE-11, CAM-01, CAM-02]

estimate:
  tokens: 130000
  raw_tokens: 130000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "An unaimed ground dash shows the retargeted Running_Slide clip on the Mannequin, travelled on the same physics frame as the Dash entry; jump, steering and the next dash respond at once (no control delay, no lock)"
    - "Aimed dashes keep their directional Dodge clips and the air dash keeps Dodge_Forward plus the DEV-02 hold; the FSM states are unchanged (no new movement state)"
    - "There is one documented retarget path (BoneMap on SkeletonProfileHumanoid as the pivot vocabulary) with a mixamo and a ual source family; a later UAL clip needs only a conform row and a RETARGETED row"
    - "No .fbx file sits inside the Godot project; the raw Mixamo download lives in the reference library at KayKit/Mixamo/ and only a mesh-free conformed scene is under attimo/assets/"
    - "The follow camera sits closer (arm at most 4 m), the pivot sits slightly above shoulder height, the standing character is framed in the lower part of the screen, FOV is a little wider and the upward pitch range is larger"
    - "The camera locks onto the player: while running, dashing, jumping and long jumping it never lags more than max_follow_lag horizontally or max_vertical_lag vertically, and head and feet stay inside the vertical view"
    - "While aiming, the right arm points at the world point under the screen-centre crosshair (camera centre ray against World, max-range fallback point); CameraRig.aim_target_point() and aim_direction_from() are the reusable accessors for the Phase 4 beam"
    - "bash attimo/tests/run.sh passes with the pinned Godot 4.7.2"
  artifacts:
    - path: "attimo/tools/clip_retargeter.gd"
      provides: "Generic source-skeleton to Rig_Medium retarget (families mixamo, ual, rig_medium) via BoneMap + SkeletonProfileHumanoid"
    - path: "attimo/tools/conform_external_clip.gd"
      provides: "Headless FBX/GLB to mesh-free .scn conform step for external clips"
    - path: "attimo/assets/animations/external/mixamo/running_slide.scn"
      provides: "Conformed Mixamo source (Skeleton3D + AnimationPlayer with one clip, no mesh, no script)"
    - path: "attimo/assets/animations/rig_medium/rig_medium_library.res"
      provides: "Library with 14 clips incl. Running_Slide on Rig_Medium track paths"
    - path: "attimo/tests/smoke/test_retarget.gd"
      provides: "Map validity, round-trip, direction-parity and slide-depth guards"
    - path: "attimo/tests/smoke/test_aim_target.gd"
      provides: "Crosshair ray target and arm feed guards"
  key_links:
    - from: "attimo/scripts/player/states/dash.gd"
      to: "attimo/scripts/player/mannequin_animator.gd"
      via: "Dash.slide presentation hint read in _on_state_changed -> dash_node_for -> travel Slide"
      pattern: "slide"
    - from: "attimo/scripts/player/states/dash.gd"
      to: "attimo/scripts/player/procedural_pose.gd"
      via: "_lean_target_deg returns 0 while the running Dash has slide true"
      pattern: "slide"
    - from: "attimo/tools/build_animation_library.gd"
      to: "attimo/tools/clip_retargeter.gd"
      via: "RETARGETED rows baked into rig_medium_library.res"
      pattern: "RETARGETED"
    - from: "attimo/scripts/player/mannequin_animator.gd"
      to: "attimo/scripts/camera/camera_rig.gd"
      via: "_feed_aim_modifier -> player.camera_rig().aim_target_point() -> AimPoseModifier.set_aim_point"
      pattern: "aim_target_point"
---

<objective>
Three related fixes in the Godot project `attimo/`, one task and one atomic commit each, on branch `dev`:

1. Slide: the user's Mixamo download `Running Slide.fbx` becomes the presentation of the unaimed ground dash on the Mannequin (Rig_Medium), through a generic, documented retarget pipeline that also accepts the Quaternius UAL skeleton later.
2. Camera: closer, lower-third framing slightly above shoulder height, wider FOV and pitch headroom, tighter follow, and a vertical lock so jumps never let the player drift out of frame.
3. Crosshair aim: the aim target is the world point under the screen-centre crosshair; the arm aims there from the shoulder (parallax-corrected), and a reusable accessor serves the Phase 4 beam.

Purpose: core value is the movement feel. The slide gives the ground dash a readable body motion, the camera keeps the fast player framed, and the aim matches what players expect from third-person shooters.
Output: retarget tooling, the Running_Slide clip and Slide tree node, retuned CameraRig, the crosshair ray accessor, updated tests and docs.

Tracer-first note: the three fixes are independent vertical slices that the user asked for as one task each, so there is no separate tracer task. Task 1 goes first because it is the riskiest (headless FBX load) and gets the freshest context; its first step is an explicit go/no-go gate with a fallback, so a blocked slide never blocks Tasks 2 and 3.

Decisions taken here (planner discretion, the user asked for the outcome, not the mechanism):
- The slide is presentation of the existing `Dash` state, not a new movement state: the FSM, timings and hand-offs stay exactly as they are (Phase 2/3 rule: animation never delays control). Only the unaimed ground dash slides; aimed dashes keep the D-12 directional Dodge clips; the air dash keeps Dodge_Forward and the DEV-02 hold.
- The forward dash lean is not applied during the slide: ProceduralPose pitches the whole Mannequin about the hip pivot, which would push the slide's extended lead foot about 15 cm into the floor. The lean stays for the aimed ground dash (dash_lean_deg * aim_lean_scale).
- The guard `test_asset_hygiene` forbids .fbx inside the project, so the raw FBX goes to the reference library (`KayKit/Mixamo/`, the same place the user put the UAL pack) and a headless conform step writes a mesh-free `.scn` into `attimo/assets/animations/external/mixamo/`.
- The retarget is baked in code (BoneMap objects on SkeletonProfileHumanoid built from typed constants), not through importer retarget options in `.import` files, because the Mannequin and the kit clips keep their Rig_Medium bone names and the importer's rest fixer would need the target re-imported too.
- Phase 3 D-03 ("no slide verb") stays true as a verb rule; the user's request is recorded as deviation DEV-04 (external retargeted clip on the Mannequin, also a FOUND-05 deviation). Phase 2 D-15 (vertical hold band, "no fixed hard lock") is superseded by the user's camera request and recorded as DEV-05.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@docs/ANIMATION-MAP.md
@docs/CONVENTIONS.md

Environment facts (verified while planning):
- Pinned engine on this Windows machine: `C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` prints `4.7.2.stable.official.ed1daf0bf`. Every run.sh call sets `GODOT` to it. Below, `$G` stands for `GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`, written out in full in each `<automated>` command.
- `Running Slide.fbx` (untracked, repo root, 1.9 MB, Kaydara FBX binary) has bones named `mixamorig:Hips`, `mixamorig:Spine`, `mixamorig:Spine1`, `mixamorig:Spine2`, `mixamorig:Neck`, `mixamorig:Head`, `mixamorig:LeftShoulder`, `mixamorig:LeftArm`, `mixamorig:LeftForeArm`, `mixamorig:LeftHand`, `mixamorig:LeftUpLeg`, `mixamorig:LeftLeg`, `mixamorig:LeftFoot`, `mixamorig:LeftToeBase` (and Right*, fingers, `HeadTop_End`, `Hips_skin`), a Beta mesh, no embedded textures, take name `mixamo.com`. Godot usually sanitizes `:` in bone names to `_`.
- Rig_Medium joints (Mannequin_Medium.glb): root > hips > spine > chest > head; chest > upperarm.l/.r > lowerarm > wrist > hand; hips > upperleg.l/.r > lowerleg > foot > toes. No neck, no clavicle. `wrist` is the joint at the forearm end, `hand` a short palm bone under it. Upper arms rest in a T-pose. The Mannequin faces +Z, its left is +X.
- UAL source (NOT integrated here, untracked, do not `git add` it): `KayKit/Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb`, UE-style skeleton root, pelvis, spine_01-03, neck_01, Head, clavicle_l/r, upperarm, lowerarm, hand, thigh, calf, foot, ball (+ fingers), root motion off.
- Pre-existing uncommitted changes (`attimo/project.godot`, two `.png.import` files) are not part of this task. Never stage them; stage explicit paths only.
- `dash_time` is 0.18 s; `aim_lean_scale` 0.5; `dash_lean_deg` 20. `test_movement_metrics` snapshots MovementConfig into docs/MOVEMENT-METRICS.md, so this plan adds NO MovementConfig field.
- `test_tuning_panel` (7) asserts exactly four `aim_*` range floats on CameraRig, so new CameraRig exports must not start with `aim_` as range floats.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Running_Slide retargeted onto Rig_Medium as the unaimed ground-dash presentation, generic retarget pipeline</name>
  <files>KayKit/Mixamo/Running Slide.fbx, attimo/tools/conform_external_clip.gd, attimo/tools/clip_retargeter.gd, attimo/tools/build_animation_library.gd, attimo/tools/build_mannequin_tree.gd, attimo/assets/animations/external/mixamo/running_slide.scn, attimo/assets/animations/rig_medium/rig_medium_library.res, attimo/scenes/player/mannequin_tree.tres, attimo/scripts/player/states/dash.gd, attimo/scripts/player/mannequin_animator.gd, attimo/scripts/player/procedural_pose.gd, attimo/tests/smoke/test_retarget.gd, attimo/tests/smoke/test_animation_library.gd, attimo/tests/smoke/test_asset_hygiene.gd, attimo/tests/smoke/test_animation_timing.gd, attimo/tests/smoke/test_aim_layer.gd, attimo/tests/smoke/test_dash.gd, attimo/tests/smoke/test_scene_run.gd, attimo/tests/smoke/test_procedural_pose.gd, docs/ANIMATION-MAP.md, docs/CONVENTIONS.md, README.md</files>
  <read_first>attimo/tools/build_animation_library.gd, attimo/tools/build_mannequin_tree.gd, attimo/scripts/player/mannequin_animator.gd, attimo/scripts/player/states/dash.gd, attimo/scripts/player/procedural_pose.gd (lines 1-115), attimo/tests/smoke/test_animation_library.gd, attimo/tests/smoke/test_animation_map.gd, attimo/tests/smoke/test_asset_hygiene.gd, docs/ANIMATION-MAP.md, docs/CONVENTIONS.md (Folder layout, Player scene), .planning/phases/03-animated-mannequin-aim-mode/03-CONTEXT.md (D-01, D-02, D-03, D-12)</read_first>
  <behavior>
    - test_retarget (r1): every profile name in the retarget maps exists in SkeletonProfileHumanoid; every Rig_Medium name exists on the Mannequin skeleton; the mixamo family resolves all its bones on running_slide.scn; mixamo name normalization maps `mixamorig:Hips`, `mixamorig_Hips` and `mixamorig1:Hips` to `Hips`; every ual source name maps to a profile bone (static, no file).
    - test_retarget (r2): retargeting Idle_A from the Rig_Medium source family onto Rig_Medium reproduces every original rotation key within 0.5 degrees (round trip proves the math and the track writing).
    - test_retarget (r3): at every key of Running_Slide, each limb bone direction of the target (upperarm, lowerarm, upperleg, lowerleg, spine to chest) matches the source bone direction in character space within 2 degrees.
    - test_retarget (r4): Running_Slide hips x and z stay at rest (within 1 mm); the deepest hips height is at most 80 % of the rest hips height; no foot or toes joint sinks more than 10 % of the rest hips height below its rest height.
    - test_retarget (r5): running_slide.scn holds only Node3D, Skeleton3D and AnimationPlayer nodes, no MeshInstance3D and no node with a script (T-qbt-01).
    - test_animation_library: 14 clips incl. Running_Slide (LOOP_NONE, every track path begins with Rig_Medium/Skeleton3D:); the Slide window of the tree ends in the low slide pose (hips at window end at most 80 % of rest).
    - Animator: an unaimed ground dash travels to `Slide` on the same physics frame as Run -> Dash; an aimed ground dash keeps Dash/DashLeft/DashRight/DashBack; an air dash keeps `Dash` and the DEV-02 hold; clip_scale of Slide equals Slide timeline length / dash_time.
    - ProceduralPose: lean stays exactly 0 and the Mannequin transform identity through an unaimed ground dash (slide) and its hop; an aimed ground dash still leans to dash_lean_deg * aim_lean_scale about the hip pivot and eases out within lean_out_time.
  </behavior>
  <action>
Implements the user's slide request as DEV-04 (deviation from Phase 3 D-03 wording and FOUND-05 "kit clips only"; D-03 stays true as "no slide verb/state"). Keep D-01 (ground dash lean), D-02 (air dash, DEV-02 hold) and D-12 (aimed directional dashes) intact except the lean change stated below.

Step A, go/no-go gate (do this first). Create folder `KayKit/Mixamo/` and move the untracked `Running Slide.fbx` from the repo root into it with a plain mv (the user's copy in Downloads stays as backup). Write `attimo/tools/conform_external_clip.gd` (extends SceneTree, typed, `##` header, run via `--tool`). It holds a typed constant table of rows: raw path relative to the repo root (`KayKit/Mixamo/Running Slide.fbx`), output path (`res://assets/animations/external/mixamo/running_slide.scn`), target clip name (`Running_Slide`). For each row: resolve the raw path as `ProjectSettings.globalize_path("res://")` joined with `..` and the relative path, simplified (same pattern as test_animation_map's DOC path); load `.fbx` through `FBXDocument` + `FBXState`, `.glb`/`.gltf` through `GLTFDocument` + `GLTFState` (`append_from_file`, then `generate_scene`); find the Skeleton3D and the AnimationPlayer; pick the single animation that is not `RESET` (fail if there are several and the row names none); free every MeshInstance3D and every node that is neither an ancestor of nor equal to the Skeleton3D or the AnimationPlayer; replace the AnimationPlayer's libraries with one default library holding only the chosen clip renamed to the row's clip name (leave the AnimationPlayer and the Skeleton3D where they are so track paths stay valid); set `owner` = root on every remaining descendant; pack and save with ResourceSaver; reload the saved scene and assert: Skeleton3D with at least 15 bones, exactly one clip, no MeshInstance3D, no node with a script. Print every bone name, the clip name and length, and `CONFORM: SAVED` / `CONFORM: FAILED (...)`, quit 0/1.
Run it. GO = the .scn reloads with the skeleton and the clip. NO-GO = FBXDocument cannot load the file or yields no animation. On NO-GO: if Blender MCP tools are available, import the FBX in Blender and export a GLB (armature and its action only, Export Deformation Bones Only, no mesh) to `KayKit/Mixamo/running_slide.glb`, point the conform row at that GLB and re-run. If that is not possible either, restore every Task 1 path (move the FBX back to the repo root, delete the new tool), commit nothing for Task 1, continue with Tasks 2 and 3, and report the slide as blocked with the exact error and these Blender steps.

Step B, retargeter. Write `attimo/tools/clip_retargeter.gd` (extends RefCounted, no class_name, preloaded by the tools and tests). Data, all typed constants keyed by SkeletonProfileHumanoid bone names (the pivot vocabulary, coordinator requirement):
- Profile to Rig_Medium: Root root, Hips hips, Spine spine, UpperChest chest, Head head, LeftUpperArm upperarm.l, LeftLowerArm lowerarm.l, LeftHand wrist.l, LeftUpperLeg upperleg.l, LeftLowerLeg lowerleg.l, LeftFoot foot.l, LeftToes toes.l, and the Right* counterparts on `.r`. `hand.l/.r` and `root` are unmapped (they hold rest). If a source family has no UpperChest, Rig_Medium chest falls back to the source Chest.
- Family `mixamo` (names after normalization, which strips a leading `mixamorig` plus optional digits plus `:` or `_`): Hips Hips, Spine Spine, Spine1 Chest, Spine2 UpperChest, Neck Neck, Head Head, LeftShoulder LeftShoulder, LeftArm LeftUpperArm, LeftForeArm LeftLowerArm, LeftHand LeftHand, LeftUpLeg LeftUpperLeg, LeftLeg LeftLowerLeg, LeftFoot LeftFoot, LeftToeBase LeftToes, plus Right*.
- Family `ual` (ready for later, no clip uses it now): root Root, pelvis Hips, spine_01 Spine, spine_02 Chest, spine_03 UpperChest, neck_01 Neck, Head Head, clavicle_l LeftShoulder, upperarm_l LeftUpperArm, lowerarm_l LeftLowerArm, hand_l LeftHand, thigh_l LeftUpperLeg, calf_l LeftLowerLeg, foot_l LeftFoot, ball_l LeftToes, plus the `_r` side.
- Family `rig_medium`: the inverse of the Profile to Rig_Medium map (used by the round-trip self-test).
- A per-family facing yaw correction in degrees (0 for all three; the parity test catches a wrong value).
API: a function that builds a Godot `BoneMap` (profile = `SkeletonProfileHumanoid.new()`, `set_skeleton_bone_name(profile_bone, actual_bone)`) for a family on a given Skeleton3D; a public `sample_globals(skeleton, skeleton_to_character, animation, time)` returning character-space Transform3D per bone (walk parents manually from track values or rests; do not rely on Skeleton3D global-pose caches, the nodes are not in a tree); and `retarget(source_root, clip, family, target_skeleton, target_skeleton_to_character, track_prefix, pin_horizontal) -> Animation`. Character space = the Skeleton3D's transform relative to its scene root times the bone pose; use orthonormalized bases for rotations so FBX unit scales cancel.
Algorithm per mapped profile bone b, sampled at 30 Hz over the source length (one key per sample):
(1) Rest alignment: dir_s and dir_t are the character-space rest directions from b to the first bone along the profile tail chain (`SkeletonProfile.get_bone_tail`, walking on while a tail is unmapped) that is mapped in both skeletons; A_b = shortest rotation dir_s to dir_t (reuse `AimPoseModifier.rotation_between` semantics for the opposite case), identity when no such tail exists. Reference rotation Q_ref = A_b * source rest global rotation.
(2) Transfer: D = source global rotation at time t * Q_ref inverse; target global rotation = D * target rest global rotation. This reproduces the source bone directions exactly (the (r3) guard) and is independent of each skeleton's local axis conventions, so T-pose (Mixamo) and other rests (UAL) both work.
(3) Unmapped target bones: global = parent global * rest local. Convert target globals to skeleton space and then to local rotations (parent inverse times child) in hierarchy order.
(4) Hips position: x and z pinned to the hips rest position when pin_horizontal is true (the dash moves the body in code, same reason as ROOT_PINNED); y by floor contact: pose the target with hips at rest height, then shift the hips vertically so the lowest target foot/toes joint height minus its rest height equals the source's lowest foot/toes joint height minus its rest height times (target hips rest height / source hips rest height).
(5) Tracks: for every target bone a rotation track and a position track (rest position except hips), and scale tracks only if Idle_A has them (mirror the kit clip's per-bone track types); paths `Rig_Medium/Skeleton3D:<bone>`.

Step C, library and tree. In `attimo/tools/build_animation_library.gd` add a typed `RETARGETED` table (row: clip `Running_Slide`, conformed source `res://assets/animations/external/mixamo/running_slide.scn`, family `mixamo`, loop false, pin_horizontal true); after the kit clips, bake each row with the retargeter onto the skeleton of `res://assets/characters/mannequin/Mannequin_Medium.glb` and add it to the library; print the hips height of each retargeted clip as a share of rest per sample (the measurement for the window). Update the header comment. Run it. In `attimo/tools/build_mannequin_tree.gd` add a state machine node `Slide` = `_clip(&"Running_Slide")` with use_custom_timeline, `start_offset` SLIDE_START, `timeline_length` SLIDE_LENGTH, stretch_time_scale false, LOOP_NONE, and add `Slide` to the immediate-edge state list. Choose the window from the printed curve: SLIDE_START = last sample before the hips minimum with height at least 95 % of rest (the drop begins); window end = first sample within 10 % of the total drop of the minimum, plus 0.1 s of the low hold; if SLIDE_LENGTH / 0.18 exceeds 4, move SLIDE_START later until it fits. Never include the run-in steps or the get-up. Write both constants with a comment that cites the measured numbers. Run it.

Step D, presentation wiring. `dash.gd`: add `var slide: bool` with a `##` doc ("presentation hint read by MannequinAnimator and ProceduralPose: true for a ground dash started without aim; movement never reads it"), set in enter right after in_air as not in_air and not actor.aiming. `mannequin_animator.gd`: add `&"Slide": &"Running_Slide"` to DASH_CLIPS; in _ready, after the clip-length loop, overwrite the Slide entry of _dash_lengths with the Slide node's `timeline_length` read from the tree root (StateMachine node, then Slide), so clip_scale plays the window in exactly dash_time; extend `dash_node_for(direction, slide := false)` to return `&"Slide"` when slide is true and the player is not aiming; `_on_state_changed` passes the Dash node's slide value. No other change: the travel stays on the same call, the DEV-02 hold stays air-only, Dash -> LongJump still travels to Jump at once. `procedural_pose.gd`: `_lean_target_deg` returns 0 while the current state is a Dash with in_air or slide true; update the header doc (the slide carries its own pose; the D-01 lean now shows on the aimed ground dash, scaled by aim_lean_scale; the lean-out into the long jump is unchanged for that case).

Step E, tests (write test_retarget first and see it fail before Step B is complete, per the behavior block). New `attimo/tests/smoke/test_retarget.gd` (extends RefCounted, `run(tree, check)`, read-only fixed paths) with (r1) to (r5). Update: `test_animation_library.gd` (14 clips, Running_Slide checks, window guard via the tree's Slide node values, header comment); `test_asset_hygiene.gd` (whitelist 34 with `animations/external/mixamo/running_slide.scn`, count assertion 34, header comment names the 03-02 to qbt extension and that conformed external sources are deliberate entries; FORBIDDEN_EXTENSIONS unchanged); `test_animation_timing.gd` scenario (2) Run -> Dash expects `&"Slide"`; `test_dash.gd` (around line 50) and `test_scene_run.gd` (around line 192) expect `&"Slide"` where the dash is an unaimed ground dash (check each; air dashes stay `&"Dash"`); `test_aim_layer.gd` (f6) expects `&"Slide"`/`&"Running_Slide"` and the clip-scale scenario expects the Slide window / dash_time for the unaimed ground dash; `test_procedural_pose.gd` (p2)-(p4) assert lean 0 and identity through the unaimed slide dash, and move the lean-in, pivot, tilt and ease-out checks to an aimed forward ground dash with the target dash_lean_deg * aim_lean_scale; (s1) additionally asserts lean 0 on every row of the unaimed hop and gains an aimed variant that keeps today's ease-out assertions. Do not weaken any other assertion.

Step F, docs. `docs/ANIMATION-MAP.md`: rule line 8 becomes kit clips plus retargeted external clips listed in a new "External clips" section (DEV-04); Ground dash row becomes the unaimed ground dash: `Dash` (ground, aim not held), node `Slide`, clip `Running_Slide`, window stretched to dash_time, no procedural lean, same-frame travel, never delays control; the Aim dashes row notes the aimed ground lean; add `Slide` to the node list and `Running_Slide` as a retargeted clip; "Left out" keeps the D-03 term: slide stays no verb and no state, the unaimed ground dash only presents the retargeted clip (quick 261118-qbt, DEV-04); new section "External clips" with a table (clip, family, raw source, conformed file, window) and the steps for adding one: raw file into the reference library, conform row, family map (mixamo or ual, both ready), RETARGETED row, whitelist entry, map row, run both tools. `docs/CONVENTIONS.md`: folder row `assets/animations/external/<family>/` (conformed mesh-free .scn, generated by tools/conform_external_clip.gd); rules: raw external sources stay outside the project in the reference library (`KayKit/Mixamo/`, the UAL pack under `KayKit/Universal Animation Library[Standard]/`), FBX never inside the project, the retarget path (tools/clip_retargeter.gd, BoneMap on SkeletonProfileHumanoid, families mixamo/ual/rig_medium); Player scene: the `Dash.slide` hint. `README.md` Credits: the Running Slide clip from Adobe Mixamo, used under the Mixamo terms (embedding in the game is allowed, standalone redistribution is not); note that the raw FBX contains the Mixamo Beta mesh.

Commit (explicit paths only, include the generated `.gd.uid` sidecars of new scripts, never the pre-existing project.godot or .png.import changes, never the UAL folder): `feat(quick-261118-qbt): unaimed ground dash plays retargeted Running_Slide (generic Mixamo/UAL retarget pipeline)` with the Co-Authored-By trailer from the session attribution.
  </action>
  <verify>
    <automated>GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh --tool res://tools/conform_external_clip.gd && GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd && GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd && GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh test_retarget,test_animation_library,test_animation_map,test_asset_hygiene,test_animation_timing,test_dash,test_scene_run,test_aim_layer,test_procedural_pose,test_mannequin_animation</automated>
    <human-check>Gym (F5 on movement_gym): run and tap Shift. The Mannequin drops into the slide during the dash with both feet on or just above the floor, no foot through the floor, and pops back into the run. Dash + jump leaves the slide into the long jump at once. Hold aim and dash: the directional Dodge clips play as before. Air dash: Dodge pose as before.</human-check>
  </verify>
  <done>Running Slide.fbx is in KayKit/Mixamo/, no .fbx is inside attimo/, running_slide.scn is mesh-free and whitelisted, the library holds 14 clips, the tree has a Slide node, an unaimed ground dash travels to Slide on the Dash entry frame, the aimed and air dashes are unchanged, the listed tests pass, docs and README updated, one commit on dev. Or, on NO-GO, Task 1 left no trace and the blocker is reported.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Camera closer, lower-third framing above shoulder height, tighter follow and vertical lock on jumps</name>
  <files>attimo/scripts/camera/camera_rig.gd, attimo/scenes/camera/camera_rig.tscn, attimo/tests/smoke/test_camera_rig.gd, docs/CONVENTIONS.md</files>
  <read_first>attimo/scripts/camera/camera_rig.gd, attimo/scenes/camera/camera_rig.tscn, attimo/tests/smoke/test_camera_rig.gd, attimo/tests/fixtures.gd, docs/CONVENTIONS.md (Camera section), .planning/phases/02-movement-core-follow-camera/02-CONTEXT.md (D-14 to D-18)</read_first>
  <behavior>
    - (e) rewritten "camera locks onto jumps": during a held ground jump and a long jump stage 1 (dash + jump on one tick from a run), every process frame: vertical lag between the rig and (interpolated player y + pivot_height) is at most max_vertical_lag + 0.01 m, horizontal lag at most max_follow_lag + 0.01 m, and the player's feet (origin + 0.05 m) and head (origin + 2.2 m) are in front of the camera with vertical NDC inside -0.95 .. 0.95; the rig rises more than 1.2 m during the jump (it follows, the opposite of the old D-15 check).
    - (k) new framing: at spawn with the default pitch, the chest point (origin + 1.3 m) projects to vertical NDC between -0.45 and -0.1, the head top (origin + 2.2 m) at most 0.3, the feet at least -0.9; spring_length is at most 4.0; pivot_height lies between the Mannequin's measured right-shoulder height (upperarm.r rest, world y) + 0.05 and + 0.4.
    - (l) new dash follow: during a ground dash at 22 m/s the horizontal lag never exceeds max_follow_lag + 0.01 m.
    - (a)-(d), (f)-(j) keep passing unchanged (structure, channels, pitch clamp, jitter at 10 and 60 TPS, step landing, ledge, wall pull-in, open space, corridor).
  </behavior>
  <action>
Implements the user's camera request; it supersedes the Phase 2 D-15 vertical hold band ("no fixed hard lock"), recorded as DEV-05. Keep D-14 (centered framing, shoulder offset only in aim), D-18 (hand-built rig, per-frame sphere cast fallback, additive FOV/offset sources), top_level, physics interpolation off on the rig, following the interpolated target in _process, mouse look without delta scaling.

Retune `attimo/scripts/camera/camera_rig.gd` exports, each with an updated `##` doc stating the value's purpose:
- pivot_height 1.6 -> 2.0 m (slightly above the shoulders of the about 2.2 m Mannequin; if test (k) measures the shoulder more than 0.15 m away from 1.8 m, set it to measured shoulder + 0.2, rounded to 0.05, and record it).
- default `pitch` -0.3 -> -0.22 rad (flatter view, more horizon, character lower in frame).
- pitch_max 0.6 -> 0.75 rad (more room to look up at high platforms); pitch_min stays -1.2.
- base_fov 75 -> 78 degrees.
- follow_rate 14 -> 22 1/s; vertical_follow_rate 6 -> 12 1/s.
- New `max_follow_lag` = 0.6 m: after the horizontal lerp, clamp the rig's xz offset from the anchor to this length (keeps dashes and long jumps at 14-22 m/s framed; steady-state lag at run speed 8.5 m/s is about 0.39 m, so the clamp is inactive while running and the jitter proxy stays valid).
- New `max_vertical_lag` = 0.35 m: after the vertical lerp, clamp the rig's y into anchor.y +- this value.
- Vertical goal: the anchor y in every state (grounded and airborne). Remove the airborne hold band export, its last-grounded-height field and the branches of `_vertical_goal` that use them (simplify or inline the function; keep `_target_grounded` only if something still reads it, else remove it). Update snap_to_target accordingly.
- `_max_arm_length` and `_arm_length` initial values 5.0 -> 3.6 (they are overwritten from the scene in _ready, keep them consistent).
- Update the class header comment: centered framing slightly above the shoulder, lower-third read, tight follow with the two lag clamps, vertical lock replacing the Phase 2 D-15 band per the user's request of 2026-11-18 (quick 261118-qbt, DEV-05).
In `attimo/scenes/camera/camera_rig.tscn`: SpringArm3D spring_length 5.0 -> 3.6, Camera3D fov 75.0 -> 78.0. The gym and test scenes instance this scene without overrides (verified), so no other scene changes.
Do not touch the aim exports, the aim blend, the FOV/offset source API, recenter, auto-follow or the arm cast.

Tests in `attimo/tests/smoke/test_camera_rig.gd` (write the new scenarios first, see them fail on the old values): replace (e) as in the behavior block, add (k) and (l), update the header comment (D-15 band replaced by the lock, DEV-05). Add a helper `_ndc_y(camera, world_point)`: transform the point into camera space with the inverse of camera.global_transform, return (y / -z) / tan(fov / 2) with fov in radians (Camera3D keeps height by default, so fov is vertical); also return or check z < 0 (in front). For the long jump use the same input pattern as test_procedural_pose (send dash pressed, jump pressed, dash released on one tick after a run-up). Release every action and restore tick rate before freeing nodes, like the existing scenarios.

`docs/CONVENTIONS.md` Camera section: add the framing numbers (pivot 2.0 m, arm 3.6 m, pitch -0.22 rad default, pitch range -1.2 .. 0.75, FOV 78), the two lag clamps and the vertical lock replacing D-15 (DEV-05); keep every other camera rule.

Commit (explicit paths): `feat(quick-261118-qbt): closer lower-third follow camera with tight horizontal and vertical lock` with the Co-Authored-By trailer.
  </action>
  <verify>
    <automated>GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh test_camera_rig,test_aim_camera,test_camera_controls,test_tuning_panel,test_aim_pose,test_latency,test_movement_gym</automated>
    <human-check>Gym: the camera sits closer, the character stands in the lower part of the screen with the head near the centre, jumps and long jumps keep the character framed without bobbing lag, dashes do not leave the character behind, the camera does not judder at 60 and 10 TPS (F6 / 0 cycles the tick rate).</human-check>
  </verify>
  <done>CameraRig and camera_rig.tscn carry the documented values and the two lag clamps, the old airborne hold band is gone, test_camera_rig has the new (e), (k), (l) and passes with all old scenarios, the listed camera-related tests pass, CONVENTIONS updated, one commit on dev.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Crosshair ray aim target, arm aims at the world point under the crosshair, reusable accessor for Phase 4</name>
  <files>attimo/scripts/camera/camera_rig.gd, attimo/scripts/player/player_controller.gd, attimo/scripts/player/mannequin_animator.gd, attimo/scripts/player/aim_pose_modifier.gd, attimo/tests/smoke/test_aim_target.gd, docs/CONVENTIONS.md, docs/ANIMATION-MAP.md</files>
  <read_first>attimo/scripts/camera/camera_rig.gd (after Task 2), attimo/scripts/player/aim_pose_modifier.gd, attimo/scripts/player/mannequin_animator.gd (_feed_aim_modifier, after Task 1), attimo/scripts/player/player_controller.gd (input_direction, _find_rig, _tick_aim), attimo/scripts/ui/crosshair.gd, attimo/scripts/core/physics_layers.gd, attimo/tests/smoke/test_aim_pose.gd, attimo/tests/smoke/test_aim_camera.gd, attimo/tests/fixtures.gd</read_first>
  <behavior>
    - (t1) pure `CameraRig.aim_ray_start(origin, forward, pivot)`: pivot 3 m ahead on the ray gives origin + forward * 3; pivot behind the lens gives origin; pivot off the ray gives its projection.
    - (t2) open space, pitch raised so the centre ray misses the floor: aim_target_point() equals camera position + camera forward * crosshair_ray_length within 1 mm and last_aim_hit is false.
    - (t3) a World box with its near face 8 m in front: the point lies on the box's near face (within 0.05 m), on the camera centre ray (distance to the ray line below 1 mm), last_aim_hit is true and last_aim_collider is that box.
    - (t4) aim_direction_from(origin) is unit length and points from origin to aim_target_point().
    - (t5) full player + rig with a wall about 6 m ahead, aim held past aim_blend_time: the AimPoseModifier's received aim point equals rig.aim_target_point() within 1 mm, last_error_deg is below 1 degree, and the shoulder-to-point direction differs from the camera forward by more than 1 degree (the parallax is real and the arm follows the hit point, not the camera forward).
    - test_aim_pose, test_aim_camera, test_aim_layer and test_crosshair keep passing.
  </behavior>
  <action>
Implements the user's crosshair request on top of CAM-02 (Phase 3 D-11 arm direction, D-13 to D-15 aim camera). The crosshair is already drawn at the screen centre; for a perspective Camera3D without h/v offset the centre ray is the camera position along the camera's -Z, so no viewport query is needed (state this in the doc).

`attimo/scripts/camera/camera_rig.gd`: new export group "Crosshair ray" with `crosshair_ray_length` (float, 100.0 m, plain @export, NOT an `aim_`-prefixed range float, so the F2 aim rows stay four) and `crosshair_ray_mask` (`@export_flags_3d_physics`, default `PhysicsLayers.WORLD`; Phase 4 may add Interactable/Enemy bits). Read-only state for consumers: `last_aim_hit: bool`, `last_aim_collider: Object`, `last_aim_point: Vector3`. Functions with `##` docs:
- static `aim_ray_start(origin, forward, pivot) -> Vector3`: origin + forward * max((pivot - origin) dot forward, 0). The ray starts level with the character, so geometry between the lens and the character (possible with the aim shoulder offset) is never the target.
- `aim_target_point() -> Vector3`: on demand, from the current camera transform: forward = -camera.global_basis.z normalized; start from aim_ray_start with the rig's own global_position as pivot; one `PhysicsRayQueryParameters3D` from start to camera position + forward * crosshair_ray_length with crosshair_ray_mask; the hit position, else that end point; writes the three last_* fields. The query uses direct_space_state like the existing per-frame arm cast in _process. Non-finite results fall back to the end point.
- `aim_direction_from(origin) -> Vector3`: normalized (aim_target_point() - origin); camera forward when the distance is below 0.001.
`attimo/scripts/player/player_controller.gd`: public `camera_rig() -> CameraRig` that returns the rig of the viewport's current camera through the existing _find_rig, or null; document it as the lookup for the hand and the Phase 4 beam.
`attimo/scripts/player/mannequin_animator.gd` `_feed_aim_modifier`: when `player.camera_rig()` is not null, feed `set_aim_point(rig.aim_target_point())`; otherwise keep today's fallback (camera origin + forward * converge_distance). Update the comment (the arm now converges on the crosshair hit point; the AimPoseModifier aims from the shoulder, so the hand lies on the shoulder-to-point line and the camera-to-character parallax is corrected).
`attimo/scripts/player/aim_pose_modifier.gd`: add a read-only getter `aim_point() -> Vector3` for the last received point (the (t5) wiring check) and update the header: the point comes from CameraRig.aim_target_point(); converge_distance is the fallback without a rig. No solver change.

New `attimo/tests/smoke/test_aim_target.gd` (write it first and see it fail): scenarios (t1) to (t5) from the behavior block, using Fixtures.spawn_floor, spawn_player, spawn_camera_rig and spawn_box; set rig.yaw and rig.pitch directly and wait a few process frames before querying; release aim and free nodes at the end of each scenario.

Docs: `docs/CONVENTIONS.md` Camera section gets an "Aim target" rule: the aim target is the world point under the screen-centre crosshair, CameraRig.aim_target_point() / aim_direction_from() / last_aim_hit / last_aim_collider, ray mask crosshair_ray_mask (World now), max-range fallback, ray start level with the character, found through PlayerController.camera_rig(); the Phase 4 beam fires from the hand along aim_direction_from(hand origin). It is a query, not an EventBus fact (the bus holds no per-frame state). `docs/ANIMATION-MAP.md` Aim stance row: AimPoseModifier points the right arm at the crosshair target point (CameraRig.aim_target_point()).

Commit (explicit paths, incl. the new test's .gd.uid): `feat(quick-261118-qbt): crosshair ray aim target, arm aims at the world point under the crosshair` with the Co-Authored-By trailer.
  </action>
  <verify>
    <automated>GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh test_aim_target,test_aim_pose,test_aim_camera,test_aim_layer,test_crosshair,test_tuning_panel && GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh</automated>
    <human-check>Gym: hold right mouse, put the crosshair on a near pillar and then on a far wall: the right arm points at the spot under the crosshair in both cases (near targets visibly converge), also while strafing and at steep pitch.</human-check>
  </verify>
  <done>CameraRig exposes aim_target_point(), aim_direction_from(), aim_ray_start() and the last_* fields, the animator feeds the crosshair hit point, test_aim_target passes, the full suite ends with RUN.SH: PASSED, docs updated, one commit on dev.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| downloaded asset -> headless tool | `Running Slide.fbx` is an external binary parsed by the engine's FBX loader in an editor-time tool |
| conformed scene -> runtime load | `running_slide.scn` is loaded by `load()` in the library tool and tests; a binary scene could carry scripts |
| physics query -> aim | the crosshair ray reads the physics space every aimed frame |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-qbt-01 | Tampering / Elevation | conform_external_clip.gd, running_slide.scn | medium | mitigate | The conform tool keeps only Skeleton3D and AnimationPlayer (plus ancestor Node3Ds), frees meshes and every other node, and asserts after reload that no node has a script; test_retarget (r5) re-checks the committed .scn on every run |
| T-qbt-02 | Tampering | conform tool paths | low | mitigate | Raw and output paths are fixed typed constants (raw under the repo's reference library, output under res://assets/animations/external/); no path comes from arguments or user input |
| T-qbt-03 | Denial of service | build_animation_library retarget | low | mitigate | Retarget fails loudly (quit 1) on a missing bone map entry, missing clip or non-finite key instead of writing a broken library; the library is regenerated deterministically |
| T-qbt-04 | Information disclosure (licensing) | KayKit/Mixamo/Running Slide.fbx | low | accept | Mixamo terms allow embedding in the game, not standalone redistribution; README credits state it and that the raw FBX contains the Beta mesh. Whether a public remote is acceptable is the developer's call (flagged in the summary) |
| T-qbt-05 | Denial of service | CameraRig.aim_target_point | low | accept | One ray per aimed frame, same order of cost as the existing per-frame arm sphere cast |
| T-qbt-SC | Tampering | npm/pip/cargo installs | high | accept | No package-manager installs in this plan; only engine-bundled classes (FBXDocument, GLTFDocument, BoneMap, SkeletonProfileHumanoid) are used |
</threat_model>

<verification>
- Full suite: `GODOT="C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash attimo/tests/run.sh` ends with `RUN.SH: PASSED` after Task 3 (and after Task 2 if Task 1 is blocked).
- `git status` shows no untracked `Running Slide.fbx` at the repo root, no staged UAL files, and the pre-existing project.godot / .png.import modifications still unstaged.
- `git log --oneline -3` shows the three task commits on `dev` (or two plus a reported Task 1 blocker).
- Human gym checks (end-of-phase mode, no blocking checkpoint): the three `<human-check>` items above.
</verification>

<success_criteria>
- Unaimed ground dash shows the slide on the Dash entry frame, with no control delay and no foot through the floor; aimed and air dashes unchanged.
- One documented retarget path serves Mixamo now and UAL later, guarded by test_retarget.
- Camera: arm 3.6 m, pivot about 2.0 m, FOV 78, pitch -1.2 .. 0.75, horizontal lag at most 0.6 m, vertical lag at most 0.35 m, player framed through jumps and long jumps; all Phase 2 camera tests still pass.
- Aim: the arm converges on the crosshair hit point; CameraRig.aim_target_point() / aim_direction_from() exist for Phase 4.
- Suite green, docs (ANIMATION-MAP, CONVENTIONS, README) match the code.
</success_criteria>

<output>
Create `.planning/quick/261118-qbt-slide-animation-from-running-slide-fbx-c/261118-qbt-SUMMARY.md` when done: measured Slide window (SLIDE_START, SLIDE_LENGTH, playback scale), the Mixamo bone names as Godot imported them, the measured shoulder height and final pivot_height, test counts, the three commit hashes, and the licensing flag for the raw FBX.
</output>
