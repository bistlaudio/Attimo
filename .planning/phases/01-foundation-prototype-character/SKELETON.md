# Walking Skeleton — Attimo

**Phase:** 1
**Generated:** 2026-11-04

## Capability Proven End-to-End

Pressing an Input Map action makes the KayKit Mannequin_Medium play the matching KayKit Rig_Medium clip in place in a Prototype Bits test scene. The gameplay fact (jumped, landed, dash_started, movement_state_changed) is broadcast on the EventBus and shown in the debug event log, and a headless smoke suite on pinned Godot 4.7.2 proves all of it. Per D-09 Option A (user decision 2026-11-04), Phase 1 has no movement physics: the Player never moves, and states are timer-driven.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.7.2-stable, standard build (not .NET), version string `4.7.2.stable.official.ed1daf0bf`. The macOS zip is verified against the official SHA-512 and installed at `$HOME/Applications/Godot_4.7.2/Godot.app`. Scripts find it through the `GODOT` env var. | CLAUDE.md pin. A wrong binary rewrites `project.godot`/`.import` files, so `attimo/tests/run.sh` refuses any other version. |
| Language | Typed GDScript. `debug/gdscript/warnings/untyped_declaration=2` turns untyped declarations into parse errors. | Typing is enforced by the engine, not by convention. This also covers `tools/` and `tests/`. |
| Physics | Jolt. Physics interpolation is on. Phase 1 has NO movement physics (D-09 Option A): no velocity, gravity, floor checks or `move_and_slide()`. From Phase 2 the rule is one `move_and_slide()` per tick, in `PlayerController`, with states only changing `velocity`. | CLAUDE.md plus the user decision. The static Prototype Bits pieces already carry box collision on World, ready for Phase 2. |
| Renderer | Forward+ (D3D12 on Windows). | Already set. Glow, fog and SDFGI stay off in Group A. |
| Project root | `attimo/` holds `project.godot` (D-01). The repo root holds `KayKit/`, `docs/` and `.planning/`. | Godot never imports the raw packs. Moving the project root later would change every `res://` path (costly). |
| Directory layout | Folders by type: `autoload/`, `scenes/`, `scripts/`, `assets/` (D-05), plus `tests/` and `tools/` (flagged assumption A6). Files are `snake_case`, nodes and classes `PascalCase`. | One predictable place per file type. |
| Player architecture | `CharacterBody3D` (Player, layer 2) > `VisualRoot` (feet pivot) > Mannequin. A node-based `StateMachine` with `State` children (Idle, Run, Jump, Fall, Dash) is the source of truth (D-06, D-09). In Phase 1 the states are timer-driven to match clip lengths and only rotate `VisualRoot` toward the input direction. Phase 2 adds velocity to the same states. | Later phases rotate and scale `VisualRoot` only: flip/lean (P3), the hero swap (P9) and squash/stretch (P11). |
| Animation pipeline | `tools/build_animation_library.gd` merges the KayKit clips into `rig_medium_library.res` and sets loop modes. `tools/build_mannequin_state_machine.gd` writes the `AnimationTree` state machine `.tres`. `MannequinAnimator` maps FSM states to tree states through the LOCAL `state_changed` signal (D-07, D-08). | No retargeting is needed, because the Mannequin and Rig_Medium share the `Rig_Medium/Skeleton3D:<bone>` track paths. The build scripts keep the assets reproducible and the editor click-free. |
| Feedback architecture | The `EventBus` autoload declares typed fact signals only. Gameplay emits them and never calls feedback (D-10, D-11). | Juice (P11-12) and audio (P14) connect later without gameplay edits. A smoke guard enforces the rule. |
| Debug tooling | The event log is a `CanvasLayer` scene instanced by the test scene, not an autoload. F3 or the key left of 1 toggles it through the `debug_event_log` action (D-12). | It is easy to strip from release builds (REL-03). |
| Collision layers | 1 World, 2 Player, 3 Interactable, 4 Enemy, 5 Projectile/Beam, 6 Hazard. Layers 7-32 are reserved. The `PhysicsLayers` const class holds the bitmasks (D-14). | Every mask in every later scene uses these numbers (costly to change). |
| Input | Input Map actions only. KB+M is bound and the gamepad is reserved but unbound. The `look_*` actions exist with no events (D-15). | Action names are referenced throughout the code (costly to change). Gamepad support is Phase 13. |
| Asset pipeline | The raw KayKit packs are tracked in repo-root `KayKit/`. Used files are COPIED into `attimo/assets/` (D-02, D-04). Prototype Bits pieces are wrapped in `StaticBody3D` scenes with box collision (no trimesh). | A whitelist smoke test keeps `attimo/assets/` to exactly what is used. |
| Data layer | None in Phase 1. | Persistence arrives with checkpoints (P6) and settings (P7). |
| Test harness | A headless `SceneTree` smoke runner (`tests/run_smoke.gd`) auto-discovers `tests/smoke/test_*.gd`. `tests/run.sh` does the version gate, `--import`, the run, a log grep and the exit code. | Godot exit codes alone hide script errors (Pitfall 8). |
| Run / deployment | Local only: `bash attimo/tests/run.sh`, and F5 in the pinned editor opens `scenes/test/test_scene.tscn`. | The Windows export is Phase 15. |
| Branching | Phase work happens on `dev`. `dev` merges to `main` only after verification. | CLAUDE.md Git workflow. |

## Stack Touched in Phase 1

- [ ] Project scaffold: engine pin, project settings, typed-as-error, test runner (plan 01-01)
- [ ] Input -> gameplay FSM -> fact bus path (plans 01-01, 01-03)
- [ ] Presentation: Mannequin plus AnimationTree driven by kit clips (plan 01-02)
- [ ] Input Map, collision layers and conventions documented (plan 01-04)
- [ ] World: Prototype Bits pieces with collision (plan 01-05) and the test scene as main scene (plan 01-07)
- [ ] Debug view: event log overlay and the feedback guard (plan 01-06)
- [ ] Data layer: not applicable (no persistence in Phase 1)
- [ ] Run: documented local full-stack run (`bash attimo/tests/run.sh`, F5 in the pinned editor) (plans 01-01, 01-07)

## Out of Scope (Deferred to Later Slices)

- ALL movement physics (D-09 Option A): velocity, gravity, real jump arcs, landing by floor contact, dash travel, the kinematic move call (Phase 2)
- Tuned movement values, the MovementParams resource, coyote time, jump buffer, double jump, air-dash limits and cooldowns (Phase 2)
- Follow camera, mouse look, sensitivity and invert-Y (Phase 2). Phase 1 uses one static `Camera3D` and world-axis input.
- Collision for slopes, stairs and moving platforms (Phase 2, MOVE-08)
- Full clip mapping: sprint lean, double-jump flip, held air-dash pose, aim strafe, root-motion handling of `Dodge_Forward` (Phase 3)
- Gamepad bindings (Phase 13)
- Particles, juice, the cue catalogue, camera shake, hit-stop (Phases 11-12)
- Audio (Phase 14), the Meshy hero (Phase 9), Git LFS (deferred, revisit before Phase 9)
- Save data, menus, checkpoints (Phases 6-7)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: run, sprint, variable jump, double jump and ground/air dash with a jitter-free mouse-look camera. The movement physics and the MovementParams resource go into the existing Phase 1 states, replacing their demo timers.
- Phase 3: every movement state animated from kit clips, plus aim mode with crosshair
- Phase 4: Fernauslöser beam, module framework, turquoise interactable highlight, greybox mechanism kit
- Phase 5: Pull/Push module with momentum, module pickups, teaching rooms
- Phase 6: beam shooting, greybox enemies, health, checkpoints, fast respawn
- Phase 7: full Prototype Bits level, title/pause/settings menus
- Phase 8: greybox object-boss and end screen (closes Group A)
