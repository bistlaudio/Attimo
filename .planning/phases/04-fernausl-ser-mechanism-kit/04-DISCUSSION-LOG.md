# Phase 4: Fernauslöser & Mechanism Kit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-20
**Phase:** 04-fernausl-ser-mechanism-kit
**Areas discussed:** Fernauslöser design, Glow & aim assist, Mechanism behaviour, Sandbox puzzle room

---

## Fernauslöser design

| Option | Description | Selected |
|--------|-------------|----------|
| Aim only | RMB held, LMB fires | ✓ |
| Also hip fire | LMB without aim at nearest target | |
| Aim optional, hip with strong assist | both | |

| Option | Description | Selected |
|--------|-------------|----------|
| Tap = one impulse | short beam, one trigger | |
| Hold = continuous beam | beam while held | |
| Tap + hold per target | two rules | |

**User's choice (free text):** short tap = small pulse shot, short hold = bigger shot, never a beam.

| Option | Description | Selected |
|--------|-------------|----------|
| Heavy mechanisms | big pulse needed for heavy parts | ✓ |
| More range | | (later added: big pulse also reaches further) |
| Area / multiple targets | | |
| Feel only | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Instant hit + pulse visual | raycast, same frame | ✓ |
| Fast projectile | | |
| Slow projectile | | |

Charge: ~0.4 s, release fires ✓ (vs auto-fire, you decide). Empty/wrong target: pulse fires anyway ✓ (vs firing blocked). Cooldown: ~0.25 s ✓ (vs none, you decide).

**Notes:** User asked whether small enemies come with the shot: answered Phase 6 (SHOOT-01..03); hit data prepared now.

---

## Glow & aim assist

| Option | Description | Selected |
|--------|-------------|----------|
| Always faint, stronger in range | | ✓ (stronger in aim, "goggles") |
| Only in aim | | |
| Constant, target extra | | |

Target look: user asked for visualisation. HTML mockup published (artifact NudbTjxCdfq4ZWJ1qaeLKr) and headless screenshots rendered (A bright pulse + ring, B + outline, C + marker). **Choice:** A, but more minimal, thinner, steampunk.

Goggles: user wants a very minimal HUD only in the goggles (aim), thin white lines, maybe goggle rim at the sides. A goggle HUD mockup with 6 elements was rendered. **Choice:** 1 rim + 2 reticle, 3 charge arc, 5 module indicator. Rejected: 4 range scale, 6 cooldown needle ("cooldown of what, I don't like it there").

Reticle colour: white, turquoise on target ✓ (vs brass/cream).

| Option | Description | Selected |
|--------|-------------|----------|
| Snap, no camera pull | | |
| Snap + slight slowdown | sticky aim | ✓ |
| Snap + camera pull | | |

Range: ~20 m / big pulse further ✓ / you decide.

---

## Mechanism behaviour

First pass (toggle/valve/movement/door questions) was answered with "what do we even interact with? give me options first". Claude explained the roadmap list and the three kinds (triggers, reacting parts, invisible logic). User then asked for 20 ideas against the steampunk look, to pick from, and added the near interaction (E, arm out, palm pulses and glows, Iron Man vibe).

20 ideas presented (lever, hand-wheel valve, energy core, pressure plate, clockwork crank, signal bell, gear platform, piston column, extending bridge, conveyor, gear gate, steam jump nozzle, steam wall, chain platform, pendulum, swing bridge, tilting platform, propeller updraft, steam cannon, clock-hand platform).

**User's picks:** 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20; asked to remove redundancies and make a rounded proposal.

**Proposal accepted:** 4 triggers (lever, valve, energy core, crank) + 6 mechanisms (gear gate, rotating platform [7/17/20], lift platform [8/14], conveyor, steam nozzle [12/13/18/19], pendulum). User asked what was dropped: only 4, 9, 16 (never picked); bell folded into lever/core placement.

Near interaction in Phase 4: yes ✓ (vs later). Palm glow also on the shot: yes ("flash, energy should show").

Lever/valve: toggle ✓. Moving parts: configurable per instance ✓. Gate: on = open, off = closed ✓. Crank: hold E to wind up ✓. Nozzle: sets direction, keeps sideways momentum ✓ (vs additive, overrides all). Pendulum: knocks away ✓ (vs only block).

---

## Sandbox puzzle room

User (mid-turn message): extend the gym with a second room where everything is displayed.

| Option | Description | Selected |
|--------|-------------|----------|
| Showcase + small puzzle at the end | | |
| Showcase, puzzle as room 3 | | |
| Showcase only | | |

**User's choice (free text):** showcase, then several puzzle rooms that together cover all mechanisms.

Transition: through a door in the gym ✓ (vs debug teleport, both).

---

## Claude's Discretion

Puzzle room count and layout, all tuning numbers, near-contact range and aim interplay, arm-out pose reuse, pulse streak shape, dummy module behaviour, optional "stays on" lever mode.

## Deferred Ideas

Full goggle look (Phase 11), hand particles (Phase 12), pulse vs enemies/props (Phase 6), module HUD icon (Phase 5), pendulum damage (Phase 6), unpicked mechanisms 4/9/16.
