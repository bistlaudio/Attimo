---
date: "2026-11-23 20:30"
promoted: true
promoted_to: docs/GAME-DESIGN.md
---

# Energy-Momentum Core Mechanic (design session 2026-11-23)

Decisions agreed with the user and the co-designer (bistl). This note feeds the roadmap rework of Phase 5, the new Kit phase (Block 6, still open) and Phases 6-8. All numbers are starting values for the F2 tuning panel, not locked balance.

## Names

- Game title stays **Attimo**. The Loader's slow-motion hold literally freezes "the moment", so the title now fits the core mechanic.
- The player character is called **Rino**.
- The boost state (energy >= 50) is called **Moto Perpetuo**.

## 1. Core loop

Rino's prosthetic arm is a battery for momentum. The player collects energy, stores it in the arm and spends it on stronger movement, the Loader discharge, shots and mechanisms. Fast movement charges the arm again: **speed -> energy -> more speed.** This energy-momentum loop is the game core and shapes all coming phases and mechanisms.

## 2. Governing rule

> **The base version is free; the injected version costs energy.**

| Move | Free (base) | Injected (costs energy) |
|---|---|---|
| Triple jump 1-2-3 | always available, normal heights | at >= 50 (Moto Perpetuo) buffed: higher and faster, no cost |
| Dash | ground dash, always available | **air dash**: needs energy; with an empty arm the air dash does not fire at all |
| Dash hop (long jump chain) | 1 stage only, unspectacular | up to 3 stages, each stage costs; not spammable |
| Wall run | short (~0.6 s); jumping off is always free | longer, costs energy per second after the free window |
| Loader (right click) | redirect only: discharges with the stored speed, no bonus, with a cooldown | discharge with bonus speed |

The air dash does not break the rule: the ground dash is the base version, the air dash is its injected form.

When the player lacks energy for an injected move, the base version fires automatically (no "failed" moment). Exception: the air dash, which simply does not fire.

## 3. The resource

- **Scale 0-100, split into 4 cores of 25.** The four cores on the arm glow and show the charge diegetically. This answers the open Phase 6 question (real resource: yes).
- **Moto Perpetuo from 50 (2 cores):** +10-15 % run speed, buffed Jump 3, the arm glows brighter.
- **Respawn / checkpoint:** always respawn with exactly 1 core (25). Fair, no soft-lock, no farming before a checkpoint.

### Income

| Source | How | Starting value |
|---|---|---|
| Momentum (passive) | charges while above dash exit speed (~12 m/s) | +3-6/s, scales with speed |
| Arcane energy capsules | broken, glowing machines and gadgets placed in the world, drained with the Siphon (replaces the earlier "energy rifts" idea) | +40 per capsule, then empty |
| Siphon (Moira-style drain) | drain an enemy at close range | up to +35 per enemy, ~2 s, player is vulnerable while draining |
| Shoot -> absorb | shooting costs energy, the enemy bursts into shards, the player siphons the shards | shot -10, shards +25, net +15 |
| Charge button ("Super Saiyan" charge) | stand still and hold, very slow | +5/s, emergency fallback only |

**Siphon vs. shoot (intended balance):** the Siphon is more *efficient* (+35 vs. net +15 per enemy) but slow and risky; shoot-and-absorb yields less but is fast, stays in the flow and is more *fun*. A real choice, not an efficiency race.

### Spending

| Spend | Cost (start) |
|---|---|
| Loader discharge (with bonus) | 25 (1 core) |
| Dash hop stage 2 / 3 | 15 each |
| Air dash | 10 |
| Wall run after 0.6 s | 15/s |
| Shot | 10 |
| Escaping an attraction field quickly | 20/s |
| Energy core (mechanism) | any amount the player chooses to pay in |

## 4. Right click: the Loader (replaces aim mode)

Inspired by the Loader character in Risk of Rain: stop, store and redirect momentum.

1. **Hold:** momentum is frozen and stored; Rino brakes hard or hangs in the air. Slow motion (~0.25x), camera freely rotatable. Hold is capped (~1.2 s real time), then the Loader discharges automatically.
2. **Release:** discharge in the view direction (including up and down) at `max(stored speed, minimum push) + bonus`, capped.
3. **Look while holding:** the crosshair becomes a **charge ring** that fills with the stored momentum and shows the speed; a **dashed trajectory preview** of the discharge; the world is slightly **desaturated** with a **turquoise vignette**. With an empty arm the ring stays grey and the preview shows no bonus segment.
4. **Removed:** goggle HUD, zoom, shoulder offset and aim pose (Phase 3/4 aim mode). The small always-on crosshair stays for hip-fire shots and targets; aim-assist logic stays for targets.

The old Phase 5 (Pull/Push) is replaced by this mechanic. Pull and push are dropped.

## 5. Left click: two modules, switched with the mouse wheel

- **Siphon** (hold): cone in front of the hand; drains enemies, shards and energy capsules. Brings energy.
- **Shot** (tap): the existing Fernauslöser pulse as a projectile. Costs energy; hits targets and enemies. Targets activated by hip-fire shots replace levers.

Both run on the Phase 4 hand module framework (one folder + one registry entry per module).

## 6. Mechanism kit (Block 6): first pass decided

Rethought from scratch, starting from the energy layer; the steampunk and nature layers were derived from it. Content below is the agreed first pass. Exact looks are done in the design phase (see 6.7).

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

**Axis 2: Energy relation (tag):** Free / Costs / Amplified (works stronger when the arm is charged). There is **no "charges" column**: the only energy source in the world is siphoning broken machines and energy capsules (special case, see 6.4).

**Axis 3: Theme (tag):** Steampunk (incl. clockwork), Energy (arcane / spacey, turquoise), Overgrown nature.

### 6.2 Base rules

1. **Coupling:** Steampunk = free and mechanical, it helps you. Turquoise = energy (costs or amplified); any object that touches energy shows turquoise, also as a turquoise core on a brass body. Nature = world and danger, free, never touches energy and never helps you.
2. **Platforms are neutral.** They never cost, charge or get amplified. They stand on their own and only interact with the world and themselves (crumble, tilt, sink). Rare exceptions allowed (e.g. a drawbridge switched by a target).
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
| Obstacles | **Force-field barrier**: breaks only to a charged Loader discharge | deliberately empty (an obstacle that punishes charging would undermine the core loop) |
| Boosters | deliberately empty (the Loader itself is the paid booster) | **Bounce pad with core**: higher/further when the arm is charged |
| Mechanisms | **Energy core** (pay in any amount; more energy -> more parkour spawns or a farther door), **Target** (shot costs energy) | **Charge gate**: opens only while you arrive with >= X charge; checks, does not consume |

**Only energy source:** **energy capsule** (small, quick siphon) and **broken machine** (large, slower siphon, more energy).

### 6.5 Layer 1: Steampunk (free, mechanical)

| Role | Objects |
|---|---|
| Platforms | Clock-hand platform (vertical rotation, always on, fix floor bugs), tilting platform (always on), paternoster, **rail cart** (moves along a track), **piston steps** (extend from and retract into a wall in rhythm), **drawbridge** (folds down when a target is hit) |
| Environment | Updraft (continuous lift), geyser (pulsed burst), **steam stream** (horizontal, replaces the wind tunnel) |
| Obstacles | Pendulum, piston wall, **steam hammer** (timed stamper from above) |
| Boosters | Slingshot core (Loader counterpart, free aim, see 6.6), steam cannon (fixed direction), boost ring (air-dash counterpart), speed pad (dash-hop counterpart, replaces conveyors, **steam boost-nozzle look**; some switched by targets), wall pad (wall-run counterpart, brass and steam look), bounce pad base version |
| Mechanisms | The output side: gates, gear gates and platforms switched by targets and energy cores |

### 6.6 Slingshot core: the Loader you can touch (steampunk)

Layer 1, free, no energy bonus. Must feel exactly like the Loader (same input, same timing), only location-bound and fully steampunk in look:

1. **Enter:** a brass cage/ring catches Rino with a steam hiss, momentum freezes, Rino hangs in the ring.
2. **Hold:** same slow motion and free camera as the Loader. The charge ring becomes a **pressure gauge** (needle climbs with the stored speed), the trajectory preview is drawn in **brass dashes**; auto-launch after the max hold time.
3. **Release:** steam blast, launch in the view direction at `max(entry speed, fixed push)`, no energy bonus.

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
| 5 | Reaction to load | crumble / sink / tip / fall; triggered by weight, proximity or impact (charged Loader) | crumbling platform, collapse, sinking debris, tipping trunk, falling debris, snap bloom (proximity), force-field barrier (impact) |
| 6 | Trigger | sends a signal; invisible AND / OR / timer logic combines signals | target, energy core, charge gate |
| 7 | Energy source | amount, siphon duration | energy capsule, broken machine |
| 8 | Wall surface | wall-run surface | wall pad |

**Components: what it can do additionally** (child nodes, attachable to any block)

| Component | Does | Examples |
|---|---|---|
| Receiver | gets switched by a trigger signal | switched speed pad, drawbridge, gates |
| Damage / push | hurts or pushes on contact | pendulum, steam hammer, piston wall, snap bloom |
| Amplification | reads the arm charge and acts stronger | bounce pad with core, gravity zone |
| Energy cost | drains energy while used | fast escape from the attraction field |

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

### 6.9 Old showroom stations: verdict

- **Keep:** updraft, geyser, slingshot core, boost ring, piston wall, pendulum, crumbling platform, paternoster, wall pad, tilting platform, gravity zone.
- **Rework:** steam cannon (fix; kept as the fixed-direction variant of catch & launch), clock-hand rotating platform, conveyors -> speed pads, wind tunnel -> steam stream, attraction field -> trap, bounce pad -> amplified variant, energy core -> pay-in amount, steam nozzle wall -> steam look of the wall surface (see below).
- **Cut:** steam nozzle jump, lying rotating platform, lift platforms (chain, piston), repulsion field, pneumatic tube, lever, pressure plate, valve, crank; the timer as a visible object.
- **AND / OR / timer:** kept as invisible level-design logic on the trigger block (e.g. two targets open one gate; a target opens a gate for 5 s as a speed challenge).
- **Steam wall fixes (user feedback):** the jump off the steam wall must feel natural like the normal wall jump; currently it is over the top and just flings Rino away. The wall run on it is buggy: Rino currently runs with the head against the wall (wrong orientation).

### 6.10 Raw inputs (historical)

Co-designer session notes (2026-11-23, raw): threshold speed buff; momentum stopper discharges in view direction; target hit from the hip instead of levers; pressure plate out; valve out; energy core with a payment amount (more energy -> parkour spawns that must be run quickly, or a door further away that needs speed); crank out; timer out; wall run costs energy after x seconds, jumping off free; gravity zone stays, keeps momentum, no energy cost; steam updraft stays; steam nozzle wall needs a much better version; repulsion field out; attraction field as a trap (too close -> pulled in, slow free escape or fast escape for energy); wind tunnel kept in mind but should become steam; lift platforms out; rotating platforms out, except clock-hand (vertical) rotation always on without floor bugs and the tilting platform always on; conveyors become Mario-Kart-style speed pads (short boost), some activated by targets; geyser great; steam nozzle jump out; bounce pad higher/further when energy is in the arm; level gimmick: charge the level and things activate depending on the charge; boost ring fits; angled steam nozzle (cannon) ok but needs a fix; pneumatic tube out; slingshot core as a free "jump core" counterpart of the Loader; pendulum fits; piston wall fits.

## 7. Roadmap impact (proposal, apply via /gsd-phase)

- **Phase 5 -> Energy Arm & Loader:** resource with cores and the Moto Perpetuo threshold, passive momentum charge, energy capsules, charge button, energy costs for the moves above, Loader with charge-ring HUD and trajectory preview, removal of aim mode, a Loader test room with a metrics table.
- **New phase after 5 -> Kit rework** per the new Block 6.
- **Phase 6:** Siphon and Shot modules, enemies, shards, module pickup, energy HUD next to health (replaces the stamina open question).
- **Phase 7:** level gimmick "charge the level".
- **Phase 8:** boss beaten through Loader discharges and shots on weak points.
