# Phase 3: Animated Mannequin & Aim Mode - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-12
**Phase:** 3-Animated Mannequin & Aim Mode
**Areas discussed:** Ground dash & slide, Aim mode behavior, Jump 3 / run / landing, Aim camera & crosshair

---

## Ground dash & slide

| Option | Description | Selected |
|--------|-------------|----------|
| Dodge_Forward + forward lean | Kit clip plus code lean | ✓ |
| Dodge_Forward plain | Clip unchanged | |
| Slide look | Crouching pose, no kit clip | |

**User's choice:** Dodge_Forward with forward lean; must look good when jumping out of the dash.
**Notes:** Slide question was not understood ("I thought dash with lean, then blend into jump"); slide dropped. Air dash stays as is. Long jump: Jump_Start + stretch lean chosen.

## Aim mode behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Always face crosshair | Strafe and backwards clips | ✓ |
| Smooth follow | Delayed turn | |

**User's choice:** Always face crosshair; run, jump, dash allowed.
**Notes:** Pose: user first preferred the extended arm, viewed Magic_Raise (arm goes up) and rejected it; only 1H_Aiming points forward, so 1H_Aiming. Mannequin has no finger bones.

## Jump 3, run, landing

| Option | Description | Selected |
|--------|-------------|----------|
| Forward flip, flight time | Rejected: too playful for steampunk | |
| Dive (Hechtsprung) | Shown in viewer | |
| Pirouette around vertical axis | One rotation, flight time | ✓ |
| Half flip | Shown in viewer | |

**User's choice:** Pirouette; also at long-jump stack stage 3. Landing: blend without lock.

## Aim camera & crosshair

**User's choice:** Right shoulder with swap key; slightly tighter FOV (10-15 deg) with fast blend; small dot with thin ring.

## Claude's Discretion

Pirouette direction and timing, lean angles, run clip scaling, aim speed and sensitivity factors, FOV/offset values, crosshair size, action name for shoulder swap.

## Deferred Ideas

Slide; other aim poses; other Jump 3 variants.
