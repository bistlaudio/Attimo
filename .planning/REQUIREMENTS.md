# Requirements: Attimo

**Defined:** 2026-11-02
**Core Value:** Flüssiges, schnelles Bewegungsgefühl — Laufen, Sprungkette, Dash und Dash-Hop fühlen sich smooth an, und die Hand verbindet sich nahtlos damit.

## v1 Requirements

Requirements for the vertical slice. Each maps to a roadmap phase.

### Foundation & Pipeline

- [x] **FOUND-01**: Project runs in Godot 4.7.x (pinned) with typed GDScript, Jolt physics, Forward+ and physics interpolation enabled
- [x] **FOUND-02**: All player input goes through named Input Map actions (KB+M bound now, gamepad slots reserved)
- [x] **FOUND-03**: Collision layers, groups and folder conventions are fixed and documented
- [x] **FOUND-04**: Repo hygiene: raw KayKit/VFX packs stay tracked in the repo root `KayKit/` as a shared reference library, outside the Godot project folder so they are never imported; only used assets are copied into the project's `assets/`
- [x] **FOUND-05**: Prototype uses KayKit Prototype Bits for all greybox geometry and the KayKit Mannequin_Medium (Rig_Medium) as prototype character with KayKit animation clips; no particles/juice VFX in the prototype group
- [ ] **FOUND-06**: Style contract exists: palette atlas, poly budgets per asset class, turquoise = interactable only, second accent colour for decoration, Blender→GLB export checklist

### Movement

- [x] **MOVE-01**: Player can run with acceleration/deceleration curves and camera-relative steering
- [x] **MOVE-02**: Player runs at one tunable run speed (no separate sprint); extra speed comes from the dash and the dash-hop long jump
- [x] **MOVE-03**: Player can jump with variable height (release early = lower jump), with heavier fall gravity
- [x] **MOVE-04**: Coyote time and jump buffering make jumps forgiving
- [x] **MOVE-05**: Ground jumps chain Jump 1 -> Jump 2 -> Jump 3 (the highest; no spin since quick 261127-p64) inside a landing window; there is no air jump, glide, dive or ground-pound
- [x] **MOVE-06**: Player can dash on the ground
- [x] **MOVE-07**: Player can dash once in the air (resets on landing), and a dash can flow into a jump (dash + jump = long jump; clean repeats on landing stack its speed over three stages)
- [x] **MOVE-08**: Player keeps momentum from moving platforms and conveyors, and handles slopes and steps without sticking or launching
- [x] **MOVE-09**: Player animations follow movement state, built from the KayKit Rig_Medium kit plus a few retargeted Mixamo/UAL clips (DEV-04, see docs/ANIMATION-MAP.md) (clips, cuts, blends, playback speed, procedural root/visual rotation and scale): idle, run (Running_A), jump (Jump_Start → Jump_Idle → Jump_Land), the Jump 3 pirouette (one turn about the vertical axis, not started while aiming, DEV-03; Jump_Start re-cut + procedural rotation), ground/air dash (Dodge_Forward, held pose in air), aim-mode strafe (Running_Strafe_L/R, Walking_Backwards)
- [x] **MOVE-11**: Movement verbs are limited to what the animation kit supports; a new verb needs a kit clip or a clip composition before it is added
- [x] **MOVE-10**: Movement values live in a tunable resource and are documented in a movement-metrics table (jump height/distance, dash distance)
- [x] **MOVE-12**: Player can wall-run along glowing wall-run pads and kick off wall-run or wall-jump pads with a wall-jump (pads only, D-09); shown as the run clip plus a roll lean (MOVE-11 composition)

### Camera & Aim

- [ ] **CAM-01**: Third-person follow camera, centered behind the character (shoulder offset only in aim mode), follows smoothly with mouse look, without jitter and without clipping through walls
- [x] **CAM-02**: Holding the aim button blends into an aim mode with crosshair, tighter FOV and shoulder offset
- [x] **CAM-03**: Mouse sensitivity and invert-Y are configurable
- [x] **CAM-04**: Interactables in range glow turquoise; the targeted one is clearly highlighted
- [x] **CAM-05**: Light aim assist snaps the target to the nearest valid interactable near the crosshair (with hysteresis)
- [x] **CAM-06**: The crosshair is always visible (small dot and thin ring outside aim, the full goggle HUD only while aiming), and an "E" key prompt floats over the nearest near-contact interactable in range

### Hand Modules

- [x] **HAND-01**: Hand module framework: a module is a definition resource + behaviour scene; adding a module = one folder + one registry entry; arm mesh never changes
- [x] **HAND-02**: Interactables declare which modules they accept; modules only talk to the Interactable contract
- [x] **HAND-03**: Module 1 "Fernauslöser": player aims and fires a turquoise pulse (tap = small, hold = big) that triggers mechanisms at range
- [x] **HAND-04**: Right-click Loader: holding freezes and stores momentum in slow motion with a free camera, charge ring and trajectory preview; releasing discharges in the view direction (bonus costs one core, empty arm only redirects). Replaces aim mode and Pull/Push (docs/GAME-DESIGN.md section 4)
- [ ] **HAND-05**: Picking up a module is a clear moment (pickup feedback, HUD icon) and unlocks the module permanently
- [ ] **EXTR-01**: Extractor (hold, cone in front of the hand, the only left-click action) drains energy capsules (+3 steps), broken machines (+5 steps) and enemies for energy, with a visible beam from the hand to the source (capsules and machines built in Phase 5, beam and steps in 05.1, enemies in Phase 6)
- [ ] **HAND-06**: Each module has a teaching room: safe first use, then a test, then a twist
- [x] **HAND-07**: Every interactable's glow element is a steampunk primitive element (brass bezel or gear ring around a faceted turquoise core) shaped to fit its mechanic, built from shared primitives and materials; the glow stages still switch on the core

### Mechanisms & World

- [x] **MECH-01**: Levers, hand-wheel valves, energy cores, clockwork cranks, gear gates, rotating and lift platforms, conveyors, steam nozzles and pendulums exist as reusable mechanism components
- [x] **MECH-02**: Mechanisms are wired via signals in the editor, including simple logic (AND, OR, timer)
- [x] **MECH-03**: Moving mechanisms (gears, platforms, conveyors) carry the player correctly
- [x] **MECH-04**: Movement mechanisms exist as reusable components with a showcase station and a smoke test each: repulsor field, attractor field, point-symmetric slingshot core, wall-run pad, wall-jump pad, bounce pad, boost ring, pressure plate, crumbling platform, wind tunnel, low-gravity zone
- [x] **MECH-05**: Steampunk extras: piston punch wall, pneumatic tube, pressure-valve geyser, paternoster (D-11)

### Energy (docs/GAME-DESIGN.md sections 2-3)

- [x] **ENRG-01**: The arm stores 0-100 energy in 4 cores of 25, readable on the arm; from 50 the player is in Moto Perpetuo (faster run, buffed Jump 3, brighter arm); respawn always with one core
- [x] **ENRG-02**: Energy income without enemies: passive charge while moving above about dash exit speed, energy capsules and broken machines, and a slow charge button
- [x] **ENRG-03**: Base moves are free and injected versions cost energy (air dash, dash hop stages 2-3, wall run after the free window); without energy the base version fires automatically, the air dash does not fire
- [x] **ENRG-04**: Removal of aim mode (goggle HUD, zoom, shoulder offset, aim pose, pull/push); the always-on crosshair and target aim assist stay
- [x] **ENRG-05**: Energy HUD top left (diegetic arm cores plus core chambers, Moto Perpetuo state, active module and a momentum readout); health joins it in Phase 6

### Mechanism Kit (docs/GAME-DESIGN.md section 6)

- [x] **KIT-01**: The kit runs on 8 logic blocks and 4 attachable components; values in `.tres` configs, looks as inherited scenes
- [x] **KIT-02**: All objects of the steampunk, energy and nature layers exist as block + components + look, honouring the coupling rule
- [x] **KIT-03**: The slingshot core plays like the Loader in a steampunk look (smaller core, catches only when Rino is inside, no trajectory line, gives +1 step); levers, pressure plates, valves and cranks are cut, and energy cores and charge gates are the remaining triggers (gear-disc targets removed 2026-11-25)
- [x] **ENRG-06**: The energy is a clock of 12 whole steps (no percentages or fractions): HUD clock with hour hand (and a second hand for timed income), the 4 arm cores = 3 steps each, Moto Perpetuo from 6, respawn with 3; costs and income only in whole steps, time only as tick intervals
- [x] **ENRG-07**: Running and the jump chain are free; every ability costs steps (dash and air dash 1, dash hop stages 2/3 +1 each, wall run 2 + 1 every 1 s, wall jump 1, Loader 1-3); an unpaid ability does not fire and always shows the refusal (clock shake and red flash, arm flicker, empty klack sound)
- [x] **ENRG-08**: Income in whole steps: passive clock tick (+1 every 20 s), charge key R (+1 every 10 s), capsule +3, broken machine +5, +1 per steampunk booster use with a cooldown; moves that cost steps never charge (momentum charge removed)
- [x] **ENRG-09**: The Loader is paid by holding (1-3 steps, one segment per step on a smaller ring, no trajectory line) and flies a straight line: speed = own speed + push + steps x (push step + k x own speed), capped, overflow lengthens the straight flight; the camera can look up almost vertically everywhere without flipping backward
- [x] **ENRG-10**: The shot and the gear-disc targets are removed; left click is only the Extractor and the module switch is dormant; the force-field barrier becomes a Loader field that does not break and lets a Loader with >= 2 steps glide through with a brake
- [x] **KIT-04**: Cut stations removed, reworked stations replaced, showroom regrouped by layer and role with a station and smoke test per object

### Shooting & Enemies (exact design defined in its phase)

- [ ] **SHOOT-01**: Enemies are beaten with the Extractor (drain at close range, player vulnerable) and with Loader hits (a discharge into the enemy); there is no shot (removed 2026-11-25); enemy income is paid in whole steps
- [ ] **SHOOT-02**: Destructible/reactive objects (e.g. barrels, crates, pipes) react to Loader hits
- [ ] **SHOOT-03**: 1–2 simple enemy types (e.g. small machines turned evil) with simple behaviour (patrol, notice, attack), defeated by the Extractor and Loader hits
- [ ] **SHOOT-04**: Hits on objects and enemies give clear feedback (hit reaction, VFX, hit-stop)

### Progression & Health

- [ ] **PROG-01**: Checkpoints save progress; respawn is near-instant
- [ ] **PROG-02**: Every puzzle has a reset path, so the player can never soft-lock
- [ ] **PROG-03**: Player has 3–5 health points shown diegetically or in a minimal HUD; at 0 the player respawns at the last checkpoint
- [ ] **PROG-04**: Falling into a kill zone respawns the player at the last checkpoint

### Level

- [ ] **LEVEL-01**: One vertical-slice level, built on a grid that matches the kit pieces
- [ ] **LEVEL-02**: Level gates paths by ability (lock shown before key), so each module opens previously seen areas
- [ ] **LEVEL-04**: Level gimmick "charge the level": the player feeds energy into the level and mechanisms activate depending on the charge
- [ ] **LEVEL-03**: Story is told only through world and look (lab destination visible, ruins, overgrowth), no dialogue or cutscenes

### Boss

- [ ] **BOSS-01**: One object-boss (an object turned evil by the catastrophe) with 2–3 phases
- [ ] **BOSS-02**: Every boss attack is telegraphed and has a recovery window
- [ ] **BOSS-03**: Boss is damaged through Loader discharges (and the Extractor) on its weak points plus arena mechanisms, no shot and no separate combat system
- [ ] **BOSS-04**: Boss health is readable (e.g. glowing cores going out)

### Feel & Juice

- [x] **FEEL-01**: Feedback hooks: gameplay events are broadcast so juice can be layered on without touching gameplay code
- [ ] **FEEL-02**: Every movement action has visual/kinetic feedback (landing, jump, Jump 3, the long jump stage 3 pirouette, dash, long jump)
- [ ] **FEEL-03**: Every hand action and mechanism activation has visual feedback (pulse, impact, pull, push, activation)
- [ ] **FEEL-04**: Camera feedback (trauma-based shake, FOV kick) and hit-stop on impacts
- [ ] **FEEL-05**: Juice is tuned to one fixed, strong level (no presets or toggles)
- [x] **FEEL-06**: Input-to-response latency is measured; target ≤ 66 ms, hard limit 100 ms
- [ ] **FEEL-08**: Juice catalogue lives as data (cues per action with empty SFX slots so audio plugs in last without code changes)
- [x] **FEEL-10**: Loader metrics table (minimum push, bonus, cap, hold time, slow-motion factor, energy rates) documented and tuned

### Polish

- [ ] **POLISH-01**: Polish pass: all mechanics (movement, camera, modules, shooting, enemies, mechanisms, boss) are re-tuned and rounded off together so the whole game feels great
- [ ] **POLISH-02**: Edge cases and rough spots found while playing the full slice are fixed (stuck spots, unclear moments, timing)

### Art & Look

- [ ] **ART-01**: Final Meshy hero replaces the Mannequin: rigged onto KayKit Rig_Medium as rigid segments (~6–9k tris), all existing KayKit clip mappings keep working
- [ ] **ART-02**: Steampunk prop/environment kit in the palette atlas, within poly budgets, consistent with KayKit style
- [ ] **ART-03**: Lighting and atmosphere: warm directional light, turquoise emissive glow, fog, steam particles
- [ ] **ART-04**: Loader and Extractor poses are composed from kit clips via the AnimationTree upper-body layer, no new clips

### Menus & UX

- [ ] **UX-01**: Title screen to start the game
- [ ] **UX-02**: Pause menu with resume, restart from checkpoint and quit (mouse released while paused)
- [ ] **UX-03**: Settings menu: mouse sensitivity, invert-Y, volume
- [ ] **UX-04**: End screen after the boss is defeated

### Audio (last)

- [ ] **AUDIO-01**: Sound effects for movement, hand modules, mechanisms and boss
- [ ] **AUDIO-02**: Music for the level and the boss fight

### Controller (after KB+M is done)

- [ ] **CTRL-01**: Gamepad bindings for all actions
- [ ] **CTRL-02**: Stick look and aim assist tuned for controller

### Release

- [ ] **REL-01**: Game exports as a standalone Windows build (.exe) that runs without the Godot editor
- [ ] **REL-02**: Performance is profiled on a weaker machine (e.g. uni laptop) and the slice runs smoothly there (target 60 fps)
- [ ] **REL-03**: Debug tools/overlays are stripped or disabled in the release build

## v2 Requirements

Deferred. Tracked but not in the current roadmap.

### Movement extras

- **MOVE-13**: Ledge grab (no kit clip, would need a new animation)

### Content

- **HAND-08**: Third hand module
- **CONT-01**: Collectibles (hidden gears/cores)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Visual arm swapping per module | Too much work; arm always looks the same, modules are abilities |
| Dialogue and cutscenes | Story is told only through world and look |
| Multiple levels | Vertical slice: one level, one boss |
| Full combat system (weapons, many enemy types, combat arenas) | No shooting (removed 2026-11-25): Extractor and Loader hits + 1–2 simple enemy types; boss is a puzzle boss using the Loader and mechanisms |
| Skill trees, save slots | Not needed for a slice |
| Localization | Uni prototype |
| Playtest study / questionnaires / consent forms | User decision: just the game, juice tuned to one fixed strong level |
| Custom animation authoring | Movement and poses come only from the KayKit kit (cuts, blends, procedural tweaks) |
| Juice presets, levels or toggles (debug or settings) | No juice levels/toggles (user decision) |
| Reduce-motion option (was FEEL-07) | No juice levels/toggles (user decision) |
| Readable-with-juice-off guarantee (was FEEL-11) | No juice levels/toggles (user decision) |

## Traceability

Which phases cover which requirements. Group A (Prototyp) = Phases 1-8, Group B (Produktion) = Phases 9-15.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 9 | Pending |
| MOVE-01 | Phase 2 | Complete |
| MOVE-02 | Phase 2 | Complete |
| MOVE-03 | Phase 2 | Complete |
| MOVE-04 | Phase 2 | Complete |
| MOVE-05 | Phase 2 | Complete |
| MOVE-06 | Phase 2 | Complete |
| MOVE-07 | Phase 2 | Complete |
| MOVE-08 | Phase 2 | Complete |
| MOVE-09 | Phase 3 | Complete |
| MOVE-10 | Phase 2 | Complete |
| MOVE-11 | Phase 3 | Complete |
| MOVE-12 | Phase 04.1 | Complete |
| CAM-01 | Phase 2 | Pending (144 Hz judder check not verified; accepted override, see 02-VERIFICATION.md) |
| CAM-02 | Phase 3 | Complete |
| CAM-03 | Phase 2 | Complete |
| CAM-04 | Phase 4 | Complete |
| CAM-05 | Phase 4 | Complete |
| CAM-06 | Phase 04.1 | Complete |
| HAND-01 | Phase 4 | Complete |
| HAND-02 | Phase 4 | Complete |
| HAND-03 | Phase 4 | Complete |
| HAND-04 | Phase 5 | Complete |
| HAND-05 | Phase 6 | Pending |
| HAND-06 | Phase 6 | Pending |
| EXTR-01 | Phase 05.1 (beam and whole-step income from capsules and machines) + Phase 6 (enemies) | Partial (05.1 part built in 05.1-08 / 05.1-10, closed in 05.1-22 pending UAT; enemy part pending in Phase 6) |
| ENRG-01 | Phase 5 | Complete |
| ENRG-02 | Phase 5 | Complete |
| ENRG-03 | Phase 5 | Complete |
| ENRG-04 | Phase 5 | Complete |
| ENRG-05 | Phase 5 | Complete |
| KIT-01 | Phase 05.1 | Complete |
| KIT-02 | Phase 05.1 | Complete |
| KIT-03 | Phase 05.1 | Complete |
| KIT-04 | Phase 05.1 | Complete |
| ENRG-06 | Phase 05.1 | Complete |
| ENRG-07 | Phase 05.1 | Complete |
| ENRG-08 | Phase 05.1 | Complete |
| ENRG-09 | Phase 05.1 | Complete |
| ENRG-10 | Phase 05.1 | Complete |
| HAND-07 | Phase 04.1 | Complete |
| MECH-01 | Phase 4 | Complete |
| MECH-02 | Phase 4 | Complete |
| MECH-03 | Phase 4 | Complete |
| MECH-04 | Phase 04.1 | Complete |
| MECH-05 | Phase 04.1 | Complete |
| SHOOT-01 | Phase 6 | Pending |
| SHOOT-02 | Phase 6 | Pending |
| SHOOT-03 | Phase 6 | Pending |
| SHOOT-04 | Phase 12 | Pending |
| PROG-01 | Phase 6 | Pending |
| PROG-02 | Phase 7 | Pending |
| PROG-03 | Phase 6 | Pending |
| PROG-04 | Phase 6 | Pending |
| LEVEL-01 | Phase 7 | Pending |
| LEVEL-02 | Phase 7 | Pending |
| LEVEL-04 | Phase 7 | Pending |
| LEVEL-03 | Phase 10 | Pending |
| BOSS-01 | Phase 8 | Pending |
| BOSS-02 | Phase 8 | Pending |
| BOSS-03 | Phase 8 | Pending |
| BOSS-04 | Phase 8 | Pending |
| FEEL-01 | Phase 1 | Complete |
| FEEL-02 | Phase 11 | Pending |
| FEEL-03 | Phase 12 | Pending |
| FEEL-04 | Phase 11 | Pending |
| FEEL-05 | Phase 11 | Pending |
| FEEL-06 | Phase 2 | Complete |
| FEEL-08 | Phase 11 | Pending |
| FEEL-10 | Phase 5 | Complete |
| POLISH-01 | Phase 12 | Pending |
| POLISH-02 | Phase 12 | Pending |
| ART-01 | Phase 9 | Pending |
| ART-02 | Phase 10 | Pending |
| ART-03 | Phase 10 | Pending |
| ART-04 | Phase 6 | Pending |
| UX-01 | Phase 7 | Pending |
| UX-02 | Phase 7 | Pending |
| UX-03 | Phase 7 | Pending |
| UX-04 | Phase 8 | Pending |
| AUDIO-01 | Phase 14 | Pending |
| AUDIO-02 | Phase 14 | Pending |
| CTRL-01 | Phase 13 | Pending |
| CTRL-02 | Phase 13 | Pending |
| REL-01 | Phase 15 | Pending |
| REL-02 | Phase 15 | Pending |
| REL-03 | Phase 15 | Pending |

**Coverage:**
- v1 requirements: 87 total
- Mapped to phases: 87
- Unmapped: 0 ✓

---
*Requirements defined: 2026-11-02*
*Last updated: 2026-11-25 after the 05.1 playtest-feedback discuss (ENRG-06..10 added for 05.1; EXTR-01, KIT-03, SHOOT-01..03, BOSS-03, ART-04 reworded: energy clock in steps, shot and targets removed). Earlier: 2026-11-24 after Phase 5 plan 05-05 (EXTR-01 marked as partly built in Phase 5: module, capsules and machines; ENRG-05 confirmed in Phase 5). Earlier: 2026-11-23 after the energy-momentum rework (Phase 5 rescoped to Energy Arm & Loader, Phase 05.1 Kit Rework inserted; HAND-04, FEEL-10, ART-04, SHOOT-01, BOSS-03 reworded; ENRG-01..05, EXTR-01, KIT-01..04, LEVEL-04 added; source docs/GAME-DESIGN.md)*
