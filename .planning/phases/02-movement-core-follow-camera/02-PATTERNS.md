# Phase 2: Movement Core & Follow Camera - Pattern Map

**Mapped:** 2026-11-04
**Files analyzed:** 22
**Analogs found:** 19 / 22

All analogs are git-tracked under `attimo/` (verified via `git ls-files`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `scripts/player/player_controller.gd` (mod) | controller | request-response (physics tick) | itself (Phase 1 scaffold) | exact |
| `scripts/player/movement_config.gd` (new, `MovementConfig` Resource) | config | transform | none (see No Analog) | none |
| `resources/player/movement_default.tres` (new) | config | n/a | none | none |
| `scripts/player/states/idle.gd`, `run.gd`, `jump.gd`, `fall.gd`, `dash.gd` (mod) | state | event-driven | `scripts/player/states/run.gd`, `jump.gd` | exact |
| `scripts/player/states/sprint.gd`, `double_jump`/`long_jump`/`air_dash` (new) | state | event-driven | `scripts/player/states/dash.gd` | role-match |
| `scripts/player/states/ground_state.gd`, `air_state.gd` (new helpers) | state base | event-driven | `scripts/core/state.gd` | role-match |
| `autoload/event_bus.gd` (mod: new facts) | service | pub-sub | itself | exact |
| `scripts/camera/camera_rig.gd` + `scenes/camera/camera_rig.tscn` (new) | component | streaming (per frame) | `player_controller.gd` (class_name + @onready) | partial |
| `scripts/camera/camera_settings.gd` (new) | utility | file-I/O | none | none |
| `scripts/debug/metrics_overlay.gd`, `latency_probe.gd`, `tuning_panel.gd` (new) | component | event-driven | `scripts/debug/event_log.gd` + `scenes/debug/event_log.tscn` | exact |
| `scripts/gym/moving_platform.gd`, `fall_reset.gd` (new) | component | event-driven | `scripts/player/states/*` for typing style; `scenes/proto/primitive_*.tscn` | partial |
| `scenes/test/movement_gym.tscn` (new) | scene | n/a | `scenes/test/test_scene.tscn` | exact |
| `scenes/proto/*` slope/beam wrappers (new) | scene | n/a | `scenes/proto/primitive_floor.tscn` | exact |
| `tools/build_movement_gym.gd`, `tools/measure_movement.gd` (new) | tool | batch | `tests/run_smoke.gd` + `tests/fixtures.gd` (run via `run.sh --tool`) | role-match |
| `project.godot` (mod: `camera_recenter`, floor settings) | config | n/a | existing `[input]` entries (e.g. `aim`, `dash`) | exact |
| `docs/CONVENTIONS.md` (mod) | doc | n/a | itself | exact |
| `tests/smoke/test_movement_config.gd` and other new movement smoke tests | test | request-response | `tests/smoke/test_jump_fact.gd` | exact |
| `tests/fixtures.gd` (mod: add floor helper) | test util | n/a | itself | exact |
| `tests/smoke/test_jump_fact.gd`, `test_dash_fact.gd`, `test_movement_facts.gd` (mod) | test | request-response | themselves | exact |
| `tests/smoke/test_asset_hygiene.gd` (mod if new Prototype Bits are copied; whitelist count is 25) | test | n/a | itself | exact |

## Pattern Assignments

### `scripts/player/player_controller.gd` (controller)
**Analog:** itself. Keep `class_name`, `@onready`, `face()` and `state_machine.setup(self)`. Header says Phase 2 adds velocity, gravity and the single `move_and_slide`.
```gdscript
class_name PlayerController
extends CharacterBody3D
const TURN_SPEED: float = 14.0
@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	state_machine.setup(self)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)   # Phase 2: add gravity + move_and_slide() exactly once here

func input_direction() -> Vector3:      # make camera-relative (rotate by camera yaw)
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return Vector3(input.x, 0.0, input.y)

func face(direction: Vector3, delta: float) -> void:   # rotates VisualRoot only, inside the physics tick
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, minf(TURN_SPEED * delta, 1.0))
```
Player scene (`scenes/player/player.tscn`): layer 2, mask 1, group `player`, states are `Node` children of `StateMachine` with script ext_resources (`[node name="Run" type="Node" parent="StateMachine"] script = ExtResource(...)`). New states must be added as sibling nodes there; the node name is the transition key.

### States (idle/run/sprint/jump/fall/dash/air variants)
**Analog:** `scripts/player/states/run.gd`, `jump.gd`, `dash.gd`, base `scripts/core/state.gd`.
```gdscript
extends State
func enter(previous: StringName) -> void: ...
func physics_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	actor.face(direction, delta)
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	if Input.is_action_just_pressed(&"jump"):
		return &"Jump"
	if direction == Vector3.ZERO:
		return &"Idle"
	return &""          # "" = stay
```
Facts: emit in `enter` (`EventBus.jumped.emit(actor.global_position)`, `EventBus.dash_started.emit(pos, direction, _in_air)`); `landed` currently emitted from `fall.gd` (`EventBus.landed.emit(actor.global_position, 0.0)`), where Phase 2 supplies real impact_speed from floor contact. Dash enter snaps facing: `actor.visual_root.rotation.y = atan2(direction.x, direction.z)`; airborne derived from `previous` (replace with `is_on_floor()`). Replace the Phase 1 timers (`JUMP_TIME`, `FALL_TIME`, `DASH_TIME`) with velocity and floor logic; dash uses a timer for its fixed duration.
Transitions go only through `StateMachine.transition_to` (emits local `state_changed` and `EventBus.movement_state_changed`); the animator listens to the local signal.

### `autoload/event_bus.gd` (pub-sub)
Facts only, no state or logic. Add new signals in the same style:
```gdscript
signal jumped(position: Vector3)
signal landed(position: Vector3, impact_speed: float)
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
signal movement_state_changed(from_state: StringName, to_state: StringName)
```
`EventLog` auto-connects to every declared signal, so no edit is needed there. Update `REQUIRED_FACTS` in `test_feedback_guard.gd` only if the guard should require the new ones.

### `scripts/debug/metrics_overlay.gd`, `latency_probe.gd`, `tuning_panel.gd` (debug overlays)
**Analog:** `scripts/debug/event_log.gd` + `scenes/debug/event_log.tscn` (CanvasLayer layer 100, PanelContainer with StyleBoxFlat bg `Color(0,0,0,0.6)`, `%Lines` unique-name RichTextLabel).
```gdscript
class_name EventLog
extends CanvasLayer
func _ready() -> void:
	for sig: Dictionary in EventBus.get_script().get_script_signal_list():
		EventBus.connect(sig.name, _on_fact.bind(sig.name))
	visible = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_event_log"):
		visible = not visible
```
Copy: hidden at start, toggled by a `debug_*` action (add a new action and document it in CONVENTIONS.md), connects to the EventBus rather than being called by gameplay, instanced as a child scene in the test scene (`[node name="EventLog" parent="." instance=ExtResource("6_log")]`).

### `scenes/test/movement_gym.tscn`, slope/beam wrappers
**Analog:** `scenes/test/test_scene.tscn` (WorldEnvironment with ProceduralSky, Sun DirectionalLight3D with shadows, floor tiles as instances of `scenes/proto/primitive_floor.tscn` at 4 m spacing, floor y = -1, walls at +/-10.5, Player instance, EventLog instance). The scene uses a static `Camera3D`; in the gym replace with the `camera_rig.tscn` instance. Proto wrappers: copy `scenes/proto/primitive_floor.tscn` structure; use convex collision for slopes (CLAUDE.md: no trimesh). Generated by `tools/build_movement_gym.gd` per RESEARCH.

### `tools/*.gd` and new smoke tests
**Analog:** `tests/smoke/test_jump_fact.gd` + `tests/fixtures.gd`; run through `tests/run.sh` (`--tool res://tools/x.gd` for tools).
```gdscript
extends RefCounted
const Fixtures := preload("res://tests/fixtures.gd")
func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	bus.connect(&"jumped", func(position: Vector3) -> void: jumped_positions.append(position))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.tap_action(tree, &"jump")
	check.call(cond, "message")
	player.queue_free()
	await tree.process_frame
```
Fixtures offers `spawn_player`, `wait_physics`, `wait_process`, `tap_action`. Phase 1 has no floor helper; add a static floor-spawn helper there (Phase 2 needs ground). Phase 1 tests assert "position unchanged / velocity zero" (D-09) and 0.6 s + 0.3 s timers, so `test_jump_fact`, `test_dash_fact`, `test_movement_facts` must be rewritten. Tools and tests are scripted by physics-tick counts with `Input.action_press/release`, not wall clock.

## Shared Patterns

### Typed GDScript, tabs, `StringName` literals
`&"action"`, `-> StringName`, `Dictionary[StringName, State]`, `@onready`, doc comments with `##`. Applies to every `.gd`.

### Feedback guard (critical)
`tests/smoke/test_feedback_guard.gd` scans `res://scripts/core`, `res://scripts/player`, `res://autoload` (comments included) for: `AudioStreamPlayer`, `GPUParticles`, `CPUParticles`, `create_tween`, `Tween`, `Engine.time_scale`, `shake`. Avoid these words in all gameplay scripts and comments. Camera scripts in `scripts/camera/` are not scanned, but keep camera "shake" out of gameplay code (use "kick"/"offset" wording where in doubt).

### Events: emit only
Gameplay emits on `EventBus`; no gameplay code calls audio/VFX/UI. Debug tooling connects.

### Physics order
Physics and `move_and_slide` in `_physics_process` (once); camera in `_process`; interpolation ON; call `reset_physics_interpolation()` on spawn/teleport (as in `Fixtures.spawn_player`).

### Collision layers
Use `scripts/core/physics_layers.gd` / CONVENTIONS.md names (World=1, Player=2). Player mask 1.

### Input actions
Add `camera_recenter` to `project.godot` `[input]` (same dict format as `aim`/`dash`) and to `docs/CONVENTIONS.md`; `tests/smoke/test_input_map.gd` and `test_conventions.gd` likely pin the action list and must be updated in the same change.

## No Analog Found

| File | Role | Reason |
|---|---|---|
| `scripts/player/movement_config.gd` + `resources/player/movement_default.tres` | config Resource | No custom `Resource` / `@export` config exists yet; use RESEARCH.md. |
| `scripts/camera/camera_rig.gd`, `camera_rig.tscn` | camera component | No camera code exists (only a static Camera3D in test_scene). Use RESEARCH.md and CLAUDE.md rig `CameraRig > Pitch > SpringArm3D > Camera3D`. |
| `scripts/camera/camera_settings.gd` | ConfigFile persistence | No file persistence exists yet. |
| `scripts/gym/*` | moving platforms | No moving bodies exist yet. |

## Metadata

**Analog search scope:** `attimo/` tracked files (scripts, scenes, autoload, tests)
**Files scanned:** about 70 tracked entries; 12 read in full
**Pattern extraction date:** 2026-11-04
