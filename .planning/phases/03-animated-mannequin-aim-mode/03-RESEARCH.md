# Phase 3: Animated Mannequin & Aim Mode - Research

**Researched:** 2026-11-14
**Domain:** Godot 4.7.2 AnimationTree layering (BlendTree, BlendSpace2D, OneShot, Blend2 bone filter), SkeletonModifier3D, procedural body pose under physics interpolation, additive third-person aim camera, HUD crosshair, KayKit Rig_Medium clip facts
**Confidence:** MEDIUM-HIGH. Engine mechanics and clip data are HIGH (every engine claim marked VERIFIED was executed headless in a scratch copy of the project on the pinned 4.7.2 binary). How the layered aim stance and the strafe poses LOOK is MEDIUM: nothing could be rendered headless, so those items need a gym eye-check (see Open Questions).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Ground dash and long jump (dash hop)**
- **D-01:** The ground dash plays `Dodge_Forward` plus a procedural forward lean of the body (code rotation on `VisualRoot`, pitch toward the dash direction). The lean must blend cleanly into the long jump when the player jumps out of the dash, because that hand-over is the key look.
- **D-02:** The air dash stays as it is now: `Dodge_Forward` held as a pose in the air, no extra lean. The lean applies to the ground dash only.
- **D-03:** No slide. The user does not want a slide verb or a slide pose; the dash lean flowing into the jump covers it. (A slide would also have no kit clip, MOVE-11.)
- **D-04:** The long jump (dash hop) plays `Jump_Start` with a held forward stretch lean in flight (superman style), then `Jump_Land` on touchdown. The lean continues from the dash lean (D-01).
- **D-05:** The long jump at **stack stage 3** (maximum speed) additionally plays the Jump 3 pirouette (D-07). Stages 1 and 2 only use the stretch lean.

**Jump chain and landing**
- **D-06:** Jump 1 and Jump 2 use `Jump_Start` -> `Jump_Idle` -> `Jump_Land` (the current mapping).
- **D-07:** **Jump 3 (the old "salto") becomes a pirouette:** one 360 degree rotation around the vertical axis (code rotation on `VisualRoot`), normal jump pose otherwise. The rotation takes the flight time of the jump and ends shortly before landing so `Jump_Land` starts clean. No flip, no double rotation. Reason: the user finds a flip too playful for a steampunk character. The planner updates the "salto/flip" wording in REQUIREMENTS.md (MOVE-05, MOVE-09, FEEL-02) and ROADMAP.md Phase 3 criterion 1 accordingly. — **Reversibility:** reversible — the rotation is one code parameter on `VisualRoot`.
- **D-08:** Landing is a blend without lock: `Jump_Land` plays as a short blend and is overridden at once by run or idle when the player moves. No landing lock and no anticipation longer than 2 frames (ROADMAP criterion 4); the Phase 2 latency numbers must still hold.

**Aim mode: behavior**
- **D-09:** The aim button is **hold** (CAM-02). While held, the Mannequin always faces the crosshair/camera direction (no smoothing delay), and moves with `Running_Strafe_Left`/`Running_Strafe_Right` and `Walking_Backwards` blended by movement direction relative to the camera.
- **D-10:** In aim mode the player may run, jump and dash. Aim does not block movement. Run speed in aim may be reduced slightly (tunable value in `MovementConfig`, Claude picks the start factor).
- **D-11:** The aim upper-body pose is `Ranged_1H_Aiming` (arm bent, pistol-like), layered on the upper body via bone filter while the legs keep the locomotion clips. The user viewed `Ranged_Magic_Raise` (raises the arm up) and `Ranged_Magic_Shoot` (a cast) and rejected them; `1H_Aiming` is the only one of the three where the arm points forward. A procedural fine adjustment rotates the aiming arm so it points at the crosshair at any camera pitch. The Mannequin has **no finger bones**, so the hand shape cannot change; only arm, wrist and torso animate.
- **D-12:** Dash in aim mode: the figure keeps facing the crosshair, so the dash uses the directional kit clips `Dodge_Left`, `Dodge_Right`, `Dodge_Backward` (and `Dodge_Forward`) chosen by dash direction relative to facing. Outside aim mode the dash keeps D-10 of Phase 2 (turn, then `Dodge_Forward`). The planner may adjust this if the clips look wrong in the gym; flag it in the plan. — **Reversibility:** reversible — a clip choice per direction.

**Aim mode: camera and crosshair**
- **D-13:** The aim camera sits over the **right shoulder** (the prosthesis is the right arm), with a swap key to the left shoulder. This adds a new Input Map action (name to be chosen by the planner, e.g. `aim_shoulder_swap`, KB+M default and gamepad reserved) documented in `docs/CONVENTIONS.md`. — **Reversibility:** costly — action names are referenced from code (Phase 1 D-15).
- **D-14:** FOV becomes slightly tighter in aim (about 10 to 15 degrees) with a fast blend (about 0.15 to 0.2 s). Both are tunable in the F2 panel. The blend uses the additive FOV/offset sources of `CameraRig` (Phase 2 D-18), so Phase 11 camera kick still stacks on top.
- **D-15:** The crosshair is a small dot with a thin ring. The ring is reserved for Phase 4 states (it glows turquoise when a target is locked). It is shown only while aiming. Mouse sensitivity in aim follows the CAM-03 settings; a separate aim sensitivity factor is Claude's discretion.

### Claude's Discretion
- Pirouette direction (clockwise or in the movement direction), exact timing curve, and the pitch angles of the dash lean and the stretch lean.
- Run clip speed scaling against ground speed (`Running_A` playback speed, idle variant), blend times between states (the current state machine uses 0.1 s cross-fades), and foot sliding tolerance.
- Aim run-speed factor, aim sensitivity factor, exact FOV and offset values, crosshair size and colours.
- New input action name for the shoulder swap and the exact bone filter for the upper-body layer.
- Whether `Dodge_Left/Right/Backward` is enough for aim-mode dash (D-12) or needs a fallback.

### Deferred Ideas (OUT OF SCOPE)
- Slide on the ground: considered and dropped (D-03). Revisit only as its own verb with a clip composition (MOVE-11).
- Second aim pose (`Ranged_2H_Aiming`, `Ranged_Bow_Aiming_Idle`) were shown but not chosen; reconsider if the 1H pose reads badly in aim mode.
- Pirouette variants (double rotation, half flip, dive) were shown and not chosen.

Out of scope for the phase (CONTEXT domain): interactable highlight and aim assist (Phase 4), shooting and arm firing look (Phases 4/6), any juice, particles or camera kick (Phases 11-12), gamepad (Phase 13), a slide verb, final hero and its fingers/prosthesis (Phase 9).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MOVE-09 | Player animations follow movement state, built only from the KayKit Rig_Medium kit (clips, cuts, blends, playback speed, procedural root/visual rotation and scale) | New AnimationTree layout (StateMachine > TimeScale > Land OneShot > Aim Blend2), BlendSpace2D locomotion, `ProceduralPose` for lean and pirouette, clip cuts via `AnimationNodeAnimation.use_custom_timeline`, root motion cancel via `root_motion_track` (all VERIFIED, see Standard Stack and Code Examples) |
| MOVE-11 | Movement verbs are limited to what the animation kit supports; a new verb needs a kit clip or a clip composition | Verb-to-clip table (Architecture Patterns), `docs/ANIMATION-MAP.md` plus a guard test that fails when an FSM state or a referenced clip has no entry (Validation Architecture) |
| CAM-02 | Holding the aim button blends into an aim mode with crosshair, tighter FOV and shoulder offset | `CameraRig` additive `&"aim"` sources driven by an eased weight, `aim_shoulder_swap` action, procedural `Crosshair` CanvasLayer, aim facing in `PlayerController`, `aim_changed` EventBus fact |
</phase_requirements>

## Summary

The Phase 2 animation graph cannot carry this phase as it stands. Three verified problems drive the design. (1) A `Land` state in the root state machine behaves as a landing lock: after `travel(Locomotion)` the tree stayed in `Land` for 29 more frames (about 0.48 s at 60 fps) because the only edge out is `AUTO + AT_END`; a second edge between the same pair is refused by the engine. Land must become an `AnimationNodeOneShot` layer that can be faded out at once (verified: inactive 7 frames after `FADE_OUT`). (2) The aim layer needs a `Blend2` above the state machine, so the tree root becomes an `AnimationNodeBlendTree` and every parameter path moves (`parameters/playback` becomes `parameters/StateMachine/playback`); four existing smoke tests read the old paths. (3) The `Running_Strafe_Left/Right` clips rotate the `root` bone by +60 and -60 degrees, so naively layering `Ranged_1H_Aiming` on the upper body leaves the aiming arm pointing 10 to 114 degrees off forward depending on the locomotion blend. The fix that worked in the scratch run is a small `SkeletonModifier3D` that rotates `spine` and `chest` until the arm points at a target direction (residual error 0.00 degrees in all five locomotion cases). That same modifier supplies D-11's "arm points at the crosshair at any camera pitch".

Everything else is straightforward Godot: the lean and the pirouette are a transform on the `Mannequin` node (child of `VisualRoot`, set inside the physics tick so interpolation smooths it), the aim camera is two `CameraRig` source writes driven by an eased weight, the crosshair is a procedural `_draw` Control (no new asset, so the 31-file asset whitelist stays untouched except for the one new animation GLB), and run, strafe and backwards playback speeds are driven by one top-level `AnimationNodeTimeScale`. The KayKit clips are authored far slower than the 8.5 m/s run speed (measured stance-foot speed of `Running_A` is about 2.8 to 3.0 m/s), so foot sliding is a tuning compromise, not a defect to solve.

Two repo guards will fail unless handled in the same plan: `test_feedback_guard` scans `scripts/player` including comments for the tokens `Tween` and `shake` (so lean and pirouette easing must be hand-written math), and `test_movement_metrics` fails when `MovementConfig` gains a float that is not in the generated `docs/MOVEMENT-METRICS.md` snapshot (regenerate with the measure tool after adding the aim speed fields).

**Primary recommendation:** Rebuild the AnimationTree as `BlendTree[StateMachine > TimeScale > OneShot(Land) > Blend2(Aim, upper-body filter)]` with a `BlendSpace2D` locomotion state (idle, run, two strafes, backwards), add `ProceduralPose` (lean and pirouette on the `Mannequin` node) and an `AimPoseModifier` (arm-direction solver on `spine`/`chest`), drive aim camera and crosshair from one `aim_changed` fact, and update the four animation tests through one shared fixture helper.

## Architectural Responsibility Map

This is a single-process desktop game, so tiers are the game's own layers rather than web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Aim hold detection, aim facing, aim speed factor | Gameplay simulation (`PlayerController`, 60 TPS physics tick) | Input Map | Facing and speed change motion, so they live in the tick that owns `move_velocity`; presentation only reads the result |
| Animation selection from FSM state | Presentation (`MannequinAnimator`, AnimationTree) | Gameplay (`state_changed` signal) | D-08 of Phase 1: animator listens, never decides state |
| Lean and pirouette | Presentation (`ProceduralPose`, physics tick) | Gameplay (state, `chain_stage`, `long_jump_stage`) | Transform on a node under the interpolated player, so it must be written in `_physics_process` |
| Aim arm pointing and torso counter-twist | Presentation (`AimPoseModifier`, Skeleton3D pipeline) | Camera (target direction) | Must run after the AnimationMixer; SkeletonModifier3D is the supported hook |
| Aim FOV, shoulder offset, aim sensitivity | Camera (`CameraRig`, `_process`) | Event bus (`aim_changed`) | Phase 2 D-18 additive sources; camera runs in `_process` with interpolation off |
| Crosshair | HUD (`CanvasLayer` + `Control`) | Event bus | Screen space, shown only while aiming; Phase 4 adds a lock state |
| Tuning (aim speed factor, lean angles) | Config (`MovementConfig`, F2 panel rows generated from it) | Camera exports for FOV/offset | MOVE-10: numbers live in the resource; aim run factor is named in D-10 |
| Verb-to-clip documentation and guard | Docs + test | Animator constants | MOVE-11 needs a checkable map, not prose |

## Standard Stack

No new addons and no external packages. Everything is Godot 4.7.2 built-in. Debug Draw 3D stays deferred (A39 of Phase 2).

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot `AnimationTree` + `AnimationNodeBlendTree` | 4.7.2 | Root graph holding the state machine and the layers | Needed to put `Blend2` above the state machine [VERIFIED: scratch tree built and ran headless] |
| `AnimationNodeStateMachine` | 4.7.2 | Locomotion, Jump, Fall, Dash (+ Dash variants) states | Already used; keep direct manual edges for `travel()` (Phase 1 Pitfall 4) |
| `AnimationNodeBlendSpace2D` with `sync_mode` | 4.7.2 | Idle / run / strafe L / strafe R / backwards on one 2D position | `sync_mode` with `SYNC_MODE_CYCLIC_MUTABLE` "time-scales all animations to stay in step" [CITED: docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html]; property and enum exist in 4.7.2 [VERIFIED: ClassDB query] |
| `AnimationNodeOneShot` | 4.7.2 | Jump_Land overlay that can be faded out at once | Replaces the Land state (landing lock, see Pitfall 1). Parameters `parameters/<name>/request` and `/active`; requests FIRE=1, ABORT=2, FADE_OUT=3 [CITED: docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html] |
| `AnimationNodeBlend2` + filter | 4.7.2 | Upper-body aim layer. `set_filter_path(NodePath, bool)` and `filter_enabled` live on the `AnimationNode` base class [VERIFIED: ClassDB query] | With filter on, only listed bone tracks take the second input [VERIFIED: leg kept animating, `upperarm.r` matched the clip hold pose to 0.07 degrees] |
| `AnimationNodeTimeScale` | 4.7.2 | One scalar for run/strafe/dash playback speed | Parameter `parameters/TimeScale/scale` [VERIFIED: appears in the tree parameter list] |
| `AnimationNodeAnimation` custom timeline | 4.7.2 | "Cuts": `use_custom_timeline`, `start_offset`, `timeline_length`, `stretch_time_scale`, `loop_mode` | Properties exist [VERIFIED: ClassDB]; semantics [CITED: docs.godotengine.org/en/stable/classes/class_animationnodeanimation.html]. A trimmed aim hold pose appeared on the first frame [VERIFIED] |
| `SkeletonModifier3D` (custom GDScript subclass) | 4.7.2 | Arm-direction solver. Virtual `_process_modification_with_delta(delta)`; "a modification always performs after playback process of the AnimationMixer" | [CITED: docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html]; ran correctly in the scratch project [VERIFIED] |
| `AnimationTree.root_motion_track` | 4.7.2 | Cancels the `root` bone translation of the Dodge clips | [VERIFIED: root bone position stayed (0,0,0) with the track set, was (0, 0, 0.25) without] |
| `CanvasLayer` + `Control._draw` | 4.7.2 | Crosshair dot and ring, no texture | No asset, no whitelist change |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `CameraRig` source API | repo | `set_fov_offset(&"aim", ...)`, `set_offset(&"aim", ...)` | Aim camera (D-14); Phase 11 stacks on top |
| `EventBus` | repo | New typed fact `aim_changed(active: bool)` | Crosshair and camera subscribe; convention: a new fact is a new typed signal added by the phase that needs it (CONVENTIONS.md "Event bus") |
| `MovementConfig` | repo | `aim_speed_factor` and animation numbers in new export groups | F2 panel rows are generated from it, so no panel code for these floats |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| OneShot for Land | Land as a state plus code-side `playback.start(&"Locomotion")` | Hard cut, no crossfade; OneShot gives fade in and fade out for free |
| Spine/chest counter-twist modifier | Arms-only filter plus shoulder swing | Less torso twist but the arm crosses the chest for the side-on pistol pose (the clip authors the body turned about 36 degrees); try only if the twist reads badly in the gym |
| Top-level `TimeScale` | Per-state sub-BlendTree with its own TimeScale | Top-level also shortens the 0.1 s state crossfades while scale > 1; per-state is exact but multiplies nodes. Start top-level |
| `LookAtModifier3D` / 4.6 IK nodes | custom `SkeletonModifier3D` | The built-in nodes aim a bone's forward axis at a target node; here the wanted quantity is the shoulder-to-hand direction of an authored pose, which needs the custom solver (6 lines of math, verified) |

**Installation:** none. Assets: copy `Rig_Medium_CombatRanged.glb` from `KayKit/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/` into `attimo/assets/animations/rig_medium/` (the file exists in the repo; `Rig_Medium_MovementAdvanced.glb` is already copied and already holds all `Dodge_*`, `Running_Strafe_*` and `Walking_Backwards` clips).

**Version verification:** engine pinned at `4.7.2.stable.official.ed1daf0bf`, confirmed with `Godot --version` this session. No package registry applies.

## Package Legitimacy Audit

No external packages are installed in this phase (no npm, PyPI or crates, no Godot addons). The only new asset is a CC0 KayKit GLB already tracked in the repo root `KayKit/`. Audit not applicable.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## In-Repo Facts (read this session)

Verbatim values the plans must not paraphrase. Source files were opened with Read this session.

`attimo/scripts/player/mannequin_animator.gd:9-21`
```
const STATE_TO_ANIM: Dictionary[StringName, StringName] = {
	&"Idle": &"Locomotion",
	&"Run": &"Locomotion",
	&"Jump": &"Jump",
	&"LongJump": &"Jump",
	&"Fall": &"Fall",
	&"Dash": &"Dash",
}
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"LongJump"]
const RUNNING_STATES: Array[StringName] = [&"Run"]
```
`mannequin_animator.gd:27-28`: `_playback = animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback` and `state_machine.state_changed.connect(_on_state_changed)`. Line 32 sets `parameters/Locomotion/blend_position` to `1.0 if RUNNING_STATES.has(to_state) else 0.0`. Line 33-35: landing from an airborne state into `Idle` calls `_playback.travel(&"Land")`.

`attimo/tools/build_animation_library.gd:6-14`
```
const SOURCES: Array[String] = [
	"res://assets/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
]
const OUTPUT: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const WANTED: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward"]
const LOOPING: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Idle"]
```
`attimo/tools/build_mannequin_state_machine.gd:7,28-30`: `const XFADE_TIME: float = 0.1`; auto edges `_machine.add_transition(&"Start", &"Locomotion", _auto_edge(false))`, `... &"Jump", &"Fall", _auto_edge(true))`, `... &"Land", &"Locomotion", _auto_edge(true))`. Its direct-edge list (lines 33-39) has no `Land -> Locomotion` edge.

`attimo/scripts/camera/camera_rig.gd`: `func set_fov_offset(source: StringName, degrees: float) -> void:` (line 256), `func clear_fov_offset(source: StringName) -> void:` (261), `func set_offset(source: StringName, offset: Vector3) -> void:` (277), `func clear_offset(source: StringName) -> void:` (282), `func steering_yaw() -> float:` (297), `var yaw: float = 0.0` (70), `@export var base_fov: float = 75.0` (39), `@export var base_sensitivity: float = 0.0022` (33). Per-frame application at lines 186-187: `spring_arm.position = _offset_total()` and `camera.fov = get_fov_total()`. The rig runs in `_process`, is `top_level` with physics interpolation off.

`attimo/autoload/event_bus.gd:5-12`: `signal jumped(position: Vector3)`, `signal landed(position: Vector3, impact_speed: float)`, `signal dash_started(position: Vector3, direction: Vector3, in_air: bool)`, `signal movement_state_changed(from_state: StringName, to_state: StringName)`, `signal long_jumped(position: Vector3, stage: int)`, `signal chain_stage_changed(stage: int)`.

`attimo/scripts/player/player_controller.gd:118-129`: `func face(direction: Vector3, delta: float) -> void:` lerps `visual_root.rotation.y` toward `atan2(direction.x, direction.z)` at `config.turn_rate`; `func face_now(direction: Vector3) -> void:` sets `visual_root.rotation.y = atan2(direction.x, direction.z)`. Public vars: `var chain_stage: int = 0` (30), `var long_jump_stage: int = 0` (32), `var last_dash_direction: Vector3` (28). Both `chain_stage` and `long_jump_stage` are already updated when `Jump.enter` / `LongJump.enter` run, which happens before `state_changed` is emitted (`state_machine.gd` `transition_to`: `current.enter(previous)` then `state_changed.emit(previous, next)`).

`attimo/scripts/player/movement_config.gd`: `@export_range(1.0, 20.0, 0.1) var run_speed: float = 8.5` and `@export_range(0.05, 1.0, 0.01) var dash_time: float = 0.18`.

`attimo/tests/smoke/test_feedback_guard.gd:6,18-26`: `GAMEPLAY_DIRS ... ["res://scripts/core", "res://scripts/player", "res://autoload"]`; `FORBIDDEN_TOKENS` are `"AudioStreamPlayer", "GPUParticles", "CPUParticles", "create_tween", "Tween", "Engine.time_scale", "shake"`; line 4: "The scan includes comments on purpose".

`docs/CONVENTIONS.md:115`: `| `aim` | Right mouse button | L2 / LT | Hold. |`. Line 146: "Rotate or scale only `VisualRoot`, inside the physics tick." Line 157: "The clip `Dodge_Forward` shifts the root bone by +0.25 m. Phase 3 decides how to handle it."

## Measured Clip Facts (this session)

All numbers come from scratch scripts run headless on the pinned binary against the raw KayKit GLBs and against a copy of the project [VERIFIED: scratch runs]. Skeleton scale is 1.0, so skeleton units are meters.

| Clip | Length | Facts that matter |
|------|--------|-------------------|
| `Idle_A` | 1.067 s | Seamless loop (first/last frame differ 0.00 deg) |
| `Running_A` | 0.800 s | Seamless loop. Stance-foot travel speed about 2.8 to 3.0 m/s (rough, plus or minus 30 percent) against `run_speed` 8.5. Hips pitch 11 to 17 deg |
| `Running_B` | 0.800 s | Stance-foot speed about 4.4 to 4.8 m/s. MOVE-09 names `Running_A`, so this is only a note |
| `Running_Strafe_Left` / `_Right` | 0.800 s each | Seamless loops, same length as `Running_A`. They key the `root` bone yaw at +60 deg (left) and -60 deg (right), with spine yaw counter-twisting from -34 to -3 deg. Mannequin faces +Z, its left is +X |
| `Walking_Backwards` | 1.067 s | Seamless loop. Natural travel speed only about 0.5 to 0.7 m/s, so at game speeds it slides heavily. `spine` yaw constant 32 deg |
| `Ranged_1H_Aiming` | 1.067 s | NOT a loop (first/last frame differ 68 deg). Raises the arm over roughly 0.5 s, then holds a static pose from about 0.6 s. Right arm points forward-right-down (skeleton space direction about (-0.34, -0.16, 0.93)); left arm bent back. Authored with the whole body turned left about 36 deg (root yaw up to 15, hips 20) |
| `Jump_Start` | 0.600 s | Hips Y: 0.392 at 0.00, crouch bottom 0.276 at 0.25, extension 0.506 reached at 0.40, then constant. A 0.25 s crouch that starts at the moment the body already rises |
| `Jump_Idle` | 1.067 s | Seamless loop |
| `Jump_Land` | 0.667 s | Hips Y: 0.506 at touch, crouch bottom 0.245 at 0.20 to 0.25, back to 0.392 by 0.55 |
| `Dodge_Forward` | 0.400 s | Torso already leans forward inside the clip: hips 17 deg, chest 28 deg at the end. `root` translates +0.25 m in Z (hips +0.083 more) |
| `Dodge_Left` / `_Right` | 0.400 s | `root` translates +0.5 m in X (left) or -0.5 m (right); hips constant 0.353 from 0.10 s |
| `Dodge_Backward` | 0.400 s | `root` translates -0.65 m in Z; chest leans 13 deg forward |

Library facts: every clip in the source GLBs has `loop_mode` 0 (non-looping), so the library tool must keep declaring loops. `Running_Strafe_Left`, `Running_Strafe_Right` and `Walking_Backwards` are seamless and belong in `LOOPING`; `Ranged_1H_Aiming` does not.

## Architecture Patterns

### System Architecture Diagram

```
Input actions: move_*, jump, dash, aim (hold), aim_shoulder_swap (new), mouse motion
  |
  v
PlayerController._physics_process  (60 TPS; every write interpolated)
  |-- _tick_timers (existing)  +  _tick_aim: aiming = Input.is_action_pressed(aim)
  |       on change -> EventBus.aim_changed(active)            [fact, no logic]
  |-- _apply_aim_facing: if aiming, VisualRoot yaw = CameraRig.yaw   (BEFORE the states run)
  |-- StateMachine.physics_update -> Idle/Run/Jump/LongJump/Fall/Dash
  |       face()/face_now() become no-ops while aiming (aim owns facing)
  |       ground target speed = run_speed * (aiming ? aim_speed_factor : 1)
  |       state_changed(from,to) --------------------------------------+
  |-- _integrate (single move_and_slide)                               |
  v                                                                    v
ProceduralPose (physics tick)                          MannequinAnimator
  Mannequin node transform =                             travel() on same call as the state change
  lean (pitch toward travel dir)                         Land OneShot: FIRE on landing into Idle,
  + pirouette (360 yaw) about hips pivot                              FADE_OUT on Run / Dash / Jump
  (reads chain_stage, long_jump_stage,                   dash clip by dash dir vs facing (aim)
   Dash in_air, aiming)                                  _process: smooth + write parameters
                                                           Locomotion/blend_position (Vector2)
                                                           TimeScale/scale, Aim/blend_amount
                                                                   |
                                                                   v
AnimationTree root = BlendTree
  StateMachine -> TimeScale -> OneShot(Land) -> Blend2(Aim, upper-body filter) -> output
                                                       ^ Ranged_1H_Aiming (cut to its hold pose)
                                                                   |
                                                                   v
Skeleton3D -> AimPoseModifier (runs after the AnimationMixer)
  rotates spine + chest so shoulder->hand points at target_direction, clamped, influence = aim weight

EventBus.aim_changed ---> CameraRig: eased aim weight w
                              set_fov_offset(&"aim", -fov_delta * w)
                              set_offset(&"aim", Vector3(side * shoulder_x * w, 0, 0))   (Pitch-local, +X = right)
                              look sensitivity *= lerp(1, aim_sensitivity_factor, w)
                          Crosshair (CanvasLayer): visible only while aiming (dot + ring, _draw)
```

### Recommended Project Structure
```
attimo/
├── scripts/player/
│   ├── mannequin_animator.gd      # extended: new graph, parameter driving, dash clip variants, Land OneShot
│   ├── procedural_pose.gd         # NEW: lean + pirouette on the Mannequin node (class ProceduralPose)
│   ├── aim_pose_modifier.gd       # NEW: SkeletonModifier3D arm-direction solver (class AimPoseModifier)
│   └── player_controller.gd       # aiming flag, aim facing, ground_target_speed()
├── scripts/camera/camera_rig.gd   # aim weight, sources, shoulder swap, aim sensitivity
├── scripts/ui/crosshair.gd        # NEW (class Crosshair); scenes/ui/crosshair.tscn NEW
├── scenes/player/mannequin.tscn   # tree_root -> new BlendTree resource, root_motion_track, modifier node
├── tools/build_mannequin_state_machine.gd   # rewritten to emit the BlendTree (rename recommended)
├── tools/build_animation_library.gd         # +CombatRanged source, +8 clips, loop flags
└── tools/movement_gym_builder.gd  # instance the crosshair, then regenerate the gym
docs/ANIMATION-MAP.md              # NEW: verb -> clip composition (MOVE-11)
```

### Pattern 1: BlendTree root with the state machine as one node
**What:** `AnimationNodeBlendTree` containing `StateMachine`, `TimeScale`, `Land` (OneShot), `LandClip`, `Aim` (Blend2, filter on), `AimClip`, wired `StateMachine -> TimeScale -> Land[0]`, `LandClip -> Land[1]`, `Land -> Aim[0]`, `AimClip -> Aim[1]`, `Aim -> output`.
**When to use:** always for this phase.
**Resulting parameter paths** [VERIFIED: printed from the live tree]: `parameters/StateMachine/playback`, `parameters/StateMachine/Locomotion/blend_position`, `parameters/TimeScale/scale`, `parameters/Land/request`, `parameters/Land/active`, `parameters/Aim/blend_amount`.

### Pattern 2: One locomotion BlendSpace2D for both modes
**What:** Points (x = strafe, right is +; y = forward): idle (0,0), run (0,1), strafe_l (-1,0), strafe_r (1,0), back (0,-1); `min_space` (-1,-1), `max_space` (1,1), `sync_mode = SYNC_MODE_CYCLIC_MUTABLE`. Outside aim the animator writes `Vector2(0, speed / run_speed)`. In aim it writes the velocity in the facing frame: `local = visual_root.global_basis.inverse() * move_velocity`, `position = Vector2(-local.x, local.z) / (run_speed * aim_speed_factor)` (Mannequin left is +X, so a left strafe gives negative x).
**Why:** one node means aim entry only moves the blend position (no 1D to 2D hand-over); outside aim forcing x = 0 avoids strafe bits while the facing lags the input during turns.
**Smooth in `_process`** with `move_toward` at about 10 per second so the idle-to-run blend crossfades instead of cutting. The current code writes 0.0 or 1.0 in the signal handler (a hard cut inside Locomotion). Writing the first target on the state-change call keeps "same frame".

### Pattern 3: Land as a OneShot overlay
FIRE on `state_changed` from an airborne state into `Idle`. FADE_OUT (fade 0.1 s) on `Idle -> Run`, on any move into `Dash` or `Jump`, so the crouch never delays control. Landing into `Run` fires nothing, as today. Optionally shorten the clip with a custom timeline (`timeline_length` about 0.3 s with `stretch_time_scale = true`) so the bounce reads as short (D-08 "short blend").

### Pattern 4: Procedural pose on the Mannequin node
`ProceduralPose` is a child of `Player`, reads `state_changed`, and every physics tick writes `mannequin.transform` as `T(p) * R * T(-p)` with `p = (0, hips_height, 0)` (hips world Y is 0.392 at rest and 0.437 in the run clip [VERIFIED: skeleton read]; start with 0.45). This pivots the stretch lean about the body centre instead of the feet. Lean axis for a travel direction `d` (world, flattened) is `up x d` expressed in `VisualRoot` space, so the same code leans along the dash direction when facing and travel differ (aim mode). Use hand-written `move_toward` easing; do NOT use any tween class (guard test).
- Why a child transform and not `visual_root.rotation`: `PlayerController.face()` lerps `visual_root.rotation.y`, and `Dash`, `LongJump` and `CameraRig.recenter()` read `visual_root.global_basis.z` as the facing. A 360 degree spin on `VisualRoot` itself would corrupt all of those mid-air. This keeps the intent of D-01/D-07 (code rotation in the visual hierarchy under the player, one parameter) with a node that nothing reads for facing. Flag to the user as a deliberate deviation from the letter of "on VisualRoot".
- Lean continuity (D-01 to D-04): the pitch is a state variable eased toward a per-state target (ground dash `dash_lean`, long jump `stretch_lean`, else 0). Because it eases from where it is, the Dash to LongJump hand-over is continuous by construction. Ramp in about 0.05 s (so it starts on the first tick, no anticipation), ramp out about 0.12 s.
- Pirouette (D-07): angle 0 to 2 pi about the vertical axis. A closed-loop rate, `rate = remaining_angle / max(predicted_time_left * 0.9, epsilon)`, with `predicted_time_left` from the current `vertical_speed`, altitude above take-off and the config gravities, copes with the release cut and variable heights; on landing, finish any remainder within about 0.1 s. Alternatives (fixed rate from the ideal airtime) leave a visible unfinished spin after a cut jump. The metrics doc gives airtime 0.83 s for a full Jump 3 at run speed.
- Composition for long jump stage 3 (D-05): yaw outside pitch gives a tilted spinning top; pitch outside yaw gives a corkscrew about the body axis. Make the nesting a single switch and judge in the gym (A4).
- Suppress the pirouette and reduce the lean while aiming (aim owns facing, D-09). Cancel the pirouette on an air dash. Both are assumptions to confirm (Assumptions Log A3).

### Pattern 5: Aim layer plus arm-direction solver
Blend2 inputs: 0 = main (locomotion, Land), 1 = `Ranged_1H_Aiming` as an `AnimationNodeAnimation` with `use_custom_timeline = true`, `start_offset = 0.6`, `timeline_length = 0.4`, `loop_mode = Animation.LOOP_NONE` [VERIFIED: hold pose on the first frame; with `LOOP_LINEAR` the clip wraps back through the raise every cycle, observed as 25 to 35 degree swing]. Filter paths use the clip track prefix `Rig_Medium/Skeleton3D:` plus `spine, chest, head, upperarm.l, lowerarm.l, wrist.l, hand.l, handslot.l, upperarm.r, lowerarm.r, wrist.r, hand.r, handslot.r`. `handslot.*` do not exist on the Mannequin (CONVENTIONS line 156); filter entries for missing bones are harmless in the scratch run.
Do not add `hips` or `root` to the filter: `hips` makes strafes impossible to read as pelvis motion, and `root` carries the strafe yaw that gives the legs their direction.
`AimPoseModifier` (child of `Skeleton3D`) rotates `spine` by a share of the needed rotation, re-reads the arm, then rotates `chest` by the rest, so the shoulder-to-hand direction equals `target_direction` (skeleton space). Measured arm error before correction at aim weight 1 (no modifier): idle 51, run 60, strafe L 9, strafe R 114, back 56 degrees; after correction 0.00 in every case [VERIFIED]. Strafe R at 114 degrees is the problem case (pelvis turned -60 plus the authored side-on stance). Add `max_twist_deg` and eyeball it (Open Question 1).
`influence` is applied by the Skeleton3D, so set it to the aim weight for a free blend in and out. Target direction: `normalize(camera_point - shoulder_world)` with `camera_point = camera_origin + camera_forward * converge_distance` (start 15 m), converted into skeleton space with the inverse skeleton global basis; this accounts for the shoulder-to-crosshair parallax. Phase 4 can replace `camera_point` with the ray hit.

### Pattern 6: Aim camera
`CameraRig` owns an eased `aim_weight` (move toward 1 or 0 at `1 / aim_blend_time` per second, then smoothstep), connected to `EventBus.aim_changed`. Each `_process` it writes `set_fov_offset(&"aim", -aim_fov_delta * w)` and `set_offset(&"aim", Vector3(side * aim_shoulder_offset * w, 0.0, 0.0))` (`Pitch`-local X is camera right; the arm cast origin includes the offset, so wall collision accounts for it, per the existing doc comment). `side` is +1 (right) or -1 (left) and is itself eased so the swap slides. Start values (Assumptions Log A2): `aim_fov_delta` 12 degrees, `aim_shoulder_offset` 0.6 m, `aim_blend_time` 0.18 s, `aim_sensitivity_factor` 0.8. FOV-proportional sensitivity for -12 degrees at base 75 is tan(31.5)/tan(37.5) = 0.80 (computed).
Disable `recenter()` and auto-follow while aiming and use `rig.yaw` for facing (not `steering_yaw()`), or W will strafe by the leftover auto-follow offset (Pitfall 9).

### Anti-Patterns to Avoid
- **Land as a state with an AT_END edge:** lock of up to about 0.57 s (Pitfall 1).
- **Spinning `VisualRoot` itself:** breaks every facing reader (Pattern 4).
- **Second `add_transition` between the same pair:** the engine refuses it, so an "AUTO at end plus manual immediate" pair cannot coexist [VERIFIED: error on the duplicate `Land -> Locomotion` in the scratch builder].
- **Reading modifier results through `Skeleton3D` from tests:** the outside read returned the unmodified animation pose [VERIFIED]; assert on values the modifier records itself.
- **Putting layer weights in `_physics_process` at 10 TPS:** parameters step per tick; smooth in `_process`.
- **Untyped GDScript anywhere** (including tools and tests): the project turns untyped declarations into parse errors (hit during the scratch runs).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Idle/run/strafe/back blend with cycle matching | Per-clip weights and manual phase sync | `AnimationNodeBlendSpace2D` + `sync_mode` CYCLIC_MUTABLE | Different lengths (0.8 vs 1.067 s) would drift out of phase otherwise |
| Upper-body versus lower-body layering | Writing bone poses after the tree | `Blend2` with filter paths | The tree owns the pose each frame; late writes race it |
| Aim arm and torso fix-up | Writing into `Skeleton3D` from `_process` | `SkeletonModifier3D` | Guaranteed to run after the AnimationMixer, influence blending included |
| Transient landing clip with abort | Land state plus waiting for the clip | `AnimationNodeOneShot` FADE_OUT | Measured 7 frames to inactive |
| Removing the Dodge root drift | Editing clip data | `AnimationTree.root_motion_track` | Verified zero root translation, no data change |
| Clip speed/offset/stretch | Duplicating and trimming `Animation` resources | `AnimationNodeAnimation` custom timeline and `AnimationNodeTimeScale` | "Cuts" stay non-destructive, the library stays a plain merge |
| Crosshair art | PNG assets | `Control._draw` with `draw_circle` / `draw_arc` | Avoids the 31-entry asset whitelist and import files |
| Easing lean/pirouette | Tween classes | Hand-written `move_toward` / exponential smoothing | `test_feedback_guard` bans the token in `scripts/player`, comments included |

**Key insight:** every fix this phase needs is a built-in node plus a small piece of math. The risk is not missing machinery, it is the interaction of three things the Phase 2 code assumed away: a flat state-machine root, a single facing owner, and clips authored for much lower speeds.

## Runtime State Inventory

Not a rename or migration phase. Omitted deliberately. One adjacent note: the generated `res://scenes/test/movement_gym.tscn` is built by `tools/build_movement_gym.gd`; hand edits are lost on regeneration, so the crosshair must be added in `tools/movement_gym_builder.gd` and the gym regenerated. `res://scenes/test/test_scene.tscn` is hand-maintained and instances the debug overlays directly.

## Common Pitfalls

### Pitfall 1: Landing lock through the Land state
**What goes wrong:** Idle landing then Run input leaves the crouch pose playing while the character runs.
**Why it happens:** the only edge `Land -> Locomotion` is `ADVANCE_MODE_AUTO` with `SWITCH_MODE_AT_END`, and `travel()` honours AT_END. Measured: 29 frames after `travel(Locomotion)` at 60 fps (Land clip is 40 frames). A second manual edge is rejected by the engine.
**How to avoid:** Land becomes a OneShot overlay (Pattern 3). Add a test that fires Land, requests FADE_OUT and asserts `parameters/Land/active` is false within 8 frames.
**Warning signs:** `playback.get_current_node() == &"Land"` after a movement input.

### Pitfall 2: Parameter paths move
**What goes wrong:** `get(&"parameters/playback")` returns null, tests and animator crash on `.travel`.
**Why it happens:** the BlendTree root nests the state machine under `StateMachine`.
**How to avoid:** introduce one fixture helper (for example `Fixtures.playback(player)` and `Fixtures.locomotion_param(player)`) and migrate `test_mannequin_animation`, `test_movement_facts`, `test_dash`, `test_scene_run` in the same plan. Those four read `parameters/playback`, `parameters/Locomotion/blend_position` and `Land`/`Locomotion` node names; `test_dash` and `test_scene_run` also wait for `Dash` as the current node, which stays valid.

### Pitfall 3: Strafe clips carry +-60 degree root yaw
**What goes wrong:** the aimed arm points far off forward while strafing right; torso needs an implausible counter-twist.
**Why it happens:** `Running_Strafe_*` rotate the `root` bone and counter-twist the spine inside the clip; the aim clip's torso rotations are relative to a different pelvis.
**How to avoid:** the arm-direction solver, a `max_twist_deg` clamp, and a gym check of strafe right first. Do not filter `root` or `hips` into the aim layer.

### Pitfall 4: `Ranged_1H_Aiming` is not a loop
**What goes wrong:** with a loop mode the clip replays the arm raise every cycle.
**How to avoid:** `LOOP_NONE` with `start_offset` 0.6 on the node; do not add it to `LOOPING` in the library tool.

### Pitfall 5: Root drift of the Dodge clips
**What goes wrong:** `Dodge_Forward` offsets the visual +0.25 m, `Dodge_Left/Right` 0.5 m, `Dodge_Backward` -0.65 m, then snaps back on the 0.1 s crossfade.
**How to avoid:** set `root_motion_track = NodePath("Rig_Medium/Skeleton3D:root")` on the AnimationTree in `mannequin.tscn` [VERIFIED]. CONVENTIONS line 157 expects Phase 3 to decide; record the decision there.

### Pitfall 6: Clip lengths against game timings
**What goes wrong:** `dash_time` is 0.18 s but the Dodge clips are 0.4 s, so only the first 45 percent plays; `Jump_Start` spends its first 0.25 s crouching while the body already rises.
**How to avoid:** stretch Dodge to `dash_time` through `TimeScale` (0.4 / dash_time, live-tunable); trim `Jump_Start` with `start_offset` about 0.2 to 0.25 (crouch bottom to extension), tune in the gym. This is the "re-cut" MOVE-09 allows, and it addresses ROADMAP criterion 4's "no anticipation longer than 2 frames" for the jump.

### Pitfall 7: Feedback guard and comment words
**What goes wrong:** `test_feedback_guard` fails on the substring `Tween` or `shake` anywhere under `scripts/core`, `scripts/player`, `autoload`, comments included.
**How to avoid:** no tween classes there, and phrase comments without those words. `scripts/camera` and `scripts/ui` are not scanned, but keep the easing style consistent.

### Pitfall 8: Drift guards
**What goes wrong:** (a) a new `MovementConfig` float fails `test_movement_metrics` until `docs/MOVEMENT-METRICS.md` is regenerated (`bash attimo/tests/run.sh --tool res://tools/measure_movement.gd`); (b) `test_asset_hygiene` asserts the whitelist has exactly 31 entries; (c) `tests/run.sh` has an `ORIGINALS` array of tracked KayKit files; (d) `test_input_map` and `test_conventions` carry the action lists and doc checks.
**How to avoid:** change the asset, the whitelist (31 to 33: `Rig_Medium_CombatRanged.glb` and its `.import`), the count assertion, `ORIGINALS` and the action lists in the same commit.

### Pitfall 9: Aim facing versus steering yaw
**What goes wrong:** W moves slightly sideways in aim after a recenter or auto-follow; the strafe blend shows a phantom strafe.
**Why it happens:** `input_direction()` uses `rig.steering_yaw()` which excludes the auto-follow and recenter offset, while aim facing uses `rig.yaw`.
**How to avoid:** ignore `camera_recenter` and auto-follow while aiming, and zero the steering offset on aim enter. Decide explicitly in the plan.

### Pitfall 10: Aim facing, face_now and dash direction
**What goes wrong:** `Dash.enter` and `LongJump.enter` call `actor.face_now(direction)`, which would rotate the figure away from the crosshair; `Dash.enter` falls back to `visual_root.global_basis.z` when there is no input.
**How to avoid:** `face()` and `face_now()` early-return while aiming; apply the aim yaw before the state update each tick so the fallback reads the camera facing. Classify the Dodge clip from the dash direction against the facing at `enter` (the animator runs right after `enter`, `Dash.enter` has already set the direction in `last_dash_direction`).

### Pitfall 11: Modifier results are not observable from outside
**What goes wrong:** a test reading `Skeleton3D.get_bone_global_pose` sees the unmodified pose and "proves" nothing, or wrongly fails.
**How to avoid:** have `AimPoseModifier` record `last_error_deg` / `last_target` and assert on those.

### Pitfall 12: Headless animation timing is wall-clock
**What goes wrong:** frame-count assertions on pose time flake, because AnimationTree advances by the real process delta in a headless run (measured: without `--fixed-fps 60` the Jump to Fall hand-off took 3 frames instead of the expected 36).
**How to avoid:** assert on state and parameters, use `wait_until` with tick budgets (the existing `TREE_TRAVEL_TICKS` style), or set `callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` in a test and call `advance(1.0 / 60.0)` per physics frame. The project's own runner does not pass `--fixed-fps`.

### Pitfall 13: Interpolation
**What goes wrong:** lean or pirouette written in `_process` jitters or is ignored, because `Mannequin` sits under an interpolated `CharacterBody3D`.
**How to avoid:** write it in `_physics_process` only. At the 10 TPS diagnostic rate a full pirouette in 0.83 s is about 8 ticks, 45 degrees per tick, still well under the 180 degree per-tick limit of quaternion interpolation.

## Code Examples

### Tree builder skeleton (verified API calls)
```gdscript
# Source: scratch tool run on Godot 4.7.2 (tools/proto_tree.gd in the session scratchpad); API per
# docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html and ..._animationnodeoneshot.html
const SKEL: String = "Rig_Medium/Skeleton3D:"
const UPPER: Array[String] = ["spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r"]

var loco: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
loco.min_space = Vector2(-1, -1)
loco.max_space = Vector2(1, 1)
loco.sync_mode = AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE
loco.add_blend_point(_clip(&"Idle_A"), Vector2(0, 0), -1, &"idle")          # name argument avoids the engine warning
loco.add_blend_point(_clip(&"Running_A"), Vector2(0, 1), -1, &"run")
loco.add_blend_point(_clip(&"Running_Strafe_Left"), Vector2(-1, 0), -1, &"strafe_l")
loco.add_blend_point(_clip(&"Running_Strafe_Right"), Vector2(1, 0), -1, &"strafe_r")
loco.add_blend_point(_clip(&"Walking_Backwards"), Vector2(0, -1), -1, &"back")

var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
tree.add_node(&"StateMachine", machine)
tree.add_node(&"TimeScale", AnimationNodeTimeScale.new())
var land: AnimationNodeOneShot = AnimationNodeOneShot.new()
land.fadein_time = 0.05
land.fadeout_time = 0.1
tree.add_node(&"Land", land)
tree.add_node(&"LandClip", _clip(&"Jump_Land"))
var aim: AnimationNodeBlend2 = AnimationNodeBlend2.new()
aim.filter_enabled = true
for bone: String in UPPER:
	aim.set_filter_path(NodePath(SKEL + bone), true)
tree.add_node(&"Aim", aim)
var aim_clip: AnimationNodeAnimation = _clip(&"Ranged_1H_Aiming")
aim_clip.use_custom_timeline = true
aim_clip.start_offset = 0.6
aim_clip.timeline_length = 0.4
aim_clip.loop_mode = Animation.LOOP_NONE
tree.add_node(&"AimClip", aim_clip)
tree.connect_node(&"TimeScale", 0, &"StateMachine")   # connect_node(input_node, input_index, output_node)
tree.connect_node(&"Land", 0, &"TimeScale")
tree.connect_node(&"Land", 1, &"LandClip")
tree.connect_node(&"Aim", 0, &"Land")
tree.connect_node(&"Aim", 1, &"AimClip")
tree.connect_node(&"output", 0, &"Aim")
```
In the state machine, every pair of the manual states needs one direct `ADVANCE_MODE_ENABLED` + `SWITCH_MODE_IMMEDIATE` edge (0.1 s xfade, as the current builder does), plus the two auto edges `Start -> Locomotion` and `Jump -> Fall` (AT_END). No `Land` state any more. Add `DashLeft`, `DashRight`, `DashBack` (clips `Dodge_Left`, `Dodge_Right`, `Dodge_Backward`) as additional states.

### Animator parameter driving (design sketch; the parameter names are verified, the policy is assumed)
```gdscript
const P_LOCO: StringName = &"parameters/StateMachine/Locomotion/blend_position"
const P_SCALE: StringName = &"parameters/TimeScale/scale"
const P_LAND_REQ: StringName = &"parameters/Land/request"
const P_AIM: StringName = &"parameters/Aim/blend_amount"

func _process(delta: float) -> void:
	_loco = _loco.move_toward(_loco_target(), LOCO_BLEND_RATE * delta)
	animation_tree.set(P_LOCO, _loco)
	animation_tree.set(P_AIM, move_toward(float(animation_tree.get(P_AIM)), 1.0 if player.aiming else 0.0, delta / AIM_BLEND_TIME))
	animation_tree.set(P_SCALE, _clip_scale())

func _fire_land() -> void:
	animation_tree.set(P_LAND_REQ, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
func _fade_land() -> void:
	animation_tree.set(P_LAND_REQ, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
```
`_clip_scale()` returns `0.4 / config.dash_time` in any Dash state, `clampf(speed / run_ref_speed, 1.0, max_scale)` in Locomotion, 1.0 otherwise. Start `run_ref_speed` near 4.5 m/s so run plays at about 1.9x (assumption A2); sliding is accepted.

### Arm-direction solver (core verified)
```gdscript
# Source: scratch run on Godot 4.7.2; in-modifier residual error 0.00 deg for idle, run, both strafes, back
class_name AimPoseModifier
extends SkeletonModifier3D

@export var target_direction: Vector3 = Vector3(0.0, 0.0, 1.0)   # skeleton space, set by the animator each frame
@export_range(0.0, 1.0, 0.05) var spine_share: float = 0.4
var last_error_deg: float = 0.0                                  # tests read this, not the Skeleton3D

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	var want: Vector3 = target_direction.normalized()
	var spine_rot: Quaternion = Quaternion.IDENTITY.slerp(Quaternion(_arm(skeleton), want), spine_share)
	_rotate(skeleton, &"spine", spine_rot)
	_rotate(skeleton, &"chest", Quaternion(_arm(skeleton), want))
	last_error_deg = rad_to_deg(_arm(skeleton).angle_to(want))

func _arm(skeleton: Skeleton3D) -> Vector3:
	var shoulder: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("upperarm.r")).origin
	var hand: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("hand.r")).origin
	return (hand - shoulder).normalized()

func _rotate(skeleton: Skeleton3D, bone: StringName, rotation_in_skeleton_space: Quaternion) -> void:
	var index: int = skeleton.find_bone(bone)
	var parent_basis: Basis = skeleton.get_bone_global_pose(skeleton.get_bone_parent(index)).basis
	var current: Basis = parent_basis * Basis(skeleton.get_bone_pose_rotation(index))
	var rotated: Basis = Basis(rotation_in_skeleton_space) * current
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * rotated).get_rotation_quaternion())
```
Add the `max_twist_deg` clamp and the camera-pitch/parallax target in the real version (the scratch code omitted both). `Quaternion(a, b)` is undefined for exactly opposite vectors; clamp before use.

### Crosshair
```gdscript
# Source: standard Control drawing (design; not run in this session)
class_name Crosshair
extends Control

@export var dot_radius: float = 2.0
@export var ring_radius: float = 14.0
@export var ring_width: float = 1.5
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.8)   # Phase 4 sets a turquoise lock colour here
var locked: bool = false                                     # reserved for Phase 4

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, dot_radius, ring_color)
	draw_arc(center, ring_radius, 0.0, TAU, 48, ring_color, ring_width, true)
```
Full-rect anchors, `mouse_filter = MOUSE_FILTER_IGNORE`, hidden until `EventBus.aim_changed(true)`, in a `CanvasLayer` at a low layer number (debug overlays use 100 to 102).

### Input action for the shoulder swap
Name `aim_shoulder_swap`, KB+M default physical key Q (`dash` is left Shift only, Q is unbound; `test_input_map` asserts `not _has_physical_key(&"dash", KEY_Q)`), gamepad slot reserved and unbound (Assumptions Log A1). Add to `project.godot`, the `ACTIONS` lists of `test_input_map.gd` and `test_conventions.gd`, and a row in the CONVENTIONS.md table. Handle it in `CameraRig._unhandled_input` next to `camera_recenter`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AnimationNodeBlendSpace2D.sync` bool | `sync_mode` enum with cyclic modes and `cyclic_length` | present in 4.7 docs; `sync` marked deprecated | Phase-matched locomotion blends without custom code [CITED: docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html] |
| `SkeletonModifier3D._process_modification()` | `_process_modification_with_delta(delta)` | `_process_modification()` documented as deprecated in 4.7 | Use the delta variant [CITED: docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html] |
| Cutting clips by editing `Animation` resources | `AnimationNodeAnimation` custom timeline | present in 4.7 | Non-destructive cuts, compatible with MOVE-09's "cuts" wording |

**Deprecated/outdated:**
- `AnimationNodeBlendSpace*.sync` bool: use `sync_mode`.
- The Phase 1 root `AnimationNodeStateMachine` resource type in `mannequin.tscn` (`ext_resource ... type="AnimationNodeStateMachine"`): the new root is an `AnimationNodeBlendTree`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Shoulder swap key is Q, gamepad slot left unbound (D-pad is a candidate, R3 is already taken by `camera_recenter`) | Code Examples | Low: a rename costs one grep (Phase 1 D-15 makes it a costly rename later, so confirm before coding) |
| A2 | Start values: `aim_speed_factor` 0.75, aim backward speed factor about 0.6, `aim_fov_delta` 12 deg, `aim_shoulder_offset` 0.6 m, `aim_blend_time` 0.18 s, `aim_sensitivity_factor` 0.8, `converge_distance` 15 m, ground dash lean about 20 deg on top of the clip's own 17 to 28 deg, stretch lean about 55 to 70 deg, run clip reference speed about 4.5 m/s, `max_twist_deg` about 70 | Patterns 4 to 6 | Low: all are tunables; pick, then tune in the gym |
| A3 | While aiming the pirouette is suppressed and lean is reduced (aim owns facing); an air dash cancels a running pirouette | Pattern 4 | Medium: user may want pirouette in aim; confirm in plan review |
| A4 | Long jump stage 3 nesting (corkscrew about the body axis rather than a tilted top) looks better | Pattern 4 | Low: one switch; judged visually |
| A5 | `Jump_Start` `start_offset` 0.2 to 0.25 and a shortened Land (about 0.3 s) read well | Pitfall 6, Pattern 3 | Low: tuning |
| A6 | Foot-slide numbers (Running_A 2.8 to 3.0 m/s, Walking_Backwards 0.5 to 0.7 m/s) are within plus or minus 30 percent; the stance detector is approximate | Measured Clip Facts | Low: only used to pick a playback scale |
| A7 | `Dodge_Left/Right/Backward` look acceptable as aim-mode dashes (D-12) and the aim layer over them reads fine | D-12 | Medium: gym check; fallback is `Dodge_Forward` plus the aim pose |
| A8 | A 114 degree solver correction for strafe right (and 50 to 60 for idle/run/back) reads acceptably with a clamp; otherwise switch to the arms-only fallback | Pattern 5 | High for the look of CAM-02/D-11, medium for schedule; needs a human gym check |
| A9 | `Mannequin` child transform is smoothed by physics interpolation like any other child of the player (documented behaviour, not run this session) | Pattern 4 | Low |
| A10 | Ignoring recenter/auto-follow while aiming is acceptable | Pitfall 9 | Low |
| A11 | CONVENTIONS says the Mannequin is about 2.2 m tall; this session the head bone sat at y 1.23 m and a skinned mesh AABB read 2.2 m (the AABB may overestimate). Not used for any number here except the hips pivot (0.39 to 0.44 m, measured) | Pattern 4 | Low |

## Open Questions

1. **Does the layered 1H aim stance read well over strafe right, run and idle?**
   - What we know: the solver gets the arm exactly on target, but needs 51 (idle), 60 (run), 56 (back), 114 (strafe R) and 9 (strafe L) degrees of spine/chest correction at weight 1; the clip's own stance is a side-on pistol pose.
   - What's unclear: whether that twist looks natural; nothing could be rendered headless.
   - Recommendation: plan a time-boxed gym checkpoint (`checkpoint:human-verify`, `human_verify_mode` is end-of-phase) with three fallbacks in order: raise `spine_share`/clamp the twist; arms-only filter plus shoulder swing; as the last resort reduce the strafe blend toward the forward run while aiming. The deferred `Ranged_2H_Aiming` is the CONTEXT-sanctioned alternate pose.
2. **The deviation "pirouette and lean on the Mannequin child node, not on VisualRoot".**
   - What we know: required to keep every facing reader correct; intent of D-01 and D-07 is preserved.
   - Recommendation: record it in the plan and note it for the user; no discuss round needed unless they object.
3. **Where do animation and aim tuning numbers live?**
   - `aim_speed_factor` must be in `MovementConfig` (D-10). Lean angles, pirouette and animation ratios fit the same resource (F2 rows free) at the cost of one `measure_movement` regeneration (Pitfall 8a). Camera aim numbers are `CameraRig` exports and need F2 rows (D-14); the panel builds camera controls by hand in `tuning_panel.tscn`, so a small generated "Aim camera" section is a plan task.
4. **Aim run speed asymmetry:** `Walking_Backwards` natural speed is far below the strafe/run speeds. A separate backward factor (A2 suggests about 0.6) keeps the slide plausible; confirm.
5. **Strafe blend near diagonals:** with sync mode cyclic mutable the diagonal back-left/back-right mixes a 1.067 s walk with a 0.8 s run cycle; if the legs look off, switch that node to `SYNC_MODE_CYCLIC_CONSTANT` with `cyclic_length` 0.8 (documented) or trim `Walking_Backwards` with a custom timeline.
6. **CAM-01 (144 Hz) stays an open verification gap from Phase 2.** Aim mode must not widen it: the aim sources only add to existing per-frame values in `_process`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot engine (pinned) | everything, headless tests and tools | yes | `4.7.2.stable.official.ed1daf0bf` at `~/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot` | none needed |
| `KayKit/.../Rig_Medium_CombatRanged.glb` | `Ranged_1H_Aiming` | yes (tracked under `KayKit/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/`) | n/a | none needed |
| git, bash | `tests/run.sh` repo checks | yes | n/a | none |
| Display / renderer | visual verification of the aim stance | no, headless only in this session | n/a | the human gym check at end of phase |

**Missing dependencies with no fallback:** none for automation. Visual quality items need a human on the developer's Mac.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Project smoke runner (`tests/run_smoke.gd`, auto-discovers `tests/smoke/test_*.gd`; each test is a `RefCounted` with `run(tree, check)`), Godot 4.7.2 headless |
| Config file | none; `tests/run.sh` wraps version gate, repo checks, import, run, error-grep |
| Quick run command | `bash attimo/tests/run.sh test_aim_mode,test_mannequin_animation,test_animation_map` |
| Full suite command | `bash attimo/tests/run.sh` (baseline measured this session in a docs-less copy: 25 test files, about 157 s; only `test_conventions` and `test_movement_metrics` failed, solely because `docs/` was absent from the copy, so the real baseline is green) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MOVE-09 | Every FSM state maps to a graph state; Dash variants chosen by dash direction against facing; ground dash lean starts within 2 ticks and is continuous into LongJump; Jump 3 and stage 3 long jump complete one 360 degree turn before landing; Land overlay inactive within 8 frames of a move; `Jump_Start`, Dodge root stays 0 | integration | `bash attimo/tests/run.sh test_mannequin_animation` (updated) and new `test_procedural_pose` | partly; update existing, add new |
| MOVE-09 | Library holds the 13 expected clips with loop flags (strafes and backwards loop, aim and dodge do not) | smoke | `bash attimo/tests/run.sh test_animation_library` | update existing (it currently asserts exactly six clips) |
| MOVE-11 | `docs/ANIMATION-MAP.md` lists every state node of the Player and every clip used by the tree builder; a new state without an entry fails | guard | `bash attimo/tests/run.sh test_animation_map` | Wave 0 |
| CAM-02 | `aim` hold sets `aiming`, emits `aim_changed`; facing equals `rig.yaw` the next tick; FOV total falls by the configured delta and the arm offset shifts right within blend time plus tolerance; release restores; shoulder swap flips the offset sign; aim speed factor lowers the run target; crosshair visible only while aiming | integration | `bash attimo/tests/run.sh test_aim_mode` | Wave 0 |
| CAM-02 | Arm points at the target direction for idle, run, strafe L/R, back (read `AimPoseModifier.last_error_deg`, not the Skeleton3D) | integration | `bash attimo/tests/run.sh test_aim_pose` | Wave 0 |
| Criterion 4 | Phase 2 latency numbers still hold; no new latency in the jump or dash fact path | regression | `bash attimo/tests/run.sh test_latency` | exists, run unchanged |
| Repo hygiene | whitelist 33 entries, `ORIGINALS` includes CombatRanged, action lists include `aim_shoulder_swap`, CONVENTIONS rows, feedback guard stays green | guard | `bash attimo/tests/run.sh test_asset_hygiene,test_input_map,test_conventions,test_feedback_guard,test_movement_metrics` | update existing |
| Visual | Aim stance, strafe R twist, pirouette and stretch composition, Dodge aim clips, run foot sliding | manual-only | gym session, end of phase | human UAT (justification: needs rendering) |

### Sampling Rate
- **Per task commit:** `bash attimo/tests/run.sh <the touched test names>` (under about 30 s)
- **Per wave merge:** full suite (about 160 s)
- **Phase gate:** full suite green, plus the human gym check, before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/fixtures.gd`: helpers `animation_tree(player)`, `playback(player)` (reads `parameters/StateMachine/playback`), `locomotion_blend(player)`; migrate `test_mannequin_animation`, `test_movement_facts`, `test_dash`, `test_scene_run` onto them
- [ ] `tests/smoke/test_aim_mode.gd`, `test_aim_pose.gd`, `test_procedural_pose.gd`, `test_animation_map.gd` (new)
- [ ] `test_animation_library.gd`: expected clip list, loop flags, lengths for the new clips
- [ ] `test_asset_hygiene.gd` whitelist and count (31 to 33), `tests/run.sh` `ORIGINALS`, `test_input_map.gd` and `test_conventions.gd` action lists
- [ ] Test for animation response in the same tick: send a state change, assert the travel/OneShot request is observable after one physics frame plus one process frame (no 15-tick tolerance)
- [ ] Regenerate `docs/MOVEMENT-METRICS.md` after `MovementConfig` additions

## Security Domain

`security_enforcement` is on (ASVS level 1, block on high). This phase adds no network, authentication, session, file-upload or cryptographic surface. It reads only repo-tracked KayKit assets and the existing Input Map.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a (offline game) |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | only if aim settings are persisted | Reuse the `CameraSettings` pattern: `ConfigFile` only, type-check and clamp every value on load, refuse paths outside `user://`, reject text containing `Object(` / `Resource(` / `SubResource(` / `ExtResource(` (existing T-02-13/14/23). Recommended default: do NOT persist aim tuning; keep it as rig exports |
| V6 Cryptography | no | n/a |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered `user://settings.cfg` carrying object syntax | Tampering | Existing `CameraSettings` forbidden-syntax check and clamping; do not add any `load()` of `user://` resources |
| Division by zero or NaN from tunables (`aim_blend_time`, `dash_time`, `run_speed` used as divisors in animation scaling) | Denial of service | Give every new divisor export a strictly positive minimum, as `MovementConfig` already does (T-02-02) |
| Quaternion from two opposite vectors in the solver | Denial of service (NaN pose) | Clamp or special-case before `Quaternion(a, b)` |

## Project Constraints (from CLAUDE.md)

- Engine Godot 4.7.2 standard build, typed GDScript everywhere (`untyped_declaration` is a parse error, also in tools and tests); text-first `.tscn`/`.tres`.
- Own `CharacterBody3D` controller and own node-based FSM; no addon controller, no state-machine addon. Camera is the hand-built `CameraRig`; aim and kick use the additive FOV/offset sources (D-18). Physics interpolation on; camera in `_process`, physics in `_physics_process`.
- Input only through Input Map actions; the CLAUDE.md input table already lists `aim` (hold, right mouse) and `use_hand`. New action documented in `docs/CONVENTIONS.md`.
- Animation section: AnimationTree with a Locomotion BlendSpace, upper-body layer through `AnimationNodeBlend2` with a bone filter (spine upward) driven by `aim`, `AnimationNodeOneShot` for ability triggers, code sets parameters, the movement FSM stays the source of truth, root motion off. (The verified tree matches this; root motion stays off for gameplay, `root_motion_track` is used only to cancel clip drift.)
- KayKit clips only; no custom animation authoring (REQUIREMENTS out of scope). Never edit an imported GLB in place; wrap it in a scene. Only used assets are copied from `KayKit/` into `attimo/assets/`, copy never move.
- Git: all phase work on `dev`; merge to `main` only after verification; planning docs in English, conversation with the user in German.
- GSD workflow: edits go through a GSD command; this research is read-only except the RESEARCH.md write.
- Established test rules that act as constraints: `test_feedback_guard` (no tween classes or the word shake in `scripts/core`, `scripts/player`, `autoload`), whitelist count, drift guards (Pitfall 8).

## Sources

### Primary (HIGH confidence)
- Scratch experiments on the pinned binary `4.7.2.stable.official.ed1daf0bf` (headless, scratch copy of the project and the raw KayKit GLBs, scripts in the session scratchpad): clip lengths/tracks/loop modes, torso lean over time, foot stance speeds, arm directions, root yaw per clip, first-vs-last frame loop checks, ClassDB property/method/enum listings for `AnimationNodeAnimation`, `AnimationNodeBlendSpace2D`, `AnimationNode`, `AnimationMixer`, `SkeletonModifier3D`, tree parameter paths, Land lock measurement (29 frames), OneShot FADE_OUT (7 frames), Blend2 filter behaviour, `root_motion_track`, modifier correction (0.00 deg), baseline suite run (25 files, about 157 s)
- Repo files read this session: `mannequin_animator.gd`, `build_mannequin_state_machine.gd`, `build_animation_library.gd`, `player_controller.gd`, all state scripts, `state_machine.gd`, `camera_rig.gd`, `camera_settings.gd`, `movement_config.gd`, `event_bus.gd`, `tuning_panel.gd`, `test_feedback_guard.gd`, `test_input_map.gd`, `test_asset_hygiene.gd`, `test_animation_library.gd`, `test_mannequin_animation.gd`, `docs/CONVENTIONS.md`, `docs/MOVEMENT-METRICS.md`, 03-CONTEXT.md, REQUIREMENTS.md, STATE.md, ROADMAP.md (Phase 3), `.claude/CLAUDE.md`
- https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html (Godot 4.7 docs: `sync_mode`, `SyncMode`, `cyclic_length`)
- https://docs.godotengine.org/en/stable/classes/class_animationnodeanimation.html (custom timeline properties)
- https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html (request enum, parameter names)
- https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html (virtuals, "always performs after playback process of the AnimationMixer", deprecation of `_process_modification()`)
- https://docs.godotengine.org/en/stable/classes/class_animationmixer.html (`root_motion_track`)

### Secondary (MEDIUM confidence)
- Phase 1 RESEARCH Pitfalls 2 to 4 and Pattern 8 on `travel()` and auto-advance behaviour (consistent with this session's measurements)

### Tertiary (LOW confidence)
- Visual-quality judgements (stance readability, spin composition, foot sliding tolerance): numeric reasoning only, no rendering available

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Every node and property used was instantiated or read back on the pinned engine.
- Architecture: HIGH for the tree, the modifier, the camera sources and the guard interactions; MEDIUM for the exact lean/pirouette feel and the aim stance appearance.
- Pitfalls: HIGH for items 1, 2, 4, 5, 7, 8, 11, 12 (measured or read from repo guards); MEDIUM for 3, 9, 13.

**Research date:** 2026-11-14
**Valid until:** 2026-12-14 (stable engine pin; re-verify only if the Godot version changes)
