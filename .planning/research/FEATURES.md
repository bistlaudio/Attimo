# Feature Landscape

**Domain:** 3D third-person action-platformer with an upgradeable tool (prosthetic steampunk hand, swappable ability modules), Metroidvania-lite gating, one level + one object-boss (university vertical slice, Godot 4)
**Researched:** 2026-11-02
**Overall confidence:** MEDIUM (feel numbers and genre conventions are well established from practitioner sources and genre knowledge; no authoritative playtest data. Web sources are mostly blog and community pages, so they are treated as MEDIUM/LOW and cross-checked against genre experience.)

**Locked decision (2026-11-02, from user):** The prosthetic arm looks the same at all times. Hand modules are PURE ABILITIES: an input, a gameplay effect and a VFX/SFX signature. There are NO visual arm swaps, no per-module arm meshes, no attach/detach animations. Consequences are folded into the module framework below (cheaper art, simpler rigging, identity carried by VFX color/shape, HUD icon and sound instead of geometry).

**Module definitions are NOT fixed.** The module SYSTEM is researched as a framework. Candidate modules appear only as options to be chosen per phase.

---

## Table Stakes

Features players expect. Missing = the slice feels like a tech demo, not a polished platformer. Core Value of the project (fluid, fast movement connected seamlessly to the hand) means the movement and camera rows are non-negotiable.

### A. Movement game feel (Core Value, highest priority)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Camera-relative run with acceleration/deceleration curves | Instant velocity changes feel stiff; weighty-but-snappy ramp is the baseline of A Hat in Time, Astro Bot | Med | Separate ground accel, ground friction, air accel. Tune on `CharacterBody3D.velocity`, not by setting velocity directly. Character turns toward move direction with fast but non-instant rotation (about 0.08-0.12 s) |
| Sprint (hold or auto-sprint past stick/key threshold) | Named in PROJECT.md; "fast" is Core Value | Low | On keyboard, hold Shift. Sprint should also widen camera FOV slightly (speed feedback) |
| Jump with variable height (cut upward velocity on button release) | Tap=hop, hold=full jump is universal in the genre | Low | Cut factor about 0.4-0.5 on release while ascending. Communicates control precision |
| Asymmetric gravity (heavier on the way down) | Removes floatiness; define jump by apex height + time-to-apex, derive gravity | Low | Fall gravity about 1.5-2x rise gravity, plus terminal velocity cap |
| Coyote time | Without it, ledge jumps feel broken (sources agree) | Low | Start 0.10-0.15 s; community values range 0.1-0.2 s. Make it an exported tunable |
| Jump buffering | Presses just before landing must not be eaten | Low | Start 0.10-0.15 s. Same buffer should apply to dash and (later) hand-trigger input |
| Air control | Players correct mid-air; no-air-control feels like a 90s platformer | Low | Air accel about 60-80% of ground accel; allow turning but cap air speed |
| Dash (ground and air, short cooldown, i-frames optional) | Named in PROJECT.md; defines the "fast" feel | Med | One air dash per airtime reset on landing. Fixed duration and distance (not physics-driven) for predictability. Must be cancel-able into jump (dash-jump) for flow |
| Ground detection robustness (slopes, ledges, stairs, moving platforms) | Conveyor belts and rotating gears ARE the level, so the controller must inherit platform velocity | Med-High | `CharacterBody3D` floor snap, `floor_max_angle`, platform velocity inheritance. This is a hidden table stake because mechanisms are the world |
| Ledge forgiveness (edge nudge / step-up) | Missed jumps by a pixel are the top 3D frustration | Med | Small corner correction when head bonks; step-up for low obstacles |
| Landing feedback: squash/stretch, dust puff, footstep SFX, landing sound scaled to fall height | Players "feel" the ground via these; cheap, huge payoff | Low | Squash is a mesh scale tween (chibi proportions make it read well). Brief camera dip on hard landings |
| Animation set matching movement: idle, run, sprint, jump up/apex/fall, land, dash, hand-trigger pose | Animation-state mismatch kills perceived responsiveness | Med | Blend tree driven by speed and vertical velocity. Meshy character needs a usable rig (see Pitfalls/asset pipeline) |
| Responsive input via Input Actions (rebindable names, no hard-coded keys) | Project constraint; controller later | Low | Define actions up front: move, sprint, jump, dash, aim, trigger, interact, pause, camera. Consumes zero extra effort now, saves the controller phase |

### B. Camera and aiming

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Orbit third-person camera with mouse look | Baseline for every reference game | Low-Med | `SpringArm3D` pivot rig; clamp pitch; mouse sensitivity setting |
| Camera collision (no clipping through walls) | A clipping camera ruins presentation in tight ruins | Low-Med | `SpringArm3D` with collision mask; also fade or ignore thin props and foliage. Mask tuning on steam and foliage is an easy bug source |
| Over-the-shoulder aim mode: hold to aim, FOV zoom, camera shifts to shoulder, crosshair shown | Named in PROJECT.md. Ratchet & Clank, Control, Kena use this pattern | Med | Smooth blend (about 0.15-0.25 s) between explore and aim camera offsets; character faces camera direction in aim mode; reduced move speed and no sprint while aiming (keeps dash as the escape) |
| Smooth camera follow with vertical damping | Prevents nausea when jumping; keeps player visible while falling | Med | Vertical lag/"platform snapping" idea from 3D platformers: camera does not chase every jump, resets on landing |
| Camera recenter / look-ahead in movement direction (optional toggle) | Mouse-only players still need ahead-of-travel visibility for jumps | Low-Med | Light version; keep mouse as primary input |
| Crosshair that reacts (idle / over-valid-target / locked) | Required to teach "teal glow = interactable" | Low | Color/size change; ties into soft-lock below |

### C. Interaction and highlight system

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Teal glow on interactables (energy cores) | In PROJECT.md; this IS the visual language of the game ("glowing teal = the hand can affect this") | Low-Med | Emissive material or outline shader. Rule: nothing non-interactive may glow teal (strict visual vocabulary). Glow intensifies when in range or under crosshair |
| Soft-lock / aim assist to highlighted interactables | Named in PROJECT.md. Mouse aiming with a ranged hand and moving targets is hard | Med | Implementation sketch: sphere-cast or cone query for interactables in the camera frustum, score by angular distance to crosshair then distance, magnetize crosshair or snap the beam to the best candidate within a small angle. Keep angular radius small (a few degrees) so it assists rather than aims for the player |
| Range feedback and invalid-target feedback | Players must learn why a trigger did nothing | Low | Out-of-range = dimmed glow plus short "denied" sound; wrong-module = distinct glyph |
| Interaction beam / tether visual (teal ray from the hand to target) | A ray with no visible line feels like nothing happened. Also reads as the hand's identity | Med | Line mesh or particle ribbon, soft glow, hit spark at the target, animate in/out |
| Instant feedback on trigger: sound + target reaction within one frame | Remote-trigger feels fake if response lags | Low | Mechanism should start a visible motion (or at least a startup shake) immediately even if the full effect takes seconds |

### D. Hand module SYSTEM (framework only; modules themselves are defined per phase)

The framework must make "add a new module" cheap and make every module satisfy the project's rule: clear input, clear effect, and a level situation that needs it. Per the locked decision, a module has NO visual arm change. Identity comes from beam/VFX color or shape, SFX, crosshair glyph and HUD icon.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `HandModule` base definition (Godot Resource): id, display name, icon, input action, targeting rule, cooldown/energy cost, VFX/SFX references, `activate(target)` hook | Project requires modules to be "easily added and swapped" | Med | One `Resource` per module + one small script. Adding a module = new resource + script + one level situation. This is the single most important architectural row in the Active list |
| Module inventory and equipped slot (acquire, equip, switch) | Loop is "find part, hand gets ability" | Med | Slice scale: 2-4 modules total. Selection by number keys / mouse wheel / radial hold; cycle is simplest. Hide the selector until the second module is owned |
| Module acquisition moment (pickup in world, short feedback, HUD icon appears) | The "gain" beat is the emotional payoff of the loop | Low-Med | Environmental pickup of a "Bauteil" (part) with glow and chime, freeze-frame, icon pop on HUD, no cutscene. The new ability's first use should be taught right there (see below) |
| Per-module clear single input | Players juggle movement + aiming + trigger. More than 2-3 distinct button roles overload mouse/keyboard | Low | Suggested convention: `Aim` (hold RMB) + `Use module` (LMB), module-switch on wheel/Q/E. Modules differ by effect, not by new buttons |
| Target compatibility rules (interactable declares which module types it accepts) | Enables lock-and-key and avoids "any module opens everything" | Low | Interactables expose `accepts: [module_id]`; wrong module = "denied" feedback |
| Ability-gating in the level (soft gates by layout, hard gates by compatibility) | Core of Metroidvania-lite loop | Med | See "Ability gating" notes below |
| Save module state across respawn/checkpoint | Losing modules on death would break the loop | Low | Module ownership persists; world mechanism state follows checkpoint rules (see below) |

**What makes each module understandable (design rules for per-phase module definition):**
1. One verb per module (trigger / freeze / pull / push / rewind). If it needs a paragraph, it is two modules.
2. Introduce in a safe "teaching room" where the only solution is using the new module once, with no failure penalty (classic Zelda/Metroid pattern: demonstrate, then test, then combine).
3. Show the lock before the key: players should see an obviously blocked route earlier (glowing barrier, out-of-reach lever, sealed valve) so the gain creates a "now I can" moment. Genre guidance repeated in practitioner sources: each ability, once earned, should open at least two places already seen.
4. Second use should recombine with movement (e.g. dash plus module), third use is in the boss. Reuse beats variety at slice scale.
5. Combine modules only in the boss and one late puzzle; do not build N-by-N interaction matrices.

**Candidate modules (OPTIONS ONLY, not commitments; the first is stated in PROJECT.md "if confirmed in the phase"):**

| Candidate | Verb | Fits mechanism type | Relative complexity |
|-----------|------|---------------------|---------------------|
| Remote Trigger beam (teal ray) | Activate from distance | Switches, valves, gear levers | Low (simplest; also teaches aim and soft-lock) |
| Stasis Escapement (freeze moving parts) | Freeze | Conveyors, rotating gears, swinging blades, boss attack | Med (needs `freeze` state on all moving mechanisms) |
| Rewind Clockwork (rewind object state) | Undo | Broken or collapsed platforms, boss timing | High (needs state history per object; scope-risk) |
| Steam Piston burst (boost/shockwave) | Push / boost | Light obstacles, vertical launch, boss stun | Med (movement integration, physics response) |
| Magnet Grapple hook | Pull / traverse | Anchor points, rails | High (traversal physics and camera interplay; strong feel win if it is done well) |

Recommendation for the roadmap: ship 2 modules in the slice (trigger + one of freeze or steam-burst), keep a third as a stretch. Each additional module costs a teaching room, a lock set, a VFX/SFX identity and a boss interaction.

### E. Environmental puzzles with mechanisms

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Switch / lever / valve interactables with on/off and timed states | Named in PROJECT.md | Low-Med | One generic `Mechanism` base class with signals (`activated`, `deactivated`) and a link graph (target nodes assigned in the editor) |
| Rotating gears and gear-driven platforms | Visual signature (World Look.png) | Med | Use `AnimatableBody3D` so the controller inherits platform velocity; script rotation on a deterministic clock |
| Conveyor belts | Named in PROJECT.md | Med | Use `StaticBody3D.constant_linear_velocity`, or add belt velocity manually in the controller; test dash and jump on belts |
| Doors/bridges/lifts opened by mechanisms | The payoff of the puzzle | Low-Med | Reuse the same signal graph |
| Steam vents, pistons, pressure plates (environmental hazards plus tools) | Atmosphere + verticality; cheap with particles | Med | Timed, readable, fair patterns; always telegraph with steam puff before the burst |
| Logic: simple chain (A starts B), timed (open for N seconds), counter (needs 2 switches) | Prevents puzzles from being one-lever trivia | Low-Med | Stop at timers and AND-gates. Anything beyond is scope creep |
| Clear failure recovery (puzzle reset or re-triggerable) | Players must not soft-lock themselves | Med | Every mechanism either resets on checkpoint reload or is always re-triggerable. See Pitfalls |
| Readable puzzle language: lit pipes/cables visibly lead from the switch to the target | Environmental communication without dialogue or UI | Low-Med | Glowing teal pipes that light up when powered. This replaces text hints and doubles as environmental storytelling |

### F. Boss fight (object-boss, "item turned evil by the catastrophe")

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dedicated arena with readable bounds and platforms | Platformer bosses are traversal tests as much as combat | Med | Arena doubles as the final puzzle room: mechanisms in the arena are the player's weapons |
| 2-3 phases with clear change between them (health bars, new attack, arena change) | Genre standard; practitioner sources describe an escalation at 75% / 50% HP thresholds with a final phase combining earlier attacks | Med-High | For the slice: 3 phases maximum; phase transition = invulnerable beat + visible change (arena shifts, boss damage state, color) |
| Telegraphed attacks (wind-up pose, sound cue, ground marker) | First death should teach, not frustrate | Med | Every attack: anticipation (0.5-1.0 s early, shorter later) → active → recovery window. Recovery is the damage opportunity |
| Boss is hurt through the player's hand tool and arena mechanisms, not generic combat | Ties the slice together, and keeps combat scope tiny (no player attack/health system) | Med | Example loop: boss attack exposes a teal weak-point; player triggers the module from the right spot; mechanism in the arena does the damage. Which module does what is decided in the phase |
| Player health with generous recovery + short death penalty | Needed for any boss | Low-Med | 3-5 hit points, regenerate at checkpoints; or one-hit "fall/knockback" forgiving model. Respawn at the arena start without replaying the level |
| Boss health indicator | Players need to see progress | Low | Diegetic option: boss's own glowing cores extinguish one by one (fits teal-core language, no HUD bar) |
| Victory beat + level exit | Closing the loop; the story is "return to the lab" | Low-Med | Boss dies/powers down, gate opens, level-end pose. No cutscene (Out of Scope) |

### G. Environmental storytelling (no dialogue / cutscenes)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Set dressing that tells the lab-accident story (warning signs, wrecked equipment, overgrowth, blueprints, personal items) | Project says story is world and look only | Med (art-time) | 8-15 hero storytelling vignettes placed along the critical path; reuse modular props |
| Visual progression from destroyed outskirts to the lab entrance | Gives the slice a narrative arc without words | Med | Lighting and prop density change as the player approaches the goal |
| Icon-based language only (no readable text, or minimal symbols/pictograms) | No localization burden, fits Out of Scope | Low | Teal glyphs on interactables, pictographic signs. Sparse bits of diegetic text are acceptable but are not required |
| Level landmarks (a visible distant lab/tower) | Wayfinding goal without UI markers | Low-Med | Skybox or far geometry; matches "floating islands over clouds" reference |

### H. Juice and feedback

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Footstep, jump, land, dash, mechanism, pickup and boss SFX | Silent games feel unfinished | Med | Reuse licensed/free SFX packs; layer 2 sounds per key action; random pitch variance |
| Ambient music/loop + ambient bed (wind, steam, gears) | Atmosphere is half the polish, and it carries the "warm and hopeful" tone | Med | One looping track + stinger for pickup/boss. Library audio is fine |
| Dust/steam/ground particles; dash trail; module beam VFX; pickup sparkle | Visual response to all verbs | Med | GPUParticles3D, keep counts low; style them in teal/cream/warm palette |
| Screenshake and camera kick on impactful events (landing hard, boss slam, heavy mechanism) | Genre-expected feedback; must be configurable | Low | Trauma-based shake with decay; add accessibility toggle |
| Hit-stop (freeze frames about 40-80 ms) on boss hit and big pickups | Strong "impact" for tiny cost | Low | Careful: use time-scale or per-node pause to avoid desyncing physics-driven platforms |
| Squash/stretch on character and key objects; mechanism wobble when triggered | Low-poly chibi style reads cartoonishly well | Low | Scale tweens |
| Post-processing for mood (bloom on teal cores, light fog/god rays, color grading) | Look target ("warm, hopeful") depends on lighting | Med | Glow/bloom in Forward+/Mobile renderer; keep it performant. Pick the renderer early (see Pitfalls) |

### I. Checkpoints, respawn, HUD, pause and settings

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Checkpoints with visible activation (a lit core / lamp) | Standard; reduces frustration | Low-Med | 3-6 checkpoints per level, placed before each hard section, boss arena and after each module acquisition |
| Instant respawn on void fall or hazard (about 1 s, no load screen) | Platformers live on quick retries | Low-Med | Fade or quick wipe; restore mechanism state to the checkpoint snapshot, or reset the section |
| State persistence rule for puzzles at checkpoint (decide and document) | Prevents soft-locks | Med | Recommended: puzzle state resets with the room, but module ownership and "puzzle solved" flags persist once solved |
| Minimal HUD: crosshair, equipped module icon, small health indicator (appears when damaged) | Project tone is minimalist; avoids clutter | Low | Show module + cooldown near the crosshair or bottom corner; hide everything else |
| Pause menu: resume, settings, restart from checkpoint, quit | Expected in every build; also needed for demoing | Low | `process_mode = WHEN_PAUSED`; works with hit-stop and time-scale |
| Settings: master/music/SFX volume, mouse sensitivity, invert Y, fullscreen/resolution, FOV | Mouse+keyboard playability | Low-Med | Persist with `ConfigFile`. Also a "screenshake" slider (accessibility) |
| Basic tutorialization through level design (no text) | Players must learn dash, aim, module use | Med | Teaching rooms and a short on-screen icon prompt of the input (e.g. "RMB" glyph) shown the first time; hidden after use |
| Title/start screen and end screen | Presentation for the uni demo | Low | Static scene with a "play" button; closing card after the boss |

---

## Differentiators

Features that raise the slice above a typical student platformer. None are required, but each should be a deliberate pick. Ordering reflects value per effort.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Movement and hand tightly fused (e.g. trigger usable in mid-air/mid-dash with the same input buffer; slow-mo-free aim in air; dash reloads on trigger) | Directly delivers the stated Core Value; the "seamless connection" that Ratchet and Astro Bot reference | Med | Allow aim mode in air with a slight air-slowdown, not a full slow-mo. Buffer the trigger input |
| Wall-run | Named in PROJECT.md as "maybe" | High | Valuable for flow but camera and collision complexity is large. Treat as stretch after the base movement is polished; if cut, nothing else depends on it |
| Mechanism-driven traversal as the main "weapon" (movement + remote trigger = puzzle-platforming, as with Ultrahand/Portal's physics-puzzle spirit) | Distinct identity: a platformer where your tool rewires the world | Med | Design levels as "trigger the right thing at the right time while moving" sequences. Time-pressure puzzles (open for 5 s) make the movement matter |
| Living world cues (reactive foliage, steam responding to the player, glowing cores pulsing toward the player) | "Warm and hopeful" tone and strong environmental narrative | Med | Shader tricks; cheap and charming |
| Distinctive module VFX identity (each module has a unique color/shape/sound language, even with one unchanging arm) | Replaces the cut visual arm swaps; keeps modules readable and satisfying | Low-Med | Palette discipline: teal = trigger; pick one accent hue per extra module. HUD icon and crosshair glyph change to match |
| Boss as a "final exam" of everything taught (movement + each module + level mechanisms) | Makes the slice feel authored, as in the best Metroidvania bosses | Med | See boss notes. Costs design time, not much engineering |
| Diegetic boss health (cores extinguish) and diegetic HUD cues | Minimal UI, strong look | Low-Med | Fits Control-style minimalism |
| Photo-mode-lite / "vista points" with composed views | Showcase value for a uni demo | Low | A few designed vistas (parallax over clouds) with a camera framing hint |
| Adaptive music layers (calm exploration, tense boss) | Emotional shape | Med | Two or three stems crossfaded; can be cut to two tracks |
| Ghost "assist" options (longer coyote time, slower mechanisms, invincibility) | Accessibility, and good for a demo audience | Low-Med | Exposed as settings; mostly constants already tunable |
| Secret collectibles (parts/gears hidden in alt routes) feeding a simple counter | Rewards exploration and Metroidvania-lite feel | Low-Med | Only if the content budget allows; no meta-progression attached |

---

## Anti-Features

Deliberately NOT built for the vertical slice. Document these in REQUIREMENTS "Out of Scope" to defend against creep.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Visual arm/module swapping (per-module arm meshes, attach/detach animations, morphing arm) | LOCKED by user decision on 2026-11-02. Cuts rigging, modeling and animation cost; the Meshy character stays a single asset | Module identity through beam/VFX color and shape, SFX, crosshair glyph and HUD icon; arm keeps one idle glow state |
| Locking the module list in advance | User wants modules defined per phase | Build the generic `HandModule` framework; define modules in the phase that needs them |
| Dialogue, cutscenes, readable story text, voice acting | Out of Scope; story through world and look | Environmental vignettes and pictograms |
| Multiple levels, hub world, overworld map | Slice = one polished level | One long, vertical level with 2-3 distinct zones |
| Open world / large free exploration | Too much content and navigation work | Linear-with-branches level, one or two optional alcoves |
| Full combat system (melee combos, enemy variety, loot, upgrade trees, inventory/crafting) | No time for balancing; dilutes Core Value | One boss and, at most, passive hazards; maybe one simple patrol enemy only if scope allows |
| Enemies with AI beyond the boss | AI, navigation meshes and balance multiply content | Environmental hazards (steam, blades, moving gears) |
| Complex physics sandbox (free-form object attaching as in Ultrahand) | Physics stability is a time sink in Godot; Jolt tuning is nontrivial | Authored mechanisms with deterministic behavior; limited, scripted physics props |
| Full wall-run + wall-jump + grapple + glide + swim movement kit | Each movement verb multiplies camera, animation and level work | Run/sprint/jump/dash first; add one extra verb only after the base is polished |
| Skill tree, XP, currency, shop, achievements | No gameplay need in a slice | The module collection is the entire progression |
| Save slots / persistent profile / cloud save | Not needed for 20-40 minute slice | Checkpoints in memory + settings in `ConfigFile` |
| Controller polish (rumble, adaptive aim, glyph swapping) in the first iteration | Out of Scope; Input Actions suffice for later | Keep Input Map clean so controller bindings can be added later |
| Localization, multi-language UI | No text-heavy UI | Icons, minimal strings |
| Multiplayer or leaderboards | Irrelevant | None |
| Procedural generation | Fights authored feel | Hand-built level |
| Photorealistic or high-poly assets, dynamic global illumination bells | Conflicts with low-poly look and performance | Baked or simple lighting, stylized materials, emissive bloom |
| Heavy cinematic camera systems (scripted cameras, boss intro fly-bys) | These read as cutscenes and cost time | Camera hint zones for a few vistas only |
| Complex boss AI/behavior trees | Hard to debug; boss should be authored | A readable state machine with scripted attack sequences per phase |

---

## Feature Dependencies

```
Input Actions setup
  -> Third-person controller (CharacterBody3D)
       -> Coyote time + jump buffer + variable jump + air control  (feel layer)
       -> Dash
            -> Dash-jump / dash-cancel tuning
       -> Platform velocity inheritance (moving platforms, conveyors)
            -> Conveyor belts, rotating gears, lifts
  -> Camera rig (SpringArm3D pivot)
       -> Camera collision
       -> Aim mode (hold-to-aim, crosshair)
            -> Interactable detection + teal highlight
                 -> Soft-lock / aim assist
                      -> Hand beam (remote trigger)  [first module]
                           -> Mechanism base class + signal graph
                                -> Switches, valves, gears, conveyors, doors
                                     -> Puzzle rooms
                                     -> Checkpoint state snapshot/reset rules

HandModule Resource framework
  -> Module inventory + equipped slot + switch input
       -> Module pickup moment (HUD icon, SFX, VFX)
            -> Teaching room per module
                 -> Locked route elsewhere in the level (lock before key)
  -> Target compatibility (accepts: module ids)
  -> Per-module VFX/SFX/HUD identity (no arm swap)

Mechanisms + modules + movement
  -> Boss arena
       -> Boss state machine (phases, telegraphs, weak point)
            -> Player health + death/respawn at arena
            -> Boss defeat -> level exit

Art/pipeline gates:
  Meshy character rig/export -> animation set -> movement polish
  Blender-MCP prop kit -> mechanisms, set dressing -> environmental storytelling

Juice layer (SFX, particles, screenshake, hit-stop, post FX) depends on all verbs existing but can be added incrementally.
HUD/pause/settings depend on Input Actions and are independent of gameplay content.
```

Key ordering facts:
- Movement feel and camera come first, because the Core Value lives there and every other feature (aiming, platform riding, boss) is tuned on top.
- The mechanism base class must exist before the first module is meaningful; the first module (remote trigger) is the simplest and doubles as the test bed for aim, soft-lock and mechanisms.
- The `HandModule` framework should be built together with the first module (not before), so the abstraction is shaped by real use; the second module is the real test of the framework.
- Checkpoint/reset rules must be defined before more than two or three puzzles exist, or retrofitting state restoration will be painful.
- Boss depends on everything: movement, aim, at least two modules, mechanisms, health and respawn.

---

## MVP Recommendation

The MVP of the slice, in build order:

1. **Movement and camera feel** (table stakes A + B): controller, sprint, variable jump, coyote, buffer, dash, platform inheritance, SpringArm camera with collision, aim mode. Greybox level to tune. This phase is the Core Value gate.
2. **Interaction and first module** (C + D basics + E base): teal highlight, soft-lock, remote-trigger beam, mechanism base class, switches/valves/gears/conveyors, `HandModule` resource with exactly one module in it.
3. **Module framework proof** (D): second module (freeze or steam-burst, chosen in-phase), inventory/switch input, pickup moment, lock-before-key level layout.
4. **Vertical-slice level** (E + G + I): puzzle rooms, checkpoints, respawn rules, set dressing and storytelling vignettes, landmarks.
5. **Boss** (F): arena, 2-3 phases, telegraphs, weak-point loop using the modules, player health, victory and exit.
6. **Polish pass** (H + I): SFX, music, particles, screenshake, hit-stop, post FX, HUD/pause/settings, title and end screens.
7. **Differentiator picks, only after polish**: wall-run, third module, collectibles, adaptive music.

Defer: wall-run (High), third module, adaptive music, collectibles, photo vistas. Cut first if schedule slips: third module, wall-run, collectibles, boss phase 3.

**Complexity summary for estimating:** Low: input actions, coyote/buffer, variable jump, landing squash, pause/settings, hit-stop. Medium: controller on moving platforms, aim camera, soft-lock, mechanisms graph, module framework, checkpoints with state rules, VFX/SFX pass. High: boss encounter (phases + telegraph + arena integration), wall-run, any rewind/grapple module.

---

## Confidence Notes

| Area | Confidence | Basis |
|------|------------|-------|
| Movement feel parameters (coyote about 0.1-0.15 s, buffer about 0.1-0.15 s, variable jump cut, fall gravity) | MEDIUM-HIGH | Several independent practitioner sources agree on ranges (0.1-0.2 s); values are tunables, to be adjusted by feel |
| Godot node approach (CharacterBody3D, SpringArm3D, AnimatableBody3D, Resource-based modules) | MEDIUM | Consistent with community tutorials and Godot conventions; verify specifics against current Godot docs during phase research |
| Module design rules, lock-and-key (ability opens at least two seen-but-blocked places) | MEDIUM | Practitioner guidance plus well-known Metroidvania/Zelda practice |
| Boss design (3 phases, telegraph/recovery, tool-based damage) | MEDIUM | Practitioner write-ups; genre-standard, not formally tested |
| Soft-lock details | MEDIUM | Standard technique; tuning values need playtesting |
| Candidate module list | LOW (by design) | Options from PROJECT.md discussion; explicitly not commitments |

## Sources

- [Game Feel Week 1](https://yoyonova.itch.io/game-feel-week-1) (jump/coyote/buffer guidance, MEDIUM-LOW, community)
- [How to make a platformer feel good](https://cyborgape78.github.io/Articles/How to make a platformer feel good.html) (6-frame coyote/buffer, variable jump, MEDIUM-LOW)
- [Godot genre platformer skill notes](https://skills.cat/skills/thedivergentai/gd-agentic-skills/godot-genre-platformer) (coyote about 0.1 s, LOW)
- [Godot Third Person Controller (Jeh3no)](https://github.com/Jeh3no/Godot-Third-Person-Controller/) (state machine, jump buffer and coyote, MEDIUM)
- [3D Controls Toolkit, Godot Asset Library](https://godotengine.org/asset-library/asset/3297) (MEDIUM)
- [Godot Third-Person Camera Basics: SpringArm3D, no wall clipping, shoulder view](https://uhiyama-lab.com/en/notes/godot/springarm3d-third-person-camera/) (MEDIUM-LOW)
- [CharacterBody3D movement, gravity, jumping and third-person camera](https://uhiyama-lab.com/en/notes/godot/characterbody3d-movement/) (MEDIUM-LOW)
- [Sprawl: How to Make a Metroidvania (Map + Ability Gates)](https://sorceress.games/blog/sprawl-how-to-make-a-metroidvania-map-ability-gates) (gating rules, LOW-MEDIUM)
- [Summer Engine: Metroidvania template](https://www.summerengine.com/templates/adventure/metroidvania/metroidvania) (ability opens two seen rooms, LOW-MEDIUM)
- [Salt & Steel boss design doc](https://salt-and-steel.pages.dev/docs/15/boss-design) (phase thresholds, telegraph shrink, LOW-MEDIUM)
- [Nemo monthly update 41](https://diesoft.games/2025/11/28/nemo-monthly-update-41.html) (boss built around a newly gained ability, LOW-MEDIUM)
- [Crafting Legendary Boss Battles (Wayline)](https://www.wayline.io/blog/crafting-legendary-boss-battles) (telegraphing, LOW)
- Genre knowledge of Ratchet & Clank, Psychonauts, A Hat in Time, Astro Bot, Kena, Zelda: Tears of the Kingdom (Ultrahand), Control, Portal (design patterns, not verified against primary sources in this session)
- Project context: M:/GIT/Attimo/.planning/PROJECT.md, plus coordinator decision of 2026-11-02 (no visual arm swaps)
