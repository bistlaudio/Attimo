---
phase: 01-foundation-prototype-character
verified: 2026-11-04T12:00:00Z
status: human_needed
score: 4/4 roadmap success criteria verified (automated evidence); 4 human-judgment items open
covered_files:
  - .planning/phases/01-foundation-prototype-character/01-01-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-01-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-02-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-02-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-03-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-03-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-04-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-04-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-05-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-05-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-06-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-06-SUMMARY.md
  - .planning/phases/01-foundation-prototype-character/01-07-PLAN.md
  - .planning/phases/01-foundation-prototype-character/01-07-SUMMARY.md
  - README.md
  - attimo/assets/animations/rig_medium/rig_medium_library.res
  - attimo/autoload/event_bus.gd
  - attimo/project.godot
  - attimo/scenes/debug/event_log.tscn
  - attimo/scenes/player/mannequin.tscn
  - attimo/scenes/player/mannequin_state_machine.tres
  - attimo/scenes/player/player.tscn
  - attimo/scenes/proto/primitive_cube_small.tscn
  - attimo/scenes/proto/primitive_floor.tscn
  - attimo/scenes/proto/primitive_pillar.tscn
  - attimo/scenes/proto/primitive_wall.tscn
  - attimo/scenes/test/test_scene.tscn
  - attimo/scripts/core/physics_layers.gd
  - attimo/scripts/core/state.gd
  - attimo/scripts/core/state_machine.gd
  - attimo/scripts/debug/event_log.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/fall.gd
  - attimo/scripts/player/states/idle.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/run.gd
  - attimo/tests/fixtures.gd
  - attimo/tests/run.sh
  - attimo/tests/run_smoke.gd
  - attimo/tools/build_animation_library.gd
  - attimo/tools/build_mannequin_state_machine.gd
  - docs/CONVENTIONS.md
covered_digest: "v4:sha256:560b06c1a30a8c76c003626d15bf03be10eb78b4b804e018dcdb9509ce8030c2"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Open the project in the pinned Godot 4.7.2 editor, press F5, and use W/A/S/D, Space, and Q or Left Ctrl. Watch the Mannequin."
    expected: "Idle_A loops while standing. Running_A plays in place while a move key is held, and the Mannequin turns toward the input direction. Space plays Jump_Start, Jump_Idle, then Jump_Land. Dash plays Dodge_Forward. The Player does not translate (D-09). Poses look like the KayKit clips with no broken skeleton, T-pose flashes, or foot glitches."
    why_human: "Headless tests prove state names, blend values, and that bone poses change. They cannot judge whether the animation looks right or whether transitions look acceptable. Review WR-03 predicts a visible Idle to Run pop because the Locomotion blend snaps between 0.0 and 1.0."
  - test: "In the running test scene press F3 (or the key left of 1) while performing jump, run, and dash."
    expected: "A timestamped overlay appears with jumped, landed, dash_started, and movement_state_changed lines, newest last, capped at 14 lines. F3 hides it again. It starts hidden."
    why_human: "Tests assert log contents and toggle logic through simulated actions. Only a person can judge readability, placement, and whether the real key binding (including the left-of-1 key on a German keyboard) toggles the overlay."
  - test: "Look at the test scene through the static camera (F5)."
    expected: "The 20 x 20 m floor, wall ring, and the 1 m / 2 m / 4 m reference blocks and the Mannequin are all framed and readable. The Prototype Bits texture is applied, with no missing-texture look."
    why_human: "The camera is a fixed Camera3D (tests only confirm one current camera with no script). Framing, scale readability, and look are visual judgments."
  - test: "Open Project Settings > Layer Names > 3D Physics in the editor, and select a block's StaticBody3D to view the Collision layer grid."
    expected: "Layers 1-6 are named World, Player, Interactable, Enemy, Projectile/Beam, Hazard. Layers 7-32 are unnamed. Prototype Bits wrappers show layer 1 checked."
    why_human: "The names are verified in project.godot text and via ProjectSettings in tests. Only the editor shows how the inspector renders them."
---

# Phase 1: Foundation & Prototype Character Verification Report

**Phase Goal:** As the developer, I want the KayKit Mannequin animating on input in a Prototype Bits test scene, so that the project base and the prototype pipeline are proven.
**Verified:** 2026-11-04
**Status:** human_needed
**Re-verification:** No, initial verification

All automated evidence passes. No FAILED truth, no blocker. The status is `human_needed` only because four visual and feel items cannot be judged programmatically.

## Goal Achievement

### Observable Truths (ROADMAP success criteria are the contract)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The project opens in pinned Godot 4.7.x and runs a test scene with typed GDScript, Jolt, Forward+ and physics interpolation. Layers, groups and folders are documented. | VERIFIED | The pinned binary reports `4.7.2.stable.official.ed1daf0bf`. `project.godot` has `3d/physics_engine="Jolt Physics"`, `common/physics_interpolation=true`, `config/features=("4.7","Forward Plus")`, `gdscript/warnings/untyped_declaration=2`, and `run/main_scene` set to the test scene. `docs/CONVENTIONS.md` (148 lines) has sections for folder layout, naming, typed GDScript, collision layers, groups, Input Map, event bus, player scene and tooling. `run.sh` reports `SMOKE SUMMARY: tests=13 passed=464 failed=0` and `RUN.SH: PASSED`. Human item 4 covers how the layer names look in the editor. |
| 2 | Raw KayKit/VFX packs stay tracked in root `KayKit/` (outside the Godot project). Only used Prototype Bits, Mannequin_Medium and Rig_Medium library are under `assets/`. | VERIFIED | `git ls-files KayKit` lists 2314 tracked files. `git ls-files attimo/assets` lists exactly 25 files: Mannequin GLB and texture, 3 Rig_Medium GLBs plus `rig_medium_library.res`, 4 Prototype Bits `.gltf`/`.bin` pairs and the shared texture, plus `.import` sidecars. No KayKit directory exists inside `attimo/`. No LFS attribute exists (the `.gitattributes` check in `run.sh` passes). `test_asset_hygiene` and the `run.sh` repo checks (KayKit tracked, originals tracked, no LFS) pass. |
| 3 | The test scene is built from Prototype Bits pieces. Input Map actions make the Mannequin_Medium play Idle, Run, Jump and Dodge clips. Gamepad slots are reserved but not bound. | VERIFIED (visual quality: human item 1) | `test_scene.tscn` instances only the four `primitive_*` wrappers, the Player and the EventLog. The scene test confirms every mesh sits under a wrapper or the Mannequin (54 meshes). The simulated play-through passes: `move_forward` puts the tree in Locomotion with blend 1.0, a jump ends with `landed` within 120 frames, and dash travels the tree to Dash with exactly one `dash_started`. `rig_medium_library.res` holds the six clips (Idle_A, Running_A, Jump_Start, Jump_Idle, Jump_Land, Dodge_Forward) and the animation tests pass. All 18 actions exist (aim, dash, debug_event_log, interact, jump, look_*, module_*, move_*, pause, sprint, use_hand). `project.godot` has zero `InputEventJoypad*` entries. The `look_*` actions have empty event lists. `player_controller.gd` reads input only via `Input.get_vector` and `is_action_*`. |
| 4 | Gameplay facts (jumped, landed, dash_started) are broadcast on an event bus and appear in a debug event log. Gameplay code calls no feedback, and the scene contains no particles or juice. | VERIFIED (log feel: human item 2) | `event_bus.gd` holds only the four typed signals: `jumped`, `landed`, `dash_started` and `movement_state_changed`. `Jump.enter` emits `jumped`, `Fall` emits `landed` once, `Dash.enter` emits `dash_started`, and `StateMachine` emits `movement_state_changed` on setup and on every transition. A grep for Particles/Tween/AudioStream/time_scale/shake under `scripts/` and `autoload/` returns nothing. `test_feedback_guard` passes. The scene test finds 0 particle nodes, glow, fog and SDFGI all off. `event_log.gd` auto-connects to every EventBus signal via `get_script_signal_list`. The log contents test finds jumped, landed, dash_started and movement_state_changed lines. |

**Score:** 4/4 roadmap truths verified by automated evidence. 0 behavior-unverified. The state-transition truths (`landed` fires exactly once, `dash_started` fires once, the Player never moves) are exercised by the passing named smoke tests (`test_movement_facts`, `test_dash_fact`, `test_scene_run`), not just by symbol presence.

### Plan-level must-haves (merged, no scope reduction)

| Plan | Key truths | Status |
|------|-----------|--------|
| 01-01 | run.sh passes on pinned engine and refuses other versions (exit 3). Space gives Idle to Jump and one `jumped`. Jolt/Forward+/interpolation/typed-errors set. No movement physics (D-09). README documents the pin. | VERIFIED |
| 01-02 | Six-clip library with the correct loop modes. Mannequin under VisualRoot (feet pivot). AnimationTree travels to Jump and then Land. GLB wrapped in `mannequin.tscn`. Only the declared GLBs were copied. | VERIFIED (visual: human item 1) |
| 01-03 | Run, Fall/`landed` and Dash/`dash_started` verbs. Position and velocity stay zero. Every state change emits `movement_state_changed`. | VERIFIED |
| 01-04 | 18 actions with KB+M bindings, no gamepad events. Layers 1-6 named. `PhysicsLayers` constants. `CONVENTIONS.md` (148 lines, above the 80-line minimum). | VERIFIED |
| 01-05 | Four Prototype Bits wrappers with a box on layer 1, mask 0 and no trimesh. Ray probes hit each top face. | VERIFIED |
| 01-06 | Event log overlay is generic, capped at 14 lines, a scene not an autoload, and toggled by `debug_event_log`. FEEL-01 guard in place. | VERIFIED (feel: human item 2) |
| 01-07 | Test scene is the main scene. 20 walls with no overlap, standing at y 0. Whitelist of 25 asset files. `run.sh` KayKit/LFS checks. | VERIFIED |

### Required Artifacts

`verify.artifacts` reports all passed for every plan: 7/7, 6/6, 4/4, 5/5, 5/5, 4/4 and 4/4 (35 of 35). No artifact is missing or a stub.

### Key Link Verification

`verify.key-links` reports every link verified: 5/5, 4/4, 4/4, 2/2, 2/2, 2/2 and 3/3 (22 of 22). Examples: the EventBus autoload registration, `EventBus.jumped.emit` in `jump.gd`, `state_machine.physics_update` in the controller, `main_scene` pointing at the test scene, and the Mannequin instanced under `VisualRoot`.

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Real data | Status |
|----------|---------------|--------|-----------|--------|
| `event_log.gd` | `lines` | Live `EventBus` signals emitted by the FSM states | Yes. The test finds all four fact types in the log. | FLOWING |
| `mannequin_animator.gd` | AnimationTree travel and `blend_position` | `StateMachine.state_changed` | Yes. Tree state and blend values are asserted in the tests. | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full harness on pinned Godot | `bash attimo/tests/run.sh` | `tests=13 passed=464 failed=0`, `RUN.SH: PASSED` | PASS |
| Engine pin | `$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot --version` | `4.7.2.stable.official.ed1daf0bf` | PASS |

The full workspace test command was run once, as the verifier contract requires.

### Probe Execution

SKIPPED. The plans declare no `probe-*.sh` scripts.

### Requirements Coverage

Every ID in the PLAN frontmatter is accounted for. No requirement mapped to Phase 1 in REQUIREMENTS.md is orphaned (FOUND-06 maps to Phase 9).

| Requirement | Source plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| FOUND-01 | 01-01, 01-07 | Pinned Godot 4.7.x, typed GDScript, Jolt, Forward+, physics interpolation | SATISFIED | Truth 1. `project.godot` settings plus the version gate in `run.sh` and `test_project_settings`. |
| FOUND-02 | 01-01, 01-03, 01-04 | All input via named Input Map actions, KB+M now, gamepad reserved | SATISFIED (combined) | 01-01 set up the `jump` tracer. 01-03 added `move_*` and `dash` use. 01-04 completed all 18 actions with no gamepad events and a raw-polling guard. The combined result holds. See the WR-05 note on guard coverage. |
| FOUND-03 | 01-04 | Collision layers, groups and folder conventions fixed and documented | SATISFIED | Layers 1-6 in `project.godot`, `PhysicsLayers` constants, and `docs/CONVENTIONS.md`. See the WR-02 note on doc-sync assertions. |
| FOUND-04 | 01-02, 01-05, 01-07 | Raw packs in root `KayKit/`, only used assets under `attimo/assets/` | SATISFIED | Truth 2. 2314 tracked reference files, 25 whitelisted project assets, no LFS. |
| FOUND-05 | 01-02, 01-03, 01-05, 01-07 | Prototype Bits greybox, Mannequin_Medium on Rig_Medium, no particles or juice | SATISFIED | Truths 3 and 4. 54 meshes all under wrappers or the Mannequin, 0 particle nodes. |
| FEEL-01 | 01-01, 01-03, 01-06, 01-07 | Gameplay events broadcast so juice can be layered on later | SATISFIED (combined) | 01-01 laid the bus and the `jumped` tracer. 01-03 added `landed`, `dash_started` and `movement_state_changed`. 01-06 added the log and the guard. All four facts are emitted by gameplay code and consumed by the log. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | No TBD/FIXME/XXX debt markers in phase files (the only `XXX` hits are `mktemp` templates in `run.sh`). No TODO/HACK/PLACEHOLDER. | none | - |

### Review Advisories (01-REVIEW.md, not failing)

The code review found 0 critical, 6 warning and 9 info items. None is a blocker for the phase goal. They are kept here for planning:

- **WR-01 and WR-02:** Weak test assertions. The event-log eviction check cannot detect wrong-end eviction. The doc-sync checks in `test_conventions` are mostly substring tautologies, so the claim in `CONVENTIONS.md:10` is stronger than the guard.
- **WR-03:** The Locomotion `blend_position` snaps between 0.0 and 1.0, so Idle to Run may pop visually. Unknown states silently map to Idle. This feeds human item 1 and is relevant to the core "smooth feel" value in Phase 2/3.
- **WR-04:** `StateMachine.transition_to` guards unknown states with `assert` only, which release builds strip.
- **WR-05:** `run.sh` has no timeout, so a stuck `await` hangs the harness. (The raw-input scan list is also narrow, per IN-05.)
- **WR-06:** Some tests leak EventBus connections and pressed actions.
- **IN-03:** Dash can be chained from Fall indefinitely, which postpones `landed`. This is to be capped in Phase 2 (MOVE-06/07).

### Human Verification Required

See the `human_verification` list in the frontmatter. Four items remain: animation quality in the running scene, F3 log feel and key binding, camera framing of the test scene, and the layer names as shown in the inspector.

### Gaps Summary

No gaps. Every roadmap success criterion and every plan must-have has passing automated evidence (464 assertions, 35 of 35 artifacts, 22 of 22 key links), and every requirement ID (FOUND-01 to FOUND-05, FEEL-01) is satisfied. The phase cannot be marked `passed` only because four visual and feel checks need a person at the editor. REQUIREMENTS.md still shows these six requirements as Pending, and the ROADMAP Phase 1 checkbox is unticked. Both are tracking updates for the orchestrator after human sign-off.

---

_Verified: 2026-11-04_
_Verifier: Claude (gsd-verifier)_
