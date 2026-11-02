# Architecture Research

**Domain:** Godot 4 3D third-person platformer with a modular hand-ability ("Modul") system
**Researched:** 2026-11-02
**Confidence:** MEDIUM-HIGH (Godot patterns are well established and come from the engine's own docs and long-standing community practice. Exact addon versions and the newest Godot minor version were only partly verified, see Sources and Gaps.)

**Scope note (user decision, 2026-11-02):** The prosthetic arm mesh NEVER changes. Modules are pure ability components: input binding, effect logic and VFX attached to a fixed hand/arm socket. There is no mesh swapping, no attachment-slot geometry and no per-module animation rig. This simplifies the module system considerably (see Pattern 4).

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│ AUTOLOADS (global, few, no gameplay logic)                           │
│  EventBus (signals only)   GameState (unlocks, flags)                │
│  SaveService (checkpoint, user://)   DebugOverlay (F-keys, tuning)   │
└───────▲──────────────────────▲──────────────────────▲────────────────┘
        │ signals              │ read/write           │ signals
┌───────┴──────────────────────┴──────────────────────┴────────────────┐
│ LEVEL SCENE (level_01.tscn) - one scene, no streaming                │
│  ┌────────────┐  ┌──────────────┐  ┌───────────────┐  ┌───────────┐  │
│  │ Geometry / │  │ Mechanisms   │  │ Checkpoints / │  │ Boss      │  │
│  │ Props      │  │ (components) │  │ Pickups       │  │ Arena     │  │
│  └────────────┘  └──────▲───────┘  └───────────────┘  └─────▲─────┘  │
│                         │ Interactable contract (groups+layers)│     │
└─────────────────────────┼─────────────────────────────────────┼──────┘
                          │                                     │
┌─────────────────────────┼─────────────────────────────────────┼──────┐
│ PLAYER SCENE (player.tscn)                                    │      │
│  CharacterBody3D (root)                                       │      │
│   ├─ Model (glTF instance, Skeleton3D, AnimationTree)         │      │
│   ├─ StateMachine ──► States (Idle/Run/Sprint/Air/Dash/...)   │      │
│   ├─ MovementParams (Resource: .tres)                         │      │
│   ├─ InputRouter (reads Input Map -> intent struct)           │      │
│   ├─ HandController ──► active HandModule (component node)    │      │
│   │     ├─ Targeting (RayCast/ShapeCast, assist, highlight)   │      │
│   │     └─ HandSocket (Marker3D on arm bone: VFX anchor)      │      │
│   └─ CameraRig (separate node tree, follows player)           │      │
│        └─ Yaw -> Pitch -> SpringArm3D -> Camera3D             │      │
└──────────────────────────────────────────────────────────────────────┘
```

Data flows in two directions with distinct mechanisms:
- Downward (parent to child, controller to component): direct calls and property access.
- Upward and sideways (anything else): signals, either local (child to parent) or via EventBus for cross-scene concerns.

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| EventBus (autoload) | Global signal hub for cross-scene events only (`player_died`, `checkpoint_reached`, `module_unlocked`, `boss_defeated`). No state, no logic. | `extends Node` with only `signal` declarations |
| GameState (autoload) | Source of truth for progression: unlocked modules, flags, last checkpoint id. Emits change signals. | Node holding a `SaveData` Resource instance |
| SaveService (autoload) | Persist/restore `SaveData` to `user://`, restart level at checkpoint. | `ResourceSaver` / `ResourceLoader` on a `.tres` (text, diff-able) |
| DebugOverlay (autoload) | Runtime tuning panel, state label, velocity graph, god mode, teleport-to-checkpoint. Stripped in release via `OS.is_debug_build()`. | CanvasLayer + Labels, `Input.is_action_just_pressed("debug_*")` |
| Player (CharacterBody3D) | Owns the physics body, velocity, `move_and_slide()` call (exactly one place). | Root script is thin; delegates to StateMachine |
| StateMachine + States | Decide how velocity changes per physics tick; handle transitions. | Node-based states (see Pattern 1) |
| MovementParams | All tunable numbers for feel. | Custom `Resource` with `@export` vars, saved as `.tres` |
| InputRouter | Translate Input Map actions into a device-agnostic intent each frame. | Node reading `Input.get_vector()` / `is_action_*`; no hard-coded keys anywhere else |
| CameraRig | Over-shoulder follow, aim mode, collision, smoothing. Independent of the player's body rotation. | Node3D chain with SpringArm3D, `top_level` follow |
| HandController | Owns equipped/unlocked modules, routes the "use hand" action to the active module, owns Targeting. | Node on the player; holds `Array[HandModuleDef]` and instantiates module scenes |
| HandModule (component) | One ability: reads input intents when active, runs effect on target, spawns VFX at HandSocket. | Scene (`.tscn`) with script extending `HandModule`, described by a `HandModuleDef` Resource |
| Targeting | Find best Interactable in a cone/aim ray, drive highlight, provide aim assist. | Camera-origin RayCast3D + ShapeCast3D, filtered by collision layer + group |
| Interactable (contract) | World object advertises "I can be affected by module X". | Component node `Interactable` on the object, signals out |
| Mechanism components | Valve, Gear, Conveyor, Switch, Door: reusable behavior wired in the editor. | Small scenes with `@export` NodePaths and signals |
| Boss | Encounter state machine with phases; reuses the same StateMachine base. | Node-based states + `BossPhase` Resources |

## Recommended Project Structure

Feature-folders (group by feature, not by file type) so an AI agent can find everything about "player" in one place. Assets from Blender/Meshy live in `assets/` and are imported, not edited by hand.

```
project.godot
addons/                         # gdUnit4 (or GUT), nothing else initially
autoload/
  event_bus.gd
  game_state.gd
  save_service.gd
  debug_overlay.gd (+ .tscn)
core/                           # reusable, game-agnostic building blocks
  state_machine/
    state_machine.gd            # StateMachine node
    state.gd                    # base State
  components/
    interactable.gd             # Interactable contract
    health.gd                   # if the boss needs it
  resources/
    movement_params.gd          # class_name MovementParams
    hand_module_def.gd          # class_name HandModuleDef
    save_data.gd                # class_name SaveData
player/
  player.tscn / player.gd
  states/                       # idle.gd, run.gd, sprint.gd, jump.gd, fall.gd, dash.gd, (wall_run.gd)
  input_router.gd
  params/
    default_movement.tres       # the tuned feel lives here
  camera/
    camera_rig.tscn / camera_rig.gd
    camera_params.tres
hand/
  hand_controller.gd
  targeting.gd (+ .tscn)
  hand_module.gd                # base class HandModule
  modules/
    remote_trigger/             # first module
      remote_trigger.tscn / remote_trigger.gd
      remote_trigger.tres       # HandModuleDef
      vfx/
    <next_module>/              # copy the folder to add a module
mechanisms/
  valve/  gear/  conveyor/  switch/  door/   # each: .tscn + .gd
  wiring/                       # optional helper for editor-assigned links
world/
  levels/level_01.tscn
  checkpoints/checkpoint.tscn
  pickups/module_pickup.tscn    # grants a HandModuleDef
boss/
  boss.tscn / boss.gd
  states/
  phases/*.tres
ui/
  hud/ (crosshair, prompt)      # minimal, no dialogue per scope
assets/                         # imported glTF, textures; subfolders: characters/ props/ environment/ vfx/
  README.md                     # poly budgets and export rules (see PROJECT.md asset pipeline)
tests/
  unit/                         # pure logic: params, state transitions, save data
  integration/                  # scene runner: player in a test room, mechanism wiring
  test_rooms/                   # tiny .tscn scenes used by tests and for manual feel tuning
```

### Structure Rationale

- **core/ vs feature folders:** `core/` has no dependency on game content; features depend on `core/`, never the reverse. This keeps the state machine and Interactable reusable by Player, Boss and mechanisms.
- **hand/modules/<name>/ as a self-contained folder:** adding a module = adding one folder (scene, script, `HandModuleDef` .tres, VFX) plus one registry line. No other file changes. This is the key "easy to add and swap" requirement.
- **test_rooms/:** a flat gray-box scene per mechanic is the cheapest place to tune feel and the deterministic place for integration tests.
- **Everything is `.tscn` / `.tres` / `.gd`:** all params, module definitions, save data and boss phases are text Resources. Avoid binary `.res` and avoid committing scenes with huge embedded sub-resources (use external `.tres` files for diffability).

## Architectural Patterns

### Pattern 1: Node-based State Machine (flat first, hierarchical only if needed)

**What:** Each state is a child Node of a `StateMachine` node, with `enter(prev)`, `exit()`, `physics_update(delta)` and `handle_input()` hooks. States return or emit the next state name. The player owns velocity; states mutate it; the root calls `move_and_slide()` once.
**When to use:** Always for the player and the boss. Prefer this over enum+match because (a) each state is a small, separately testable and AI-editable file, (b) states can be unit-tested by instancing them with a stub player, (c) enum+match grows into one 600-line script that is hard to diff and review. Use a hierarchical machine only if duplication appears (e.g. an `Airborne` parent shared by Jump/Fall/WallRun/Dash-air). Start with flat plus a small shared base class (`AirState`, `GroundState`) via inheritance, which gives 90% of the benefit without a full HSM.
**Trade-offs:** More files than enum, slight indirection. Transitions scattered across states can hide the full graph, so document the transition table in the state machine script header or a markdown file.

**Example:**
```gdscript
# core/state_machine/state.gd
class_name State extends Node
signal transition_requested(next_state: StringName)
var actor: Node  # set by StateMachine (typed in subclasses)
func enter(_prev: StringName) -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass

# player/states/sprint.gd
extends GroundState
func physics_update(delta: float) -> void:
    var dir := actor.intent.move_world  # Vector3, camera-relative
    actor.velocity = actor.velocity.move_toward(dir * actor.params.sprint_speed,
                                                actor.params.accel * delta)
    if not actor.is_on_floor(): transition_requested.emit(&"Fall")
    elif actor.intent.jump_buffered: transition_requested.emit(&"Jump")
```

### Pattern 2: Tunable data as Resources (+ runtime hot-tweak)

**What:** `MovementParams extends Resource` with `@export` fields grouped by `@export_group` (walk_speed, sprint_speed, accel, decel, air_control, jump_velocity, gravity_up, gravity_down, coyote_time, jump_buffer_time, dash_speed, dash_time, dash_cooldown, ...). One `.tres` per profile; the player references it via `@export var params: MovementParams`.
**When to use:** All feel-critical numbers. This is the project's Core Value, so feel tuning must be cheap.
**Trade-offs:** Resources are shared by reference: mutating at runtime changes the saved file in-editor and affects all users. For debug tweaking, either edit the shared instance deliberately (and rely on the editor's save) or `duplicate()` per instance. Use a distinct "variable gravity" model (higher gravity when falling or when jump is released) as parameters, not as hard-coded branches.

### Pattern 3: Input abstraction via Input Map + intent struct

**What:** Define actions in Input Map from day one (`move_left/right/forward/back`, `jump`, `sprint`, `dash`, `aim`, `hand_use`, `module_next/prev`, `interact`, `pause`, `debug_*`). Bind KB+M now; later add gamepad events to the same actions in `project.godot` with no code change. Only `InputRouter` calls `Input.*`; everything else reads an `Intent` (RefCounted or plain dictionary-like class): `move: Vector2`, `move_world: Vector3`, `jump_pressed/held`, `jump_buffered`, `dash_pressed`, `aim_held`, `look_delta`.
**When to use:** Always. This also makes tests trivial (feed a fake Intent) and enables replay or AI-scripted inputs.
**Trade-offs:** One extra layer. Controller specifics that are NOT free later: look input needs stick-based camera speed (not delta pixels), deadzones per action, and aim-assist strength tuning. Keep camera look as two paths (`look_delta` from mouse, `look_axis` from stick, summed in CameraRig) so the second path can be added without refactor. Use `Input.get_vector()` with named deadzone settings in the Input Map, not manual math.

### Pattern 4: Hand modules as Resource definition + component scene (no mesh swapping)

**What:** Because the arm mesh is fixed, a module consists only of:
1. `HandModuleDef extends Resource` (data): `id: StringName`, `display_name`, `icon`, `scene: PackedScene` (the behavior), `target_group: StringName` (what it can affect, e.g. `&"triggerable"`), `max_range`, `cooldown`, `aim_assist_angle`, `highlight_color`, `unlock_flag`.
2. A behavior scene whose root script `extends HandModule` and implements a tiny interface: `activate(ctx)`, `deactivate()`, `on_use_pressed(target)`, `on_use_released()`, plus signals `used(target)`, `cooldown_started(t)`.
3. VFX children that parent to the single `HandSocket` Marker3D on the arm bone (via `BoneAttachment3D` or just a socket Node3D on the skeleton). All modules share this socket, so VFX authoring is "particles/mesh relative to socket origin".

`HandController` holds `unlocked: Array[HandModuleDef]`, instantiates the module scene lazily when first equipped, and calls only the base-class interface. Modules never reference the Player or other modules; they receive a context (`HandContext`: socket, targeting result, camera, owner player for velocity effects) at `activate`.

**Registration:** a single `hand/module_registry.tres` (an `Array[HandModuleDef]` Resource) or just a folder scan at startup via `DirAccess` in the debug build and a fixed list in release (folder scan inside exported PCK needs care with `.remap` files; the explicit registry is safer). Adding a module = new folder + one entry in the registry.

**Active vs passive modules:** Some candidate modules (Dampfstoß-Kolben boost, Rücklauf-Uhrwerk) affect the player's own movement or time rather than a target. The same interface covers this: `target_group` may be empty and the module acts on `ctx.player` through a deliberately narrow API (`apply_impulse(Vector3)`, never direct state-machine manipulation). If a module needs a new player state (e.g. grapple swing), it requests it via `actor.request_state(&"Grapple")` and the state ships with the module's folder, registered into the StateMachine at equip time. Flag this for per-module research.

**Unlock / progression gating:** pickup scene (`module_pickup.tscn`, export `module: HandModuleDef`) calls `GameState.unlock(def.id)`; GameState emits `EventBus.module_unlocked(id)`; HandController listens and adds to its list. Level gating is physical and data-driven, not scripted: a mechanism's `Interactable.required_module: StringName` means it simply never highlights or reacts unless that module is active. Soft-gating by geometry (a gap only crossable with the Dampfstoß module) needs no code at all.

**Trade-offs:** Resource+scene is slightly more ceremony than one script per module, but gives (a) inspector-editable range/cooldown tuning, (b) an icon and name for the HUD for free, (c) a clean seam for tests (instantiate module scene with a fake context).

**Example:**
```gdscript
# hand/hand_module.gd
class_name HandModule extends Node3D
signal used(target: Node)
var def: HandModuleDef
var ctx: HandContext
func activate(c: HandContext) -> void: ctx = c
func deactivate() -> void: pass
func on_use_pressed(_target: Interactable) -> void: pass
func on_use_released() -> void: pass

# hand/modules/remote_trigger/remote_trigger.gd
extends HandModule
func on_use_pressed(target: Interactable) -> void:
    if target and target.accepts(def.id):
        target.trigger(def.id, ctx.player)   # Interactable emits signal; it owns reaction
        used.emit(target)
```

### Pattern 5: Interactable contract (module to world)

**What:** The world never knows module classes, and modules never know mechanism classes. The only contract is the `Interactable` component:
- Node with `class_name Interactable`, a child of any world object (valve, switch, door). Exports: `accepts_modules: Array[StringName]` (which module ids may affect it), `highlight_mesh_paths`, `one_shot: bool`.
- Signals: `triggered(source: Node)`, `focused()`, `unfocused()`.
- Methods: `accepts(module_id) -> bool`, `trigger(module_id, source)`, `set_highlighted(on: bool)`.
- Discovery: the parent object's `Area3D`/`StaticBody3D` is on a dedicated physics layer `Interactable` (layer 5, say) and the Interactable node adds itself to group `&"interactable"` in `_ready()`. Targeting uses the physics layer for cheap ray/shape queries and the group for validation, then reads the Interactable via group membership or a `meta`/child lookup.
- Highlight: Interactable toggles a shared turquoise emission, either by setting `MeshInstance3D.material_overlay` (a shared `ShaderMaterial` / `StandardMaterial3D` with a fresnel/emission) or a `next_pass` outline. `material_overlay` is simplest: no mesh duplication, one shared `.tres`. Pulse via shader time uniform, no AnimationPlayer needed.
- Aim assist: Targeting does (1) a camera-center RayCast3D hit test; if nothing, (2) a ShapeCast3D (sphere, radius from `aim_assist_angle` and distance) collecting Interactables, scored by angular distance to the crosshair, filtered by `accepts(active_module_id)` and line-of-sight ray. The best candidate is the "focus". Optional magnetism (slight reticle snap) is a presentation-only effect so it is trivially tunable. Highlight "available" candidates dimly while hand module is equipped, "focused" candidate brightly.

**When to use:** Every object the hand can affect. Keep it a composition component, not an inheritance base, so a Door and a Valve can share it without a common parent class.
**Trade-offs:** One more node per object, but zero coupling and no `is_instance_of` chains.

### Pattern 6: Signals up, calls down; editor-wired mechanisms

**What:** Rules of thumb used across the project:
- Parent calls child methods directly (HandController calls `module.on_use_pressed`).
- Child announces with signals; parent or an editor connection decides the reaction.
- Siblings never reference each other by path in code. Cross-object wiring is done in the editor via exported `NodePath`/node references or Godot's signal connections stored in the `.tscn`.
- EventBus is for events with multiple unrelated listeners across scene boundaries (HUD, audio, save, GameState). Do not route every gameplay signal through it; it becomes an untraceable global. Rule: if the emitter and listener are both inside level_01, use a local signal.
- Direct calls are fine and preferred inside one scene when it is a hard dependency.

**Mechanisms as components:** Each mechanism is a small scene with a uniform signal vocabulary so they chain:
- Inputs (made available in the inspector): a `Interactable` child (hand can trigger it) and/or exported `activated_by: Array[Node]` or a method `set_powered(bool)` / `activate()`.
- Outputs: signals `activated`, `deactivated`, `progress_changed(value)`.
- Examples: `Switch` (Interactable -> toggles -> emits `toggled(on)`); `Valve` (Interactable -> animates rotation -> emits `opened`); `Gear` (rotates when `powered`; kinematic AnimatableBody3D carrying platforms); `Conveyor` (StaticBody3D with `constant_linear_velocity`, speed export, `powered` toggles it); `Door` (listens `open()`/`close()`, tweens).
- Wiring is entirely `.tscn` text: `[connection signal="opened" from="Valve" to="Door" method="open"]`. An AI agent can edit these lines directly. For multi-input logic (two switches open one door) add a tiny `Logic` node (`AND`, `OR`, `Counter`) with an `input_changed` method rather than putting logic in scripts.
- Use `AnimatableBody3D` (with `sync_to_physics`) for anything the player stands on that moves (gears, platforms, elevators). Moving platforms must carry the CharacterBody3D; Godot 4's `move_and_slide()` handles platform velocity when the platform is `AnimatableBody3D`/`constant_*_velocity`; set `platform_on_leave` so momentum is kept when jumping off (feel-critical).

### Pattern 7: Camera rig

**What:** A separate scene (not a child that inherits player rotation) following the player:

```
CameraRig (Node3D, top_level = true, position lerped to player.target_point)
 └─ Yaw (Node3D)           # rotated by horizontal look
     └─ Pitch (Node3D)     # rotated by vertical look, clamped (e.g. -70..+60 deg)
         └─ SpringArm3D    # spring_length from CameraParams, shape = SphereShape3D(radius ~0.2), collision_mask = world layer only
             └─ Camera3D
```
- Over-shoulder: offset the Yaw/Pitch pivot (or the Camera3D `h_offset`) laterally by `shoulder_offset`; side swap optional.
- Aim mode: lerp (not snap) `spring_length`, `shoulder_offset`, FOV and look sensitivity multiplier to the aim preset, driven by `intent.aim_held`. Keep both presets in `camera_params.tres` as sub-Resources `CameraPreset`. Show crosshair in HUD only while aiming.
- Collision: SpringArm3D with a sphere shape and a mask that excludes the player, Interactables and triggers. Add the player body RID to `SpringArm3D.add_excluded_object()`. Small `margin` to avoid clipping near-plane through walls.
- Smoothing: follow position with frame-rate-independent lerp (`1.0 - exp(-k * delta)`), but rotation of the look pivot is NOT smoothed for mouse (raw input must feel direct); smooth FOV changes (sprint/dash widen), spring length, and vertical follow (so jumping does not whip the camera). Use `Engine.physics_ticks_per_second` interpolation: enable `physics_interpolation` (Godot 4.4+) for the player and camera to avoid jitter when render FPS differs from physics tick (a common source of "not smooth" complaints in a project whose Core Value is smoothness).
- Player facing: in free mode the model rotates toward movement direction (slerp with `turn_speed` param); in aim mode the model faces camera yaw (strafing).
- Camera drives movement direction: `InputRouter` converts 2D input to `move_world` using the camera yaw basis, so the player and camera stay decoupled (player never holds a camera reference; the router is given a `basis_provider`).

**Trade-offs:** More nodes than a single SpringArm on the player, but avoids the classic bugs (camera rotating with the character, jitter from physics vs process, collision with own body).

### Pattern 8: Boss as state machine with data-driven phases

**What:** Reuse `core/state_machine`. Boss states (`Idle`, `Telegraph`, `Attack_X`, `Stagger`, `Phase_Transition`, `Defeated`) and `BossPhase` Resources (`.tres`: health threshold, attack weights, speed multiplier, which states are enabled). A thin `BossBrain` picks the next attack from the current phase's weighted list and tells the state machine. The "puzzle boss" pattern fits this project best: the boss's vulnerability is created by the hand modules and world mechanisms (e.g. arena valves expose a weak point). Therefore the boss exposes its own `Interactable`s (weak points) and the arena uses the same mechanism components. This makes the boss a composition of existing pieces rather than a new subsystem.
**When to use:** Single boss, vertical slice. Do not build a general enemy AI framework. Do not use behavior trees or GOAP.
**Trade-offs:** Hard-coded attack scripts are fine; telegraphing and readability matter more than variety.

### Pattern 9: Checkpoint and save (minimal)

**What:** `SaveData extends Resource` (`unlocked_modules: Array[StringName]`, `flags: Dictionary`, `checkpoint_id: StringName`). Checkpoints are `Area3D` scenes with an id; entering one emits `EventBus.checkpoint_reached(id)`, GameState records it, SaveService writes `user://save.tres`. Respawn = reload current scene, place the player at the checkpoint Marker3D, re-apply unlocked modules and re-apply persistent mechanism state. Mechanism state persistence: each persistent mechanism has an exported `persist_id` and joins group `&"persistent"` implementing `get_state()/apply_state()` (only needed for one-shot mechanisms such as opened doors; start with "reload level resets non-persistent mechanisms" and persist only what is necessary).
**Trade-offs:** Scene reload for respawn is simplest and avoids stale-state bugs; accept the ~sub-second load for a single level. Keep it text (`.tres`) for debugging rather than binary `store_var`.

## Data Flow

### Frame / Tick Flow (feel-critical path)

```
Hardware (mouse/keys) -> Input Map actions
    -> InputRouter (_physics_process, sampled once per tick) -> Intent
    -> CameraRig yaw -> Intent.move_world
    -> StateMachine.current_state.physics_update(delta)  (reads Intent + MovementParams)
    -> Player.velocity updated -> move_and_slide()  [single call site]
    -> AnimationTree parameters updated from velocity/state (presentation only, no gameplay logic)
    -> CameraRig follows (process, interpolated)
```

### Hand Use Flow

```
[hand_use pressed] -> InputRouter Intent.hand_use_pressed
   -> HandController.update(): Targeting.get_focus(active_module.def)
        -> Interactable.set_highlighted(true/false) (focus changes only)
   -> active_module.on_use_pressed(focus)
        -> focus.trigger(module_id, player)
             -> Interactable emits `triggered`
                  -> (editor connection) Valve.open() -> emits `opened`
                       -> (editor connection) Door.open() / Gear.set_powered(true)
   -> module spawns VFX at HandSocket (e.g. turquoise beam to focus.global_position)
```

### State Management

```
GameState (autoload, single source of truth)
   unlocked modules, flags, checkpoint
      ▲ unlock()/set_flag()          │ signals via EventBus
ModulePickup / Boss ──────────────────┘──► HandController, HUD, SaveService
```
Gameplay state that is NOT global (current player state, module cooldowns, mechanism positions) stays local to its node. Do not mirror it in GameState.

### Key Data Flows

1. **Input to motion:** Input Map -> Intent -> State -> velocity. Only InputRouter touches `Input`.
2. **Module to world:** Module -> Interactable.trigger() -> signal -> mechanism -> signal -> other mechanism. Modules know only Interactable; mechanisms know only signals.
3. **Progression:** Pickup -> GameState.unlock -> EventBus.module_unlocked -> HandController/HUD/Save.
4. **Tuning:** `.tres` params are edited in Inspector (live in running game via remote scene tree) or via DebugOverlay sliders that write to the live params resource.

## Debug and Tuning Tooling

- **DebugOverlay autoload** (debug builds only): current player state name, speed, vertical velocity, `is_on_floor`, coyote/buffer timers, focused Interactable, FPS. Toggle with an action.
- **Live tuning:** Godot's remote inspector edits the running scene's exported Resources (note shared-reference caveat above). Optionally add sliders generated from `MovementParams` property list (`get_property_list()` filtered by `PROPERTY_USAGE_EDITOR`) so new parameters appear automatically; a "Print params as .tres diff" or "Save to default_movement.tres" button via `ResourceSaver.save` closes the loop so tuned values land in git.
- **Gizmos/drawing:** Draw targeting ray/cone, spring arm, ground check and dash path with `ImmediateMesh` or a debug-draw helper, toggled by action. Use `@tool` scripts sparingly (they run in the editor and can corrupt scenes if buggy).
- **Test rooms:** `tests/test_rooms/` gray-box scenes (flat run strip, jump gaps at known distances, wall-run wall, mechanism sandbox) double as manual tuning rooms. Quantify feel with measurable targets: max jump height, jump distance at sprint, time-to-top-speed. Assert them in tests so tuning regressions are caught.
- **Cheats:** teleport to checkpoint, unlock all modules, god mode, slow-motion (`Engine.time_scale`).
- **Rendering of the Low-Poly look is a separate concern:** keep lighting/environment in one `WorldEnvironment` resource so art direction tuning does not touch gameplay scenes.

## Testing Strategy

- **Framework recommendation:** GdUnit4 (addon, active, v6.x line observed in 2026, MEDIUM confidence on exact version). Reasons: `GdUnitSceneRunner` can simulate input and await signals/frames, JUnit XML export, command-line runner for headless CI, plus a GitHub Action. GUT is the acceptable alternative and also text-based; choose one and do not mix. Pin the addon version in the repo and verify compatibility with the chosen Godot version before phase 1.
- **What to test (high value, low cost):**
  - Pure logic: `MovementParams` sanity (e.g. gravity > 0, coyote time >= 0), coyote/jump-buffer timer logic, state transition tables, `SaveData` round trip, `HandModuleDef` validation (scene set, id unique across the registry), Interactable `accepts()` rules, boss phase selection (seeded RNG).
  - Integration via scene runner: player in a test room reaches a known jump height; a switch triggers a door via the editor-authored connection; a module pickup unlocks a module and the HUD event fires; checkpoint respawn restores unlock state.
  - Contract test: iterate the module registry and instantiate each module scene with a fake `HandContext`; assert it implements the interface and does not error on `activate/deactivate`. This guards "easy to add" as modules grow.
- **What not to test:** subjective feel, camera smoothness, VFX. Cover through test rooms and the debug overlay.
- **Determinism:** tests drive `_physics_process` via the scene runner's simulate-frames; keep logic in `_physics_process` with `delta` so results are reproducible; inject RNG seeds.
- **CI caveat:** headless Godot can exit 0 despite script errors or an un-awaited check (reported on a community forum). Make CI parse the GdUnit4 report/XML and fail on any `ERROR` in log output, not just on the exit code. Confidence MEDIUM (single forum report).
- **Typing for AI agents:** use static typing everywhere (`var x: float`, typed arrays, `class_name`), since errors surface at parse time and are catchable by a headless `--check-only` / `--import` run before tests. Run `godot --headless --quit` style import step in CI so `.uid`/class cache are valid (class_name resolution requires the global class cache from an import pass).

## Text-Friendliness Rules for an AI Coding Agent

1. Prefer text formats only: `.tscn`, `.tres`, `.gd`, `project.godot`, `.import` files committed, glTF assets are imported by Godot (the `.import` sidecar is text).
2. Keep scripts small and one responsibility per file; `class_name` for every reusable type so references are by type, not path strings.
3. Prefer editor-authored `[connection]` lines and `@export` references over `get_node("../../X")` strings; if paths are unavoidable use `%UniqueName` (scene-unique nodes) so renaming parents does not break scripts.
4. Do not hand-write UIDs for new resources; `uid://` values are generated by the editor. When an agent creates a `.tscn`/`.tres` by hand, omit the `uid` attribute and use `res://` paths (Godot assigns UIDs on next open/import; Godot 4.4+ also writes `.gd.uid` files that should be committed). Verify with a headless import pass after agent edits.
5. Avoid giant inline sub-resources in scenes (animation libraries, meshes) so diffs stay readable: store them as separate `.tres`.
6. Add `.gitignore` for `.godot/`, and `.gitattributes` for text line-ending normalization (Windows dev machine: avoid CRLF churn in `.tscn`).
7. Provide a short `docs/conventions.md` (layers, groups, action names, signal naming `past_tense`, folder rules) so the agent follows the same vocabulary. The collision layer table is a project setting; document it in the same place.
8. Use GDScript only (no C#, no GDExtension) for the slice: no build step, fastest agent iteration.

## Collision Layers and Groups (define in phase 1, change never)

| Layer | Name | Used by |
|------:|------|---------|
| 1 | World | static level geometry, camera collision |
| 2 | Player | CharacterBody3D |
| 3 | Platforms | moving AnimatableBody3D (player collides, camera optional) |
| 4 | Enemies/Boss | boss body, hazards |
| 5 | Interactable | hand targeting queries only |
| 6 | Triggers | checkpoints, kill zones (Area3D) |

Groups: `interactable`, `persistent`, `player`, `checkpoint`. Name layers in Project Settings so the `.godot`-independent `project.godot` text documents them.

## Scaling Considerations

(For a vertical slice, "scale" means content growth: more modules, more mechanisms, more levels later, not users.)

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Slice: 1 level, ~3-4 modules, 1 boss | As described. Flat state machine, explicit module registry, scene reload for respawn. |
| 5-10 modules | Introduce `Logic` helper nodes for puzzles; module folder scanning/validation tests; consider module-specific player states registered at equip time. |
| Multiple levels | Add level scenes + a `LevelManager` autoload with scene transitions and `ResourceLoader.load_threaded_request` for streaming; promote persistence to per-level flags. Not needed now. |

### Scaling Priorities

1. **First bottleneck: movement states duplicating logic.** Fix with shared base states (`GroundState`/`AirState`), then hierarchical machine if still painful.
2. **Second bottleneck: module-to-player coupling** when modules need special movement (grapple, boost). Fix by routing through a narrow player API and module-provided states, never by letting modules write `velocity` arbitrarily.
3. **Performance** is not a risk at this scale if the Low-Poly budgets in the asset pipeline are respected; watch physics cost from many ShapeCasts per frame (limit targeting to one query per physics tick) and transparent VFX overdraw (steam).

## Anti-Patterns

### Anti-Pattern 1: Everything in autoloads

**What people do:** Put player reference, camera, level state and utilities in autoloads for convenient access.
**Why it's wrong:** Hidden coupling, impossible to test scenes in isolation (tests must run with the same global state), reload/respawn bugs from stale globals.
**Do this instead:** Autoloads only for EventBus, GameState, SaveService, DebugOverlay. Pass references down via `@export` or the context object.

### Anti-Pattern 2: One giant player script / enum+match with all abilities

**What people do:** Movement, camera, hand and animation in `player.gd` with `match state:`.
**Why it's wrong:** Every new ability (dash, wall-run, module) risks regressions; AI edits conflict; unit testing impossible.
**Do this instead:** State machine with one file per state, `HandController` and `CameraRig` as separate nodes.

### Anti-Pattern 3: Modules that know the world (or world that knows modules)

**What people do:** `if module is RemoteTrigger and target is Valve:` chains, or mechanisms checking the player's equipped module.
**Why it's wrong:** Every new module touches every mechanism, defeating "easy to add".
**Do this instead:** `Interactable.accepts(module_id)` plus signals. New module -> new folder + registry entry only.

### Anti-Pattern 4: Mesh/animation coupling per module (explicitly out of scope)

**What people do:** Swap arm meshes or rig attachments per ability.
**Why it's wrong here:** User decision: arm is fixed. It would add Blender/Meshy pipeline work and runtime attachment logic with no gameplay benefit.
**Do this instead:** Fixed arm, per-module VFX parented to the shared `HandSocket`. If a module needs a distinct pose, add an animation to the shared AnimationTree (upper-body blend), not a new mesh.

### Anti-Pattern 5: Physics in `_process` / multiple `move_and_slide()` calls

**What people do:** Movement in `_process`, or calling `move_and_slide()` from states and the root.
**Why it's wrong:** Frame-rate dependent feel, double movement, jitter. Directly harms the Core Value.
**Do this instead:** All gameplay in `_physics_process`, single `move_and_slide()` in the player root, physics interpolation enabled, camera updated after the player.

### Anti-Pattern 6: Scripting every puzzle connection

**What people do:** A level script that finds nodes by path and connects signals in `_ready()`.
**Why it's wrong:** Not visible in the editor, not diff-friendly, breaks on renames.
**Do this instead:** Editor-authored connections in the `.tscn` and exported node references; `Logic` nodes for combinations.

### Anti-Pattern 7: Hard-coded keys or `Input.is_key_pressed`

**What people do:** `KEY_SHIFT` checks for sprint.
**Why it's wrong:** Blocks controller support without refactor, contrary to project constraint.
**Do this instead:** Input Map actions only, read only in InputRouter.

### Anti-Pattern 8: Over-engineering the boss and save system

**What people do:** Behavior trees, generic serialization frameworks.
**Why it's wrong:** Time sink for one boss and one level.
**Do this instead:** State machine + phase Resources; `SaveData` Resource with three fields.

## Suggested Build Order (dependencies)

```
1. Project skeleton + conventions        (folders, layers, Input Map, autoload stubs, .gitignore, test addon, CI check)
2. Player body + InputRouter + flat state machine + MovementParams   [Core Value]
        depends on: 1
3. CameraRig (follow, collision, smoothing) + physics interpolation  [Core Value]
        depends on: 2 (target) and Input Map; developed in lockstep with 2
4. Movement extras: sprint, dash, coyote/buffer polish, moving platforms, (wall-run optional)
        depends on: 2, 3; tuned in test rooms with DebugOverlay
5. Interactable contract + Targeting + highlight + aim mode (camera aim preset, crosshair)
        depends on: 3 (aim camera), 1 (layers)
6. HandController + HandModule base + HandModuleDef + first module (remote trigger) + HandSocket VFX
        depends on: 5
7. Mechanism components (Switch, Valve, Door, Gear, Conveyor) + Logic nodes, wired in a sandbox room
        depends on: 5 (Interactable); can start in parallel with 6 using a fake trigger
8. Progression: ModulePickup, GameState unlock, HUD module indicator, Checkpoint + SaveService + respawn
        depends on: 6, 7
9. Second/third module (validates the "easy to add" claim; adjust interface once, early)
        depends on: 6, 8
10. Level 01 blockout (gray-box, using test-proven mechanisms) -> art pass with Blender/Meshy assets
        depends on: 4, 7, 8; art pipeline runs in parallel from phase 2 (character import/rigging early)
11. Boss (state machine, phases, weak-point Interactables, arena mechanisms)
        depends on: 7, 9, 10
12. Polish: audio, VFX, controller bindings and camera stick path, tuning pass
        depends on: all
```

Ordering rationale: the Core Value is movement plus camera feel, so they come first and are tuned continuously. The Interactable contract is built before the first module so the module system is designed against a real consumer. Build the second module immediately after the first (before level content) so the module interface is validated while changing it is still cheap. Character import (Meshy to Godot, skeleton, AnimationTree) should start early because movement states drive animation parameters; use a placeholder capsule until then so gameplay is not blocked.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Meshy / Blender MCP (asset pipeline) | Export glTF -> `assets/` -> Godot import; character with humanoid skeleton and a hand-bone socket | Fixed arm means only one rig and one `HandSocket`. Decide poly budget and bone naming before rigging; wrong scale and axis conventions are the main import risk. |
| GdUnit4 / GUT CI | Headless CLI run, JUnit XML | Parse report, do not trust exit code alone. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| InputRouter -> States | Intent object (read) | Only place `Input` is used |
| CameraRig <-> Player | Router receives camera yaw basis; camera follows a `Marker3D` target | No mutual node references |
| HandController -> Module | Direct method calls (base interface) | Module receives `HandContext` |
| Module -> Interactable | `accepts()` + `trigger()` | Only coupling between ability and world |
| Interactable -> Mechanism | Signals, editor connections | Mechanisms never see modules |
| Mechanism -> Mechanism | Signals / `Logic` nodes | No code coupling |
| Pickup/Boss -> GameState | Method call on autoload, then EventBus signal | GameState is the only writer of progression |
| Anything -> HUD | EventBus signals | HUD never polled by gameplay |
| Module -> Player movement | Narrow API (`apply_impulse`, `request_state`) | Needed only for movement-type modules |

## Gaps and Open Questions (for phase-level research)

- Exact current Godot version: search results show 4.6.x stable (Jan to May 2026) and an unverified 4.7 listing. Pin a version in phase 1 (recommend the latest verified-stable 4.6.x unless 4.7 is confirmed on godotengine.org) and confirm GdUnit4 compatibility.
- Movement-type modules (boost, grapple, time rewind) may require extra player states or time-scoped mechanisms (rewind needs recordable mechanism state: design `Rewindable` interface before committing to that module).
- Wall-run: kept optional in PROJECT.md; if included it needs wall detection and camera interaction research.
- Aim-assist numbers (cone angle, magnetism) and highlight shader are tuning problems, not architecture; settle by prototyping in phase 5.
- Mechanism persistence granularity (what survives checkpoint respawn) to be decided with level design.
- Animation approach (AnimationTree with state machine vs driven by code) depends on what Meshy-generated rigging provides; research with the first imported character.

## Sources

- Godot official documentation (stable): CharacterBody3D, SpringArm3D, Resources, Input Map and `Input.get_vector`, physics interpolation, scene organization best practices ("Scene organization", "Autoloads versus regular nodes", "Using signals"), project organization. Pattern knowledge from the docs; not re-fetched in this session. Confidence: HIGH for patterns, MEDIUM for version-specific details (verify against the pinned version).
- Godot release listings (secondary mirrors, 4.6.0 stable Jan 2026, 4.6.2/4.6.3, an unconfirmed 4.7): https://www.apkmirror.com/apk/godot-foundation/godot-engine-4-2/ . Confidence: LOW-MEDIUM; verify at godotengine.org/releases.
- GdUnit4 repository (scene runner, CLI tool, JUnit XML, GitHub Action): https://github.com/MikeSchulze/gdUnit4 and listing https://dev.co/testing/open-source/gdunit4 (v6.1.3, 2026-04-27, third-party). Confidence: MEDIUM.
- Godot forum report on headless runs exiting 0 despite failures: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990 . Confidence: MEDIUM (single report).
- Community practice (state machine as nodes, component pattern, "call down signal up", Resource-based data): widely documented in Godot community tutorials and GDQuest/Godot docs; synthesized, not individually cited. Confidence: MEDIUM-HIGH.
- Project context: M:/GIT/Attimo/.planning/PROJECT.md

---
*Architecture research for: Godot 4 3D third-person platformer with modular hand-ability system*
*Researched: 2026-11-02*
