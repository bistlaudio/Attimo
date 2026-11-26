# Attimo: Game Design

> **Living document. This is the single source of truth for what carries the game.**
> Whenever a design decision is made or changed (in a discuss session, a phase, a playtest or a quick chat), update this file in the same session and add a line to the change log at the bottom. Its two HTML views, the site `docs/game-design.html` and the fullscreen deck `docs/attimo-presentation.html`, are updated together with this file, and checked at the end of every phase. Phase CONTEXT/PLAN files may refine details, but if they change a rule here, this file is updated too. All numbers are starting values for the F2 tuning panel, not locked balance; tuned values live in `MovementConfig` and `docs/MOVEMENT-METRICS.md`.

## 0. Identity

- **Game:** Attimo ("the moment"). 3D third-person platformer, uni prototype, vertical slice (one level, one boss).
- **Premise:** the protagonist caused the apocalypse when something went wrong in their lab and wants to get back to it, through a destroyed, overgrown world.
- **Character:** **Rino**, with a steampunk prosthetic arm that stores energy as time: an **energy clock with 12 steps**, shown on the HUD and by four glowing turquoise cores on the arm (3 steps each).
- **Boost state:** **Moto Perpetuo** (from 6 steps).
- **Core value:** fluid, fast movement. Running, the jump chain, dash and dash hop must feel smooth, and the arm must connect to them seamlessly. If everything else wobbles, this must work.
- **Themes:** steampunk (incl. clockwork), arcane energy (turquoise, spacey), overgrown nature.
- **Movement baseline:** run, triple jump 1-2-3, dash, dash hop (long jump), wall run and wall jump on pads. Metrics: `docs/MOVEMENT-METRICS.md`.

**Why a clock fits (2026-11-25):** *Attimo* means "the moment", and *moment* and *momentum* share one root, so the energy-momentum core reads literally as "energy is time": every ability costs Rino a moment. Clockwork is one of the three themes (clock-hand platform, gears). *Moto Perpetuo* is the perpetual-motion idea of clockwork. The Loader's slow motion stretches the moment. The numbers fit: 12 steps = 4 arm cores x 3. And a clock keeps ticking by itself, which is the small passive income.

## 1. Core loop

Rino's prosthetic arm stores time as energy. The player gathers steps (the clock ticking, the charge key, extracting capsules and machines, and riding the free steampunk machines of the world) and spends them on abilities: dash, dash hop, wall run, wall jump and the Loader. **The world gives momentum and time; Rino spends time to make momentum.** Moves that cost steps never charge, so spending and earning never fight each other. This energy loop is the game core and shapes all coming phases and mechanisms.

## 2. Governing rule

> **Running and the jump chain are free; every ability costs time (steps).**

| Move | Free | Costs steps |
|---|---|---|
| Run, triple jump 1-2-3 | always; at Moto Perpetuo (>= 6) Jump 3 is buffed, still free | - |
| Dash (ground and air) | - | 1 step each |
| Dash hop (long jump chain) | - | stage 1 is the dash (1); stages 2 and 3 cost +1 each; without the step a stage falls back to stage 1 |
| Wall run | - | 2 steps on entry, then 1 every 1 s; when the next tick cannot be paid, Rino drops off |
| Wall jump | - | 1 step |
| Loader (right click) | - | 1 to 3 steps, loaded by holding (section 4) |

**Refusal:** when the clock cannot pay an ability, it does not fire, and the player always sees and hears why: the clock shakes and flashes red, the arm flickers and an empty "klack" plays. There is no weak emergency version (a dash at 0 steps simply does not happen). The only silent fallback left is a dash hop stage 2/3 dropping to stage 1.

The free counterpart of every ability lives in the world: the steampunk boosters (section 6.5) give movement for free and even add a step.

**Wall run look:** Rino runs diagonally, feet on the wall and head leaning away from it (body tilted), not upright.

## 3. The resource: the energy clock

The whole energy system counts in **whole steps**. There are no percentages and no fractions; time only appears as a tick interval ("1 step every X s").

- **Scale 0-12 steps** ("hours"). HUD top left: a clock face with an **hour hand**, the face filled turquoise up to the hand. Spending makes the hand jump back with a "klack"; income makes it jump forward with a tick. For the timed income (passive, charge key) a small **second hand** shows the progress to the next step.
- **Arm cores:** the four cores on the arm stay the diegetic read; each core = one quarter of the face = 3 steps.
- **Moto Perpetuo from 6 steps (half the clock):** +10-15 % run speed, buffed Jump 3; the arm glows brighter, both feet and a point on the back glow too (short flash on entering, fade on leaving, no screen effect).
- **Respawn / checkpoint:** always respawn with exactly **3 steps** (one core). Fair, no soft-lock, no farming before a checkpoint.

### Income

| Source | Steps (start, F2) |
|---|---|
| Passive: the clock ticks by itself, always (also standing still) | +1 every 10 s |
| Charge key R (hold while standing still; moving, jumping or dashing cancels) | +1 every 5 s (instead of the passive tick, not on top) |
| Energy capsule (Extractor) | +3 |
| Broken machine (Extractor) | +5 |
| Using a steampunk element (slingshot, steam cannon, updraft, geyser, steam stream, boost ring, speed pad, bounce pad) | +1 per use, with a per-element cooldown |
| Enemies (Phase 6: Extractor drain, Loader hit) | set in Phase 6, whole steps |
| Any move that costs steps (dash, hop, wall run, wall jump, Loader) | never |

The momentum passive charge of Phase 5 (charging above ~10 m/s) is removed.

### Spending

| Spend | Steps (start, F2) |
|---|---|
| Dash / air dash | 1 |
| Dash hop stage 2 / 3 | +1 / +1 |
| Wall run | 2 on entry, then 1 every 1 s |
| Wall jump | 1 |
| Loader | 1-3 (chosen by holding) |
| Loader field pass | needs a Loader with >= 2 steps |
| Escaping an attraction field quickly | 1 every 0.5 s |
| Energy core (mechanism) | 1 step per pay-in tick, as many as the player chooses; thresholds 3 / 6 / 9 |

## 4. Right click: the Loader

Inspired by the Loader character in Risk of Rain: stop, store and redirect momentum, paid in steps.

1. **Hold:** momentum is frozen and stored; Rino brakes hard or hangs in the air. Slow motion (~0.25x), camera freely rotatable. While holding, the ring fills **step by step** (about one step every 0.3 s real time, F2), and each step is paid at once from the clock (the hand klacks back). Max 3 steps. With an empty clock the Loader does not start (refusal); with fewer steps the ring stops filling. Hold is capped (~1.2 s real time), then the Loader discharges by itself.
2. **Release:** discharge in the view direction (including up and down) on a **straight line, no parabola**. Speed = `own speed + push + steps x (push per step + k x own speed)`; start values push 4 m/s, push per step 2 m/s, k 0.1, cap 22 m/s. Rino flies straight without gravity for a base distance per step (6 / 10 / 14 m); speed above the cap is not lost but lengthens the straight flight. Then gravity resumes and the speed carries on.
3. **Look while holding:** the crosshair becomes a **smaller charge ring split into 3 step segments** that light up as steps are loaded (the current ring look, smaller). There is **no trajectory line**: the crosshair direction is the flight line. The world is slightly desaturated with a turquoise vignette.
4. **Rules:** on the ground the Loader brakes Rino hard (~0.1 s skid), then Rino stands while the momentum is stored; the discharge may go up (super jump out of a run). One use per air phase, refilled on landing. The Loader neither refills nor spends the air dash; after the release air control is locked for ~0.15 s. A Loader hit damages enemies (Phase 6).
5. **Camera:** the camera may look up almost vertically (~89 degrees) everywhere, not only while holding, but never flips over the top to look backward.
6. **Feel property: "geladen" (a loaded spring).** Holding builds tension (step segments fill, rising hum, slight camera pull-back); the release is sharp with a short hitstop. Every cue points at this one property.
7. **Removed:** goggle HUD, zoom, shoulder offset and aim pose (Phase 3/4 aim mode); the free redirect without cost and the dashed trajectory preview (2026-11-25).

The old Phase 5 (Pull/Push) is replaced by this mechanic. Pull and push are dropped.

## 5. Left click: the Extractor

- **Extractor** (hold): cone in front of the hand (35 degrees, 4 m, F2 starting values); drains energy capsules (+3) and broken machines (+5); enemies in Phase 6. A visible turquoise **beam** runs from the hand to the source while extracting. The arm points at the source and the source goes dark, then refills after its `respawn_time`.
- **The shot is removed (2026-11-25).** There is no projectile, no charge shot and no gear-disc target anymore. Left click is only the Extractor.
- **Module system:** the Phase 4 hand module framework (one folder + one registry entry per module) stays in code but is dormant: the mouse wheel and keys 1/2 switch nothing until a later module arrives.
- **Enemies (Phase 6):** beaten with the Extractor (drain at close range, player vulnerable) and with Loader hits (a discharge into the enemy).

### HUD

Top left: the **energy clock** (12 steps, hour hand, second hand for timed income), the Moto Perpetuo state and a **momentum readout** (speed gauge). Health joins it in Phase 6. The four glowing cores on the arm stay the diegetic main read. The always-on crosshair stays and is drawn smaller while the Loader is held and inside the slingshot core.

### Gym coverage (Phase 5, reworked in 05.1)

Phase 5 built the Loader room and the energy area `Zone_Energy` (charge track, capsules, broken machine, charge spot, stations per injected move, shot stations). In 05.1 the energy area is converted to steps: the charge track goes (movement no longer charges), the shot stations become **Loader-field obstacles** without gates, and the move stations show the step costs. Energy rates in `docs/MOVEMENT-METRICS.md` (FEEL-10) are rewritten in steps when 05.1 builds them.

## 6. Mechanism kit

Rethought from scratch, starting from the energy layer; the steampunk and nature layers were derived from it. Content below is the agreed first pass. Exact looks are done in the design phase (see 6.8).

### 6.1 Three axes: the kit cube

Every world object gets a profile on three axes. Role defines the chapters; energy relation and theme are tags.

**Axis 1: Role in the level (chapters)**

| Role | Question it answers |
|---|---|
| Platforms | What do I stand or run on? |
| Environment | Which zone acts on me while I am in it? |
| Obstacles | What blocks me, hurts me or puts me under time pressure? |
| Boosters | What gives me movement for free? |
| Mechanisms | What do I actively interact with? |

**Axis 2: Energy relation (tag):** Free / Costs / Amplified (works stronger when the arm is charged). There is **no "charges" column**: energy comes from extracting broken machines and energy capsules (special case, see 6.4), and since 2026-11-25 every free steampunk booster also gives +1 step per use (a small bonus with a cooldown, not a role of its own).

**Axis 3: Theme (tag):** Steampunk (incl. clockwork), Energy (arcane / spacey, turquoise), Overgrown nature.

### 6.2 Base rules

1. **Coupling:** Steampunk = free and mechanical, it helps you; it never costs steps, but using a steampunk booster gives +1 step, shown by a brass gear spark flying to the arm, an audible clock tick and a small turquoise accent on the element. Turquoise = energy (costs or amplified); any object that touches energy shows turquoise, also as a turquoise core on a brass body. Nature = world and danger, free, never touches energy and never helps you.
2. **Platforms are neutral.** They never cost, charge or get amplified. They stand on their own and only interact with the world and themselves (crumble, tilt, sink). Rare exceptions allowed (e.g. a drawbridge switched by an energy core).
3. **Booster rule:** every energy move has a free counterpart in the world, so level design can dial how much energy a section demands.
4. **The cube is deliberately sparse.** Empty cells are intended; it is a gap-check tool, not a fill-every-cell target.

### 6.3 Unique trait per layer

| Layer | Trait | Asks the player |
|---|---|---|
| Steampunk | **Timing**: predictable, rhythmic, always free | "Can you hit the rhythm?" |
| Energy | **Decision**: spend, save or risk; may break physics | "Do you spend it?" |
| Nature | **Resistance**: brakes, decays, one-shot, no rhythm | "Can you keep your speed?" |

### 6.4 Layer 2: Energy (turquoise)

| Role | Costs | Amplified |
|---|---|---|
| Platforms | neutral | neutral |
| Environment | **Attraction field**: trap; slow escape free, fast escape costs | **Gravity zone**: low gravity; with energy you float longer |
| Obstacles | **Loader field**: does not break; Rino glides through only during a Loader discharge with >= 2 steps and loses some speed (start -30 %); anything else is softly pushed back | deliberately empty (an obstacle that punishes charging would undermine the core loop) |
| Boosters | deliberately empty (the Loader itself is the paid booster) | **Bounce pad with core**: higher/further when the arm is charged |
| Mechanisms | **Energy core** (pay in steps; each threshold 3 / 6 / 9 switches one more output: parkour pieces, the drawbridge, speed pads; never doors) | **Charge gate**: a check volume that switches a receiver while you are inside with >= X steps; checks, does not consume; not a door |

**Energy sources in the world:** **energy capsule** (+3 steps, quick extraction) and **broken machine** (+5 steps, slower extraction), plus the +1 step per steampunk booster use. Targets (gear discs) were removed with the shot on 2026-11-25. There are no gates or doors as outputs.

### 6.5 Layer 1: Steampunk (free, mechanical)

| Role | Objects |
|---|---|
| Platforms | Clock-hand platform (vertical rotation, always on, fix floor bugs), tilting platform (always on), paternoster, **rail cart** (moves along a track), **piston steps** (extend from and retract into a wall in rhythm), **drawbridge** (folds down when an energy core threshold is reached) |
| Environment | Updraft (continuous lift), geyser (pulsed burst), **steam stream** (horizontal, replaces the wind tunnel); each gives +1 step per use (per-element cooldown, small turquoise accent) |
| Obstacles | Pendulum, piston wall, **steam hammer** (timed stamper from above) |
| Boosters | Slingshot core (Loader counterpart, free aim, see 6.6), steam cannon (fixed direction), boost ring (air-dash counterpart), speed pad (dash-hop counterpart, replaces conveyors, **steam boost-nozzle look**; some switched by energy cores), wall pad (wall-run counterpart, brass and steam look), bounce pad base version. **Each booster gives +1 step per use** (per-element cooldown) |
| Mechanisms | The output side: platforms, the drawbridge and speed pads switched by energy cores and charge gates (no gates or doors) |

### 6.6 Slingshot core: the Loader you can touch (steampunk)

Layer 1, free, no energy bonus. Must feel exactly like the Loader (same input, same timing), only location-bound and fully steampunk in look:

1. **Enter:** a small brass cage/ring catches Rino with a steam hiss only when he is actually inside it (no suction from outside), momentum freezes, Rino hangs in the ring.
2. **Hold:** same slow motion and free camera as the Loader. The charge ring becomes a smaller **pressure gauge** (needle climbs with the stored speed); there is no trajectory line (same as the Loader); the crosshair is drawn smaller; auto-launch after the max hold time.
3. **Release:** steam blast, then the cage discharges like a **free 2-step Loader**: speed = `own speed + push + 2 x (push per step + k x own speed)`, capped at 22 m/s, straight flight of the 2-step base distance (10 m) plus the overflow, in the view direction. No steps are paid, and using it gives +1 step.

It teaches the Loader without a tutorial: same input and timing, only the look says "free and mechanical".

### 6.7 Layer 3: Overgrown nature (world and danger)

| Role | Objects |
|---|---|
| Platforms | Crumbling platform (ruins), **sinking debris** (gives way under your weight), **tipping trunk** (fallen tree or column, tips when you land on its end) |
| Environment | **Leaf storm** (gusts through gaps in the ruins, visible as whirling leaves; force volume pushing against you) and **resin pool** (thick amber resin sticks to the feet; drag zone -> less speed -> less passive charge) |
| Obstacles | **Collapse** (paths break away as you run over them), **falling debris** (drops from ruins as you pass), **snap bloom** (mutated carnivorous plant that bites when you get close; reaction to proximity + damage component) |
| Boosters | deliberately empty: nature never helps you |
| Mechanisms | none |

Rejected **looks** for nature: giant mushroom, vine wall, waterfall, thicket, thorn vines. The **functions** behind them stay with new looks: waterfall -> leaf storm, thicket -> resin pool, thorn vines -> snap bloom. More nature looks on the reaction-to-load block (ruins, roots, bridges) can be added later without new logic.

### 6.8 Architecture: 8 logic blocks + 4 components + looks

Professional pattern: logic separated from look, and cross-cutting abilities as attachable components (composition), so new objects are mostly assembled, not coded.

**Logic blocks: what the object does** (one script each, values in a config resource `.tres`, like `MovementConfig`)

| # | Block | Parameters | Objects |
|---|---|---|---|
| 1 | Force volume | direction or radial, continuous / pulsed, strength, drag, gravity scale | updraft, geyser, steam stream, gravity zone, attraction field, leaf storm, resin pool (drag) |
| 2 | Impulse | direction, strength | speed pad, boost ring, bounce pad (base and with core) |
| 3 | Catch & launch | free aim / fixed direction; shares code with the Loader | slingshot core, steam cannon |
| 4 | Timed motion | path or rotation, always on / cyclic / switched | clock-hand platform, tilting platform, paternoster, rail cart, piston steps, drawbridge, gates, pendulum, steam hammer, piston wall |
| 5 | Reaction to load | crumble / sink / tip / fall / let through; triggered by weight, proximity or impact (Loader with >= 2 steps) | crumbling platform, collapse, sinking debris, tipping trunk, falling debris, snap bloom (proximity), Loader field (impact, lets through) |
| 6 | Trigger | sends a signal; invisible AND / OR / timer logic combines signals | energy core, charge gate |
| 7 | Energy source | amount, extraction duration | energy capsule, broken machine |
| 8 | Wall surface | wall-run surface | wall pad |

**Components: what it can do additionally** (child nodes, attachable to any block)

| Component | Does | Examples |
|---|---|---|
| Receiver | gets switched by a trigger signal | switched speed pad, drawbridge, parkour pieces |
| Damage / push | hurts or pushes on contact (until health exists in Phase 6 it only pushes and reports the hit amount) | pendulum, steam hammer, piston wall, snap bloom, falling debris |
| Amplification | reads the arm charge and acts stronger | bounce pad with core, gravity zone |
| Energy cost | costs whole steps per tick while used | fast escape from the attraction field, paying into an energy core |

**Looks:** inherited scenes that only swap visuals. **Presets:** `.tres` value sets (e.g. "geyser strong" / "geyser weak").

| You want | You add |
|---|---|
| a new object | block + components + look, usually no new code |
| a new look | an inherited scene |
| a new variant | a `.tres` preset |
| a genuinely new behaviour | a new block (only case that needs new code) |

**Parallels between layers come from components, not duplicate objects:** steampunk object + amplification component = its energy counterpart (bounce pad -> bounce pad with core). Layers stay distinct through their core blocks:

| Layer | Trait | Core block |
|---|---|---|
| Steampunk | timing | timed motion, catch & launch |
| Energy | decision | trigger, energy source (+ amplification / energy cost components) |
| Nature | resistance | reaction to load |

Look rule: a look may change freely **within its layer**, but must never break the coupling. A free booster never gets a nature look, and anything that costs or is amplified always keeps a turquoise signal.

**Architecture guardrails** (from the lecture review, `docs/reference/LECTURE-PRINCIPLES.md` section 3):

1. No flag soup inside a block: variants of timed motion and force volume are one selected profile, not combinable booleans; a variant that needs much special code becomes its own block.
2. Runtime state lives on the node, never in the shared `.tres` config (or `duplicate()` it first).
3. A component exists only once it has two users; until then the energy cost is a force-volume parameter.
4. Each block documents its interface (config, signals in and out) and has a contract test; each object keeps its smoke test.
5. EventBus facts carry values (ids, positions, amounts), not node references.

### 6.9 Old showroom stations: verdict

- **Keep:** updraft, geyser, slingshot core, boost ring, piston wall, pendulum, crumbling platform, paternoster, wall pad, tilting platform, gravity zone.
- **Rework:** steam cannon (fix; kept as the fixed-direction variant of catch & launch), clock-hand rotating platform, conveyors -> speed pads, wind tunnel -> steam stream, attraction field -> trap, bounce pad -> amplified variant, energy core -> pay-in amount, steam nozzle wall -> steam look of the wall surface (see below).
- **Cut:** steam nozzle jump, lying rotating platform, lift platforms (chain, piston), repulsion field, pneumatic tube, lever, pressure plate, valve, crank; the timer as a visible object; since 2026-11-25 also gear-disc targets (normal and heavy), gates and doors as outputs, and the force-field barrier (replaced by the Loader field).
- **AND / OR / timer:** kept as invisible level-design logic on the trigger block (e.g. two energy cores raise one bridge; a charge gate switches a speed pad for 5 s as a speed challenge).
- **Steam wall fixes (user feedback):** the jump off the steam wall must feel natural like the normal wall jump; currently it is over the top and just flings Rino away. The wall run on it is buggy: Rino currently runs with the head against the wall (wrong orientation).

### 6.10 Rules fixed in the Phase 05.1 discuss

1. **Slingshot input:** the cage is small (ring about 0.7 m) and catches Rino only when his chest is actually inside the core (0.6 m from its centre): touching the outside or flying past never catches and never pulls (2026-11-26, D-54). Entering the core catches Rino and starts the hold at once (Loader slow motion, cap and free camera, same values). If RMB is held, its release fires. If not, a press continues the hold and the release fires (a tap fires at once). With no input the cage auto-launches at the Loader's hold cap. The launch adds no bonus and spends no steps; since 2026-11-25 it gives +1 step (steampunk income) and flies the Loader's straight line as a free 2-step discharge (2026-11-25 replan). It refills the Loader's one air use and leaves the air dash alone.
2. **Steam cannon:** the fixed-direction catch & launch. A short fixed hold with no slow motion and no input, then a launch along the barrel at a fixed speed that does not depend on the entry speed, so the arc is always the same.
3. **Steam wall:** the steam nozzle wall push is gone. A steam-look wall pad behaves exactly like the plain wall pad (same wall run, same wall jump, no extra push). ~~Rino runs along the wall upright, leaning slightly toward it.~~ **2026-11-25:** Rino runs diagonally, feet on the wall and head leaning away from it.
4. **Clock-hand platform:** a hand pivoted at one end that sweeps back and forth, always on, clamped below the floor angle so it never throws the rider off. It does not do a full 360-degree turn. To be confirmed in playtest.
5. ~~**Targets:** gear discs fired only by a shot (tap or charged); a capsule stays nearby. A heavy gear disc needs a full-charge shot and replaces the valve.~~ **2026-11-25:** targets are removed together with the shot.
6. **Energy core:** hold E near the core to pay in, 1 step per pay-in tick. The paid amount stays, and each threshold (start 3 / 6 / 9 steps) switches one more output (more parkour pieces, the drawbridge, a speed pad; never a door).
7. ~~**Force-field barrier:** only a Loader discharge with bonus breaks it.~~ **Loader field** (2026-11-25): does not break; a Loader with >= 2 steps glides through with a brake. **Attraction field:** walking out is always possible and free; a fast escape (dash or Loader) costs 1 step every 0.5 s.
8. **Showroom = gym:** the gym gets one area per layer (grouped by role) plus a mixed course (the new energy layer area is not the Phase 5 energy area). The Phase 5 Loader room and energy area keep their layout; the shot stations in the energy area become Loader-field obstacles without gates (2026-11-25).

## 7. Roadmap mapping

| Phase | Delivers from this document |
|---|---|
| 5 Energy Arm & Loader | built the first energy version (0-100, 4 cores), the Loader, the removal of aim mode, the Extractor (capsules and machines), the shot (removed again in 05.1) and the energy HUD |
| 05.1 Kit Rework | section 6: kit cube, 8 logic blocks + 4 components, the three layers, showroom regroup; plus (2026-11-25) sections 2-5 rebuilt: the energy clock in whole steps, every ability costs, refusal feedback, passive tick and steampunk income, Extractor beam, shot and targets removed, the paid straight-line Loader, camera pitch, slingshot and crosshair changes |
| 6 Extractor, Enemies & Recovery | enemies beaten by the Extractor (drain) and by Loader hits, enemy income in whole steps, health next to the clock HUD, checkpoints and fast respawn; no shot |
| 7 Level | the "charge the level" gimmick, built from the kit |
| 8 Boss | beaten through Loader discharges (and the Extractor) on weak points; no shot |

## Change log

| Date | Change |
|---|---|
| 2026-11-23 | Created from the energy-momentum design session (note `.planning/notes/2026-11-23-energy-momentum-core-mechanic.md`): core loop, governing rule, resource, Loader, modules, mechanism kit (Block 6). |
| 2026-11-23 | Left-click drain module renamed from Siphon to **Extractor** (verb: extract). Gym rule: every gameplay phase ends with the movement gym reworked and extended (ROADMAP rules). HTML view `docs/game-design.html` added. |
| 2026-11-23 | Lecture review (C&D II + III) added as `docs/reference/LECTURE-PRINCIPLES.md` with the project skill `attimo-design-principles`; architecture guardrails added to 6.8; fullscreen deck `docs/attimo-presentation.html` added next to the site. |
| 2026-11-24 | Phase 5 discuss: passive charge from ~10 m/s; charge button on R; Loader rules (ground brake, once per air phase, independent of the air dash) and feel property "geladen"; shot is a charged projectile (tap 10, hold up to 25, full-charge tell, no beam); stronger snap assist, no slowdown, gear-disc targets; Extractor (capsules only), shot and energy HUD with momentum readout pulled into Phase 5; Moto Perpetuo also lights feet and back. |
| 2026-11-24 | Phase 5 executed: Loader room and energy area in the gym (doorway from the Loader room, charge track, capsules, broken machine, drain plates, injected-move and shot stations), capsules next to every shot puzzle, signs rewritten for hip fire (tap or charge, no aim hold); Extractor on capsules and machines, charged projectile shot with bend, energy-gated glow, notched shot ring; Loader pitch raised to about 75 degrees while holding; energy rows added to the metrics doc. Numbers (7 degree assist, 540 degrees per second bend, 40 m/s, 4 m extract range) are F2 starting values. |
| 2026-11-24 | Phase 05.1 discuss (auto run): section 6.10 added (slingshot input, steam cannon fixed speed, steam wall = plain wall pad behaviour, clock hand as a bounded always-on sweep, shot-only targets, energy core pay-in with E and thresholds, barrier and attraction-field rules, showroom merged into the gym layer areas); 6.8 components: energy cost also covers the energy core pay-in, damage only pushes until Phase 6. |
| 2026-11-25 | Playtest feedback, live 05.1 discuss (05.1-CONTEXT D-34..D-58): energy becomes a **clock with 12 whole steps** (no percentages or fractions; Moto 6, respawn 3, arm cores = 3 steps each); new governing rule "running and the jump chain are free, every ability costs steps" (dash and air dash 1, hop stages +1, wall run 2 + 1/s, wall jump 1, Loader 1-3); refusal with clock shake, red flash, arm flicker and klack; income: passive tick +1/10 s, R +1/5 s, capsule +3, machine +5, steampunk booster +1 per use; costing moves never charge (momentum charge removed); shot, gear-disc targets and gates removed, Extractor only (beam visual), module switch dormant; Loader paid by holding, straight-line flight with the formula own speed + push + steps x (push step + k x own speed), overflow lengthens the straight flight, no trajectory line, smaller segmented ring; camera up to ~89 degrees everywhere; force-field barrier replaced by the Loader field (>= 2 steps, brake); slingshot smaller, catches only inside; wall run diagonal, head away from the wall; Phase 6 enemies beaten by Extractor and Loader hits. Section 0 explains why the clock fits the theme. |
| 2026-11-25 | Replan answers (05.1-CONTEXT D-59..D-62): the slingshot core discharges as a **free 2-step Loader flight** (formula with 2 steps, cap 22 m/s, 10 m straight flight plus overflow, no cost, +1 step; 6.6, 6.10); the **steam stream** joins the steampunk +1-step income list (3, 6.5); the Phase 5 Loader room keeps its positions while its gap and ledge are re-sized for 1 vs 3 steps. |
| 2026-11-26 | Plan 05.1-14 (D-54, D-43): the slingshot core is smaller and catches only with the chest inside 0.6 m of its centre (no suction); the cage and the steam cannon give +1 step per catch with a 3 s per-element cooldown (`KitBlock.grant_step`, `EnergyRelation.GIVES`), shown by a brass gear spark flying to the arm and a small turquoise accent on the element. The HTML views carry no slingshot input detail, so they are unchanged. |
| 2026-11-26 | Plan 05.1-15 (D-09, D-11, D-26, D-27, D-43, D-61): the **Force volume** block is live (profiles directional and drag, timing continuous or pulsed). Updraft, geyser and steam stream carry the old nozzle, geyser and wind tunnel numbers and give +1 step per use (updraft and stream on entering, geyser on its launching burst; 3 s cooldown, standing inside never farms). Nature gets a look pass (moss, bark, amber resin, weathered stone): the **leaf storm** pushes in gusts (7 m/s, 1.2 s on, 1.0 s off; its acceleration must beat the run's 70 m/s2 restoring rate, start value 74, so a gust slows the run clearly but never turns it around) and the **resin pool** drags the run to 45 % speed (start values for F2). Nature never touches energy. |
| 2026-11-26 | Plan 05.1-16 (D-10, D-11, D-14, D-24, D-25, D-30, D-43): the **Impulse** block is live (profiles boost, pad, bounce). Boost ring (20 m/s along its axis, air dash back), **speed pad** (replaces the conveyors, which are gone from the gym; a short forward boost to 12.5 m/s while grounded, carried on by a jump) and bounce pad (old drop-height bounce) give +1 step per use with a 3 s cooldown. The **Amplification** component reads the arm steps only (factor 1 + 0.5 x steps / 12) and has two users: the **bounce pad with core** (bounce speed times the factor) and the **gravity zone** (a Force volume with the new gravity profile, gravity 0.35 divided by the factor, so it floats longer with a fuller clock); neither spends energy. The Phase 5 boost-line rings were swapped for the kit ring in place. The HTML views carry no such numbers, so they are unchanged. |
