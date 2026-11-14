# Phase 3: Animated Mannequin & Aim Mode - Pattern Map

**Mapped:** 2026-11-14
**Files analyzed:** 22 new/modified
**Analogs found:** 21 / 22 (all analog paths verified git-tracked, relative to `attimo/`)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `scripts/player/mannequin_animator.gd` (mod) | presentation/animator | event-driven (state_changed) + per-frame params | itself (extend) | exact |
| `scripts/player/procedural_pose.gd` (new) | presentation component | event-driven + physics-tick transform | `scripts/player/mannequin_animator.gd` (listener pattern), `scripts/player/player_controller.gd` `face()` (visual transform in tick) | role-match |
| `scripts/player/aim_pose_modifier.gd` (new) | SkeletonModifier3D | transform | none in repo (use RESEARCH solver) | no analog |
| `scripts/player/player_controller.gd` (mod) | controller | request-response (tick) | itself | exact |
| `scripts/player/movement_config.gd` (mod, `aim_speed_factor`) | config | n/a | itself (`run_speed` export) | exact |
| `scripts/player/states/dash.gd`, `long_jump.gd`, `idle/run/ground_state` (mod: aim speed, facing) | state | request-response | themselves | exact |
| `autoload/event_bus.gd` (mod, `aim_changed`) | event bus | pub-sub | itself | exact |
| `scripts/camera/camera_rig.gd` (mod: aim weight, sources, swap, sensitivity) | camera | per-frame | itself (`set_fov_offset`, `set_offset`) | exact |
| `scripts/ui/crosshair.gd` + `scenes/ui/crosshair.tscn` (new) | HUD component | event-driven | `scripts/debug/metrics_overlay.gd` + `scenes/debug/metrics_overlay.tscn` (CanvasLayer, EventBus listener) | role-match |
| `scenes/player/mannequin.tscn` (mod: BlendTree root, root_motion_track, modifier node) | scene | config | itself | exact |
| `tools/build_mannequin_state_machine.gd` (rewrite to BlendTree) | tool | batch/file-I/O | itself | exact |
| `tools/build_animation_library.gd` (mod: +CombatRanged, +8 clips, loops) | tool | batch/file-I/O | itself | exact |
| `tools/movement_gym_builder.gd` (mod: instance crosshair) | tool | batch | itself | exact |
| `project.godot` (+ `aim_shoulder_swap` action) | config | n/a | `camera_recenter` entry, lines 33-38 | exact |
| `docs/CONVENTIONS.md`, `docs/ANIMATION-MAP.md` (new), `docs/MOVEMENT-METRICS.md` (regenerate) | docs | n/a | CONVENTIONS.md input table line 115 | role-match |
| `tests/fixtures.gd` (mod: playback/locomotion helpers) | test helper | n/a | itself | exact |
| `tests/smoke/test_mannequin_animation.gd`, `test_movement_facts`, `test_dash`, `test_scene_run` (mod: new param paths) | test | request-response | `test_mannequin_animation.gd` | exact |
| `tests/smoke/test_input_map.gd`, `test_asset_hygiene.gd`, `test_conventions.gd` (mod) | test | guard | `test_input_map.gd` ACTIONS list | exact |
| new tests (aim camera, procedural pose, aim modifier, land one-shot, animation map guard) | test | request-response | `test_mannequin_animation.gd`, `test_camera_rig.gd` | role-match |
| `assets/animations/rig_medium/Rig_Medium_CombatRanged.glb` (+ .import) | asset | n/a | sibling `Rig_Medium_MovementAdvanced.glb` | exact |

## Pattern Assignments

### `scripts/player/mannequin_animator.gd` (modify)

**Analog:** itself (lines 1-37). It is a `Node` with `@export state_machine`, `@export animation_tree`, connects `state_changed` in `_ready`.

Current pattern to replace (lines 23-37):
```gdscript
var _playback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	_playback = animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	state_machine.state_changed.connect(_on_state_changed)

func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	animation_tree.set(&"parameters/Locomotion/blend_position", 1.0 if RUNNING_STATES.has(to_state) else 0.0)
	if to_state == &"Idle" and AIRBORNE_STATES.has(from_state):
		_playback.travel(&"Land")
		return
	_playback.travel(STATE_TO_ANIM.get(to_state, &"Locomotion"))
```
Changes: path becomes `parameters/StateMachine/playback`; Land becomes OneShot request (`parameters/Land/request`, FIRE / FADE_OUT) instead of `travel(&"Land")`; add `_process` smoothing for `parameters/StateMachine/Locomotion/blend_position` (Vector2), `parameters/TimeScale/scale`, `parameters/Aim/blend_amount`. Keep typed `Dictionary[StringName, StringName]` constants style (lines 9-21). Keep "travel on same call as state_changed". Use RESEARCH "Animator parameter driving" sketch. No Tween/shake tokens (scanned dir `scripts/player`).

### `scripts/player/procedural_pose.gd` (new, class `ProceduralPose`)

**Analog:** `scripts/player/mannequin_animator.gd` for wiring (exported refs, signal connect), and `player_controller.gd` lines 118-129 for "visual transform written inside the physics tick":
```gdscript
func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, minf(config.turn_rate * delta, 1.0))
```
Write `mannequin.transform` in `_physics_process` only (interpolation). Read `chain_stage`, `long_jump_stage` (player_controller.gd ~line 30-32; set in `Jump.enter`/`LongJump.enter` before `state_changed` emits), `Dash.in_air` (`dash.gd` line 17), `last_dash_direction`. Easing via `move_toward`, no tween classes (feedback guard).

### `scripts/player/aim_pose_modifier.gd` (new)

No in-repo analog for SkeletonModifier3D. Copy the verified solver from 03-RESEARCH.md "Arm-direction solver" (lines 439-460). Record `last_error_deg` for tests. Typed GDScript everywhere (`gdscript/warnings/untyped_declaration=2` in project.godot makes untyped declarations errors).

### `scripts/player/player_controller.gd` (modify)

**Analog:** itself. `_physics_process` (line ~54): `_tick_timers(delta); state_machine.physics_update(delta); _integrate(delta)`. Add `_tick_aim` and `_apply_aim_facing` before `state_machine.physics_update`. `face()` and `face_now()` (lines 118-129) early-return while `aiming`. `input_direction()` (lines 75-89) uses `rig.steering_yaw()`; in aim use `rig.yaw` (RESEARCH Pitfall 9). Emit `EventBus.aim_changed` only on change. Find rig via existing `_find_rig(camera)`.

### `scripts/player/movement_config.gd` (modify)

**Analog:** `@export_range(1.0, 20.0, 0.1) var run_speed: float = 8.5`. Add `aim_speed_factor` and lean/pirouette numbers in new `@export_group`s. After adding floats run `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` to regenerate `docs/MOVEMENT-METRICS.md` or `test_movement_metrics` fails. F2 panel rows are generated from the resource (`scripts/debug/tuning_panel.gd`), no panel code needed for these.

### `autoload/event_bus.gd` (modify)

**Analog:** itself (lines 1-12), facts only, typed signals with doc comment:
```gdscript
## Emitted by the LongJump state on enter. `stage` is ...
signal long_jumped(position: Vector3, stage: int)
```
Add `signal aim_changed(active: bool)` with a `##` comment. Also update chain_stage_changed comment "salto" -> pirouette.

### `scripts/camera/camera_rig.gd` (modify)

**Analog:** itself. Additive source API (lines 255-292): `set_fov_offset(source, degrees)`, `clear_fov_offset`, `set_offset(source, Vector3)` (Pitch-local, +X right), `clear_offset`. Applied each `_process` at lines 186-187:
```gdscript
spring_arm.position = _offset_total()
camera.fov = get_fov_total()
```
Add an eased `aim_weight` in `_process` (before line 186), write `set_fov_offset(&"aim", -aim_fov_delta * w)` and `set_offset(&"aim", Vector3(side * aim_shoulder_offset * w, 0, 0))`. New `@export` vars follow the doc-commented style (lines 22-67). Sensitivity: `_unhandled_input` line 149 `var scale: float = base_sensitivity * settings.sensitivity`, multiply by lerp(1, aim_sensitivity_factor, w). Skip `recenter()` (line ~156) and auto-follow while aiming. Shoulder swap: `event.is_action_pressed(&"aim_shoulder_swap")` in `_unhandled_input`, same style as `camera_recenter` (line 156). Connect `EventBus.aim_changed` in `_ready`.

### `scripts/ui/crosshair.gd` + `scenes/ui/crosshair.tscn` (new)

**Analog:** `scenes/debug/metrics_overlay.tscn` / `scripts/debug/metrics_overlay.gd`: `class_name X extends CanvasLayer`, `visible = false` in `_ready`, header doc comment, listens to EventBus only. Scene format:
```
[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/debug/metrics_overlay.gd" id="1_overlay"]
[node name="MetricsOverlay" type="CanvasLayer"]
layer = 101
script = ExtResource("1_overlay")
```
Use a lower layer number, a child `Control` with `_draw` (`draw_circle`, `draw_arc`), no texture (asset whitelist). Connect `EventBus.aim_changed` to toggle visibility. Instance it in `tools/movement_gym_builder.gd` and hand-maintained `scenes/test/test_scene.tscn` (gym is generated, never hand-edit `movement_gym.tscn`).

### `scenes/player/mannequin.tscn` (modify)

**Analog:** itself (lines 1-18). Replace `ExtResource("3_sm")` tree_root with the BlendTree resource, add `root_motion_track = NodePath("Rig_Medium/Skeleton3D:root")`, replace `parameters/Locomotion/blend_position = 0.0` with the new paths (`parameters/StateMachine/Locomotion/blend_position`), add `AimPoseModifier` as child of the Skeleton3D.

### `tools/build_mannequin_state_machine.gd` (rewrite)

**Analog:** itself. Keep structure (`extends SceneTree`, `_initialize`, `_clip`, `_auto_edge`, `_manual_edge`, `XFADE_TIME = 0.1`, `ResourceSaver.save`, `quit(0 if err == OK else 1)`). Copy edge pattern lines 27-41:
```gdscript
_machine.add_transition(&"Start", &"Locomotion", _auto_edge(false))
_machine.add_transition(&"Jump", &"Fall", _auto_edge(true))
var direct: Array[Array] = [[&"Locomotion", &"Jump"], ...]
for edge: Array in direct:
	_machine.add_transition(edge[0] as StringName, edge[1] as StringName, _manual_edge())
```
Remove `Land` state and both Land edges; add `DashLeft/Right/Back` states with direct edges; locomotion becomes BlendSpace2D (RESEARCH "Tree builder skeleton" lines 377-416); wrap in `AnimationNodeBlendTree`. Only one transition per ordered pair is allowed by the engine.

### `tools/build_animation_library.gd` (modify)

**Analog:** itself. Extend `SOURCES` (add `Rig_Medium_CombatRanged.glb`), `WANTED` (+`Ranged_1H_Aiming`, `Running_Strafe_Left/Right`, `Walking_Backwards`, `Dodge_Left/Right/Backward`), `LOOPING` (+strafes, backwards; NOT `Ranged_1H_Aiming`). Loop logic at line 30 unchanged.

### `project.godot` (+ `aim_shoulder_swap`)

**Analog:** `camera_recenter` block (lines 33-38), a mouse/key event with `"device":-1`. Add alphabetically near `aim`. Must also update `test_input_map.gd` `ACTIONS` array (lines 5-10), `docs/CONVENTIONS.md` table (line 115 area), and `test_conventions`. Key-only event (no gamepad; slot reserved in docs).

### Tests

**Analog:** `tests/smoke/test_mannequin_animation.gd`. Structure: `extends RefCounted`, `const Fixtures := preload("res://tests/fixtures.gd")`, `func run(tree: SceneTree, check: Callable)`, spawn floor + player via `Fixtures.spawn_floor/spawn_player`, `await Fixtures.wait_physics(tree, n)`, `check.call(cond, msg)`, free nodes at end. Lines 24-31 and 61-79 read `parameters/playback`, `Locomotion/blend_position`, node `Land`: migrate to a new Fixtures helper (e.g. `Fixtures.playback(player)`). For the camera aim tests use `Fixtures.spawn_camera_rig(root, target)` (fixtures.gd line ~41). For modifier assertions read `last_error_deg`, never the Skeleton3D (Pitfall 11). Avoid frame-count pose timing (Pitfall 12); use state/params with tick budgets.

## Shared Patterns

### Animation shows state, never drives it
**Source:** `scripts/player/mannequin_animator.gd` lines 3-4 and CONTEXT code_context. Listen to local `StateMachine.state_changed`; gameplay never calls presentation. Apply to animator, ProceduralPose, crosshair, camera aim.

### EventBus facts
**Source:** `autoload/event_bus.gd`. Typed signals, no state or logic. New fact `aim_changed(active: bool)` is the only cross-system aim channel for camera and crosshair.

### Feedback guard
**Source:** `tests/smoke/test_feedback_guard.gd` lines 6, 18-26. Dirs `scripts/core`, `scripts/player`, `autoload` forbid tokens `Tween`, `shake`, `AudioStreamPlayer`, `GPUParticles`, `Engine.time_scale` etc., comments included. Use `move_toward` easing and word comments accordingly. `scripts/camera` and `scripts/ui` are not scanned.

### Typed GDScript, physics-tick visual writes
**Source:** `project.godot` `[debug] gdscript/warnings/untyped_declaration=2` (untyped is an error); CONVENTIONS line 146 "Rotate or scale only VisualRoot, inside the physics tick." Camera work stays in `_process`. (Phase 3 deliberately applies lean/pirouette on the `Mannequin` child, not `VisualRoot` itself; flagged in RESEARCH Pattern 4.)

### Drift guards to update in the same commit
- `docs/MOVEMENT-METRICS.md` regenerate after new `MovementConfig` floats (`test_movement_metrics`).
- `test_asset_hygiene.gd` whitelist 31 -> 33 (`Rig_Medium_CombatRanged.glb` + `.import`); `tests/run.sh` `ORIGINALS` array.
- `test_input_map.gd` ACTIONS, `test_conventions`, `docs/CONVENTIONS.md` (shoulder swap, root-motion decision at line 157).
- ROADMAP/REQUIREMENTS "salto/flip" wording -> pirouette (D-07).

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `scripts/player/aim_pose_modifier.gd` | SkeletonModifier3D | transform | No SkeletonModifier3D or skeleton post-processing in repo; use RESEARCH verified solver |
| `docs/ANIMATION-MAP.md` + guard test | docs/test | n/a | New artifact; model the guard on `test_conventions.gd` / `test_input_map.gd` list-vs-doc checks |

## Metadata

**Analog search scope:** `attimo/` tracked files (`git ls-files`: scripts, autoload, scenes, tools, tests, project.godot)
**Files scanned:** about 70 listed, 14 read in full or in part
**Pattern extraction date:** 2026-11-14
