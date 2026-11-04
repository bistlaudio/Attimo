# Phase 1: Foundation & Prototype Character - Research

**Researched:** 2026-11-04
**Domain:** Godot 4.7.2 project bootstrap (GDScript, Jolt, Forward+, physics interpolation), glTF/AnimationTree pipeline for KayKit Mannequin_Medium + Rig_Medium clips, autoload event bus, headless smoke testing
**Confidence:** HIGH (almost every pipeline claim below was reproduced in a throw-away spike project against the real Godot 4.7.2 binary and the real KayKit files; the spike lives only in the session scratchpad, not in the repo)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Repo, assets and structure**
- **D-01:** The Godot project root stays `attimo/` (contains `project.godot`). The repo root keeps `.planning/`, `docs/` and `KayKit/`. Godot only imports what lies under `attimo/`, so `KayKit/` is never imported. — **Reversibility:** costly — moving `project.godot` later changes every `res://` path and the repo layout.
- **D-02:** The raw packs (`KayKit/`: Character Animations, Skeletons, Dungeon Pack, Prototype Bits, Brackeys VFX, Kenney particles, ~205 MB) stay tracked in git as a shared reference library. They were committed on `dev` in `a8ece0e`. The earlier plan to gitignore them is dropped. ROADMAP.md (Phase 1 criterion 2), REQUIREMENTS.md (FOUND-04) and CLAUDE.md (Git Workflow) were updated to match.
- **D-03:** No Git LFS for now. Plain git. Revisit before Phase 9 (Meshy hero, steampunk kit, audio) if binaries grow large.
- **D-04:** Used assets are COPIED (not moved) from `KayKit/` into `attimo/assets/`. `KayKit/` stays complete as reference. Only the used Prototype Bits pieces, the Mannequin_Medium and the Rig_Medium animation library go into `assets/`.
- **D-05:** Folder layout by type inside `attimo/`: `scenes/`, `scripts/`, `assets/`, `autoload/`. Files are `snake_case`, nodes and classes are `PascalCase`.

**Character and animation**
- **D-06:** Player scene `player.tscn`: `CharacterBody3D` > `VisualRoot` > Mannequin scene. `VisualRoot` has its pivot at the feet. Later phases reuse it for flip/lean (Phase 3), the final hero (Phase 9) and squash/stretch (Phase 11).
- **D-07:** The Mannequin is wrapped in its own scene around the imported GLB. The imported GLB is never edited in place.
- **D-08:** Animation runs through an `AnimationTree` with a state machine (Locomotion, Jump, Fall, Dash as in the stack plan in CLAUDE.md). Code sets parameters. The movement state machine stays the source of truth.
- **D-09:** Phase 1 is a demo, not real movement. The scaffold (`CharacterBody3D`, node-based state machine) exists, but there is no tuned walk/jump physics. Input actions trigger the clips (Idle, Run, Jump, Dodge). Tuned movement is Phase 2.

**Event bus and debug log**
- **D-10:** The event bus is an autoload with typed signals (for example `signal jumped(position: Vector3)`). Gameplay code only emits. It calls no feedback directly. Juice (Phases 11-12) and audio (Phase 14) connect to these signals later.
- **D-11:** Phase 1 declares only the facts the demo triggers: `jumped`, `landed`, `dash_started`, plus a movement state change fact (for example `movement_state_changed`). More facts arrive with their own phases.
- **D-12:** The debug event log is an in-game overlay: a scrolling list of recent events with timestamps, toggled by a key (for example F3). No particles and no juice effects in the scene.

**Conventions and documentation**
- **D-13:** Conventions are documented in `docs/CONVENTIONS.md`: collision layers, groups, folder and naming rules, Input Map action names. Layer names are also set in `project.godot` so the editor shows them.
- **D-14:** Collision layers (full list plus reserve): World, Player, Interactable, Enemy, Projectile/Beam, Hazard. Further layer numbers stay free and reserved. — **Reversibility:** costly — every mask in every scene and script references these numbers.
- **D-15:** Input Map uses the action names from the stack table in CLAUDE.md (`move_forward/back/left/right`, `jump`, `sprint`, `dash`, `aim`, `use_hand`, `interact`, `module_next/prev`, `pause`). KB+M is bound now. Gamepad slots are reserved but not bound. — **Reversibility:** costly — action names are referenced from code throughout.

**Project settings (carried from CLAUDE.md, not re-discussed)**
- Godot 4.7.2 standard build, typed GDScript, Jolt (already set), Forward+ with D3D12 on Windows (already set), Physics Interpolation ON (still to set). The current `project.godot` has Jolt and D3D12 only: no input actions, no layers, no interpolation, no scenes yet.

### Claude's Discretion
- Exact key for the debug log toggle, overlay look and event payload fields.
- Test scene layout and size, as long as it uses only Prototype Bits pieces and has reference geometry on a 1 m grid.
- Exact AnimationTree state names and the clip-to-state mapping, using the KayKit clip names (Idle_A, Running_A/B, Jump_*, Dodge_*).
- Groups list in CONVENTIONS.md, beyond the layers above.

### Deferred Ideas (OUT OF SCOPE)
- Git LFS for large binaries: revisit before Phase 9.
- Cleaning the 205 MB of raw packs out of git history: not planned. Only relevant if repo size becomes a problem.

Also out of scope per the phase boundary: real movement tuning (Phase 2), camera (Phase 2), gamepad bindings (Phase 13), particles/juice (Phases 11-12), Meshy work, the cue catalogue (Phase 11).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Project runs in Godot 4.7.x (pinned) with typed GDScript, Jolt physics, Forward+ and physics interpolation enabled | `project.godot` target block below (verified keys: `physics/common/physics_interpolation`, `debug/gdscript/warnings/untyped_declaration=2` turns untyped code into a parse error); `Engine.get_version_info()` pin test; local binary availability notes |
| FOUND-02 | All player input goes through named Input Map actions (KB+M bound now, gamepad slots reserved) | Verified `[input]` serialisation format (`"device":-1`), action table, empty-events trick for `look_*`, grep guard against raw key polling |
| FOUND-03 | Collision layers, groups and folder conventions are fixed and documented | Layer table with bitmask values, `layer_names/3d_physics/layer_N` keys verified, CONVENTIONS.md outline, `PhysicsLayers` constants pattern |
| FOUND-04 | Raw KayKit/VFX packs stay tracked in repo root `KayKit/`; only used assets copied into `attimo/assets/` | Exact source paths, files to copy (gltf needs `.bin` + texture), asset whitelist test |
| FOUND-05 | Prototype uses Prototype Bits for greybox + Mannequin_Medium (Rig_Medium) with KayKit clips; no particles/juice | Verified: Mannequin + animation GLB share track paths, animation-library builder script, AnimationTree text format, wrapper-scene pattern, tscn `node_paths` gotcha |
| FEEL-01 | Feedback hooks: gameplay events broadcast so juice can be layered on without touching gameplay code | EventBus autoload code, generic auto-connecting debug log (verified variadic handler), grep guard for forbidden feedback calls |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Directives extracted from `/Users/bistl/GIT/Attimo/.claude/CLAUDE.md` that the plan must respect:

- Engine: **Godot 4.7.2-stable, standard build (NOT .NET)**; pin the exact version in README and have every machine use it.
- **GDScript, statically typed everywhere** (`var speed: float`, `-> void`). No C#.
- **Jolt** physics (default for new projects), **Forward+** renderer, D3D12 on Windows. Use primitive/convex collision shapes for platforms, not trimesh of the visual mesh.
- Player = `CharacterBody3D` + own controller script; **hand-rolled node-based state machine** (State nodes under a StateMachine node). No addon controller, no RigidBody3D.
- Physics Interpolation ON; camera work in `_process`, physics in `_physics_process`.
- Input Map actions from day one; action names exactly as in the stack table (`move_forward/back/left/right`, `look_*`, `jump`, `sprint`, `dash`, `aim`, `use_hand`, `interact`, `module_next/prev`, `pause`).
- Assets: KayKit style, glTF. Raw packs stay in repo-root `KayKit/` (outside `attimo/`); only used assets are copied to `attimo/assets/`.
- Addons list must stay SHORT. gdUnit4 is OPTIONAL. Debug Draw 3D and Phantom Camera are **not** Phase 1 (camera = Phase 2).
- **Git:** all phase work on `dev`; never commit phase work to `main`; merge `dev` to `main` only after verification.
- **GSD workflow:** file changes go through GSD commands (execute-phase), not ad hoc.
- **Language:** user writes German, answers in German; planning docs stay in English.
- Conventions/Architecture sections of CLAUDE.md are empty: Phase 1 establishes the patterns (documented in `docs/CONVENTIONS.md`).

## Summary

Phase 1 is almost entirely "wire known engine features together correctly", and the risky unknowns are small and now resolved. I downloaded nothing new: the user already has `Godot_v4.7.2-stable_macos.universal.zip` in `~/Downloads`; I extracted it into the session scratchpad and ran a scratch project against it (`4.7.2.stable.official.ed1daf0bf`). Everything below tagged `[VERIFIED: spike]` was executed there: GLB import, animation library extraction, `AnimationTree` state-machine travel, `project.godot` serialisation of input actions/layers/autoloads, a typed-GDScript-as-error setting, an autoload event bus with a generic auto-connecting debug listener, a state machine + player scaffold driven by simulated input, and an exit-code-reporting headless test runner.

The three non-obvious results that most shape the plan: (1) `Mannequin_Medium.glb` and the `Rig_Medium_*.glb` animation files use identical node paths (`Rig_Medium/Skeleton3D:<bone>`), so KayKit clips play on the Mannequin with **no retargeting**; but the clips import as non-looping and live inside per-file `AnimationPlayer`s, so a small build script must merge the wanted clips into one `AnimationLibrary` `.res` with loop modes set. (2) The animation GLB skeletons contain `handslot.l/r` bones that the Mannequin skeleton does not have; the tracks are silently ignored (no warnings), but Phase 5 attachments must use `hand.r`/`hand.l`. (3) Hand-written `.tscn` files must declare `node_paths=PackedStringArray(...)` for any script with Node-typed `@export` vars, otherwise the exports arrive `null` (reproduced).

**Primary recommendation:** Build Phase 1 as four small plans in this order: (A) `project.godot` + folder skeleton + EventBus + CONVENTIONS.md, (B) asset copy/import + animation-library build script + `mannequin.tscn` wrapper + AnimationTree, (C) player scaffold (state machine, 5 states, animator) + Prototype Bits test scene + debug event log, (D) headless smoke test suite + human play-through. Use the verified code in the Code Examples section as the starting point instead of re-deriving it.

## Architectural Responsibility Map

This is a game (single-process Godot app), so "tiers" are engine layers rather than browser/API/DB.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Engine/runtime settings (Jolt, interpolation, typing, layers, input) | `project.godot` (config) | `docs/CONVENTIONS.md` | Settings are the single source of truth; docs mirror them; a smoke test asserts they match |
| Gameplay facts (jumped, landed, dash_started, state change) | Autoload `EventBus` (signals only) | — | Emitters (states) and listeners (debug log now; juice/audio later) never reference each other |
| Movement state (what the player is doing) | `StateMachine` + `State` nodes under `Player` | `CharacterBody3D` script (single `move_and_slide()` call site) | CLAUDE.md: FSM is source of truth |
| Animation playback | `AnimationTree` inside `mannequin.tscn` | `MannequinAnimator` node (maps FSM state -> tree state) | D-08: code sets parameters; FSM stays authoritative; animator is presentation, listens to the FSM's local signal, not the global bus |
| Visual orientation/scale hooks | `VisualRoot` (Node3D, pivot at feet) | — | D-06: later phases rotate/scale this node, never the body |
| Greybox collision | `StaticBody3D` wrapper scenes (one per Prototype Bits piece) | Layer `World` | KayKit glTFs ship without collision; wrapper = collision + instanced glTF |
| Debug event log | `CanvasLayer` scene instanced by the test scene | Reads `EventBus` signals generically | Debug-only; not an autoload so it is trivially absent from release (REL-03) |
| Asset pipeline (animation library) | Editor-time tool script (`tools/`) -> committed `.res` | `.glb` sources in `assets/` | Reproducible, no editor clicking, text-driven |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine (standard, not .NET) | **4.7.2-stable** | Engine | Pinned by CLAUDE.md; `4.7.2.stable.official.ed1daf0bf` ran all spikes [VERIFIED: spike, `Godot --version`] |
| GDScript (typed) | bundled | All code | CLAUDE.md; typing enforced by `debug/gdscript/warnings/untyped_declaration=2` [VERIFIED: spike - untyped `var a = 5` fails to load with "Warning treated as error"] |
| Jolt Physics | bundled | 3D physics | Already set in `project.godot` line 19: `3d/physics_engine="Jolt Physics"` [VERIFIED: attimo/project.godot:19] |
| Forward+ renderer | bundled | Rendering | `config/features` line 14 contains `"Forward Plus"`; `rendering/renderer/rendering_method` resolves to `forward_plus` with no override [VERIFIED: spike + attimo/project.godot:14] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KayKit Prototype Bits 1.1 FREE (CC0) | 1.1 | Greybox pieces | Test scene geometry (copy `.gltf` + `.bin` + `prototypebits_texture.png`) |
| KayKit Character Animations 1.1 (CC0) | 1.1 | `Mannequin_Medium.glb` + `Rig_Medium_*.glb` clips | The prototype character and its clips |

**No addons are installed in Phase 1.** Phantom Camera (Phase 2), Debug Draw 3D (Phase 2+), gdUnit4 (optional, see Validation Architecture) are all deferred.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom headless smoke runner (`-s` script) | gdUnit4 v6.2.3 | gdUnit4 gives richer asserts/reports but is an addon with unverified 4.7.2 compatibility here; Phase 1 needs ~30 asserts. Stay custom; revisit in Phase 2 if pure-logic tests grow |
| Merged `AnimationLibrary` `.res` built by script | Runtime-load the GLBs and copy their `AnimationPlayer` library | Runtime merge works but is invisible to the editor and re-does work every launch; committed `.res` is inspectable in the editor |
| Wrapper scene per Prototype Bits piece | `.import` `_subresources` auto-physics on the glTF | Wrapper keeps layers/shape types explicit and visible in the scene diff (D-07 spirit); import-time physics hides them in `.import` params |

**Installation:** none (no packages). Engine: user has `~/Downloads/Godot_v4.7.2-stable_macos.universal.zip` (sha256 `c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e`); `~/Downloads/Godot.app` is **4.6.3 - do not use** [VERIFIED: ran `Godot --version` on both].

**Version verification:** engine version confirmed by running the binary (above). No registry packages involved.

## Package Legitimacy Audit

Not applicable: Phase 1 installs **no external packages** (no npm/PyPI/crates, no Godot addons). The only third-party inputs are CC0 asset files already tracked in `KayKit/`.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
 Keyboard/Mouse
      |
      v
 Input Map actions (project.godot [input])  --- gamepad: reserved, unbound
      |
      v
 Player (CharacterBody3D, layer Player, mask World)
  |-- StateMachine  (Idle | Run | Jump | Fall | Dash)  -- single move_and_slide() in Player
  |       |  \__ state_changed(from,to)  (LOCAL signal)
  |       |                  |
  |       |                  v
  |       |           MannequinAnimator --travel()--> AnimationTree (in mannequin.tscn)
  |       |                                              |-- AnimationPlayer <- rig_medium_library.res
  |       |                                              \-- Skeleton3D (Mannequin_Medium.glb)
  |       |
  |       \__ emits FACTS only: jumped / landed / dash_started / movement_state_changed
  |                         |
  v                         v
 VisualRoot (pivot=feet)   EventBus (autoload, signals only)
  \-- Mannequin                |                       |
                               v                       v
                       DebugEventLog (F3)     [Phases 11-12 juice, 14 audio connect here later]

 Test scene = StaticBody3D wrappers (World layer) around Prototype Bits glTFs + Player + DirectionalLight + Camera3D (static)
```

### Recommended Project Structure
D-05 mandates the four top-level folders. `tests/` and `tools/` are small additions (flag for user acceptance, see Open Questions); both are excluded from export later (Phase 15).

```
Attimo/                          (repo root)
├── KayKit/                      # raw packs, tracked, never imported (outside attimo/)
├── docs/CONVENTIONS.md          # D-13
├── .planning/
└── attimo/                      # Godot project root (D-01)
    ├── project.godot
    ├── autoload/
    │   └── event_bus.gd
    ├── scenes/
    │   ├── player/              # player.tscn, mannequin.tscn, mannequin_state_machine.tres
    │   ├── proto/               # one StaticBody3D wrapper scene per Prototype Bits piece
    │   ├── test/                # test_scene.tscn (main scene)
    │   └── debug/               # event_log.tscn
    ├── scripts/
    │   ├── core/                # state.gd, state_machine.gd, physics_layers.gd (game-agnostic)
    │   ├── player/              # player_controller.gd, mannequin_animator.gd, states/*.gd
    │   └── debug/               # event_log.gd
    ├── assets/
    │   ├── characters/mannequin/        # Mannequin_Medium.glb (+ .import)
    │   ├── animations/rig_medium/       # 3 source GLBs + rig_medium_library.res
    │   └── prototype_bits/              # *.gltf, *.bin, prototypebits_texture.png
    ├── tools/build_animation_library.gd # editor-time, run headless
    └── tests/run_smoke.gd, tests/run.sh # headless smoke suite
```

`*.import` files and `*.gd.uid` files MUST be committed (Godot 4.4+ writes a `.uid` per script) [VERIFIED: spike produced `scripts/player.gd.uid`, `*.glb.import`]. `.godot/` stays ignored (`attimo/.gitignore` line `.godot/` [VERIFIED: file read]).

### Pattern 1: `project.godot` target state
**What:** The exact text Godot itself serialises. Generated by a throw-away script using `ProjectSettings.set_setting` + `ProjectSettings.save()`, then diffed. Hand-editing is also fine if you copy this format exactly.
**Verified output (excerpt, Godot 4.7.2):**
```ini
[application]

config/name="Attimo"
run/main_scene="res://scenes/test/test_scene.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

EventBus="*res://autoload/event_bus.gd"

[debug]

gdscript/warnings/untyped_declaration=2

[input]

jump={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
aim={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
look_left={
"deadzone": 0.2,
"events": []
}

[layer_names]

3d_physics/layer_1="World"
3d_physics/layer_2="Player"
3d_physics/layer_3="Interactable"
3d_physics/layer_4="Enemy"
3d_physics/layer_5="Projectile"
3d_physics/layer_6="Hazard"

[physics]

3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
```
[VERIFIED: spike - produced by `ProjectSettings.save()` on 4.7.2; the existing `[physics] 3d/physics_engine` and `[rendering] rendering_device/driver.windows="d3d12"` survive untouched. Existing values verified in attimo/project.godot:14,19,23]

Notes the planner must carry into tasks:
- Set `event.device = -1` on every script-created `InputEvent`, otherwise the script writes `"device":16` (observed). Editor-created events use `-1`.
- Keys are stored by `physical_keycode` (layout-independent), `keycode:0`. Good for WASD on non-QWERTY layouts.
- `look_left/right/up/down` are defined **with empty events** (mouse motion cannot be bound to an action; Phase 2 reads `InputEventMouseMotion` directly, Phase 13 binds the right stick). Defining them now fixes the names (D-15) [VERIFIED: spike - `"events": []` round-trips].
- "Gamepad slots reserved but not bound" has no engine representation: it is a documentation row per action in CONVENTIONS.md plus a smoke assert that no action contains an `InputEventJoypadButton`/`InputEventJoypadMotion`.
- `debug/gdscript/warnings/untyped_declaration=2` applies to **every** script the engine parses, including `tools/` and `tests/` scripts (declare loop vars as `for i: int in 30`, locals typed or `:=`) [VERIFIED: spike].
- Do not run the Godot editor from an older binary on this project: it rewrites `project.godot` / `.import` files. `~/Downloads/Godot.app` is 4.6.3.

### Pattern 2: Input Map actions to bind (KB+M)
| Action | Binding now | Gamepad (reserved, NOT bound) |
|--------|-------------|--------------------------------|
| `move_forward/back/left/right` | W / S / A / D (physical keys) | Left stick |
| `look_left/right/up/down` | none (empty events; mouse motion read directly in Phase 2) | Right stick |
| `jump` | Space | A/Cross |
| `sprint` | Left Shift | L3 or trigger |
| `dash` | Q and Left Ctrl (both; CLAUDE.md says "decide in tuning") | B/Circle |
| `aim` | Mouse Right | L2/LT |
| `use_hand` | Mouse Left | R2/RT |
| `interact` | E | X/Square |
| `module_next` / `module_prev` | Mouse wheel down / up (number keys 1-2-3 would be direct slot selects, new actions in Phase 5) | Bumpers |
| `pause` | Escape | Start |
| `debug_event_log` (debug-only, extra) | F3 and QuoteLeft (F3 may need Fn on macOS) | none |
Action-name source: CLAUDE.md stack table [CITED: .claude/CLAUDE.md "Input" table]. `debug_*` prefix = debug-only convention (not part of D-15's player-facing list; flag in CONVENTIONS.md).

### Pattern 3: Collision layers (D-14) with correct bitmask values
`.tscn` `collision_layer`/`collision_mask` store the **bitmask** (layer N = `1 << (N-1)`), not the layer index.
| Layer # | Name | Bitmask | Who sits on it | Who masks it |
|--------:|------|--------:|----------------|--------------|
| 1 | World | 1 | static geometry, moving platforms (AnimatableBody3D) | Player body, camera SpringArm (Phase 2), beam/aim rays |
| 2 | Player | 2 | Player CharacterBody3D | enemy/hazard Areas that detect the player |
| 3 | Interactable | 4 | mechanism/interactable bodies and Areas | targeting queries (Phase 4) |
| 4 | Enemy | 8 | enemy bodies | beam/rays, player hurt checks |
| 5 | Projectile | 16 | beam/projectile hit shapes (D-14 text says "Projectile/Beam"; keep the layer *name* `Projectile` in `project.godot` for brevity or use the full text, but pick one and mirror it in the constants file) | enemies/interactables/world |
| 6 | Hazard | 32 | kill zones, damage volumes | player-detecting Areas |
| 7-32 | reserved | — | do not use; add rows to CONVENTIONS.md when a phase claims one | — |
Rule to document: the thing being detected sits on its own layer; an `Area3D`/query detects it by setting its **mask**. Checkpoint triggers and moving-platform body placement are not decided by D-14: recommend platforms on World (1) and checkpoints on a new reserved layer 7 "Trigger" claimed in Phase 6 (see Open Questions). Provide a tiny constants class so code never uses magic numbers:
```gdscript
class_name PhysicsLayers
extends RefCounted
const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const INTERACTABLE: int = 1 << 2
const ENEMY: int = 1 << 3
const PROJECTILE: int = 1 << 4
const HAZARD: int = 1 << 5
```
(`.planning/research/ARCHITECTURE.md` proposes a different 6-layer list; **D-14 supersedes it**.)

### Pattern 4: EventBus autoload (verified)
```gdscript
# autoload/event_bus.gd   (registered as EventBus="*res://autoload/event_bus.gd")
extends Node
## Gameplay FACTS only. No state, no logic. Gameplay code emits; juice/audio/debug connect.

signal jumped(position: Vector3)
signal landed(position: Vector3, impact_speed: float)
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
signal movement_state_changed(from_state: StringName, to_state: StringName)
```
[VERIFIED: spike - typed signal parameters compile under `untyped_declaration=2`; `EventBus.jumped.emit(...)` from state scripts resolves the autoload global; payload shape is Claude's discretion (D-12), `GAME-FEEL.md` suggests the same fields]
`movement_state_changed` is emitted by the `StateMachine` on every transition (see below), the other three by the state that owns the fact (`Jump.enter`, `Fall` on floor contact, `Dash.enter`).

### Pattern 5: Generic debug event log (verified auto-connect)
Connect to **every** signal declared on `EventBus` so future facts show up in the log with zero edits:
```gdscript
# scripts/debug/event_log.gd  (CanvasLayer)
extends CanvasLayer

const MAX_LINES: int = 14
var lines: Array[String] = []   # public so the smoke test can read it
@onready var _label: RichTextLabel = %Lines

func _ready() -> void:
	for sig: Dictionary in EventBus.get_script().get_script_signal_list():
		EventBus.connect(sig.name, _on_fact.bind(sig.name))
	visible = false

func _on_fact(...args: Array) -> void:          # variadic: GDScript 4.5+
	var fact: StringName = args.pop_back()      # bind() appends the signal name LAST
	lines.append("[%7.2f] %s %s" % [Time.get_ticks_msec() / 1000.0, fact, args])
	if lines.size() > MAX_LINES:
		lines.pop_front()
	_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_event_log"):
		visible = not visible
```
[VERIFIED: spike - `get_script().get_script_signal_list()` returns exactly the 4 user signals; `_on_fact.bind(name)` with `(...args: Array)` receives emitted args followed by the bound name; signal arg metadata (`name`, `type`) is also available for prettier formatting]
Keep the log in `scenes/debug/event_log.tscn` instanced in the test scene (not an autoload: ARCHITECTURE.md's "everything in autoloads" anti-pattern, and trivially absent in release). Overlay look is Claude's discretion; no particles, no tweens.

### Pattern 6: Node-based state machine + player scaffold (verified end to end)
`State` / `StateMachine` / `PlayerController` / 5 states compiled under `untyped_declaration=2` and, driven by simulated `Input.action_press`, produced: idle -> run (yaw turned to face -Z) -> jump (`Jump` anim, `jumped` fact) -> land (`landed` fact) -> dash (`Dash` anim, `dash_started` fact). See Code Examples for the reusable source. Key design rules that came out of the spike:
- `PlayerController._physics_process` calls `state_machine.physics_update(delta)` then `move_and_slide()` **once**; states only mutate `velocity`.
- Constants in `PlayerController` are explicit PLACEHOLDERS (D-09); Phase 2 replaces them with a `MovementParams` resource.
- `StateMachine.state_changed(from, to)` is a **local** signal consumed by `MannequinAnimator`; the same transition also emits `EventBus.movement_state_changed` (the global fact). Animation is presentation of state, not "feedback" in the D-10 sense.
- Spawn the Player exactly on the floor. Even so, `is_on_floor()` is false on the first physics frame (it is only updated by `move_and_slide()`), so Idle briefly enters Fall and would emit a bogus `landed`. Guard with a minimum air time (`MIN_AIR_TIME = 0.08 s`) before emitting `landed` [VERIFIED: spike reproduced bogus `landed` at startup, guard removed it].
- The Mannequin faces **+Z** (glTF forward; verified because `Dodge_Forward` moves the `root` bone +0.25 m on Z). Convert a movement direction to yaw with `atan2(dir.x, dir.z)` and rotate `VisualRoot`, never the body.

### Pattern 7: Mannequin wrapper scene + AnimationPlayer/AnimationTree
```
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://assets/characters/mannequin/Mannequin_Medium.glb" id="1_glb"]
[ext_resource type="AnimationLibrary" path="res://assets/animations/rig_medium/rig_medium_library.res" id="2_lib"]
[ext_resource type="AnimationNodeStateMachine" path="res://scenes/player/mannequin_state_machine.tres" id="3_sm"]

[node name="Mannequin" instance=ExtResource("1_glb")]

[node name="AnimationPlayer" type="AnimationPlayer" parent="." index="1"]
libraries = {
&"": ExtResource("2_lib")
}

[node name="AnimationTree" type="AnimationTree" parent="." index="2"]
tree_root = ExtResource("3_sm")
anim_player = NodePath("../AnimationPlayer")
active = true
parameters/Locomotion/blend_position = 0.0
```
[VERIFIED: spike - this text loads, animations play, bone poses change. `root_node` default `..` resolves `Rig_Medium/Skeleton3D:hips` because the GLB's own root node contains `Rig_Medium`. The wrapper root may be renamed freely (`Mannequin`)]. Mannequin mesh origin sits at the feet: bind-pose AABB y from -0.000027 to 2.2037 (about 2.2 m tall) [VERIFIED: spike] so `VisualRoot` at the body origin (feet) works and the capsule must be offset up.

### Pattern 8: AnimationTree state machine (use hand-authored `.tres` or a one-off builder)
States for the demo: `Locomotion` (BlendSpace1D: `Idle_A` at 0, `Running_A` at 1), `Jump` (`Jump_Start`), `Fall` (`Jump_Idle`, loops), `Land` (`Jump_Land`), `Dash` (`Dodge_Forward`). Verified transition semantics (4.7.2):
- **Auto-advance must be `advance_mode = AUTO` AND `switch_mode = AT_END`.** With `AUTO` + default `IMMEDIATE`, the transition fires on the very first frame (Jump->Fall after 0.1 s instead of 0.6 s) [VERIFIED: spike]. With `AT_END`, Jump->Fall happened at 0.6 s, Dash->Locomotion at 0.4 s [VERIFIED: spike], matching clip lengths Jump_Start 0.6 s, Dodge_Forward 0.4 s, Jump_Idle 1.067 s, Jump_Land 0.667 s, Idle_A 1.067 s, Running_A 0.8 s [VERIFIED: spike + GLB JSON].
- `travel(X)` walks the shortest transition path, **playing intermediates** (`travel(&"Fall")` from Locomotion played `Jump_Start` first because only Locomotion->Jump existed; `travel(&"Land")` from Jump waited for Jump's AT_END). Add an explicit edge for every pair you will `travel()` between (Locomotion->Fall for walking off ledges, Jump->Land/Fall->Land for short hops, Fall->Locomotion, Dash->Fall, Fall->Dash) or call `playback.start(state)` for hard cuts. If no path exists at all the graph jumps straight to the destination [CITED: docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html].
- `BlendSpace1D.add_blend_point(node, pos, -1, &"name")` - pass a name; omitting it logs a deprecation warning in 4.7.2 [VERIFIED: spike].
- Parameters are addressed as `parameters/<StateName>/blend_position` and `parameters/playback` (the `AnimationNodeStateMachinePlayback`) [VERIFIED: spike property list].
- Build the `.tres` once with a throw-away GDScript (`ResourceSaver.save(sm, path)`) and commit it, or hand-write it from the saved format (ids are arbitrary strings). The saved format uses `states/<Name>/node`, `states/<Name>/position`, and a flat `transitions = ["From","To",SubResource(...), ...]` array.
- `AnimationTree` must be added to a **running** tree before it evaluates; in headless `-s` scripts use `_initialize()` + `await process_frame`, not `_init()` (in `_init()` clip lengths stayed `0.0`) [VERIFIED: spike].

### Pattern 9: Animation library build script (verified, strict-typed)
Imported animation GLBs hold clips inside an `AnimationPlayer` as **non-looping** animations. Merge the wanted clips into one library and set loop modes. See Code Examples for the exact script (6 clips -> 81 KB `.res`) [VERIFIED: spike]. Clips needed now: `Idle_A` (General), `Running_A`, `Jump_Start`, `Jump_Idle`, `Jump_Land` (MovementBasic), `Dodge_Forward` (MovementAdvanced). Loop: `Idle_A`, `Running_A`, `Jump_Idle`. The clip `T-Pose` exists in every file and is excluded by the WANTED list.

### Pattern 10: Prototype Bits wrapper scenes (collision)
KayKit glTFs carry no collision. For each piece used, create `scenes/proto/<piece>.tscn`: `StaticBody3D` (layer `World`=1, mask 0) > `CollisionShape3D` (`BoxShape3D`, centred at half height) + instance of the `.gltf`. Piece origins are at the **bottom centre** (min Y = 0), so the box centre is `(0, h/2, 0)`. Verified extents (X,Y,Z metres) [VERIFIED: spike - read from glTF accessor min/max]:
| Piece | Size | Box centre y |
|-------|------|-------------:|
| `Primitive_Floor` | 4 x 1 x 4 | 0.5 |
| `Primitive_Cube_Small` | 2 x 2 x 2 | 1.0 |
| `Primitive_Cube` | 4 x 4 x 4 | 2.0 |
| `Primitive_Wall` | 4 x 4 x 1 | 2.0 |
| `Primitive_Pillar` | 1 x 4 x 1 | 2.0 |
Place floor tiles at y = **-1** so the walkable top is y = 0. All pieces are multiples of 1 m, so the 1 m grid requirement holds; snap placement to 2 m. Heights 1 / 2 / 4 m double as jump-height reference blocks. Defer `Primitive_Stairs`/`Primitive_Slope` collision to Phase 2 (MOVE-08 owns slopes/steps; stairs need per-step boxes, slopes a convex shape - do not use trimesh). The `.gltf` references `prototypebits_texture.png` by relative URI, so the PNG must sit next to the `.gltf`/`.bin` [VERIFIED: spike import succeeded with all three together]. Test scene extras: one `DirectionalLight3D`, a `WorldEnvironment` with a plain `ProceduralSkyMaterial`, a static `Camera3D` placed behind the start looking along -Z (no follow camera: that is Phase 2). No glow, fog, particles.

### Anti-Patterns to Avoid
- **Editing the imported GLB / adding nodes to it in the import dock:** D-07; always wrap.
- **Importing from `KayKit/`:** it is outside `attimo/`; copy files in (D-04).
- **Trimesh collision from visual meshes** for greybox (CLAUDE.md, Jolt ghost edges).
- **Gameplay scripts calling `AudioStreamPlayer`, `GPUParticles3D`, `Tween`, `Engine.time_scale`, camera shake:** violates D-10/FEEL-01; guarded by a grep test.
- **Raw key polling in gameplay:** `Input.is_key_pressed`, `is_physical_key_pressed`, `is_mouse_button_pressed` bypass the Input Map (FOUND-02); guarded by a grep test.
- **Everything-in-autoloads:** only `EventBus` is an autoload in Phase 1.
- **Putting the `AnimationTree` driver in the global bus path:** the animator listens to the local `StateMachine.state_changed`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Clip playback/blending/crossfade | A custom animation sequencer | `AnimationTree` + `AnimationNodeStateMachine` (+ `BlendSpace1D`) | Already in engine; D-08 |
| Retargeting KayKit clips to the Mannequin | BoneMap/retarget pipeline | Nothing: identical skeleton + node paths (`Rig_Medium/Skeleton3D:<bone>`) | Verified clips play directly |
| Typed-code enforcement | A linter script | `debug/gdscript/warnings/untyped_declaration=2` | Engine parse error; also catches tools/tests |
| Layer name registry | A name->int map in code | `layer_names/3d_physics/layer_N` in `project.godot` + small `PhysicsLayers` const class | Editor shows names; consts avoid magic numbers |
| Fact fan-out | Custom pub/sub, string-keyed event dictionaries | Typed signals on one autoload | Compile-time checked, debuggable, matches D-10 |
| Debug log listener per signal | Hand-connecting each new fact | `get_script().get_script_signal_list()` + variadic handler | New facts auto-appear (verified) |
| Collision for greybox | Auto-generated trimesh | Box/convex primitive per piece | CLAUDE.md |
| Test runner | Home-grown framework | One `SceneTree` script that asserts and `quit(failures)` | Exit code verified to propagate |

**Key insight:** every "hard" piece of this phase is an existing engine feature configured correctly; the only code worth writing is the ~150-line player scaffold, the EventBus, the log overlay and the build/test scripts.

## Common Pitfalls

### Pitfall 1: Hand-written `.tscn` loses Node-typed `@export` values
**What goes wrong:** `@export var state_machine: StateMachine` is `null` at `_ready()`; error `Invalid access to property or key 'state_changed' on a base object of type 'Nil'`.
**Why it happens:** Godot's text format needs `node_paths=PackedStringArray("state_machine", "animation_tree")` in the `[node ...]` header to resolve NodePath values into Node references after instancing.
**How to avoid:** add the `node_paths=` attribute for every node whose script has Node-typed exports, or let the editor save the scene. **Warning signs:** nil errors only in scenes written by script/hand. [VERIFIED: spike, reproduced and fixed]

### Pitfall 2: Clips arrive non-looping
**What goes wrong:** `Idle_A`/`Running_A` freeze on the last frame. **Why:** KayKit names carry no `-loop` suffix; imported `loop_mode` was `0` (`LOOP_NONE`) [VERIFIED: spike, `Idle_A loop_mode=0`]. **How to avoid:** the build script sets `LOOP_LINEAR` for the looping set. **Warning signs:** pose stops after ~1 s.

### Pitfall 3: `AnimationTree` auto-advance fires immediately
**What goes wrong:** Jump->Fall after one frame; Dash->Locomotion after 0.1 s. **Why:** `advance_mode = AUTO` with the default `switch_mode = IMMEDIATE`. **How to avoid:** `AUTO` + `AT_END` on every "finishes by itself" edge. [VERIFIED: spike]

### Pitfall 4: `travel()` plays intermediate states
**What goes wrong:** walking off a ledge plays the full 0.6 s `Jump_Start` before `Fall`; a landing during `Jump` waits for the jump clip to end. **Why:** A* over the declared transitions. **How to avoid:** add direct edges (see Pattern 8) or `start()` for hard cuts. [VERIFIED: spike]

### Pitfall 5: Bogus `landed` at spawn
See Pattern 6. Also never spawn the player in the air in the smoke test unless you want a `landed`.

### Pitfall 6: `-s` scripts and the AnimationTree/autoloads
In a `SceneTree` script use `_initialize()` and `await process_frame` before reading animation state; reach autoloads in the script itself via `root.get_node("EventBus")` (the global identifier is fine inside scripts that live in scenes). [VERIFIED: spike]

### Pitfall 7: Fresh clone has no import cache
`.godot/` is gitignored, so a fresh checkout has no imported resources or global class cache; running a scene/test first yields missing-resource and `class_name` errors. **How to avoid:** always `godot --headless --path attimo --import` before tests. [VERIFIED: spike - deleting `.godot` then `--editor --quit` rebuilds it]

### Pitfall 8: Godot exit codes do not reflect script errors
`--check-only --script` returned exit 0 even for a script with parse errors; scene-script runtime errors (e.g. a missing node) also leave exit code 0. **How to avoid:** the smoke runner must (a) `load()` every `.gd` and assert `can_instantiate()` (this returned exit 1 for an untyped script), (b) `quit(failures)`, and (c) the shell wrapper greps the captured output for `SCRIPT ERROR|Parse Error|Failed to load`. [VERIFIED: spike]

### Pitfall 9: Script-created InputEvents get `device = 16`
Set `device = -1` (see Pattern 1). [VERIFIED: spike]

### Pitfall 10: Animation GLBs reference `handslot.l/r`, Mannequin skeleton lacks them
Tracks for `handslot.r/l` exist in the clips; the Mannequin skeleton has 21 bones and no handslots [VERIFIED: spike - bone list printed]. Missing-bone tracks produce **no warnings** in 4.7.2 [VERIFIED: spike, grepped output]. Consequence for later phases: attach to `hand.r`/`hand.l` via `BoneAttachment3D`, not `handslot.*`. (GAME-FEEL.md says Rig_Medium has `handslot` - true only for the animation GLB skeleton.)

### Pitfall 11: Character scale vs KayKit grid
Mannequin_Medium is about 2.2 m tall; Prototype Bits blocks are 1/2/4 m. CLAUDE.md's Meshy note (`height_meters` 1.4-1.7, "match your capsule") predates this. Capsule for Phase 1 = placeholder radius 0.5, height 2.0, offset y = +1.0 `[ASSUMED]`; Phase 2 retunes against the pieces. Record the real height in CONVENTIONS.md so Phase 9 (hero) scales to the kit, not the other way round.

### Pitfall 12: `Dodge_Forward` shifts the root bone
The clip translates the `root` bone +0.25 m along Z (hips also +0.1) [VERIFIED: spike]. With no root-motion setup the mesh slides forward and snaps back when the clip restarts. Harmless for the demo; Phase 3 decides whether to pin the root track.

### Pitfall 13: Physics interpolation rules
Everything that moves interpolated nodes must happen in `_physics_process`; after teleports call `reset_physics_interpolation()`; use custom interpolation for cameras [CITED: docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html]. Phase 1 has no moving camera, and `VisualRoot` (child of the CharacterBody3D) rotates only inside `_physics_process` (states), so the pattern holds. `AnimationTree` is left on its default idle callback mode (skeleton bone poses are not part of node interpolation).

### Pitfall 14: Wrong Godot binary
`~/Downloads/Godot.app` is 4.6.3; `/Applications` has only "Godot 3.app"; the editor's stored `executable_path` in `.godot/editor/project_metadata.cfg` points at Godot 3. Anything run with those binaries can rewrite project files. Pin the path (env var `GODOT`) in the test wrapper and in the README.

## Code Examples

All blocks below compiled and ran in the spike under `untyped_declaration=2` on 4.7.2.

### State / StateMachine
```gdscript
# scripts/core/state.gd
class_name State
extends Node
## Base class for node-based states. Return a state name from physics_update() to request a transition.

var actor: PlayerController

func enter(_previous: StringName) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> StringName:
	return &""
```
```gdscript
# scripts/core/state_machine.gd
class_name StateMachine
extends Node

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: StringName = &"Idle"

var current: State
var _states: Dictionary[StringName, State] = {}

func setup(actor: PlayerController) -> void:
	for child: Node in get_children():
		var state := child as State
		if state == null:
			continue
		state.actor = actor
		_states[state.name] = state
	assert(_states.has(initial_state), "initial_state missing: %s" % initial_state)
	current = _states[initial_state]
	current.enter(&"")
	state_changed.emit(&"", current.name)
	EventBus.movement_state_changed.emit(&"", current.name)

func physics_update(delta: float) -> void:
	var next: StringName = current.physics_update(delta)
	if next != &"" and next != current.name:
		transition_to(next)

func transition_to(next: StringName) -> void:
	assert(_states.has(next), "unknown state: %s" % next)
	var previous: StringName = current.name
	current.exit()
	current = _states[next]
	current.enter(previous)
	state_changed.emit(previous, next)
	EventBus.movement_state_changed.emit(previous, next)
```
(The spike's machine emitted only the local signal; the two `EventBus.movement_state_changed.emit(...)` lines are the one-line addition for D-11. `class_name State` extending `Node` with a typed `actor: PlayerController` couples the base class to the player; acceptable for Phase 1, generalise in Phase 8 when the boss reuses it.)

### PlayerController and a state
```gdscript
# scripts/player/player_controller.gd
class_name PlayerController
extends CharacterBody3D
## Phase 1 scaffold. Values are PLACEHOLDERS; Phase 2 replaces them with a MovementParams resource.

const RUN_SPEED: float = 6.0
const GRAVITY: float = 25.0
const JUMP_VELOCITY: float = 9.0
const TURN_SPEED: float = 14.0

@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	state_machine.setup(self)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)
	move_and_slide()   # the single move_and_slide() call site

func input_direction() -> Vector3:
	var v: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return Vector3(v.x, 0.0, v.y)

func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	# Mannequin_Medium faces +Z (glTF forward), so yaw = atan2(x, z)
	var target: float = atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target, clampf(TURN_SPEED * delta, 0.0, 1.0))
```
```gdscript
# scripts/player/states/fall.gd   (emits the 'landed' fact; guards the first-frame bogus landing)
extends State

const MIN_AIR_TIME: float = 0.08
var _impact_speed: float = 0.0
var _air_time: float = 0.0

func enter(_previous: StringName) -> void:
	_air_time = 0.0

func physics_update(delta: float) -> StringName:
	actor.velocity.y -= PlayerController.GRAVITY * delta
	_air_time += delta
	_impact_speed = -actor.velocity.y
	var dir: Vector3 = actor.input_direction()
	actor.velocity.x = dir.x * PlayerController.RUN_SPEED
	actor.velocity.z = dir.z * PlayerController.RUN_SPEED
	actor.face(dir, delta)
	if actor.is_on_floor():
		if _air_time >= MIN_AIR_TIME:
			EventBus.landed.emit(actor.global_position, _impact_speed)
		return &"Run" if dir != Vector3.ZERO else &"Idle"
	return &""
```
`Jump.enter` sets `velocity.y = JUMP_VELOCITY` and emits `EventBus.jumped.emit(actor.global_position)`, then returns `&"Fall"` once `velocity.y <= 0`; `Dash.enter` computes the direction (input or current facing), sets yaw, emits `EventBus.dash_started.emit(pos, dir, not actor.is_on_floor())`, holds a fixed velocity for 0.4 s (matches `Dodge_Forward`), then returns `Idle`/`Fall`; `Idle` and `Run` transition on `jump`/`dash`/input/floor loss. All use `Input.is_action_just_pressed(&"jump")` etc.

### MannequinAnimator
```gdscript
# scripts/player/mannequin_animator.gd   (node in player.tscn; needs node_paths= in the .tscn header)
class_name MannequinAnimator
extends Node

@export var state_machine: StateMachine
@export var animation_tree: AnimationTree

const STATE_TO_ANIM: Dictionary[StringName, StringName] = {
	&"Idle": &"Locomotion", &"Run": &"Locomotion",
	&"Jump": &"Jump", &"Fall": &"Fall", &"Dash": &"Dash",
}

func _ready() -> void:
	state_machine.state_changed.connect(_on_state_changed)

func _on_state_changed(_from_state: StringName, to_state: StringName) -> void:
	var playback := animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	animation_tree.set(&"parameters/Locomotion/blend_position", 1.0 if to_state == &"Run" else 0.0)
	playback.travel(STATE_TO_ANIM[to_state])
```
Header line required in `player.tscn`:
`[node name="MannequinAnimator" type="Node" parent="." node_paths=PackedStringArray("state_machine", "animation_tree")]`

### Animation library builder (`tools/build_animation_library.gd`)
```gdscript
extends SceneTree
## Run after import:  godot --headless --path attimo --import
##                    godot --headless --path attimo -s res://tools/build_animation_library.gd

const SOURCES: Array[String] = [
	"res://assets/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
]
const OUTPUT: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const WANTED: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward"]
const LOOPING: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Idle"]

func _initialize() -> void:
	var library := AnimationLibrary.new()
	for path: String in SOURCES:
		var instance: Node = (load(path) as PackedScene).instantiate()
		var player := instance.get_node("AnimationPlayer") as AnimationPlayer
		for clip: StringName in player.get_animation_list():
			if clip in WANTED:
				var animation := player.get_animation(clip).duplicate() as Animation
				animation.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
				library.add_animation(clip, animation)
		instance.free()
	var missing: Array[StringName] = []
	for clip: StringName in WANTED:
		if not library.has_animation(clip):
			missing.append(clip)
	if not missing.is_empty():
		push_error("Missing clips: %s" % [missing])
		quit(1)
		return
	var err: Error = ResourceSaver.save(library, OUTPUT)
	print("saved %s (%d clips) err=%d" % [OUTPUT, library.get_animation_list().size(), err])
	quit(0 if err == OK else 1)
```
[VERIFIED: spike - "saved ... (6 clips) err=0", 81,563 bytes]. Later phases extend `WANTED`/`SOURCES` (CombatRanged etc.) and re-run; the `.res` is regenerated deterministically.

### Smoke-test skeleton (`tests/run_smoke.gd`)
```gdscript
extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
	else:
		print("ok:   ", message)

func _initialize() -> void:
	await _run()
	quit(_failures)

func _run() -> void:
	var v: Dictionary = Engine.get_version_info()
	_check(v.major == 4 and v.minor == 7 and v.status == "stable", "Godot is 4.7.x stable (got %s)" % v.string)
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation") == true, "physics interpolation on")
	_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Jolt")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "Forward+")
	_check(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration") == 2, "untyped declarations are errors")
	# ... InputMap, layer names, script load sweep, asset whitelist, scene run with simulated input ...
```
`Engine.get_version_info()` returned `{major:4, minor:7, patch:2, status:"stable", build:"official", string:"4.7.2-stable (official)"}` [VERIFIED: spike]. Simulated input: `Input.action_press(&"jump")`, `await physics_frame`, `Input.action_release(&"jump")` works headless [VERIFIED: spike]. Wrapper `tests/run.sh`: import first, run, grep log for `SCRIPT ERROR|Parse Error|Failed to load`, propagate non-zero.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-signal hand-wired debug listeners | Variadic GDScript handlers (`func f(...args: Array)`) | GDScript 4.5 | One generic listener for all bus signals |
| Untyped dictionaries | Typed `Dictionary[StringName, State]` | 4.4 | Used in the verified FSM |
| Manual physics-jitter workarounds | Built-in 3D physics interpolation | 4.4 | Project setting only; rules in Pitfall 13 [CITED: Godot docs, CLAUDE.md] |
| Jolt as add-on/optional | Jolt default for new 3D projects | 4.6 | Already set in this project |
| Script `.import` hints for loops | Loop mode set on the `Animation` resource | — | Build script path chosen because KayKit names have no `-loop` suffix |

**Deprecated/outdated:**
- `.planning/research/ARCHITECTURE.md` layer table (6 layers incl. Platforms/Triggers) and feature-folder layout: superseded by D-14 and D-05.
- `.planning/research/GAME-FEEL.md` `FeelService`/`FeelSettings` preset switch: superseded by the roadmap decision "no juice presets or toggles"; Phase 1 builds only the fact bus.
- `.planning/research/KAYKIT.md` section 6 plan to gitignore raw packs / `assets/third_party/kaykit/...`: superseded by D-02/D-04.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Placeholder capsule radius 0.5 / height 2.0 (offset +1.0) suits the 2.2 m Mannequin | Pitfall 11 | Demo looks off or catches on pieces; trivial to change, Phase 2 re-tunes |
| A2 | Projectile layer name: `Projectile` vs `Projectile/Beam` (D-14 wording) | Pattern 3 | Cosmetic only if constants file mirrors the chosen name |
| A3 | Platforms on World layer; checkpoints on reserved layer 7 "Trigger" in Phase 6 | Pattern 3 | If user wants different homes, only CONVENTIONS.md text changes now; costly later |
| A4 | Keep `dash` bound to both Q and Left Ctrl for now | Pattern 2 | Cosmetic; CLAUDE.md says decide in tuning |
| A5 | `debug_event_log` extra action (F3 + QuoteLeft) acceptable as a non-D-15 action | Pattern 2 | Minor naming-convention question |
| A6 | `tests/` and `tools/` top-level folders inside `attimo/` are acceptable additions to D-05 | Structure | If rejected, move under `scripts/` subfolders |
| A7 | The `~/Downloads` 4.7.2 zip is the genuine official build (checksum recorded, not compared to godotengine.org) | Standard Stack | Supply-chain risk; verify SHA-512 against the official release page before relying on it for CI |
| A8 | A fresh-checkout import + smoke run completes in well under a minute | Validation | Slower feedback loop; not a correctness risk |
| A9 | Committing the generated `rig_medium_library.res` (binary, 81 KB) is preferable to a 364 KB text `.tres` | Pattern 9 | Both work (verified); binary churn on regeneration vs. greppable text. User's text-first preference could flip this |

## Open Questions

1. **Where do checkpoint triggers and moving platforms live in the layer scheme?**
   - What we know: D-14 lists six layers; ARCHITECTURE.md had Platforms and Triggers rows that D-14 dropped.
   - What's unclear: whether the user wants a seventh "Trigger" layer claimed later.
   - Recommendation: platforms = World (1), kill zones = Hazard (6), checkpoints = layer 7 "Trigger", added in Phase 6; list layers 7-32 as reserved now.

2. **Which Rig_Medium GLBs go into `assets/`?**
   - What we know: Phase 1 only needs 3 of 8 (General, MovementBasic, MovementAdvanced); the library `.res` is self-contained.
   - Recommendation: copy those 3 now (2.2 MB); Phase 3/5 copy CombatRanged/Tools etc. when they extend `WANTED`.

3. **Are `tests/` and `tools/` under `attimo/` acceptable given D-05's four folders?** Recommend yes (A6).

4. **Should Phase 1 add a `README.md` pin note and `CREDITS.md` (CC0 assets, optional attribution)?** CLAUDE.md asks to pin the version in README; no README exists in the repo root yet. Recommend a short root `README.md` (engine pin, how to run tests) as part of plan A.

5. **Static camera vs. tiny follow camera for the demo.** Camera is Phase 2; recommend a fixed `Camera3D` and world-axis input (W = -Z). If the user wants to see the character run far, size the floor accordingly (e.g. 5 x 5 tiles = 20 m) so the Player cannot walk off the edge (the spike's single 4 m tile made the player fall off in seconds).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.7.2 standard | everything | Partially: only as `~/Downloads/Godot_v4.7.2-stable_macos.universal.zip` (not installed; not on PATH); extracted copy ran fine | 4.7.2.stable.official.ed1daf0bf | Unzip the archive to an install location and point `GODOT` at it |
| Wrong Godot binaries present | risk | `~/Downloads/Godot.app` = 4.6.3; `/Applications/Godot 3.app` = 3.x | — | Do not use for this project |
| git | commits | yes | repo clean on `dev` | — |
| python3 | optional glTF inspection (not required by plan) | yes | system | skip |
| Windows machine with D3D12 | FOUND-01 on Windows target | not checkable from this machine | — | Verify once manually; `rendering_device/driver.windows="d3d12"` already set (attimo/project.godot:23) |
| `docs/` folder | CONVENTIONS.md | exists, contains `reference/` only | — | create file |

**Missing dependencies with no fallback:** none (the pinned engine exists as a download, needs unpacking).
**Missing dependencies with fallback:** Godot 4.7.2 install/PATH (unzip + `GODOT` env var).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom headless smoke runner: one `SceneTree` script, asserts counted, `quit(failures)` (no addon) |
| Config file | none; `attimo/tests/run_smoke.gd` + `attimo/tests/run.sh` created in Wave 0 |
| Quick run command | `"$GODOT" --headless --path attimo -s res://tests/run_smoke.gd` |
| Full suite command | `bash attimo/tests/run.sh` (runs `--import`, then the smoke script, greps the output for `SCRIPT ERROR|Parse Error|Failed to load`, returns non-zero on any failure) |

Exit-code behaviour verified: `quit(1)` yields process exit 1; scene runtime errors alone do NOT change the exit code, hence the log grep (Pitfall 8).

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | Engine is 4.7.x stable; Jolt; Forward+; physics interpolation true; `untyped_declaration == 2`; every `.gd` under `autoload/ scenes/ scripts/ tools/ tests/` loads and `can_instantiate()` | smoke | `"$GODOT" --headless --path attimo -s res://tests/run_smoke.gd` | ❌ Wave 0 |
| FOUND-02 | All D-15 actions (plus `debug_event_log`) exist in `InputMap`; movement/jump/dash/aim/use_hand/interact/pause/module_* have KB+M events; **no** action has joypad events; `look_*` exist with zero events; no `Input.is_key_pressed|is_physical_key_pressed|is_mouse_button_pressed|get_joy` in `scripts/` or `autoload/` (grep) | smoke | same | ❌ Wave 0 |
| FOUND-03 | `layer_names/3d_physics/layer_1..6` equal the D-14 names; `PhysicsLayers` constants match; `docs/CONVENTIONS.md` exists and mentions every layer name, every action name and each documented group; folders `scenes scripts assets autoload` exist | smoke (file reads) + manual read of the doc | same | ❌ Wave 0 |
| FOUND-04 | `attimo/` contains no `KayKit` directory; `assets/` file list is a subset of a whitelist (Mannequin GLB, 3 Rig_Medium GLBs, library `.res`, listed Prototype Bits `.gltf/.bin/.png` + their `.import`); repo-root `KayKit/` still tracked (`git ls-files KayKit` non-empty) | smoke + shell | `bash attimo/tests/run.sh` | ❌ Wave 0 |
| FOUND-05 | Test scene loads and runs 2 s headless without script errors; scene's only mesh sources are `scenes/proto/*` wrappers and the Mannequin; library contains `Idle_A, Running_A, Jump_Start, Jump_Idle, Jump_Land, Dodge_Forward` with looping set on Idle_A/Running_A/Jump_Idle; simulated `move_forward` -> AnimationTree current node `Locomotion` with `blend_position` 1.0; `jump` -> `Jump`; `dash` -> `Dash`; no `GPUParticles3D/CPUParticles3D` nodes in any `.tscn` (grep) | smoke | same | ❌ Wave 0 |
| FEEL-01 | Simulated jump/land/dash emit `jumped`, `landed`, `dash_started`, and `movement_state_changed` on `EventBus` (captured via the same variadic connect); event log node's `lines` contains matching entries; gameplay scripts (`scripts/player`, `scripts/core`) contain none of `AudioStreamPlayer GPUParticles CPUParticles create_tween Tween Engine.time_scale shake` (grep) | smoke | same | ❌ Wave 0 |
| (visual) | Mannequin visibly plays Idle/Run/Jump/Dodge, faces move direction, F3 toggles log, nothing glows or emits particles | manual play-through (human_verify_mode `end-of-phase`) | open `attimo/` in Godot 4.7.2, F5 | n/a |

### Sampling Rate
- **Per task commit:** quick run command (< 30 s after the first import).
- **Per wave merge:** `bash attimo/tests/run.sh`.
- **Phase gate:** full suite green + the manual play-through before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `attimo/tests/run_smoke.gd` - covers FOUND-01..05, FEEL-01
- [ ] `attimo/tests/run.sh` - import + run + log grep + exit code
- [ ] `GODOT` binary path documented (README) - 4.7.2 not installed system-wide
- No framework install needed (custom runner); gdUnit4 deliberately not added.

## Security Domain

`security_enforcement` is enabled (ASVS level 1). Phase 1 is an offline, single-player prototype scaffold: no network, accounts, persistence, or user-supplied files.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no accounts) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | minimal | Input arrives only through Input Map actions (engine-validated); no parsing of external text/files at runtime |
| V6 Cryptography | no | — |
| V14 Configuration / supply chain | yes | Pin engine version; verify the Godot download checksum; track licence of third-party assets (all CC0) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered engine binary / wrong version silently rewriting project files | Tampering | Verify SHA-512 of the official release (A7); pin version in README; use `GODOT` env var in scripts |
| Untrusted third-party assets (GLB/PNG) loaded at import time | Tampering | Assets are CC0 packs from a known author already in repo; copy only what is used; no runtime loading from user paths |
| `OS.execute`/`FileAccess` on user paths in debug tooling | Elevation | Phase 1 tools/tests only read `res://`; the one write is `ResourceSaver.save` to a fixed `res://` path |
| Debug overlay shipping in release | Information disclosure | Not an autoload; instanced only by the test scene; REL-03 later strips it |

## Sources

### Primary (HIGH confidence)
- Godot 4.7.2 binary (`4.7.2.stable.official.ed1daf0bf`), run headless in a scratch project: project settings serialisation, import, animation extraction, AnimationTree travel, typed-as-error setting, autoload/EventBus, variadic handlers, FSM scaffold, input simulation, exit codes [VERIFIED: spike]
- Real KayKit files read from `/Users/bistl/GIT/Attimo/KayKit/`: `Mannequin_Medium.glb` (21 joints, 6 meshes, root node `Rig_Medium`), `Rig_Medium_General/MovementBasic/MovementAdvanced.glb` (clip names/lengths, track paths), Prototype Bits `.gltf` accessors (extents) [VERIFIED: GLB/glTF JSON parsed + Godot import]
- `/Users/bistl/GIT/Attimo/attimo/project.godot` (read, lines 9-23), `.planning/phases/01-.../01-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.claude/CLAUDE.md`
- https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html - state machine switch/advance modes, `travel()` path behaviour, playback parameter [CITED]
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html - enabling path, `_physics_process` rule, `reset_physics_interpolation()` [CITED]

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md`, `PITFALLS.md`, `GAME-FEEL.md`, `KAYKIT.md` (project's own earlier research; partly superseded by CONTEXT decisions as noted)

### Tertiary (LOW confidence)
- none relied upon

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - engine version run; no packages
- Architecture: HIGH - FSM/animator/EventBus/test runner executed end to end in the spike; remaining unverified is the final polished test scene layout and overlay look (discretion)
- Pitfalls: HIGH - 10 of 14 reproduced directly; Pitfalls 13-14 are doc/environment facts

**Research date:** 2026-11-04
**Valid until:** 2026-12-04 (stable engine pin; re-verify only if the Godot version changes)
