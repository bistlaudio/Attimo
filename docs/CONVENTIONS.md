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
| `scenes/proto/` | Wrapper scenes for the Prototype Bits pieces (with collision). |
| `scenes/test/` | Test scenes (the Phase 1 main scene). |
| `scenes/debug/` | Debug overlays such as the event log. |
| `scripts/core/` | Generic building blocks: `State`, `StateMachine`, `PhysicsLayers`. |
| `scripts/player/` | PlayerController, the animator, and `states/` (one script per movement state). |
| `scripts/debug/` | Debug-only scripts. Strip or ignore in a release build. |
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
| `moving_platform` | reserved, Phase 2 | Moving platforms |
| `interactable` | reserved, Phase 4 | Mechanisms and anything the hand can target |
| `anchor` | reserved, Phase 5 | Hook and anchor points |
| `enemy` | reserved, Phase 6 | Enemies |
| `hazard` | reserved, Phase 6 | Kill zones and damage volumes |
| `checkpoint` | reserved, Phase 6 | Checkpoints |

A phase that uses a reserved group removes "reserved" from its row.

## Input Map

All input goes through Input Map actions. Game code under `autoload/`, `scripts/` and `scenes/` never polls raw keys, mouse buttons or joypads (`Input.is_key_pressed`, `is_physical_key_pressed`, `is_mouse_button_pressed`, `get_joy*`). `test_input_map` scans for these calls.

Keys are stored as physical keys (layout independent) with device -1 (all devices). Keyboard and mouse are bound now. The gamepad column is a reserved slot: nothing is bound, Phase 13 binds these to the same action names.

| Action | KB+M binding | Gamepad slot (reserved, unbound) | Notes |
|---|---|---|---|
| `move_forward` | W | Left stick up | |
| `move_back` | S | Left stick down | |
| `move_left` | A | Left stick left | |
| `move_right` | D | Left stick right | |
| `look_left` | none | Right stick left | No events: mouse motion cannot be bound to an action. Phase 2 reads `InputEventMouseMotion` directly. |
| `look_right` | none | Right stick right | See `look_left`. |
| `look_up` | none | Right stick up | See `look_left`. |
| `look_down` | none | Right stick down | See `look_left`. |
| `jump` | Space | A / Cross | |
| `sprint` | Left Shift | L3 or trigger | Hold. |
| `dash` | Q and Left Ctrl | B / Circle | Two bindings; CLAUDE.md says "decide in tuning". |
| `aim` | Right mouse button | L2 / LT | Hold. |
| `use_hand` | Left mouse button | R2 / RT | Fire or trigger the module. |
| `interact` | E | X / Square | |
| `module_next` | Mouse wheel down | Right bumper | |
| `module_prev` | Mouse wheel up | Left bumper | Number-key slot selects become separate actions in Phase 5. |
| `pause` | Escape | Start | |
| `debug_event_log` | F3 and Backtick (QuoteLeft) | none | Debug-only, outside the player-facing list. F3 may need Fn on macOS, hence the second key. |

## Event bus

The `EventBus` autoload carries gameplay **facts** (D-10, D-11). Gameplay code only emits typed fact signals. It never calls audio, particles, tweens, time scale or camera effects. Feedback systems connect to the bus and react.

| Signal | Payload | Emitted by |
|---|---|---|
| `jumped` | `position: Vector3` | `Jump.enter` |
| `landed` | `position: Vector3, impact_speed: float` | The Fall state on touchdown |
| `dash_started` | `position: Vector3, direction: Vector3, in_air: bool` | `Dash.enter` |
| `movement_state_changed` | `from_state: StringName, to_state: StringName` | `StateMachine` on every transition |

Listeners: the debug event log now, juice (Phases 11-12), audio (Phase 14). A new fact is a new typed signal added in the phase that needs it. The bus holds no state and no logic.

## Player scene

- Structure: `Player` (CharacterBody3D) > `VisualRoot` (Node3D, pivot at the feet) > Mannequin wrapper scene (D-06). Rotate or scale only `VisualRoot`, inside the physics tick. Later phases reuse it for flip and lean (Phase 3), the final hero (Phase 9) and squash and stretch (Phase 11).
- The state machine is the source of truth for movement (D-08). The animator listens to the local `StateMachine.state_changed` signal and never decides state.
- Phase 1 has no movement physics (D-09, Option A): states are timer-driven and the body never moves. The movement rule that starts in Phase 2: exactly one `move_and_slide()` call, in `PlayerController._physics_process`, and states only set velocity.
- The Mannequin wrapper scene wraps the imported GLB. The GLB is never edited in place (D-07).
- Capsule shape: radius 0.5, height 2.0. This is a valid body shape only in Phase 1; Phase 2 retunes it against the Mannequin.
- `Mannequin_Medium` is about 2.2 m tall and faces +Z.
- Attach held items and effects to the bones `hand.r` / `hand.l`. The `handslot` bones exist only in the clip GLBs, not in the character GLB.
- The clip `Dodge_Forward` shifts the root bone by +0.25 m. Phase 3 decides how to handle it.

## Engine and tooling

- Pinned engine: Godot 4.7.2-stable (standard, not .NET), `--version` prints `4.7.2.stable.official.ed1daf0bf`.
- The `GODOT` environment variable points `run.sh` at the pinned binary. Never open `attimo/` with another Godot version.
- Run all smoke tests: `bash attimo/tests/run.sh`. Run one: `bash attimo/tests/run.sh test_conventions`.
- Run an editor-time script headless: `bash attimo/tests/run.sh --tool res://tools/<script>.gd`.
- Install path, checksum and credits: see `README.md`.
