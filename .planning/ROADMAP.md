# Roadmap: Attimo

## Overview

The roadmap has two groups. **Group A: Prototyp** (Phases 1-8) builds every mechanic as a vertical, playable slice. It uses only KayKit Prototype Bits for geometry and the KayKit Mannequin_Medium with its Rig_Medium clips as the character. There are no particles and no juice. Group A ends when the whole slice plays from title screen to end screen and all mechanics are right. **Group B: Produktion** (Phases 9-15) then turns the prototype into the real game. First come the style contract and the final Meshy hero. Next the steampunk kit is built and the world is rebuilt with it. Then two juice phases add feedback to every action and finish with a polish pass over the whole slice. Controller support, audio and the Windows release come last, in that order.

**Rules for every phase:**
- Every phase ends with something playable.
- **Group A only:** All geometry comes from KayKit Prototype Bits. Shapes the kit lacks (gears, valves, conveyors, enemies, the boss) are stand-ins built from Prototype Bits pieces. The character is the KayKit Mannequin_Medium on Rig_Medium. No particles, no juice VFX, no camera juice and no Meshy work. Feedback that carries information is part of the mechanic and is allowed: interactable glow, reticle states, HUD, the plain beam and rope lines.
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
- [ ] **Phase 2: Movement Core & Follow Camera** - Run, sprint, variable jump, double jump, ground and air dash, platforms, and a jitter-free mouse-look camera, signed off without juice
- [ ] **Phase 3: Animated Mannequin & Aim Mode** - The Mannequin animates with every movement state from kit clips, plus aim mode with crosshair
- [ ] **Phase 4: Fernauslöser & Mechanism Kit** - Hand module framework, turquoise highlight with aim assist, Module 1 remote-trigger beam, and greybox switches, valves, gears, conveyors, doors and logic
- [ ] **Phase 5: Pull/Push & Module Unlocks** - Module 2 with a momentum test room, module pickup, hand poses from kit clips, and a teaching room per module
- [ ] **Phase 6: Shooting, Enemies & Recovery** - Beam shooting at reactive Prototype Bits objects, 1-2 greybox enemy types, player health, checkpoints and near-instant respawn
- [ ] **Phase 7: Level Blockout & Game Flow** - The full Prototype Bits level with ability gating and reset paths, plus title, pause and settings menus
- [ ] **Phase 8: Boss & Ending** - A greybox object-boss with 2-3 telegraphed phases, beaten through hand modules and arena mechanisms, followed by the end screen

### Group B: Produktion (Phases 9-15)

- [ ] **Phase 9: Style Contract & Final Hero** - Style contract first, then the final Meshy hero on Rig_Medium replaces the Mannequin
- [ ] **Phase 10: Steampunk World Building** - Steampunk prop/environment kit, the level, arena and boss rebuilt with it, warm lighting, fog and steam, and storytelling through the world alone
- [ ] **Phase 11: Movement & Camera Juice** - Data-driven cue catalogue, squash/stretch, dust and steam on every move, FOV kicks, camera shake and hit-stop at one fixed, strong level
- [ ] **Phase 12: Hand & Combat Juice + Polish** - Feedback for beam, pull, push, mechanisms and hits, then a polish pass that retunes all mechanics together and fixes rough spots
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
**Notes**: Re-verify Godot 4.7.x and addon compatibility. The Mannequin sits under a VisualRoot node with its pivot at the feet. The procedural flip and lean (Phase 3), the final hero (Phase 9) and squash/stretch (Phase 11) all reuse this node. The fact bus is the only feedback hook built in Group A (FEEL-01). It is laid now so that the juice and audio phases need no edits to gameplay code. The cue catalogue itself (FEEL-08) waits for Phase 11. No Meshy work happens here.

### Phase 2: Movement Core & Follow Camera
**Group:** A (Prototyp)
**Goal:** As a player, I want to run, sprint, jump, double jump and dash with a smooth camera, so that moving feels fluid and fast.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: MOVE-01, MOVE-02, MOVE-03, MOVE-04, MOVE-05, MOVE-06, MOVE-07, MOVE-08, MOVE-10, CAM-01, CAM-03, FEEL-06
**Success Criteria** (what must be TRUE):
  1. In a movement gym built from Prototype Bits, the player steers the Mannequin relative to a third-person mouse-look follow camera centered behind the character (shoulder offset only in aim mode, Phase 3), with smooth acceleration and deceleration, and can sprint. The camera follows without jitter at 10 TPS and at 144 Hz, and never clips through walls. Mouse sensitivity and invert-Y can be changed.
  2. Tapping jump gives a lower jump than holding it, and the fall is heavier than the rise. A jump pressed just after leaving a ledge, or just before landing, still fires. Exactly one double jump is available per airtime.
  3. The player can dash on the ground and once in the air. The air dash refills on landing, a dash can flow straight into a jump, and a dash never tunnels through walls.
  4. Moving platforms and conveyors carry the player, and the player keeps their momentum when leaving them. Gym slopes and stairs never make the player stick or launch.
  5. All movement values are live-tunable in one resource. A movement-metrics table (jump height/distance, dash distance) is recorded, and the measured jump and dash input latency meets the 66 ms target (hard limit 100 ms). Movement is signed off without any juice.
**Plans:** 5/14 plans executed

Plans:
- [x] 02-01-PLAN.md — Tracer: camera-relative run and real jump on MovementConfig + PlayerController (single move_and_slide), CameraRig follow, proven by test_ground_movement (wave 1)
- [x] 02-02-PLAN.md — Contracts and docs: camera_recenter + debug actions, new EventBus facts, CONVENTIONS, CLAUDE/STACK camera edits (wave 1)
- [x] 02-03-PLAN.md — Prototype Bits Slope and Beam: copies, collision wrappers, 31-file whitelist, run.sh originals (wave 1)
- [x] 02-04-PLAN.md — Phase 1 tests repaired for real physics, test_dash rename, animator state names, CameraRig in the test scene (wave 2)
- [x] 02-05-PLAN.md — Jump feel: variable height, coyote, buffer, one double jump (wave 2)
- [ ] 02-06-PLAN.md — Camera quality: vertical follow band, additive FOV/offset sources, jitter proxy and wall-clipping tests at 10/60 TPS (wave 2)
- [ ] 02-07-PLAN.md — Platforms, conveyors, slopes and stairs: MovingPlatform, FallReset, MOVE-08 tests (wave 2)
- [ ] 02-08-PLAN.md — LatencyProbe (60/120 TPS, 66 ms target asserted) and F4 MetricsOverlay with F6 tick-rate cycle (wave 3)
- [ ] 02-09-PLAN.md — Sprint, ground dash and air dash with cooldown, carry and no tunnelling (wave 3)
- [ ] 02-10-PLAN.md — Camera controls: CameraSettings (sensitivity, invert-Y, auto-follow mode auto/on/off), converging device-aware auto-follow, recenter (wave 3)
- [ ] 02-11-PLAN.md — Jump chain and long jump: Jump 1 -> Jump 2 -> Dash -> Jump, dash speed carried and capped (wave 4)
- [ ] 02-12-PLAN.md — F2 tuning panel: live MovementConfig sliders and camera settings (wave 4)
- [ ] 02-13-PLAN.md — Generated docs/MOVEMENT-METRICS.md with asserted latency table and drift guard (wave 5)
- [ ] 02-14-PLAN.md — Movement gym as main scene and the end-of-phase sign-off without juice, incl. mandatory 144 Hz check (wave 6)
**Notes**: The camera is a hand-built CameraRig (SpringArm3D), decided in discuss (D-18); Phantom Camera is not used. The camera rig must allow an additive FOV/offset stack, which Phase 11 needs. Measure latency at 60 and at 120 TPS. Here the Mannequin plays the Phase 1 base clips; the full state mapping comes in Phase 3.

### Phase 3: Animated Mannequin & Aim Mode
**Group:** A (Prototyp)
**Goal:** As a player, I want the Mannequin to animate with every move and to blend into an aim mode, so that movement reads clearly and I can aim.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: MOVE-09, MOVE-11, CAM-02
**Success Criteria** (what must be TRUE):
  1. The Mannequin's animation follows every movement state, using only Rig_Medium clips, cuts, blends and procedural rotation/scale. This covers idle, run, sprint with lean, jump start/air/land, the double-jump flip, the ground dash and the held air-dash pose.
  2. Every movement verb in the game is backed by a kit clip or a documented clip composition. Verbs without one, such as wall-run and ledge grab, stay out.
  3. Holding the aim button blends into an aim mode with a crosshair, a tighter FOV and a shoulder offset. In aim mode the Mannequin strafes and walks backwards using kit clips.
  4. The animation changes on the same frame as the movement state, and no clip delays control: there is no landing lock and no anticipation longer than 2 frames. The Phase 2 latency numbers still hold.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Fernauslöser & Mechanism Kit
**Group:** A (Prototyp)
**Goal:** As a player, I want to aim the Fernauslöser beam at glowing mechanisms, so that I can solve puzzles from a distance.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: HAND-01, HAND-02, HAND-03, CAM-04, CAM-05, MECH-01, MECH-02, MECH-03
**Success Criteria** (what must be TRUE):
  1. Interactables in range glow turquoise, and the targeted one is clearly highlighted. Light aim assist snaps to the nearest valid interactable near the crosshair without flickering between neighbours.
  2. Firing the Fernauslöser draws a plain turquoise beam that triggers a switch or valve at range, and the target reacts on the very next frame. An interactable that does not accept the module shows an invalid reticle state and stays unchanged.
  3. In a sandbox puzzle room built from Prototype Bits, the player solves a puzzle with the beam. The room uses switches, valves, gears, conveyor belts and doors wired in the editor, including AND, OR and timer logic.
  4. Gears, platforms and conveyors set in motion by the beam carry the player without sliding, jitter or launching.
  5. A dummy test module can be added with one folder and one registry entry, and it shows up in game without changes to other code. The arm mesh never changes.
**Plans**: TBD
**UI hint**: yes
**Notes**: The exact Fernauslöser design is confirmed at the start of the phase. Gears, valves and conveyors are stand-ins built from Prototype Bits primitives; doors use the kit's Door pieces. Beam VFX (flash, sparks, impact ring) come in Phase 12.

### Phase 5: Pull/Push & Module Unlocks
**Group:** A (Prototyp)
**Goal:** As a player, I want to pick up Pull/Push and zip to anchors with momentum, so that the hand becomes part of my movement.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: HAND-04, HAND-05, HAND-06, FEEL-10, ART-04
**Success Criteria** (what must be TRUE):
  1. The player can pull themselves toward an anchor and fly on with the carried momentum, with a plain rope line to the anchor. The player can also push. The exact push use (objects, self-push, or both) is confirmed at the start of the phase.
  2. A momentum test room exists, and the pull metrics table (range, speed cap, carry-over, release boost) is recorded and tuned. Pulling into a wall at maximum speed never tunnels or gets stuck.
  3. Beam, pull and push each show a readable Mannequin pose, composed from kit clips on an upper-body layer.
  4. Picking up a module plays the kit PickUp clip and shows the module's HUD icon. The module then stays unlocked for good and cannot be used before pickup.
  5. Each module has a teaching room: safe first use, then a test, then a twist. A fresh player gets through each room without any text.
**Plans**: TBD
**UI hint**: yes
**Notes**: Needs a focused pull/push prototype first, because the literature is thin and this is the highest risk to the core value. Starting values are in GAME-FEEL.md Section 5. The hand poses (ART-04) are built here on the Mannequin, not in Phase 9, for two reasons. First, the Mannequin and the final hero share Rig_Medium, so the poses carry over unchanged. Second, building them now checks that each module design fits the kit clips while the design is still cheap to change. The steam cone, rope ripple, hook sparks and pickup freeze come in Phase 12.

### Phase 6: Shooting, Enemies & Recovery
**Group:** A (Prototyp)
**Goal:** As a player, I want to shoot objects and enemies and recover quickly after dying, so that danger has stakes without frustration.
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: SHOOT-01, SHOOT-02, SHOOT-03, PROG-01, PROG-03, PROG-04
**Success Criteria** (what must be TRUE):
  1. Beam shots hit Prototype Bits barrels, crates and targets, and these react visibly (tip, burst into pieces or break).
  2. 1-2 simple greybox enemy types (small machines turned evil, built from Prototype Bits) patrol, notice the player and attack. The beam defeats them.
  3. The player has 3-5 health points, shown in a minimal HUD or diegetically. Taking damage is obvious from a kit Hit clip and the health display. At 0 health the player respawns at the last checkpoint.
  4. Reaching a checkpoint visibly changes its state and saves progress, including unlocked modules. After a death or a fall into a kill zone, the player is back in control at the checkpoint within about 1 second.
**Plans**: TBD
**UI hint**: yes
**Notes**: The exact shooting and enemy designs are confirmed at the start of the phase. Here a hit shows only through the target's own reaction. Sparks, hit VFX and hit-stop (SHOOT-04) come in Phases 11-12.

### Phase 7: Level Blockout & Game Flow
**Group:** A (Prototyp)
**Goal:** As a player, I want to start from a title screen and play the full prototype level, so that I can experience the whole route.
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: LEVEL-01, LEVEL-02, PROG-02, UX-01, UX-02, UX-03
**Success Criteria** (what must be TRUE):
  1. From the title screen, the player starts the game and plays the Prototype Bits level from start to the boss arena gate. The level is built on the grid of the kit pieces.
  2. Each module opens areas the player has already seen locked (lock before key), and both teaching rooms sit on the level route.
  3. Every puzzle can be reset, and no sequence of player actions leaves the player soft-locked.
  4. The pause menu offers resume, restart from checkpoint and quit. The mouse is released while paused and recaptured on resume.
  5. The settings menu changes mouse sensitivity and invert-Y with immediate effect and stores the volume. All values persist after a restart.
**Plans**: TBD
**UI hint**: yes
**Notes**: Gates use the measured movement and pull metrics plus a margin. Do a sequence-break pass. Keep the grid compatible with the steampunk kit planned for Phase 10, so pieces swap in place. The volume value drives the audio buses and becomes audible in Phase 14.

### Phase 8: Boss & Ending
**Group:** A (Prototyp)
**Goal:** As a player, I want to defeat an object-boss using my hand modules, so that the slice has a climax and an ending.
**Mode:** mvp
**Depends on**: Phase 7
**Requirements**: BOSS-01, BOSS-02, BOSS-03, BOSS-04, UX-04
**Success Criteria** (what must be TRUE):
  1. At the end of the level, the player fights one greybox object-boss, an object turned evil by the catastrophe, through 2-3 distinct phases.
  2. Every boss attack is announced by a readable telegraph (pose, motion or colour change, no particles) and followed by a recovery window the player can use.
  3. The boss takes damage only when the player hits its weak-point interactables with hand modules or arena mechanisms. There is no separate combat system.
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
  2. Jump, landing (scaled by fall speed), double jump, dash and sprint each show visible feedback in cream or amber, never turquoise. The feedback is squash/stretch, dust, a steam ring or a lean, as fits the move.
  3. Sprint, dashes and hard landings produce FOV kicks and bounded camera shake without roll, and these hold up in the level's tight rooms. Damage taken and hits on enemies and the boss trigger a short hit-stop that freezes the world without stutter.
  4. Juice runs at one fixed, strong level, tuned per cue. There are no juice presets, sliders or toggles. No feedback delays control or changes movement timing.
  5. No effect causes a hitch or jitter, even the first time it fires, at 10 TPS and at 144 Hz.
**Plans**: TBD
**Notes**: Run a 30-minute spike on `Engine.time_scale` x physics interpolation at 10 TPS before building hit-stop. Squash/stretch runs on the VisualRoot from Phase 1. Starting values are in GAME-FEEL.md Section 4. Ignore the presets and per-channel toggles described there (user decision). Pool and pre-warm particles.

### Phase 12: Hand & Combat Juice + Polish
**Group:** B (Produktion)
**Goal:** As a player, I want every hand action and hit to give clear feedback and the whole slice to feel round, so that the game feels great from start to end.
**Mode:** mvp
**Depends on**: Phase 11
**Requirements**: FEEL-03, SHOOT-04, POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):
  1. Beam, pull, push and mechanism activation each show distinct visual feedback: beam flash and impact, an amber rope and hook, a steam cone, and the mechanism activation pulse. Module pickup is a clear moment, with a brief freeze and the HUD icon popping in.
  2. Every hit on an object or enemy gives clear feedback: a hit reaction on the next frame, sparks and a short hit-stop. Big moments (module pickup, boss hit, death) feel stronger than small ones (jump, landing).
  3. Movement, camera, both modules, shooting, enemies, mechanisms and the boss are retuned together over full playthroughs. The movement and pull metrics tables are updated to the final values.
  4. Rough spots found while playing the full slice (stuck spots, unclear moments, timing problems) are logged and fixed. A final playthrough from title to end screen finds none left open.
**Plans**: TBD
**UI hint**: yes
**Notes**: There is no playtest study or questionnaire (user decision). The polish pass walks the catalogue row by row, fills gaps and freezes the final values. It also checks that the gates still match the retuned metrics.

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
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (end of Group A) → 9 → 10 → 11 → 12 → 13 → 14 → 15

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Prototype Character | 7/7 | Complete    | 2026-11-04 |
| 2. Movement Core & Follow Camera | 5/14 | In Progress | - |
| 3. Animated Mannequin & Aim Mode | 0/TBD | Not started | - |
| 4. Fernauslöser & Mechanism Kit | 0/TBD | Not started | - |
| 5. Pull/Push & Module Unlocks | 0/TBD | Not started | - |
| 6. Shooting, Enemies & Recovery | 0/TBD | Not started | - |
| 7. Level Blockout & Game Flow | 0/TBD | Not started | - |
| 8. Boss & Ending | 0/TBD | Not started | - |
| 9. Style Contract & Final Hero | 0/TBD | Not started | - |
| 10. Steampunk World Building | 0/TBD | Not started | - |
| 11. Movement & Camera Juice | 0/TBD | Not started | - |
| 12. Hand & Combat Juice + Polish | 0/TBD | Not started | - |
| 13. Controller Support | 0/TBD | Not started | - |
| 14. Audio | 0/TBD | Not started | - |
| 15. Windows Release & Performance | 0/TBD | Not started | - |
