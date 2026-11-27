# Roadmap: Attimo

## Overview

The roadmap has two groups. **Group A: Prototyp** (Phases 1-8) builds every mechanic as a vertical, playable slice. It uses only KayKit Prototype Bits for geometry and the KayKit Mannequin_Medium with its Rig_Medium clips as the character. There are no particles and no juice. Group A ends when the whole slice plays from title screen to end screen and all mechanics are right. **Group B: Produktion** (Phases 9-15) then turns the prototype into the real game. First come the style contract and the final Meshy hero. Next the steampunk kit is built and the world is rebuilt with it. Then two juice phases add feedback to every action and finish with a polish pass over the whole slice. Controller support, audio and the Windows release come last, in that order.

**Rules for every phase:**

- Every phase ends with something playable.
- **Gym rule (user decision 2026-11-23):** every gameplay phase ends with the movement gym reworked and extended. New mechanics get their own station or room, outdated stations are removed or rebuilt, and the gym layout is regrouped when the content no longer fits. The gym always shows the current state of the game.
- **Design docs rule (user decision 2026-11-23):** at the end of every phase, if the phase changed the design, update `docs/GAME-DESIGN.md` (with a change-log line), the site `docs/game-design.html` and the deck `docs/attimo-presentation.html`.
- **Lecture principles:** discuss and plan answer the checklist in `docs/reference/LECTURE-PRINCIPLES.md` (project skill `attimo-design-principles`).
- **Group A only:** All geometry comes from KayKit Prototype Bits. Shapes the kit lacks (gears, valves, conveyors, enemies, the boss) are stand-ins built from Prototype Bits pieces. The character is the KayKit Mannequin_Medium on Rig_Medium. No particles, no juice VFX, no camera juice and no Meshy work. Feedback that carries information is part of the mechanic and is allowed: interactable glow, reticle states, HUD, the plain pulse and rope lines.
- From Phase 1, gameplay emits facts on an event bus. Juice (Phases 11-12) and audio (Phase 14) listen to these facts, so they plug in without changes to gameplay code.
- There are no juice presets, levels or toggles. Juice is tuned to one fixed, strong level (user decision).
- Keyboard and mouse come first. All input goes through Input Map actions. Gamepad is tuned only in Phase 13.
- Movement and poses come only from the KayKit `Rig_Medium` clips, using cuts, blends, playback speed and procedural rotation/scale. A verb with no clip composition is not added.
- Turquoise is used only for interactables and hand feedback. Movement VFX use cream, warm white or amber.
- The exact design of each hand module and of shooting/enemies is confirmed at the start of its own phase (discuss-phase).

| Group | Phases | Look | Ends when |
|-------|--------|------|-----------|
| A: Prototyp | 1-8 | Prototype Bits + Mannequin_Medium, no particles, no juice | The full slice plays from title to end screen and all mechanics are signed off |
| B: Produktion | 9-15 | Final hero, steampunk world, juice, sound | Polished Windows build runs smoothly on a weaker laptop |

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

### Group A: Prototyp (Phases 1-8)

- [x] **Phase 1: Foundation & Prototype Character** - Pinned Godot project, conventions, repo hygiene, Mannequin_Medium animating in a Prototype Bits test scene, and the gameplay fact bus (completed 2026-11-04)
- [x] **Phase 2: Movement Core & Follow Camera** - Run, variable jump with a Jump 1-2-3 chain, ground and air dash, the dash-hop long jump, platforms, and a jitter-free mouse-look camera, signed off without juice (completed 2026-11-06)
- [x] **Phase 3: Animated Mannequin & Aim Mode** - The Mannequin animates with every movement state from kit clips, plus aim mode with crosshair (completed 2026-11-20)
- [x] **Phase 4: Fernauslöser & Mechanism Kit** - Hand module framework, turquoise highlight with aim assist, Module 1 remote-trigger pulse, and the greybox D-15/D-16 mechanism kit (levers, valves, energy cores, cranks, gear gates, rotating and lift platforms, conveyors, steam nozzles, pendulums) with AND, OR and timer logic (completed 2026-11-23)
- [x] **Phase 5: Energy Arm & Loader** - Energy resource in 4 arm cores with Moto Perpetuo, passive and capsule income, energy costs for injected moves, the right-click Loader with charge ring and trajectory preview, aim mode removed (completed 2026-11-24)
- [x] **Phase 05.1: Kit Rework** (INSERTED) - Mechanism kit rebuilt as 8 logic blocks + 4 components + looks in steampunk, energy and nature layers, showroom regrouped; plus (playtest 2026-11-25) the energy clock in 12 whole steps, every ability paid, the shot and targets removed and the straight-line Loader (completed 2026-11-27: 22/22 plans, verification 9/9, human UAT pending in 05.1-HUMAN-UAT.md)
- [ ] **Phase 6: Extractor, Enemies & Recovery** - Enemies beaten by the Extractor and Loader hits (no shot), 1-2 greybox enemy types, health next to the energy clock, Extractor and Loader teaching rooms, checkpoints and near-instant respawn
- [ ] **Phase 7: Level Blockout & Game Flow** - The full Prototype Bits level with ability gating, the "charge the level" gimmick and reset paths, plus title, pause and settings menus
- [ ] **Phase 8: Boss & Ending** - A greybox object-boss with 2-3 telegraphed phases, beaten through hand modules and arena mechanisms, followed by the end screen

### Group B: Produktion (Phases 9-15)

- [ ] **Phase 9: Style Contract & Final Hero** - Style contract first, then the final Meshy hero on Rig_Medium replaces the Mannequin
- [ ] **Phase 10: Steampunk World Building** - Steampunk prop/environment kit, the level, arena and boss rebuilt with it, warm lighting, fog and steam, and storytelling through the world alone
- [ ] **Phase 11: Movement & Camera Juice** - Data-driven cue catalogue, squash/stretch, dust and steam on every move, FOV kicks, camera shake and hit-stop at one fixed, strong level
- [ ] **Phase 12: Hand & Combat Juice + Polish** - Feedback for Loader, Extractor, energy clock, mechanisms and hits, then a polish pass that retunes all mechanics together and fixes rough spots
- [ ] **Phase 13: Controller Support** - Gamepad bindings for everything, plus stick look and aim assist tuned for controller
- [ ] **Phase 14: Audio** - Sound effects through the catalogue SFX slots, level and boss music, and a hit-stop/shake retune with sound
- [ ] **Phase 15: Windows Release & Performance** - Standalone Windows build, profiling on a weaker laptop at 60 fps, and debug tools stripped

## Phase Details

### Phase 1: Foundation & Prototype Character

**Group:** A (Prototyp)
**Goal:** As the developer, I want the KayKit Mannequin animating on input in a Prototype Bits test scene, so that the project base and the prototype pipeline are proven.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FEEL-01
**Success Criteria** (what must be TRUE):

  1. The project opens in pinned Godot 4.7.x and runs a test scene with typed GDScript, Jolt, Forward+ and physics interpolation enabled. Collision layers, groups and folder conventions are documented.
  2. Raw KayKit/VFX packs stay tracked in the repo root `KayKit/` as a shared reference library (outside the Godot project folder, so Godot never imports them). Only the used Prototype Bits pieces, the Mannequin_Medium and the Rig_Medium animation library live under `assets/`.
  3. The test scene is built from Prototype Bits pieces. Pressing Input Map actions makes the Mannequin_Medium play the KayKit Idle, Run, Jump and Dodge clips. Gamepad slots are reserved but not bound.
  4. Gameplay facts (for example jumped, landed, dash_started) are broadcast on an event bus and appear in a debug event log. Gameplay code calls no feedback directly, and the scene contains no particles or juice effects.

**Plans:** 7/7 plans complete

Plans:

- [x] 01-01-PLAN.md — Walking skeleton: pinned 4.7.2 engine, tracer Space -> Jump -> `jumped` on EventBus, headless smoke harness, README (wave 1)
- [x] 01-02-PLAN.md — Mannequin presentation: copied KayKit GLBs, merged clip library, AnimationTree, Mannequin under VisualRoot (wave 2)
- [x] 01-04-PLAN.md — Conventions: full Input Map (KB+M, gamepad reserved), layer names, PhysicsLayers, docs/CONVENTIONS.md (wave 2)
- [x] 01-05-PLAN.md — Prototype Bits pieces (Floor, Wall, Cube_Small, Pillar) with box-collision wrappers (wave 2)
- [x] 01-03-PLAN.md — Demo verbs played in place on timers (D-09: no movement physics): Run, Fall/`landed`, Dash/`dash_started` on the Mannequin (wave 3)
- [x] 01-06-PLAN.md — F3 event log overlay and the FEEL-01 feedback guard (wave 3)
- [x] 01-07-PLAN.md — Prototype Bits test scene as main scene, asset-hygiene guard, end-of-phase play-through (wave 4)

**Notes**: Re-verify Godot 4.7.x and addon compatibility. The Mannequin sits under a VisualRoot node with its pivot at the feet. VisualRoot's yaw is the facing. The final hero (Phase 9) replaces the Mannequin under this node. The procedural pirouette and lean (Phase 3) and squash/stretch (Phase 11) are written on the Mannequin child of VisualRoot, not on VisualRoot itself (DEV-01, Phase 3). The fact bus is the only feedback hook built in Group A (FEEL-01). It is laid now so that the juice and audio phases need no edits to gameplay code. The cue catalogue itself (FEEL-08) waits for Phase 11. No Meshy work happens here.

### Phase 2: Movement Core & Follow Camera

**Group:** A (Prototyp)
**Goal:** As a player, I want to run, jump (Jump 1-2-3 chain), dash and dash hop with a smooth camera, so that moving feels fluid and fast.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: MOVE-01, MOVE-02, MOVE-03, MOVE-04, MOVE-05, MOVE-06, MOVE-07, MOVE-08, MOVE-10, CAM-01, CAM-03, FEEL-06
**Success Criteria** (what must be TRUE):

  1. In a movement gym built from Prototype Bits, the player steers the Mannequin relative to a third-person mouse-look follow camera centered behind the character (shoulder offset only in aim mode, Phase 3), with smooth acceleration and deceleration, at one tunable run speed. The camera follows without jitter at 10 TPS and at 144 Hz, and never clips through walls. Mouse sensitivity and invert-Y can be changed.
  2. Tapping jump gives a lower jump than holding it, and the fall is heavier than the rise. A jump pressed just after leaving a ledge, or just before landing, still fires. Ground jumps chain Jump 1 -> Jump 2 -> Jump 3 (the highest, a pirouette) inside a landing window, and there is no air jump.
  3. The player can dash on the ground and once in the air. The air dash refills on landing, a dash can flow straight into a jump (a long jump whose speed stacks over three stages on clean repeats), and a dash never tunnels through walls.
  4. Moving platforms and conveyors carry the player, and the player keeps their momentum when leaving them. Gym slopes and stairs never make the player stick or launch.
  5. All movement values are live-tunable in one resource. A movement-metrics table (jump height/distance, dash distance) is recorded, and the measured jump and dash input latency meets the 66 ms target (hard limit 100 ms). Movement is signed off without any juice.

**Plans:** 14/14 plans complete

Plans:

- [x] 02-01-PLAN.md — Tracer: camera-relative run and real jump on MovementConfig + PlayerController (single move_and_slide), CameraRig follow, proven by test_ground_movement (wave 1)
- [x] 02-02-PLAN.md — Contracts and docs: camera_recenter + debug actions, new EventBus facts, CONVENTIONS, CLAUDE/STACK camera edits (wave 1)
- [x] 02-03-PLAN.md — Prototype Bits Slope and Beam: copies, collision wrappers, 31-file whitelist, run.sh originals (wave 1)
- [x] 02-04-PLAN.md — Phase 1 tests repaired for real physics, test_dash rename, animator state names, CameraRig in the test scene (wave 2)
- [x] 02-05-PLAN.md — Jump feel: variable height, coyote, buffer, one double jump (wave 2)
- [x] 02-06-PLAN.md — Camera quality: vertical follow band, additive FOV/offset sources, jitter proxy and wall-clipping tests at 10/60 TPS (wave 2)
- [x] 02-07-PLAN.md — Platforms, conveyors, slopes and stairs: MovingPlatform, FallReset, MOVE-08 tests (wave 2)
- [x] 02-08-PLAN.md — LatencyProbe (60/120 TPS, 66 ms target asserted) and F4 MetricsOverlay with F6 tick-rate cycle (wave 3)
- [x] 02-09-PLAN.md — Sprint, ground dash and air dash with cooldown, carry and no tunnelling (wave 3)
- [x] 02-10-PLAN.md — Camera controls: CameraSettings (sensitivity, invert-Y, auto-follow mode auto/on/off), converging device-aware auto-follow, recenter (wave 3)
- [x] 02-11-PLAN.md — Jump chain and long jump: Jump 1 -> Jump 2 -> Dash -> Jump, dash speed carried and capped (wave 4)
- [x] 02-12-PLAN.md — F2 tuning panel: live MovementConfig sliders and camera settings (wave 4)
- [x] 02-13-PLAN.md — Generated docs/MOVEMENT-METRICS.md with asserted latency table and drift guard (wave 5)
- [x] 02-14-PLAN.md — Movement gym as main scene and the end-of-phase sign-off without juice, incl. mandatory 144 Hz check (wave 6)

**Notes**: The camera is a hand-built CameraRig (SpringArm3D), decided in discuss (D-18); Phantom Camera is not used. The camera rig must allow an additive FOV/offset stack, which Phase 11 needs. Measure latency at 60 and at 120 TPS. Here the Mannequin plays the Phase 1 base clips; the full state mapping comes in Phase 3.

### Phase 3: Animated Mannequin & Aim Mode

**Group:** A (Prototyp)
**Goal:** As a player, I want the Mannequin to animate with every move and to blend into an aim mode, so that movement reads clearly and I can aim.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: MOVE-09, MOVE-11, CAM-02
**Success Criteria** (what must be TRUE):

  1. The Mannequin's animation follows every movement state, using Rig_Medium clips (plus the retargeted clips of DEV-04), cuts, blends and procedural rotation/scale. This covers idle, run, jump start/air/land, the Jump 3 pirouette (not started while aiming, DEV-03), the long jump, the ground dash and the held air-dash pose.
  2. Every movement verb in the game is backed by a kit clip or a documented clip composition. Verbs without one, such as wall-run and ledge grab, stay out.
  3. Holding the aim button blends into an aim mode with a crosshair, a tighter FOV and a shoulder offset. In aim mode the Mannequin strafes and walks backwards using kit clips.
  4. The animation changes on the same frame as the movement state, and no clip delays control: there is no landing lock and no anticipation longer than 2 frames. The one exception to the same-frame rule is the presentation-only air-dash pose hold (DEV-02): after an air dash the Dodge pose stays through the fall until landing or until air_dash_hold_time, and it never delays control. The Phase 2 latency numbers still hold.

**Plans:** 10/10 plans complete

Plans:

- [x] 03-01-PLAN.md — Tracer: generated BlendTree animation root (StateMachine, TimeScale, Land OneShot), animator on new paths, migrated path readers; developer decisions DEV-01/DEV-02/DEV-03 and the checkpoint for the remaining defaults (wave 1)
- [x] 03-02-PLAN.md — CombatRanged copy under the 33-entry whitelist; library with aim, strafe, backward and directional dodge clips; Dodge root pinned (wave 2)
- [x] 03-03-PLAN.md — Aim hold in PlayerController: aim_changed fact, camera-locked facing, camera-true steering, aim speed factors (wave 4)
- [x] 03-04-PLAN.md — Aim camera: eased FOV and fixed right-shoulder offset via additive sources, aim sensitivity, no recenter in aim, F2 rows (wave 5)
- [x] 03-05-PLAN.md — Code-drawn crosshair (dot, ring, reserved lock state) in the gym and the test scene (wave 5)
- [x] 03-06-PLAN.md — ProceduralPose on the Mannequin child (DEV-01): ground dash lean into long-jump stretch, Jump 3 / stage 3 pirouette, aim gate and finish cut (DEV-03), metrics label (wave 5)
- [x] 03-07-PLAN.md — Filtered aim layer (Ranged_1H_Aiming), strafe/back blend points, clip time scale, directional aim dashes keeping the air-dash hold (wave 6)
- [x] 03-08-PLAN.md — AimPoseModifier: right arm points at the crosshair at any pitch, torso twist clamped (wave 7)
- [x] 03-09-PLAN.md — docs/ANIMATION-MAP.md with drift guard, CONVENTIONS rules, Jump 3 wording sweep, ROADMAP criterion 4 and notes amendments (DEV-02, DEV-01), CLAUDE.md/STACK.md animation layout, phase regression, full-suite gate and gym check (wave 8)
- [x] 03-10-PLAN.md — Animation timing guard (same frame, no landing lock, 2-frame anticipation) and the air-dash pose hold DEV-02 (wave 3; split out of 03-01 in revision 1)

**UI hint**: yes

### Phase 4: Fernauslöser & Mechanism Kit

**Group:** A (Prototyp)
**Goal:** As a player, I want to aim the Fernauslöser pulse at glowing mechanisms, so that I can solve puzzles from a distance.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: HAND-01, HAND-02, HAND-03, CAM-04, CAM-05, MECH-01, MECH-02, MECH-03
**Success Criteria** (what must be TRUE):

  1. Interactables in range glow turquoise, and the targeted one is clearly highlighted. Light aim assist snaps to the nearest valid interactable near the crosshair without flickering between neighbours.
  2. Firing the Fernauslöser sends a plain turquoise pulse that triggers a lever or valve at range, and the target reacts on the very next frame. An interactable that does not accept the module shows an invalid reticle state and stays unchanged.
  3. In a showcase room plus puzzle rooms built from Prototype Bits, the player solves puzzles with the pulse. The rooms use the D-15 triggers and D-16 mechanisms wired in the editor, including AND, OR and timer logic.
  4. Gears, platforms and conveyors set in motion by the pulse carry the player without sliding, jitter or launching.
  5. A dummy test module can be added with one folder and one registry entry, and it shows up in game without changes to other code. The arm mesh never changes.

**Plans**: 5 plans

Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Tracer: hand module framework + registry (dummy module), Fernauslöser pulse (tap/hold, cooldown, range), Interactable contract, lever + Zahnrad-Tor as the gym door into room 2 (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Targeting with aim assist + sticky aim, shared glow stages, goggle HUD, near contact (E, hold), arm-out, palm glow and pulse streak, F2 Hand section (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04-03-PLAN.md — Handrad-Ventil, Energiekern, Uhrwerk-Kurbel, AND/OR/Timer logic with packed-ref round trip, showcase stations (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 04-04-PLAN.md — Rotation-carry spike as go/no-go gate (all three axes), PlayerController launch/push/knock-back + rotating carry, Dreh-/Hub-Plattform, Förderband, Dampfdüse, Pendel, showcase stations (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 04-05-PLAN.md — Three puzzle rooms with coverage and scripted solve test, pulse wording in REQUIREMENTS/ROADMAP, end-of-phase feel check (wave 5)

**UI hint**: yes
**Notes**: The exact Fernauslöser design is confirmed at the start of the phase. Gears, valves, conveyors and gates are stand-ins built from Prototype Bits primitives. Pulse VFX (flash, sparks, impact ring) come in Phase 12.

### Phase 04.1: Mechanism Kit Extension & HUD Polish (INSERTED)

**Group:** A (Prototyp)
**Goal:** As a player, I want a richer set of steampunk mechanisms that move me (fields, slingshot, wall-run and wall-jump pads, bounce pads, boost rings, wind, low gravity and more) and a clearer hand HUD, so that the showcase reads at a glance and the world itself becomes part of my movement.
**Mode:** mvp
**Depends on:** Phase 4
**Requirements**: MOVE-12 (pulled into scope), MECH-04, MECH-05, CAM-06, HAND-07 (new, see 04.1-CONTEXT.md)
**Success Criteria** (what must be TRUE):

  1. The crosshair is always on screen (small dot/ring when not aiming, the full goggle HUD while aiming), and an "E" prompt floats over the nearest near-contact interactable in range.
  2. The showcase room is split into visible sub-zones with zone headers, and every station sign carries a second line "Erwartet: ..." that states the expected behaviour.
  3. Conveyors carry the player on the belt, and every existing mechanism that should move the player does so through the PlayerController request APIs.
  4. The glow lens on every interactable is a steampunk element (brass bezel or gear ring around a glowing turquoise core) instead of a plain sphere.
  5. Every new mechanism (A-K plus the planner's steampunk extras) has its own showcase station with a lever or self-trigger, moves the player as described, and has a smoke test; wall-run and wall-jump are movement FSM states.

**Plans:** 5/5 plans complete

Plans:

**Wave 1**

- [x] 04.1-01-PLAN.md — Tracer: low-gravity zone end to end (request_gravity_scale, station with "Erwartet:" sign), request APIs for the phase (refill_air_dash, boost_along, lock_air_control), conveyor carry fix with guard test, D-06 influence audit (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04.1-02-PLAN.md — WallRun, WallJump and Capture FSM states with wall pads, Schleuderkern and Rohrpost, scope docs (MOVE-12 into v1, new IDs, HAND-08 renumbering) (wave 2)
- [x] 04.1-03-PLAN.md — Abstoß-/Anziehungsfeld, Windkanal, Sprungpolster, Boost-Ring, Druckplatte, Bröckel-Plattform, Kolbenwand, Druckventil-Geysir, Paternoster (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04.1-04-PLAN.md — Always-on crosshair with aim-only goggle HUD, E near-contact prompt, look pass with steampunk GlowElement styles on every mechanism (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 04.1-05-PLAN.md — Spacious 120 x 72 m showcase with nine zones, all 33 stations with "Erwartet:" signs, puzzle-room shift, room-2 FallReset, coplanar ray guard, D-12 load check and end-of-phase feel check (wave 4)

### Phase 5: Energy Arm & Loader

**Group:** A (Prototyp)
**Goal:** As a player, I want my arm to store energy from speed and to stop, aim and discharge my momentum with the right-click Loader, so that speed turns into energy and energy into more speed.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: HAND-04, FEEL-10, ENRG-01, ENRG-02, ENRG-03, ENRG-04, ENRG-05
**Success Criteria** (what must be TRUE):

  1. The arm holds 0-100 energy in 4 cores of 25, readable on the arm. From 50 the player is in Moto Perpetuo (faster run, buffed Jump 3, brighter arm). After a respawn the arm holds exactly one core (25).
  2. Energy comes in without enemies: passively while moving above about dash exit speed, from energy capsules and broken machines drained with the Extractor module (left-click hold), and very slowly from the charge button.
  3. Base moves stay free and the injected versions cost energy: ground dash free, air dash costs and does not fire when empty; dash hop stage 1 free, stages 2-3 cost; wall run free for about 0.6 s, then costs; jumping off is always free. Without energy the base version fires automatically (except the air dash).
  4. Holding right click freezes and stores momentum in slow motion (about 0.25x, capped about 1.2 s) with a free camera, a charge ring and a dashed trajectory preview; releasing discharges in the view direction at max(stored speed, minimum push) plus a bonus that costs one core. With an empty arm it only redirects, with a cooldown and a grey ring.
  5. Aim mode is gone (goggle HUD, zoom, shoulder offset, aim pose, pull/push); the small always-on crosshair and target aim assist stay. A Loader test room exists and the Loader metrics table (minimum push, bonus, cap, hold time, slow-motion factor, energy rates) is recorded and tuned.

  6. The movement gym is reworked for the new core: aim-mode stations and pull/push leftovers are gone, and a Loader and energy area (charge track, capsules, injected-move stations with energy readout) is added.

**Plans:** 5/5 plans complete

Plans:
**Wave 1**
- [x] 05-01-PLAN.md — Tracer: Loader core end to end (RMB `loader` action, TimeFx time owner, LoaderState, LoaderMath, minimal ArmEnergy bonus spend, real-time camera), then aim mode removed completely (aiming flag and readers, aim fact, goggle HUD, aim camera, wheel zoom, glow stage SHOT_READY, static guard) (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 05-02-PLAN.md — Tracer: Loader room in the gym with double ring and dashed preview sized from metrics and respawn with one core (feel stop), then "geladen" cues (vignette, desaturation, pull-back, hitstop, hum), super jump pitch raise and the FEEL-10 Loader metrics rows (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 05-03-PLAN.md — Tracer: passive charge fills the HUD chambers and the air dash pays or is refused, then hop and wall-run costs with silent fallback, Moto Perpetuo, charge button, and the arm cores, Moto glow and full energy HUD with momentum readout (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 05-04-PLAN.md — Tracer: Extractor drains a capsule (energy source block, module folder, keys 1/2), then the energy-priced projectile shot with hybrid charge and energy payload, stronger snap with bend, energy-gated glow, notched shot ring and broken machine (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 05-05-PLAN.md — Tracer: Zone_Energy charge track and capsule station, then all energy and shot stations with drain plates and capsules next to every shot puzzle, sign rewrite, FEEL-10 energy rows and the design-doc, roadmap and requirements updates (wave 5)

**UI hint**: yes
**Notes**: Rescoped 2026-11-23 from "Pull/Push & Module Unlocks" after the energy-momentum design session. Design source of truth: `docs/GAME-DESIGN.md` sections 1-4. Pull and push are dropped. Module pickup and teaching rooms (HAND-05, HAND-06) and the hand poses (ART-04) move to Phase 6 with the Extractor and Shot modules. The Loader needs a focused prototype first, because it is the highest risk to the core value. Research sources for this phase (see `docs/reference/LECTURE-PRINCIPLES.md` section 4): Swink, *Game Feel* (local full text) for the Loader feel; John Nesky, "50 Game Camera Mistakes" (GDC 2014) for the Loader free camera; Kyle Pittman, "Building a Better Jump" (GDC 2016) for the buffed Moto Perpetuo jump.

### Phase 05.1: Kit Rework (INSERTED)

**Group:** A (Prototyp)
**Goal:** As a level designer, I want the mechanism kit rebuilt as a few logic blocks with attachable components and looks, sorted into steampunk, energy and nature layers, so that the world reads at a glance and new objects are assembled instead of coded.
**Goal (added 2026-11-25, playtest feedback):** As a player, I want energy to be a clock of 12 whole steps that every ability pays from, and a Loader that flies a straight line, so that the costs read at a glance and the arm feels like spending moments of time.
**Mode:** mvp
**Depends on:** Phase 5
**Requirements**: KIT-01, KIT-02, KIT-03, KIT-04, ENRG-06, ENRG-07, ENRG-08, ENRG-09, ENRG-10, EXTR-01 (beam and steps only)
**Success Criteria** (what must be TRUE):

  1. The kit runs on 8 logic blocks (force volume, impulse, catch & launch, timed motion, reaction to load, trigger, energy source, wall surface) and 4 components (receiver, damage/push, amplification, energy cost); each block keeps its values in a `.tres` config and its look in an inherited scene.
  2. Every object of the three layers in `docs/GAME-DESIGN.md` section 6 exists as block + components + look, and the coupling holds: steampunk is free, anything that costs or is amplified shows turquoise, nature never helps the player.
  3. The slingshot core plays exactly like the Loader (same input and timing) in a steampunk look (small brass cage that catches only when Rino is inside, smaller pressure gauge, no trajectory line, steam blast, +1 step); levers, pressure plates, valves and cranks are cut, and energy cores and charge gates are the remaining triggers (no targets, no gates).
  4. The cut stations are removed, the reworked ones replace their old versions, and the showroom is regrouped by layer and role with a station and smoke test per object.
  5. The movement gym is rebuilt around the new kit: one area per layer (steampunk, energy, nature), each object with a station and an "Erwartet:" sign, plus a mixed course that combines the layers.
  6. The energy is a clock of 12 whole steps (HUD clock with hour hand, 4 arm cores of 3 steps, Moto Perpetuo from 6, respawn with 3), and no cost or income anywhere is a fraction or a percentage.
  7. Every ability pays its steps (dash, air dash, dash hop stages, wall run, wall jump, Loader), an unpaid ability does not fire and shows the refusal (clock shake and red flash, arm flicker, klack), and moves that cost steps never charge; income comes from the passive tick, the R key, capsules, machines and steampunk boosters.
  8. The Loader is paid by holding (1-3 steps on a smaller segmented ring, no trajectory line) and flies a straight line with the speed formula own speed + push + steps x (push step + k x own speed) and the overflow-to-distance rule; the camera can look almost straight up everywhere; the Loader field lets a Loader with >= 2 steps glide through with a brake.
  9. The shot, its stations and the gear-disc targets are gone; left click is only the Extractor, with a visible beam; the wall run is diagonal with the head away from the wall.

**Plans**: 22 plans (06 executed + 16 replanned, strictly sequential waves; D-33 deviation stated in 05.1-07-PLAN.md "Plan set notes"). Replanned 2026-11-25 after the playtest decisions D-34..D-58: plans 01-06 stay executed; 07-22 replace the deleted pre-playtest plans 07-20 (order D-58: shot removal and energy clock first, then the Loader, then the remaining kit without targets and gates, mixed course last).

Plans:
- [x] 05.1-01-PLAN.md — Kit skeleton (KitBlock, config pattern, coupling + contract tests) and slingshot as Loader (CAGE source)
- [x] 05.1-02-PLAN.md — Steam cannon FIXED profile (deterministic arc); Capture, pneumatic tube and puzzle rooms removed
- [x] 05.1-03-PLAN.md — Wall surface block, plain/steam looks, head clearance clamp, twin-pad layout fix
- [x] 05.1-04-PLAN.md — Timed motion SWEEP/TILT always on, clock-hand floor-snap / clearance fix, take-off vertical carry
- [x] 05.1-05-PLAN.md — Slingshot presentation (pressure gauge, brass dashes, steam cues) and F2 Kit section
- [x] 05.1-06-PLAN.md — Gym cutover: steampunk / energy / nature layer areas; old rooms, lift, crank, plate deleted
- [x] 05.1-07-PLAN.md — Shot removed (remote_trigger, projectile, targeting, PulseHit, shot signals); module system dormant, Extractor default
- [x] 05.1-08-PLAN.md — Energy clock logic: ArmEnergy int 0..12, passive/R accumulator, every ability paid with refusal, Extractor steps, F2/metrics ints, Energy_Track removed
- [x] 05.1-09-PLAN.md — HUD clock face (hour + second hand), refusal shake/flash/klack, wall run diagonal with the head away from the wall
- [x] 05.1-10-PLAN.md — Extractor beam; Energy source kit block (capsule +3, machine +5) replacing the old scenes in place
- [x] 05.1-11-PLAN.md — Loader paid hold (1-3 steps), speed formula with cap and overflow, straight gravity-free flight, cage on the line, loader_released(steps)
- [x] 05.1-12-PLAN.md — Loader 3-segment smaller ring, smaller crosshair and gauge, camera 89 degrees, Zone_Loader re-derived from 1 vs 3 steps
- [x] 05.1-13-PLAN.md — Reaction to load block: Loader field (>= 2 steps glide through with brake); Zone_Energy shot stations swapped; lever / valve / gear gate cut
- [x] 05.1-14-PLAN.md — Slingshot smaller, catches only inside; steampunk income hook (+1 step, cooldown, GIVES + accent) on slingshot and cannon
- [x] 05.1-15-PLAN.md — Force volume block + nature look pass: updraft, geyser, steam stream, leaf storm, resin pool
- [x] 05.1-16-PLAN.md — Impulse block + Amplification: boost ring, speed pad (conveyors cut), bounce pad, bounce pad with core, gravity zone
- [x] 05.1-17-PLAN.md — Trigger block (SignalSource rename), Receiver, charge gate, drawbridge (HINGE), switched speed pad, timer station
- [x] 05.1-18-PLAN.md — EnergyCost component: energy core pay-in (3/6/9) and attraction-field fast escape; AND / OR stations
- [x] 05.1-19-PLAN.md — Timed motion platforms: paternoster, rail cart, piston steps
- [x] 05.1-20-PLAN.md — DamagePush + player_hit: pendulum, piston wall, steam hammer
- [x] 05.1-21-PLAN.md — Reaction to load nature objects: crumbling platform, collapse, sinking debris, tipping trunk, falling debris, snap bloom
- [x] 05.1-22-PLAN.md — Mixed course, cut-file gate, Kit values in MOVEMENT-METRICS, design-doc sync, human walkthrough
**UI hint**: yes
**Notes**: Design source of truth: `docs/GAME-DESIGN.md` sections 2-6 (since 2026-11-25 also the energy clock, governing rule, Loader and Extractor sections) and `05.1-CONTEXT.md` D-34..D-58. Known fixes: the steam wall jump must feel like the normal wall jump (currently it flings Rino away), the wall run on it runs with the head to the wall, clock-hand platform floor bugs. Final looks are designed in Group B; greybox looks per layer are enough here.

### Phase 6: Extractor, Enemies & Recovery

**Group:** A (Prototyp)
**Goal:** As a player, I want to beat enemies with the Extractor and Loader hits for energy and recover quickly after dying, so that danger feeds the energy loop without frustration.
**Mode:** mvp
**Depends on**: Phase 05.1
**Requirements**: SHOOT-01, SHOOT-02, SHOOT-03, EXTR-01, HAND-05, HAND-06, ART-04, PROG-01, PROG-03, PROG-04
**Success Criteria** (what must be TRUE):

  1. The Extractor (hold, cone in front of the hand, with its beam) also drains enemies at close range for whole steps while the player is vulnerable, next to the capsules and broken machines it already drains. There is no shot (removed in 05.1).
  2. A Loader discharge into an enemy damages it (a Loader hit), so movement and combat connect; Prototype Bits barrels, crates and pipes react visibly to Loader hits. The enemy income is set in whole steps.
  3. 1-2 simple greybox enemy types (small machines turned evil, built from Prototype Bits) patrol, notice the player and attack, and are beaten by the Extractor and Loader hits.
  4. The player has 3-5 health points; health joins the energy clock HUD (diegetic cores on the arm plus a minimal readout). Taking damage is obvious from a kit Hit clip. At 0 health the player respawns at the last checkpoint with 3 steps.
  5. Reaching a checkpoint visibly changes its state and saves progress. After a death or a fall into a kill zone, the player is back in control within about 1 second. The Extractor and the Loader each have a teaching room (safe use, test, twist) and a readable pose from kit clips; module pickup (HAND-05) applies only if a new module is added, the module switch stays dormant otherwise.
  6. The movement gym is extended with an enemy area: training enemies to drain and to hit with the Loader, and a short course that mixes extracting, Loader hits and movement.

**Plans**: TBD
**UI hint**: yes
**Notes**: Rescoped 2026-11-25 (05.1 playtest discuss, `05.1-CONTEXT.md` D-56): the shot is gone, enemies are beaten by the Extractor and Loader hits. Enemy designs are confirmed at the start of the phase. Here a hit shows only through the target's own reaction. Sparks, hit VFX and hit-stop (SHOOT-04) come in Phases 11-12. Added 2026-11-23 (user request): a dash readout belongs in the HUD next to health (dash available, dash-hop long-jump combo stage). Energy is the 12-step clock (`docs/GAME-DESIGN.md` section 3): running and the jump chain are free, every ability costs steps. Design source: `docs/GAME-DESIGN.md` sections 3-5.

### Phase 7: Level Blockout & Game Flow

**Group:** A (Prototyp)
**Goal:** As a player, I want to start from a title screen and play the full prototype level, so that I can experience the whole route.
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: LEVEL-01, LEVEL-02, LEVEL-04, PROG-02, UX-01, UX-02, UX-03
**Success Criteria** (what must be TRUE):

  1. From the title screen, the player starts the game and plays the Prototype Bits level from start to the boss arena gate. The level is built on the grid of the kit pieces.
  2. Each module opens areas the player has already seen locked (lock before key), and both teaching rooms sit on the level route.
  3. Every puzzle can be reset, and no sequence of player actions leaves the player soft-locked.
  4. The pause menu offers resume, restart from checkpoint and quit. The mouse is released while paused and recaptured on resume.
  5. The settings menu changes mouse sensitivity and invert-Y with immediate effect, offers a VSync on/off option and stores the volume. All values persist after a restart.
  6. The level gimmick "charge the level" works: the player feeds energy into the level and mechanisms activate depending on the charge.

**Plans**: TBD
**UI hint**: yes
**Notes**: Gates use the measured movement and Loader metrics plus a margin, and the kit from Phase 05.1. Do a sequence-break pass. Keep the grid compatible with the steampunk kit planned for Phase 10, so pieces swap in place. The volume value drives the audio buses and becomes audible in Phase 14.

### Phase 8: Boss & Ending

**Group:** A (Prototyp)
**Goal:** As a player, I want to defeat an object-boss with Loader discharges, so that the slice has a climax and an ending.
**Mode:** mvp
**Depends on**: Phase 7
**Requirements**: BOSS-01, BOSS-02, BOSS-03, BOSS-04, UX-04
**Success Criteria** (what must be TRUE):

  1. At the end of the level, the player fights one greybox object-boss, an object turned evil by the catastrophe, through 2-3 distinct phases.
  2. Every boss attack is announced by a readable telegraph (pose, motion or colour change, no particles) and followed by a recovery window the player can use.
  3. The boss takes damage only through Loader discharges (and the Extractor) on its weak points, plus arena mechanisms. There is no shot and no separate combat system.
  4. Boss health can be read at a glance from its glowing cores going out.
  5. Defeating the boss leads to an end screen. The whole slice plays from title to ending in the prototype look, and all mechanics are signed off. This closes Group A.

**Plans**: TBD
**UI hint**: yes

### Phase 9: Style Contract & Final Hero

**Group:** B (Produktion)
**Goal:** As a player, I want to play as the final steampunk hero, so that the character matches the game's look.
**Mode:** mvp
**Depends on**: Phase 8
**Requirements**: FOUND-06, ART-01
**Success Criteria** (what must be TRUE):

  1. A style contract exists before any asset is produced. It contains the palette atlas, poly budgets per asset class, the turquoise-only-for-interactables rule, the second accent colour for decoration, the decision on the player's arm-core glow, and a Blender-to-GLB export checklist.
  2. The final Meshy hero, rigid segments on Rig_Medium at about 6-9k tris, replaces the Mannequin in every scene without changes to gameplay code.
  3. All existing clip mappings play correctly on the hero: movement states, aim mode, hand poses, and hit and spawn clips. There is no retargeting and no deformation artefact.
  4. The prosthetic arm is the rigid ArmRight segment and looks the same with every module. In a lineup scene the hero follows the style contract, and the collision capsule, camera framing and movement metrics are unchanged.

**Plans**: TBD
**Notes**: Check the Meshy licence tier before the hero is produced. Use Route A from KAYKIT.md: rig the hero onto Rig_Medium in Blender and keep the Rig_Medium bone names. The style contract comes first in Group B because the hero already needs the palette, the tri budget and the arm-core glow decision. The hero is then the first asset through the export checklist, which proves the pipeline on one asset before the world kit is built in volume.

### Phase 10: Steampunk World Building

**Group:** B (Produktion)
**Goal:** As a player, I want to explore a warm, ruined steampunk world instead of greybox, so that the story reads through the look alone.
**Mode:** mvp
**Depends on**: Phase 9
**Requirements**: ART-02, ART-03, LEVEL-03
**Success Criteria** (what must be TRUE):

  1. The level, the boss arena and the boss are rebuilt with a steampunk prop and environment kit textured from the palette atlas. The kit stays within poly budgets, matches the clean KayKit style and sits on the same grid as the Prototype Bits blockout.
  2. After the swap, every gate, puzzle, reset path and the boss fight work as in the prototype. No new geometry blocks a route or opens a shortcut.
  3. Warm directional light, fog and ambient steam set the mood, and turquoise glow marks only interactables.
  4. A fresh player can tell where the lab is, and that the world was ruined and is now overgrown, with no text, dialogue or cutscenes.

**Plans**: TBD
**Notes**: Model the palette atlas on KayKit's `dungeon_texture.png`. Assets are produced or edited through the Blender MCP. Ambient steam here is atmosphere (vents), not action feedback, which comes in Phases 11-12. Run a first frame-rate check on the target laptop after the swap, so heavy assets show up before the polish pass. Full profiling is in Phase 15.

### Phase 11: Movement & Camera Juice

**Group:** B (Produktion)
**Goal:** As a player, I want every move to give punchy feedback, so that movement feels alive and fast.
**Mode:** mvp
**Depends on**: Phase 10
**Requirements**: FEEL-02, FEEL-04, FEEL-05, FEEL-08
**Success Criteria** (what must be TRUE):

  1. Feedback cues live as data, one per action, each with an empty SFX slot. They react to the gameplay facts from Phase 1, with no changes to gameplay code.
  2. Jump, landing (scaled by fall speed), Jump 3, the long jump stage 3 pirouette, dash and long jump each show visible feedback in cream or amber, never turquoise. The feedback is squash/stretch, dust, a steam ring or a lean, as fits the move.
  3. Dashes, long jumps and hard landings produce FOV kicks and bounded camera shake without roll, and these hold up in the level's tight rooms. Damage taken and hits on enemies and the boss trigger a short hit-stop that freezes the world without stutter.
  4. Juice runs at one fixed, strong level, tuned per cue. There are no juice presets, sliders or toggles. No feedback delays control or changes movement timing.
  5. No effect causes a hitch or jitter, even the first time it fires, at 10 TPS and at 144 Hz.

**Plans**: TBD
**Notes**: Run a 30-minute spike on `Engine.time_scale` x physics interpolation at 10 TPS before building hit-stop. Squash/stretch is composed into the transform of the Mannequin child of VisualRoot, the node ProceduralPose writes since Phase 3 (DEV-01); VisualRoot's yaw stays the facing. Starting values are in GAME-FEEL.md Section 4. Ignore the presets and per-channel toggles described there (user decision). Pool and pre-warm particles. Research sources: Jan Willem Nijman, "The Art of Screenshake" (2013); Jonasson & Purho, "Juice it or lose it" (2012); Swink, *Game Feel* (polish chapters).

### Phase 12: Hand & Combat Juice + Polish

**Group:** B (Produktion)
**Goal:** As a player, I want every hand action and hit to give clear feedback and the whole slice to feel round, so that the game feels great from start to end.
**Mode:** mvp
**Depends on**: Phase 11
**Requirements**: FEEL-03, SHOOT-04, POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):

  1. Loader, Extractor, energy gain and spend, and mechanism activation each show distinct visual feedback: Loader step charge and discharge burst, extract beam, clock and core fill and drain, and the mechanism activation pulse. Module pickup is a clear moment, with a brief freeze and the HUD icon popping in.
  2. Every hit on an object or enemy gives clear feedback: a hit reaction on the next frame, sparks and a short hit-stop. Big moments (module pickup, boss hit, death) feel stronger than small ones (jump, landing).
  3. Movement, camera, both modules, shooting, enemies, mechanisms and the boss are retuned together over full playthroughs. The movement and Loader metrics tables are updated to the final values.
  4. Rough spots found while playing the full slice (stuck spots, unclear moments, timing problems) are logged and fixed. A final playthrough from title to end screen finds none left open.

**Plans**: TBD
**UI hint**: yes
**Notes**: There is no playtest study or questionnaire (user decision). The polish pass walks the catalogue row by row, fills gaps and freezes the final values. It also checks that the gates still match the retuned metrics. Research sources: same juice talks as Phase 11 plus Swink, *Game Feel*.

### Phase 13: Controller Support

**Group:** B (Produktion)
**Goal:** As a player, I want to play the whole slice with a gamepad, so that I can choose my input device.
**Mode:** mvp
**Depends on**: Phase 12
**Requirements**: CTRL-01, CTRL-02
**Success Criteria** (what must be TRUE):

  1. Every action works on a gamepad, including movement, aim, both modules, shooting and menu navigation. Keyboard and mouse keep working.
  2. Stick look turns smoothly, with a dead zone and a response curve that allow both fast turns and precise aiming.
  3. On a gamepad, aim assist makes anchors, mechanisms and enemies about as easy to hit as with the mouse.
  4. The full slice can be completed from title to end screen with a gamepad only.

**Plans**: TBD
**UI hint**: yes

### Phase 14: Audio

**Group:** B (Produktion)
**Goal:** As a player, I want sound and music on every action and moment, so that impacts and the boss fight land fully.
**Mode:** mvp
**Depends on**: Phase 13
**Requirements**: AUDIO-01, AUDIO-02
**Success Criteria** (what must be TRUE):

  1. Movement, hand modules, mechanisms and the boss have sound effects. They are plugged into the catalogue's empty SFX slots with no changes to gameplay code.
  2. The level has music, and the boss fight switches to its own music.
  3. The volume setting audibly changes the sound and music levels.
  4. With sound in, hit-stop and shake are retuned so impacts do not feel overdone.

**Plans**: TBD

### Phase 15: Windows Release & Performance

**Group:** B (Produktion)
**Goal:** As a player, I want to run the game on Windows without Godot, so that I can play it smoothly on a normal laptop.
**Mode:** mvp
**Depends on**: Phase 14
**Requirements**: REL-01, REL-02, REL-03
**Success Criteria** (what must be TRUE):

  1. A standalone Windows build (.exe) starts on a machine without the Godot editor and plays the full slice from title to end screen. Settings and checkpoints save as in the editor build.
  2. The slice is profiled on a weaker machine (for example the uni laptop) and runs smoothly there, at about 60 fps in the level and in the boss fight. The profiling results and fixes are recorded.
  3. Debug tools and overlays (event log, tuning panels, latency logger) are stripped or disabled in the release build and cannot be opened by the player.

**Plans**: TBD
**Notes**: Use export templates that match the pinned Godot 4.7.x. The main performance risks are the particles and juice from Phases 11-12 and the world kit from Phase 10. Pre-warm shaders to avoid first-use hitches.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 04.1 → 5 → 05.1 → 6 → 7 → 8 (end of Group A) → 9 → 10 → 11 → 12 → 13 → 14 → 15

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Prototype Character | 7/7 | Complete    | 2026-11-04 |
| 2. Movement Core & Follow Camera | 14/14 | Complete    | 2026-11-06 |
| 3. Animated Mannequin & Aim Mode | 10/10 | Complete    | 2026-11-20 |
| 4. Fernauslöser & Mechanism Kit | 5/5 | Complete   | 2026-11-23 |
| 5. Energy Arm & Loader | 5/5 | Complete   | 2026-11-24 |
| 05.1. Kit Rework | 22/22 | Complete (UAT pending) | 2026-11-27 |
| 6. Extractor, Enemies & Recovery | 0/TBD | Not started | - |
| 7. Level Blockout & Game Flow | 0/TBD | Not started | - |
| 8. Boss & Ending | 0/TBD | Not started | - |
| 9. Style Contract & Final Hero | 0/TBD | Not started | - |
| 10. Steampunk World Building | 0/TBD | Not started | - |
| 11. Movement & Camera Juice | 0/TBD | Not started | - |
| 12. Hand & Combat Juice + Polish | 0/TBD | Not started | - |
| 13. Controller Support | 0/TBD | Not started | - |
| 14. Audio | 0/TBD | Not started | - |
| 15. Windows Release & Performance | 0/TBD | Not started | - |
