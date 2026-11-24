# Phase 5: Energy Arm & Loader - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-24
**Phase:** 05-energy-arm-loader
**Areas discussed:** Loader rules & feel, Energy income, Making energy visible, Aim removed / left click, HUD (added by user)

---

## Loader rules & feel

| Question | Options | Selected |
|---|---|---|
| Loader on the ground | Hard brake then stand (rec.) / air only / small hop into the air | Hard brake then stand |
| Uses per air phase | Once, landing refills (rec.) / unlimited with cooldown + energy / multiple with energy, once empty | Once, landing refills |
| Relation to air dash | Independent, 0.15 s control lock (rec.) / refills air dash / spends air dash | Independent |
| Feel property | "Geladen" loaded spring (rec.) / "wuchtig" weighty / "knackig" snappy | Geladen |

## Energy income

| Question | Options | Selected |
|---|---|---|
| Passive threshold | ~10 m/s (rec.) / 12 m/s as in design doc / from running, weak | ~10 m/s |
| Charge button | Own key R, standing only (rec.) / RMB standing / E standing | R, standing only |
| Draining capsules | Hold E (rec.) / run-through pickup / mixed | **Other:** left click, because later the module decides between extracting and shooting |
| Follow-up: how much Extractor now | Real Extractor module, capsules only (rec.) / minimal raycast / Extractor + Shot both | Real Extractor module, capsules only |
| Refill | respawn_time param, gym timed, level one-shot (rec.) / always one-shot | respawn_time param |

## Making energy visible

| Question | Options | Selected |
|---|---|---|
| Cores on Mannequin | 4 greybox cores on forearm + small screen readout (rec.) / arm only / screen only | Forearm cores + readout |
| Moto Perpetuo look | Brighter arm + flash on enter/exit (rec.) / plus speed lines/FOV / arm only | **Other:** brighter arm, both feet glow, a point on the back glows |
| Spend/lack feedback | Core flash, grey flicker, silent fallback (rec.) / also signal on fallback | Recommended |

## Aim removed / left click

| Question | Options | Selected |
|---|---|---|
| Fernauslöser with Extractor on LMB | Second module, wheel switch, hip fire (rec.) / drop until Phase 6 / switch + cost 10 now | Second module, wheel switch |
| Big pulse | Drop, tap only (rec.) / keep as hip hold | **Other:** stays, longer hold draws more energy and does more damage |
| Follow-up: charge model | Tap free + continuous drain / stages 10 and 25 / tap 10 + continuous | **Other:** tap 10 fits; asked for expert view (continuous vs. 3 stages, leaning continuous) |
| Follow-up: when | Phase 5, damage Phase 6 (rec.) / Phase 6 | **Other:** Phase 5; no beam, a shot like Mega Man or Samus |
| Expert follow-up: model | Hybrid continuous drain + one readable full charge (rec.) / pure continuous / 3 fixed stages | Hybrid |
| Shot under 10 | No shot, grey flicker, gym capsules at puzzles (rec.) / weak free pulse | Recommended |
| Aim assist | Snap + hysteresis, no slowdown (rec.) / all as Phase 4 | **Other:** yes but stronger snap; targets hit in momentum should be plate-like gear discs with a noticeable snap |

## HUD (added by user)

| Question | Options | Selected |
|---|---|---|
| Which HUD | Energy HUD now, health Phase 6 (rec.) / full HUD with dead health bar | Energy HUD now |
| Where / style | Bottom left steampunk (rec.) / bottom centre / top left | **Other:** top left; plus a momentum readout; the Loader hold shows a turning ring at the crosshair like the shot charge, but slightly different so they can be told apart |

## Claude's Discretion

Loader build (Capture extension vs. new state), all Loader numbers, slow-motion technique, hold cancel, Extractor cone and movement while extracting, HUD and glow sizes, projectile speed/size/bend, assist angle.

## Deferred Ideas

- Target look as gear discs: Phase 05.1.
- Health next to energy HUD: Phase 6.
- Shot damage, shards, Extractor on enemies: Phase 6.
