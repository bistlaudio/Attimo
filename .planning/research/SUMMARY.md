# Project Research Summary

**Project:** Attimo (working title)
**Domain:** 3D third-person action-platformer, low-poly steampunk, Godot 4, university vertical slice (one level, one object-boss, ability-gated hand modules)
**Researched:** 2026-11-02
**Confidence:** MEDIUM-HIGH

## Executive Summary

Attimo is a single-level, single-boss third-person platformer whose identity rests on movement that feels fluid and fast, with a prosthetic hand that plugs into that movement. Build a self-owned `CharacterBody3D` controller with tuned numbers (coyote time, jump buffer, variable jump, fall gravity, dash as a timed state), a camera rig separate from the body, then the interaction layer. The hand is a set of abilities behind one shared socket (input binding, effect, VFX). The arm mesh never changes, so there is no module-swap art or rigging. Mechanisms talk through signals and editor-authored connections; modules only see an `Interactable` contract. Adding a module = one folder plus one registry entry.

Stack: Godot 4.7.2-stable (standard, not .NET), typed GDScript, Jolt Physics, Forward+. Phantom Camera v0.11.0.4 is the camera addon to spike first, with a SpringArm3D fallback. Asset pipeline: Meshy (hero; current 3k-triangle model is a placeholder) and Blender MCP (props), converging on a shared palette-atlas material and glTF 2.0 into Godot. Main risks: camera/body jitter from mixing physics and process updates; Meshy deformation/rig failure and style drift; scope creep and soft-locks; turquoise "interactable" hue diluted by decorative turquoise.

Sequence by dependency: prove the asset pipeline early with the placeholder, sign off movement and camera with a metrics table before level work, define the hand framework together with its first module. Modules are chosen per phase. Blockout before art; boss last among content.

## Key Findings

### Stack
- Godot 4.7.2-stable (2026-08-18). 4.8 is beta; do not use. Pin the version everywhere.
- GDScript, fully typed. Jolt Physics (decide once in phase 1). Forward+ renderer.
- CharacterBody3D + own controller + node-based state machine (no addon controller).
- Physics interpolation ON; all interpolated motion in `_physics_process`.
- Phantom Camera v0.11.0.4 (spike max one day; fallback Node3D yaw/pitch + SpringArm3D).
- Debug Draw 3D 1.7.3 (strip from release). gdUnit4 v6.2.3 optional, pure logic only. Built-in Tween only.
- Meshy API: `latest` (7.1) for geometry; test meshy-6 for texture. Use `standard` or `smart-topology`; do NOT use retiring `lowpoly` (retires 2026-10-30).
- glTF 2.0 (.glb), "+Y Up", applied transforms, no Draco, deformation bones only, flat or ~30-degree auto-smooth.
- Git: commit `.import` and `.uid`; ignore `.godot/`; `.gitattributes` / LFS for large binaries.
- Version conflict: ARCHITECTURE guessed 4.6.x (low-medium). This summary uses 4.7.2 (verified by STACK). Re-verify at project creation.

### Expected Features
- Table stakes: acceleration/deceleration, sprint, variable jump, asymmetric gravity, coyote time (~0.10-0.15 s), jump buffer (~0.10-0.15 s), air control, one air dash per airtime, platform velocity inheritance; orbit camera with collision; over-the-shoulder aim (hold key, FOV zoom, crosshair); teal glow on interactables; soft-lock aim assist with small angular radius; hand beam; module framework (Resource definition + behaviour scene, one equipped slot, pickup moment with HUD icon, one input per module, `accepts()` compatibility, state persisted across checkpoints); switches, valves, gears, conveyors, doors, simple logic; 3-6 checkpoints; near-instant respawn; reset rules; environmental storytelling with no text; boss with up to 3 phases, telegraphs, damage via hand and mechanisms, diegetic health; SFX/music/screenshake (toggleable)/hit-stop; pause, settings, title and end cards.
- Differentiators (after polish only): movement-hand fusion (trigger mid-air/mid-dash), time-pressure puzzles, distinct module VFX identity, boss as "final exam", diegetic boss health.
- Defer / cut: wall-run (cut by default; only after movement sign-off and a <=2-day spike); third module; collectibles; adaptive music; vista points; rewind and grapple (high risk). Out of scope: arm swaps, dialogue, cutscenes, multiple levels, controller polish, enemy AI beyond boss, full combat, skill trees.
- Module candidates (OPTIONS ONLY): Remote Trigger beam (simplest), Stasis/freeze, Steam Piston burst, Rewind (high risk), Magnet Grapple (high risk). Suggested: 2 modules in slice (trigger + freeze or steam-burst), chosen in-phase.

### Architecture
- Autoloads only: EventBus (signals), GameState (sole progression writer), SaveService (`SaveData` Resource to `user://`), DebugOverlay (debug builds).
- Player: CharacterBody3D root; flat state machine (one file per state; GroundState/AirState bases); single `move_and_slide()`. InputRouter is the only reader of `Input`, producing an Intent. MovementParams as tuned Resource.
- CameraRig: separate top-level tree, SpringArm3D, aim blend, collision.
- HandController owns modules; HandModule receives a narrow HandContext, never the player. HandSocket (Marker3D on arm bone) shared by all VFX.
- Interactable: physics layer 5 for queries, group `interactable`, `accepts(module_id)`, `trigger()`, highlight.
- Mechanisms: small scenes, signals, `@export` refs, `.tscn` connections. Logic nodes for AND/OR/timer.
- Boss: state machine + `BossPhase` Resources; weak points are Interactables.
- Folders: `core/`, `player/`, `hand/modules/<name>/`, `mechanisms/`, `world/`, `boss/`, `assets/`, `tests/`.
- Collision layers (fix in phase 1): 1 World, 2 Player, 3 Platforms, 4 Enemies/Boss, 5 Interactable, 6 Triggers. Groups: `interactable`, `persistent`, `player`, `checkpoint`.

### Critical Pitfalls and prevention
1. Camera/body jitter: physics interpolation on; gameplay in `_physics_process`; camera top-level sibling; `reset_physics_interpolation()` after respawn; 10-TPS and 144 Hz tests.
2. Floaty jumps: derive gravity from H and T (g=2H/T^2, v=2H/T); fall multiplier 1.5-2x; jump cut; terminal velocity; one exported Resource; movement-metrics table before blockout.
3. Slope/step/snap: floor_snap ~0.3-0.4, disable on upward velocity; platform_on_leave = ADD_UPWARD_VELOCITY; convex/box collision; gym scene with slopes 15/30/44/46 deg, steps 2/10/40 cm, seams, moving platform, conveyor.
4. Dash tunnelling: timed state with move_and_slide each tick; no teleport/Tween; clamp exit speed; walls >= 0.5 m; kill-plane volume.
5. Camera/aim/input: SphereShape3D SpringArm excluding player; mouse look in `_unhandled_input`, no delta multiply; aim_blend 0.12-0.2 s; FOV 75-90; sprint kick <= 8 deg; release mouse on pause/focus loss.
6. Aim assist and turquoise: centre-ray targeting; hysteresis (acquire ~4 deg, release ~7 deg); turquoise reserved for interactables; shared highlight material; high glow threshold.
7. Soft-locks and modules: reset path for every puzzle; gates from measured jump thresholds + margin; one-line module contract; teach-test-twist; no one-way entrances before ability; sequence-break pass.
8. Meshy character: 3k model = smoke test only; Variant A (standard, quad, ~4,500 faces) vs Variant B (smart-topology, ~8,000 tris); acceptance pose test (elbow/shoulder/knee 90 deg, spine twist, head turn); rigid-bind arm, boots, goggles; five-pose test; log settings in ASSET_LOG.md.
9. Style drift: one palette atlas (512/1024); flat or 30-deg auto-smooth; enable_pbr=false; albedo-only inspection; lineup scene as sign-off.
10. Blender/glTF import: checklist script (apply transforms/modifiers, tri count, normals, non-manifold, bbox); 1 unit = 1 m; origin at base; one import preset per class; import-check scene with height ruler.
11. Scope: 1 level, 1 boss (<= 3 phases), 2 modules (3 max), 1 steam type, ~15-25 unique props; cut list; playable main at every phase end.
12. Performance: 1 shadow directional light; <= 4-6 shadow dynamic lights; emissive cores not lights; profile draw calls; no SDFGI; steam 20-60 particles, shared material, pre-warm; test on weakest machine.

## Implications for Roadmap

Nine phases suggested. Phases 1-3 gate core value; phase 4 builds framework with first module; boss depends on everything.

**Phase 1: Foundation and Asset Pipeline Smoke Test.** Pin 4.7.2; Jolt; Forward+; physics interpolation; Input Map (KB+M, controller-ready); collision layers; folders; .gitignore/.gitattributes; conventions doc; headless check. Pipeline smoke test with the 3k placeholder: Blender conform, GLB, import preset, skeleton/BoneMap, placeholder AnimationTree. Style contract, palette atlas, turquoise rule. Move reference PNGs from repo root to `docs/reference/`. RESEARCH FLAG: yes, time-boxed spike on Meshy-to-Godot retarget.

**Phase 2: Movement Core.** CharacterBody3D, InputRouter/Intent, flat state machine (Idle, Run, Sprint, Jump, Fall, Dash, Land), MovementParams, coyote/buffer, variable jump, gravity, air control, timed dash, floor snap, platform inheritance; gym scene; metrics table; debug overlay; placeholder capsule. RESEARCH FLAG: standard; feel sign-off required.

**Phase 3: Camera and Aim.** Phantom Camera spike (<= 1 day) or SpringArm fallback; mouse look; sensitivity/invert-Y; shoulder offset; collision excluding player; damped follow; aim blend; FOV limits; crosshair states; tight-corridor test. RESEARCH FLAG: yes, spike; Phantom Camera not yet run on 4.7.2.

**Phase 4: Interaction Contract and Hand Framework (first module).** Interactable; Targeting (centre ray, ShapeCast fallback, hysteresis, line-of-sight); turquoise highlight material; HandController; HandModule base; HandModuleDef; HandSocket; first module (remote trigger candidate) with beam VFX; reticle states; first-use prompt; one teaching room; module contract. RESEARCH FLAG: light check.

**Phase 5: Mechanisms, Second Module, Progression.** Switch, Valve, Gear (AnimatableBody3D), Conveyor, Door, Logic nodes; sandbox wiring; second module (freeze or steam-burst, chosen here); inventory and switch input; pickup moment; GameState, SaveData, checkpoints, respawn and puzzle reset rules. RESEARCH FLAG: light check if freeze is chosen.

**Phase 6: Vertical-Slice Level Blockout and Gating.** level_01 grey-box, 1 m grid; three zones; lock-before-key; puzzle rooms; checkpoints; kill planes; reset affordances; sequence-break pass; fun-without-art check. RESEARCH FLAG: standard.

**Phase 7: Art Pass and Character Final.** Final Meshy hero; retopo/cleanup at joints; rigid arm/boots/goggles; five-pose test; shared AnimationLibrary; prop kit (15-25 unique, palette, MultiMesh); set dressing and vignettes; WorldEnvironment (Forward+, one directional light, emissive cores, glow threshold, toon materials, depth fog); lineup sign-off; CREDITS.md and ASSET_LOG.md. RESEARCH FLAG: yes (retopo/rig path, Meshy licence tier, Mixamo chibi locomotion).

**Phase 8: Boss.** Rigid-part boss (no skinning); state machine with BossPhase Resources (2-3 phases); telegraphs; weak-point Interactables; arena mechanisms; core-based health; player health (3-5 points or knockback model); respawn at arena; victory and exit. RESEARCH FLAG: light check.

**Phase 9: Polish, Performance, Export.** SFX, music, particles, screenshake and hit-stop (toggleable), post-processing, HUD, pause, settings, title/end; profiling on weakest machine; Windows export on a second machine; strip debug code. RESEARCH FLAG: standard.

**Ordering rationale:** core value first (2-3 gate 4); framework with its first consumer; checkpoint rules before puzzles; blockout before art; boss last among content; asset pipeline runs in parallel from phase 1.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | HIGH (engine version, Meshy params, rig constraints); MEDIUM (camera addon, poly budgets) | Phantom Camera README says Godot 4.4+; not yet tested here |
| Features | MEDIUM | Feel numbers agree across sources; genre conventions from blogs and knowledge; module candidates are options only |
| Architecture | MEDIUM-HIGH | Established Godot practice; verify 4.7.2 API details |
| Pitfalls | MEDIUM-HIGH | Interpolation and CharacterBody3D verified in docs; numbers are heuristics |

**Overall: MEDIUM-HIGH**

### Gaps to Address
- **Godot version:** 4.7.2 used; re-verify and confirm addon compatibility at project creation.
- **Meshy budget conflict:** STACK 8-10k tris (range 6-12k) vs PITFALLS 3-6k. Reference detail favours STACK. Decide in phase 1 and record.
- **Turquoise conflict:** "turquoise reserved for interactables" conflicts with (a) World Look.png turquoise decoration, (b) turquoise set-piece glow, (c) the prosthetic arm cores, which are not interactable. Decide in phase 1: different hue or non-glowing treatment for decoration, or an explicit exception for the player's arm. Record in the style contract before props are generated.
- **Meshy licence tier and terms:** unverified; check before phase 7.
- **Meshy auto-rig quality and bone naming:** resolved by phase 1 spike.
- **Camera interpolation jitter:** community reports; resolved by phase 2-3 acceptance tests.
- **Volumetric fog / MSAA on laptop hardware:** test in phase 9.
- **Module choice:** deliberately open; second module chosen in phase 5.
- **Movement numbers:** starting points; tune and record.
- **Mixamo licence wording:** confirm before submission.
- **Wall-run:** default cut; decide at end of phase 2.

## Sources
- Godot 4.6 and 4.7 release notes; godotengine.org/download/archive; Godot docs (Jolt, physics interpolation, CharacterBody3D, import, retargeting).
- Meshy API docs: Text-to-3D, Rigging, Animation library (docs.meshy.ai).
- KayKit Dungeon Remastered asset page (CC0, 1024 px atlas).
- Phantom Camera, Debug Draw 3D, gdUnit4, godot-statecharts release pages (GitHub).
- Godot forum threads on camera jitter with physics interpolation and headless exit codes.
- Practitioner heuristics (coyote/buffer, gating, boss design, budgets): LOW-MEDIUM, validate by playtest.
- Project context: .planning/PROJECT.md and user decisions of 2026-11-02.

---
*Research completed: 2026-11-02*
*Ready for roadmap: yes*
