# Requirements: Attimo

**Defined:** 2026-11-02
**Core Value:** Flüssiges, schnelles Bewegungsgefühl — Laufen, Sprint, Sprung und Dash fühlen sich smooth an, und die Hand verbindet sich nahtlos damit.

## v1 Requirements

Requirements for the vertical slice. Each maps to a roadmap phase.

### Foundation & Pipeline

- [ ] **FOUND-01**: Project runs in Godot 4.7.x (pinned) with typed GDScript, Jolt physics, Forward+ and physics interpolation enabled
- [ ] **FOUND-02**: All player input goes through named Input Map actions (KB+M bound now, gamepad slots reserved)
- [ ] **FOUND-03**: Collision layers, groups and folder conventions are fixed and documented
- [ ] **FOUND-04**: Repo hygiene: raw KayKit/VFX packs and reference images are kept out of the main tree (gitignored or LFS), only used assets are imported into `assets/`
- [ ] **FOUND-05**: Meshy placeholder hero is rigged onto KayKit `Rig_Medium` (rigid segments) and plays KayKit Idle/Run/Jump/Dodge clips in Godot
- [ ] **FOUND-06**: Style contract exists: palette atlas, poly budgets per asset class, turquoise = interactable only, second accent colour for decoration, Blender→GLB export checklist

### Movement

- [ ] **MOVE-01**: Player can run with acceleration/deceleration curves and camera-relative steering
- [ ] **MOVE-02**: Player can sprint
- [ ] **MOVE-03**: Player can jump with variable height (release early = lower jump), with heavier fall gravity
- [ ] **MOVE-04**: Coyote time and jump buffering make jumps forgiving
- [ ] **MOVE-05**: Player can double jump once per airtime
- [ ] **MOVE-06**: Player can dash on the ground
- [ ] **MOVE-07**: Player can dash once in the air (resets on landing), and a dash can flow into a jump
- [ ] **MOVE-08**: Player keeps momentum from moving platforms and conveyors, and handles slopes and steps without sticking or launching
- [ ] **MOVE-09**: Player animations follow movement state, built only from the KayKit Rig_Medium kit (clips, cuts, blends, playback speed, procedural root/visual rotation and scale): idle, run (Running_A), sprint (Running_B faster + lean), jump (Jump_Start → Jump_Idle → Jump_Land), double jump (Jump_Start re-cut + procedural flip), ground/air dash (Dodge_Forward, held pose in air), aim-mode strafe (Running_Strafe_L/R, Walking_Backwards)
- [ ] **MOVE-11**: Movement verbs are limited to what the animation kit supports; a new verb needs a kit clip or a clip composition before it is added
- [ ] **MOVE-10**: Movement values live in a tunable resource and are documented in a movement-metrics table (jump height/distance, dash distance)

### Camera & Aim

- [ ] **CAM-01**: Over-the-shoulder third-person camera follows smoothly with mouse look, without jitter and without clipping through walls
- [ ] **CAM-02**: Holding the aim button blends into an aim mode with crosshair, tighter FOV and shoulder offset
- [ ] **CAM-03**: Mouse sensitivity and invert-Y are configurable
- [ ] **CAM-04**: Interactables in range glow turquoise; the targeted one is clearly highlighted
- [ ] **CAM-05**: Light aim assist snaps the target to the nearest valid interactable near the crosshair (with hysteresis)

### Hand Modules

- [ ] **HAND-01**: Hand module framework: a module is a definition resource + behaviour scene; adding a module = one folder + one registry entry; arm mesh never changes
- [ ] **HAND-02**: Interactables declare which modules they accept; modules only talk to the Interactable contract
- [ ] **HAND-03**: Module 1 "Fernauslöser": player aims and fires a turquoise beam that triggers mechanisms at range (exact design confirmed in its phase)
- [ ] **HAND-04**: Module 2 "Pull/Push": player can pull themselves toward an anchor point and carry the momentum on, and can push/repulse with steam (exact design confirmed in its phase)
- [ ] **HAND-05**: Picking up a module is a clear moment (pickup feedback, HUD icon) and unlocks the module permanently
- [ ] **HAND-06**: Each module has a teaching room: safe first use, then a test, then a twist

### Mechanisms & World

- [ ] **MECH-01**: Switches, valves, gears, conveyor belts and doors exist as reusable mechanism components
- [ ] **MECH-02**: Mechanisms are wired via signals in the editor, including simple logic (AND, OR, timer)
- [ ] **MECH-03**: Moving mechanisms (gears, platforms, conveyors) carry the player correctly

### Shooting & Enemies (exact design defined in its phase)

- [ ] **SHOOT-01**: The hand beam can also shoot: hits deal damage/impulse to objects and enemies
- [ ] **SHOOT-02**: Destructible/reactive objects (e.g. barrels, crates, pipes) react to beam hits
- [ ] **SHOOT-03**: 1–2 simple enemy types (e.g. small machines turned evil) with simple behaviour (patrol, notice, attack), defeated by the beam
- [ ] **SHOOT-04**: Hits on objects and enemies give clear feedback (hit reaction, VFX, hit-stop)

### Progression & Health

- [ ] **PROG-01**: Checkpoints save progress; respawn is near-instant
- [ ] **PROG-02**: Every puzzle has a reset path, so the player can never soft-lock
- [ ] **PROG-03**: Player has 3–5 health points shown diegetically or in a minimal HUD; at 0 the player respawns at the last checkpoint
- [ ] **PROG-04**: Falling into a kill zone respawns the player at the last checkpoint

### Level

- [ ] **LEVEL-01**: One vertical-slice level, built on a grid that matches the kit pieces
- [ ] **LEVEL-02**: Level gates paths by ability (lock shown before key), so each module opens previously seen areas
- [ ] **LEVEL-03**: Story is told only through world and look (lab destination visible, ruins, overgrowth), no dialogue or cutscenes

### Boss

- [ ] **BOSS-01**: One object-boss (an object turned evil by the catastrophe) with 2–3 phases
- [ ] **BOSS-02**: Every boss attack is telegraphed and has a recovery window
- [ ] **BOSS-03**: Boss is damaged through the hand modules and arena mechanisms (weak points are interactables), no separate combat system
- [ ] **BOSS-04**: Boss health is readable (e.g. glowing cores going out)

### Feel & Juice

- [ ] **FEEL-01**: Feedback hooks: gameplay events are broadcast so juice can be layered on without touching gameplay code
- [ ] **FEEL-02**: Every movement action has visual/kinetic feedback (landing, jump, double jump, dash, sprint)
- [ ] **FEEL-03**: Every hand action and mechanism activation has visual feedback (beam, impact, pull, push, activation)
- [ ] **FEEL-04**: Camera feedback (trauma-based shake, FOV kick) and hit-stop on impacts, toggleable
- [ ] **FEEL-05**: Juice can be switched on/off globally to compare and evaluate feel

### Art & Look

- [ ] **ART-01**: Final hero from Meshy is integrated (rigid segments on Rig_Medium, KayKit animations, ~6–9k tris)
- [ ] **ART-02**: Steampunk prop/environment kit in the palette atlas, within poly budgets, consistent with KayKit style
- [ ] **ART-03**: Lighting and atmosphere: warm directional light, turquoise emissive glow, fog, steam particles
- [ ] **ART-04**: Hand-module poses are composed from kit clips (pull: Ranged_Magic_Raise upper body over Jump_Idle/Dodge_Forward; push: Ranged_Magic_Shoot/Throw; beam: Ranged_1H_Aiming/Ranged_Magic_Shoot) via AnimationTree upper-body layer, no new clips

### Menus & UX

- [ ] **UX-01**: Title screen to start the game
- [ ] **UX-02**: Pause menu with resume, restart from checkpoint and quit (mouse released while paused)
- [ ] **UX-03**: Settings menu: mouse sensitivity, invert-Y, volume, juice/screenshake toggle
- [ ] **UX-04**: End screen after the boss is defeated

### Audio (last)

- [ ] **AUDIO-01**: Sound effects for movement, hand modules, mechanisms and boss
- [ ] **AUDIO-02**: Music for the level and the boss fight

### Controller (after KB+M is done)

- [ ] **CTRL-01**: Gamepad bindings for all actions
- [ ] **CTRL-02**: Stick look and aim assist tuned for controller

## v2 Requirements

Deferred. Tracked but not in the current roadmap.

### Movement extras

- **MOVE-12**: Wall-run (no kit clip, would need a new animation)
- **MOVE-13**: Ledge grab (no kit clip, would need a new animation)

### Content

- **HAND-07**: Third hand module
- **CONT-01**: Collectibles (hidden gears/cores)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Visual arm swapping per module | Too much work; arm always looks the same, modules are abilities |
| Dialogue and cutscenes | Story is told only through world and look |
| Multiple levels | Vertical slice: one level, one boss |
| Full combat system (weapons, many enemy types, combat arenas) | Only beam shooting + 1–2 simple enemy types; boss is a puzzle boss using modules and mechanisms |
| Skill trees, save slots | Not needed for a slice |
| Localization | Uni prototype |
| Custom animation authoring | Movement and poses come only from the KayKit kit (cuts, blends, procedural tweaks) |

## Traceability

Which phases cover which requirements. Filled during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|

**Coverage:**
- v1 requirements: 63 total
- Mapped to phases: 0
- Unmapped: 63 ⚠️

---
*Requirements defined: 2026-11-02*
*Last updated: 2026-11-02 after initial definition*
