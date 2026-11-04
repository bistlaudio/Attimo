# Phase 2: Movement Core & Follow Camera - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-11-04
**Phase:** 2-Movement Core & Follow Camera
**Areas discussed:** Run & sprint feel, Dash behaviour, Camera feel, Movement gym & measurement, Jump combos

---

## Run & sprint feel

| Option | Description | Selected |
|--------|-------------|----------|
| Snappy | Full speed in about 0.1-0.15 s | |
| Soft/gliding | About 0.3 s build-up | |
| You decide | Snappy start | |

**User's choice:** Free text: orientate on Super Mario.
**Notes:** Air control high, sprint hold, sprint about 1.5x run speed (all recommended options).

---

## Dash behaviour

**User's choice:** Direction: asked for examples of 3D platformers, then agreed to input direction (fallback facing). Fixed distance with carried speed, jump during dash inherits speed, short cooldown 0.3-0.5 s.

---

## Camera feel

**User's choice:** Framing like Odyssey/BotW/Kirby/Bananza (centered, chosen after examples). Auto-recentering like Odyssey (also for controller), plus a recenter key. Light follow damping. Asked for an analysis of Phantom Camera vs own rig: chose own rig, Phantom Camera dropped.

---

## Movement gym & measurement

**User's choice:** One hall with zones; auto-measure overlay + metrics table; software latency measurement; platform carry with momentum on leaving (all recommended).

---

## Jump combos

| Option | Description | Selected |
|--------|-------------|----------|
| Landing chain 1-2-3 plus double jump | Odyssey-like | |
| Landing chain instead of double jump | | |
| Double jump only | Roadmap | |
| Tempo chain (speed grows) | Proposed by Claude | |

**User's choice:** Free text: not a copy of Mario. Ground: Jump 1 -> Jump 2 -> Dash -> Jump = maximum long jump. Air: double jump, double jump -> dash, or jump -> dash. Possible prosthesis down-glide while charged: decide later.
**Notes:** Variable height in every jump (recommended). Reset on landing.

---

## Claude's Discretion

Start values and curves, default sensitivity, camera constants, overlay keys.

## Deferred Ideas

Prosthetic down-glide/blast (charge mechanic), Odyssey triple jump, tempo stages, dive/glide verbs.
