# Phase 2: Movement Core & Follow Camera - Context

**Gathered:** 2026-11-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Real movement on the Phase 1 scaffold: camera-relative run and sprint, variable-height jump, ground-jump chain with long jump, one air double jump, ground dash and one air dash, platform/conveyor carry with momentum, slopes and stairs, plus a jitter-free mouse-look follow camera. Everything is tuned live from one resource in a movement gym built from Prototype Bits, with a measured movement-metrics table and input latency. Signed off without any juice.

Out of scope: full animation state mapping and aim mode (Phase 3), interactable highlighting and Fernauslöser (Phase 4), any juice/VFX (Phases 11-12), gamepad bindings (Phase 13), wall-run and ledge grab (v2).

</domain>

<decisions>
## Implementation Decisions

### Run and sprint feel
- **D-01:** Ground acceleration is orientated on Super Mario (3D): fast but perceptible build-up, noticeable turn-around/skid on direction reversal, some weight. Not instant, not floaty. All values tunable in the movement resource; Claude picks the start values and the exact curve shape.
- **D-02:** Air control is high: near-full direction control in the air, forgiving for jumps.
- **D-03:** Sprint is hold-to-sprint (`sprint` action held, release = run). Sprint speed is about 1.5x run speed with its own acceleration curve.

### Jump chain (ground) and long jump
- **D-04:** Jump height is variable in every jump: tap = short, hold = high (velocity cut on release). Chain stages only set the maximum height. Fall gravity is heavier than rise (multiplier 1.5-2x), with terminal velocity clamp.
- **D-05:** Ground chain is original, not Mario's 1-2-3: Jump 1 -> land -> Jump 2 (higher, within a landing window) -> Dash -> Jump = **maximum long jump** (high and fast, forward). Fewer chain stages give a weaker long jump (a dash-jump without a chain is still a long jump, just smaller). Landing window, stage heights and long-jump arc are tunable values.
- **D-06:** A jump pressed during or right after a plain ground dash (no chain) is already a **small long jump**: a flatter, farther arc with the dash speed carried (not a flat copy of the normal jump). Each chain stage before the dash (D-05) makes it bigger, up to the maximum long jump. Jump cancels the dash. This replaces the earlier "normal jump with dash speed" idea.
- **D-07:** The chain resets when the landing window is missed or the player stands still. Landing resets double jump and air dash.

### Air options
- **D-08:** One air double jump per airtime (MOVE-05 unchanged), one air dash per airtime. They may be combined in any order: jump -> air dash, double jump -> air dash, air dash -> double jump. Each is available once until landing. Exact ordering edge cases are Claude's discretion; keep the rule "each used at most once per airtime".
- **D-09:** Coyote time about 0.1 s and jump buffer about 0.1-0.15 s (CLAUDE.md values). A jump pressed just before landing counts as a buffered jump and keeps horizontal speed (no ground deceleration frame).

### Dash
- **D-10:** Dash direction is the input direction (camera-relative); without input it goes in the current facing direction. The figure turns instantly toward the dash direction first, then dashes "forward" (the kit only has `Dodge_Forward`). Re-evaluate in Phase 3 for aim mode.
- **D-11:** Dash is a fixed distance (short speed override, about 0.15-0.2 s) after which part of the speed carries into run/sprint. Air control is kept on exit. Short cooldown about 0.3-0.5 s. A dash never tunnels through walls (swept/shape-cast safe).
- **D-12:** Air dash is once per airtime, refilled on landing.

### Platforms
- **D-13:** Moving platforms and conveyors carry the player, and the player keeps the platform velocity as momentum when leaving it or jumping off (Mario-like). Slopes and stairs never make the player stick or launch (`floor_snap_length` about 0.3-0.5, `floor_max_angle` about 50 degrees, `floor_stop_on_slope`).

### Camera
- **D-14:** Camera framing outside aim mode is **centered behind the character**, like Odyssey/BotW/Kirby. Shoulder offset arrives only in aim mode (Phase 3). CAM-01's "over-the-shoulder" wording changes to third-person follow; the planner updates REQUIREMENTS.md/ROADMAP.md accordingly. — **Reversibility:** reversible — offset is a rig parameter.
- **D-15:** Follow uses light damping, with vertical follow smoothed so jumps do not cause bobbing (the camera catches up on landing). No fixed hard lock.
- **D-16:** Auto-follow as in Odyssey: after about 1 s without look input, while moving, the camera rotates gently behind the movement direction; sideways running pulls it along. It must never fight mouse input (it stays off while the mouse is moving) and must also work for a controller later.
- **D-17:** New input action `camera_recenter` (default: middle mouse, R3 later) snaps the camera quickly behind the character. Added to the Input Map and `docs/CONVENTIONS.md`. — **Reversibility:** costly — action names are referenced from code (D-15 of Phase 1).
- **D-18:** Camera tech: **hand-built rig, Phantom Camera is dropped.** Rig = `CameraRig (yaw) > Pitch > SpringArm3D > Camera3D`. No Phantom Camera spike. The rig must support additive contributions to FOV and offset (for Phase 3 aim blending and Phase 11 shake/FOV kick). Camera moves in `_process`, physics in `_physics_process`, jitter-free at 10 TPS and 144 Hz, never clips through walls. The planner updates the CLAUDE.md stack table (Phantom Camera row, addon list) and the STATE.md blocker. — **Reversibility:** costly — Phases 3 and 11 build on the rig's interface.
- **D-19:** Mouse sensitivity and invert-Y are configurable (CAM-03); defaults are Claude's discretion.

### Movement gym and measurement
- **D-20:** The gym is one hall with zones: measurement strip on the 1 m grid, ramps and stairs, gaps of increasing width, moving platforms (straight, circular, up/down), conveyors, narrow passages and walls for camera tests. Built only from Prototype Bits (no new assets).
- **D-21:** Metrics are measured automatically by a debug overlay (max jump height/distance, dash distance, live) toggled by a key. Results are written into `docs/MOVEMENT-METRICS.md`. Gym markings allow a manual cross-check. Include long-jump and chain values.
- **D-22:** Latency is measured in software: time from input event to velocity/state change, at 60 and 120 TPS. Target <= 66 ms, hard limit 100 ms. Screen and mouse latency are outside the measurement; noted as a caveat in the doc.
- **D-23:** All movement values live in one tunable `Resource` (live-editable, MOVE-10). No juice in this phase.

### Claude's Discretion
- Start values and curve shapes for acceleration, skid, gravity, jump heights, chain window, long-jump arc, dash speed/duration, air-order edge cases.
- Default mouse sensitivity, pitch limits, camera distance/FOV, damping constants, auto-follow timing details.
- Key for the metrics overlay and the debug camera/gym toggles.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/ROADMAP.md` §Phase 2 - goal, success criteria, notes (latency at 60 and 120 TPS, additive FOV/offset)
- `.planning/REQUIREMENTS.md` - MOVE-01..08, MOVE-10, CAM-01, CAM-03, FEEL-06
- `.planning/PROJECT.md` - core value, constraints
- `.claude/CLAUDE.md` - movement values (coyote, buffer, fall multiplier, floor settings), input table, camera section (Phantom Camera row to be replaced per D-18)
- `.planning/phases/01-foundation-prototype-character/01-CONTEXT.md` - D-06 VisualRoot, D-08 AnimationTree, D-10/D-11 event bus facts, D-14/D-15 layers and action names

### Research
- `.planning/research/GAME-FEEL.md` - feel research (latency, responsiveness)
- `.planning/research/PITFALLS.md` - known pitfalls (physics interpolation, camera ordering)
- `.planning/research/ARCHITECTURE.md`, `.planning/research/STACK.md`
- `.planning/research/KAYKIT.md` - clip coverage (long jump, dash must be built from existing clips, MOVE-11)

### Project files
- `docs/CONVENTIONS.md` - layers, groups, action names (add `camera_recenter`)
- `attimo/project.godot` - input map, layers, interpolation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `attimo/scripts/player/player_controller.gd`: Phase 1 scaffold; its header says Phase 2 adds velocity, gravity and the single `move_and_slide` call here. `input_direction()` becomes camera-relative; `face()` rotates `VisualRoot`.
- `attimo/scripts/core/state_machine.gd`, `state.gd`, and states `idle/run/jump/fall/dash` in `attimo/scripts/player/states/`: extend with sprint, double jump, long jump and air dash.
- `attimo/autoload/event_bus.gd`: emit `jumped`, `landed`, `dash_started`, `movement_state_changed` from the real states; add facts for double jump, long jump, chain stage if needed (emit only).
- `attimo/scenes/test/test_scene.tscn` and `attimo/scenes/proto/primitive_*.tscn`: base for the movement gym.
- `attimo/scripts/debug/event_log.gd`, `attimo/scenes/debug/event_log.tscn`: pattern for the metrics overlay.
- `attimo/tests/smoke/` and `attimo/tests/run.sh`: smoke-test pattern for new movement logic.

### Established Patterns
- Typed GDScript, node-based FSM, event bus emits only (no feedback calls from gameplay), physics interpolation ON, Jolt, collision layers World/Player/Interactable/Enemy/Projectile/Hazard.

### Integration Points
- Camera rig interface (additive FOV/offset) is used by Phases 3 and 11.
- Movement resource and event bus facts are used by Phases 3, 5 and 11.
- `VisualRoot` is used for lean/flip/stretch in Phases 3 and 11.

</code_context>

<specifics>
## Specific Ideas

- Ground feel and camera auto-follow reference: Super Mario Odyssey. Camera framing reference: Odyssey, Breath of the Wild, Kirby and the Forgotten Land, Donkey Kong Bananza.
- Ground combo is meant to feel original: Jump 1 -> Jump 2 -> Dash -> Jump = maximum long jump, a high and fast forward jump.
- Air should feel special: double jump, double jump -> dash, or jump -> dash.

</specifics>

<deferred>
## Deferred Ideas

- **Prosthetic down-glide/blast:** a downward glide or burst from the prosthesis while it is "charged". Undecided; decide later (links to Hand modules, Phase 5 push/steam, and a possible charge mechanic). Not in Phase 2.
- Landing-based Odyssey triple jump and the tempo-stage idea (speed grows with well-timed actions): not taken. Revisit only if the gym sign-off shows the feel lacks it.
- Dive/ground-pound and gliding as air verbs: raised as options, not chosen; would need a clip composition (MOVE-11).

</deferred>

---

*Phase: 2-Movement Core & Follow Camera*
*Context gathered: 2026-11-04*
