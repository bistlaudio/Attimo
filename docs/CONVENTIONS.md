# Attimo Conventions

These conventions fix the names that later phases build on: folders, naming, collision layers, groups, Input Map actions, the event bus and the player scene. Renaming any of them later means editing every scene and script that uses it.

## Purpose and sources of truth

- `attimo/project.godot` is authoritative for Input Map actions and collision layer names.
- `attimo/scripts/core/physics_layers.gd` (`PhysicsLayers`) is authoritative for layer bitmasks in code.
- This document mirrors both and adds the rules that have no engine representation (groups, folders, naming, bus rule, player-scene rules).
- `attimo/tests/smoke/test_conventions.gd` and `test_input_map.gd` run on every `bash attimo/tests/run.sh` and fail if this document, `project.godot` and `PhysicsLayers` drift apart.
- When you add a layer, group or action, change `project.godot`, the constants, this document and the tests in the same commit.

## Folder layout

The Godot project root is `attimo/` (D-01). `KayKit/` and the other raw asset packs sit in the repository root, outside the project, so Godot never imports them.

| Folder (under `attimo/`) | Contents |
|---|---|
| `autoload/` | Autoload singletons. Phase 1: `event_bus.gd` (EventBus). |
| `scenes/player/` | The Player scene and the Mannequin wrapper scene. |
| `scenes/camera/` | The camera rig scene (`camera_rig.tscn`, CameraRig). |
| `scenes/proto/` | Wrapper scenes for the Prototype Bits pieces (with collision). Phase 2 adds `moving_platform.tscn` and the Slope and Beam wrappers. |
| `scenes/test/` | Test scenes. `test_scene.tscn` is the Phase 1 main scene; `movement_gym.tscn` becomes the Phase 2 main scene. |
| `scenes/debug/` | Debug overlays such as the event log, the metrics overlay and the tuning panel. |
| `scripts/core/` | Generic building blocks: `State`, `StateMachine`, `PhysicsLayers`. |
| `scripts/player/` | PlayerController, the animator, and `states/` (one script per movement state). |
| `scripts/camera/` | `CameraRig` and `CameraSettings` (camera tuning persisted in `user://settings.cfg`). |
| `scripts/gym/` | Gym-only helpers (`MovingPlatform`, `FallReset`). Phase 4 builds the real mechanisms. |
| `scripts/debug/` | Debug-only scripts. Strip or ignore in a release build. |
| `resources/` | Shared `Resource` instances. `resources/player/movement_default.tres` is the one `MovementConfig` that holds every movement number. |
| `assets/characters/` | Copied character GLBs (Mannequin). |
| `assets/animations/` | Copied animation GLBs and the generated animation library. |
| `assets/prototype_bits/` | Copied Prototype Bits meshes and the shared texture. |
| `tests/` | `run.sh`, `run_smoke.gd`, `fixtures.gd` and `smoke/test_*.gd`. |
| `tools/` | Editor-time scripts run headless with `bash attimo/tests/run.sh --tool res://tools/<script>.gd`. |

Rules:

- Commit the `.import` and `.gd.uid` sidecar files. `.godot/` is ignored.
- Used assets are copied from `KayKit/` into `attimo/assets/`, never moved (D-04). `KayKit/` stays complete as a reference library.
- Never edit an imported GLB in place. Wrap it in your own scene.

## Naming

- Files and folders: `snake_case` (`player_controller.gd`, `prototype_bits/`).
- Nodes and `class_name`: `PascalCase` (`VisualRoot`, `PlayerController`, `PhysicsLayers`).
- State nodes are named after the state, `PascalCase` (`Idle`, `Jump`). The node name is the state key.
- Signals: past-tense facts in `snake_case` (`jumped`, `landed`, `dash_started`, `movement_state_changed`).
- Input actions: `snake_case`. The `debug_` prefix marks debug-only actions that are not part of the player-facing list.
- Groups: `snake_case`.
- Constants: `UPPER_SNAKE_CASE`.

## Typed GDScript

- All gameplay code is typed. `debug/gdscript/warnings/untyped_declaration=2` turns every untyped declaration into a parse error. It applies to every script the engine parses, including `tools/` and `tests/`.
- Type loop variables (`for i: int in 30`), lambda parameters and locals (`var x: float` or `:=`).
- Use `##` doc comments on public members and a short class description on the first lines of every script.

## Collision layers

`.tscn` files store the **bitmask** (layer N = `1 << (N - 1)`), not the layer index. Code uses the `PhysicsLayers` constants and never magic numbers.

| Layer | Name | Bitmask | `PhysicsLayers` | Sits on it | Masked by |
|---:|---|---:|---|---|---|
| 1 | World | 1 | `WORLD` | Static geometry, moving platforms (AnimatableBody3D) | Player body, camera SpringArm (Phase 2), beam and aim rays |
| 2 | Player | 2 | `PLAYER` | Player CharacterBody3D | Enemy and hazard Areas that detect the player |
| 3 | Interactable | 4 | `INTERACTABLE` | Mechanism and interactable bodies and Areas | Targeting queries (Phase 4) |
| 4 | Enemy | 8 | `ENEMY` | Enemy bodies | Beam and rays, player hurt checks |
| 5 | Projectile/Beam | 16 | `PROJECTILE` | Beam and projectile hit shapes | Enemies, interactables, world |
| 6 | Hazard | 32 | `HAZARD` | Kill zones, damage volumes | Player-detecting Areas |
| 7-32 | (unnamed) | | | reserved | |

Rules:

- The thing being detected sits on its own layer. A detector (`Area3D`, ray, shape cast) finds it by setting its **mask**.
- Platforms, including moving ones, go on World (1). Kill zones go on Hazard (6).
- Layer 7 "Trigger" is recommended for checkpoints and is claimed in Phase 6. Until then it is documented here only and not named in `project.godot`.
- Layers 7-32 are reserved. A phase claims one by adding a row to the table above, a name in `project.godot`, and a constant in `PhysicsLayers`.
- Phase 1 Player: `collision_layer = 2` (Player), `collision_mask = 1` (World).

## Groups

| Group | Phase | Used on |
|---|---|---|
| `player` | now (Phase 1) | The Player root node |
| `moving_platform` | now (Phase 2) | Moving platforms (`MovingPlatform`); the player carries their horizontal velocity |
| `interactable` | reserved, Phase 4 | Mechanisms and anything the hand can target |
| `anchor` | reserved, Phase 5 | Hook and anchor points |
| `enemy` | reserved, Phase 6 | Enemies |
| `hazard` | reserved, Phase 6 | Kill zones and damage volumes |
| `checkpoint` | reserved, Phase 6 | Checkpoints |

A phase that uses a reserved group removes "reserved" from its row.

## Input Map

All input goes through Input Map actions. Game code under `autoload/`, `scripts/` and `scenes/` never polls raw keys, mouse buttons or joypads (`Input.is_key_pressed`, `is_physical_key_pressed`, `is_mouse_button_pressed`, `get_joy*`). `test_input_map` scans for these calls.

No project action has a gamepad event before Phase 13.

Keys are stored as physical keys (layout independent) with device -1 (all devices). Keyboard and mouse are bound now. The gamepad column is a reserved slot: nothing is bound, Phase 13 binds these to the same action names.

| Action | KB+M binding | Gamepad slot (reserved, unbound) | Notes |
|---|---|---|---|
| `move_forward` | W | Left stick up | |
| `move_back` | S | Left stick down | |
| `move_left` | A | Left stick left | |
| `move_right` | D | Left stick right | |
| `look_left` | none | Right stick left | No events: mouse motion cannot be bound to an action. The `CameraRig` reads `InputEventMouseMotion` in `_unhandled_input` (Phase 2). |
| `look_right` | none | Right stick right | See `look_left`. |
| `look_up` | none | Right stick up | See `look_left`. |
| `look_down` | none | Right stick down | See `look_left`. |
| `jump` | Space | A / Cross | |
| `sprint` | Left Shift | L3 or trigger | Hold. |
| `dash` | Q and Left Ctrl | B / Circle | Two bindings; CLAUDE.md says "decide in tuning" (kept until the gym sign-off, A5). |
| `aim` | Right mouse button | L2 / LT | Hold. |
| `use_hand` | Left mouse button | R2 / RT | Fire or trigger the module. |
| `interact` | E | X / Square | |
| `module_next` | Mouse wheel down | Right bumper | |
| `module_prev` | Mouse wheel up | Left bumper | Number-key slot selects become separate actions in Phase 5. |
| `pause` | Escape | Start | |
| `camera_recenter` | Middle mouse button | R3 | Turns the camera behind the character (D-17). R3 is reserved for Phase 13. |
| `debug_event_log` | F3 and Backtick (QuoteLeft) | none | Debug-only, outside the player-facing list. F3 may need Fn on macOS, hence the second key. |
| `debug_tuning` | F2 and 8 | none | Debug-only. Toggles the TuningPanel. The top-row digit is the Mac-friendly alternate (F-keys need Fn). Digits 1-3 stay free for the Phase 5 module slots. |
| `debug_metrics` | F4 and 9 | none | Debug-only. Toggles the MetricsOverlay. |
| `debug_tick_rate` | F6 and 0 | none | Debug-only. Cycles the physics rate 60 -> 120 -> 10 -> 60 TPS. |

## Event bus

The `EventBus` autoload carries gameplay **facts** (D-10, D-11). Gameplay code only emits typed fact signals. It never calls audio, particles, tweens, time scale or camera effects. Feedback systems connect to the bus and react.

| Signal | Payload | Emitted by |
|---|---|---|
| `jumped` | `position: Vector3` | `Jump.enter`, for ground jumps (Jump 1 and Jump 2) |
| `double_jumped` | `position: Vector3` | `DoubleJump.enter` |
| `long_jumped` | `position: Vector3, stage: int` | `LongJump.enter`; stage 0 small, 1 mid, 2 max |
| `chain_stage_changed` | `stage: int` | `PlayerController` when the ground-jump chain stage changes; 0 on reset |
| `landed` | `position: Vector3, impact_speed: float` | `PlayerController._land` on floor contact; `impact_speed` is the downward speed at touchdown |
| `dash_started` | `position: Vector3, direction: Vector3, in_air: bool` | `Dash.enter` |
| `movement_state_changed` | `from_state: StringName, to_state: StringName` | `StateMachine` on every transition |

Listeners: the debug event log now, juice (Phases 11-12), audio (Phase 14). A new fact is a new typed signal added in the phase that needs it. The bus holds no state and no logic.

## Player scene

- Structure: `Player` (CharacterBody3D) > `VisualRoot` (Node3D, pivot at the feet) > Mannequin wrapper scene (D-06). Rotate or scale only `VisualRoot`, inside the physics tick. Later phases reuse it for flip and lean (Phase 3), the final hero (Phase 9) and squash and stretch (Phase 11).
- The state machine is the source of truth for movement (D-08). The animator listens to the local `StateMachine.state_changed` signal and never decides state.
- Movement rules (Phase 2): the controller owns `move_velocity` (horizontal) and `vertical_speed`, applies gravity in half steps, and calls `move_and_slide()` exactly once per tick in `_physics_process`. It never stores the returned velocity as state. States only write `move_velocity`, `vertical_speed` and `gravity_scale`.
- All movement numbers live in `MovementConfig` (`resources/player/movement_default.tres`). Scripts never hold tuning literals.
- `platform_on_leave` is `DO_NOTHING`; the controller carries the horizontal platform velocity manually. `floor_max_angle` is 50 degrees and the floor snap length scales with speed.
- Teleports go through `teleport()`, which calls `reset_physics_interpolation()`.
- Stairs policy: risers up to 0.15 m are climbed without a jump, 0.18 m is the theoretical limit, taller ledges need a jump.
- The Mannequin wrapper scene wraps the imported GLB. The GLB is never edited in place (D-07).
- Capsule shape: radius 0.5, height 2.0, kept unchanged for Phase 2 (A2). The gym sign-off re-checks it against the Mannequin.
- `Mannequin_Medium` is about 2.2 m tall and faces +Z.
- Attach held items and effects to the bones `hand.r` / `hand.l`. The `handslot` bones exist only in the clip GLBs, not in the character GLB.
- The clip `Dodge_Forward` shifts the root bone by +0.25 m. Phase 3 decides how to handle it.

## Camera

- Structure: `CameraRig` (Node3D, yaw) > `Pitch` (Node3D) > `SpringArm3D` > `Camera3D` (D-18). The rig is a sibling of the Player, never a child.
- The rig is `top_level` with physics interpolation OFF. It follows the interpolated player position in `_process`. Mouse look never scales by delta.
- The `SpringArm3D` masks World only.
- Framing is centered behind the character. The shoulder offset arrives only in aim mode (D-14, Phase 3).
- Other systems change FOV and offset only through the additive per-source API on the rig (`set_fov_offset`, `set_offset` and their `clear_*` counterparts), so aim mode (Phase 3) and camera kick (Phase 11) never fight over the camera.
- `camera_recenter` (middle mouse button) turns the camera behind the character.

## Settings and debug

- Camera settings persist in `user://settings.cfg` through `ConfigFile` only. Values are clamped on load. No `Resource` is ever loaded from `user://`.
- Debug overlays live under `scripts/debug/` and `scenes/debug/`. They start hidden, are toggled by `debug_` actions and are stripped in Phase 15 (REL-03).

## Engine and tooling

- Pinned engine: Godot 4.7.2-stable (standard, not .NET), `--version` prints `4.7.2.stable.official.ed1daf0bf`.
- The `GODOT` environment variable points `run.sh` at the pinned binary. Never open `attimo/` with another Godot version.
- Run all smoke tests: `bash attimo/tests/run.sh`. Run one: `bash attimo/tests/run.sh test_conventions`.
- Run an editor-time script headless: `bash attimo/tests/run.sh --tool res://tools/<script>.gd`.
- Install path, checksum and credits: see `README.md`.
