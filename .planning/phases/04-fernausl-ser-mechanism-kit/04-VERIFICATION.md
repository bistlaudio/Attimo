---
phase: 04-fernausl-ser-mechanism-kit
verified: 2026-11-23T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
warnings:
  - "CR-01 (open): Mechanism.reset() does not resync from a still-active source; the PuzzleRoom_2 pendulum (hazard only) stops after FallReset"
  - "CR-02 (open): Pendulum knock tangent rotated twice; knocks against swing direction beyond about 45 deg"
  - "WR-01..WR-04, IN-01..IN-04 from 04-REVIEW.md open, none blocking"
---

# Phase 4: Fernausloeser & Mechanism Kit Verification Report

**Phase Goal:** As a player, I want to aim the Fernausloeser pulse at glowing mechanisms, so that I can solve puzzles from a distance.
**Status:** passed (2 non-blocking critical review defects recorded as warnings)
**Re-verification:** No, initial verification

## Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Interactables glow, targeted one highlighted, aim assist without flicker | VERIFIED | `scripts/hand/targeting.gd` (glow stages, hysteresis), `test_aim_target`, `test_retarget`, `test_retarget_sanity`, `test_interactable` pass in the last full run. Human feel check approved 2026-11-23. |
| 2 | Pulse triggers lever/valve at range, next-frame reaction; non-accepting interactable shows invalid reticle and stays unchanged | VERIFIED | `remote_trigger.gd`, `interactable.gd`, `crosshair.gd`; `test_pulse`, `test_interactable`, `test_hand_module` (I re-ran: 20/20 pass) |
| 3 | Showcase room plus puzzle rooms from Prototype Bits, D-15 triggers and D-16 mechanisms, AND/OR/timer logic wired in editor | VERIFIED | `tools/puzzle_rooms_builder.gd`, `scenes/mechanisms/*.tscn` (13 scenes: triggers, logic_and/or/timer, gate, platforms, conveyor, nozzle, pendulum). I re-ran `test_mechanism_rooms`: 165/165 pass, including scripted solve of all three rooms opening the exit gate. |
| 4 | Moving mechanisms carry the player without sliding, jitter or launching | VERIFIED | `test_mechanism_carry`, `test_moving_mechanisms` (full run passed). Human feel check approved. The pendulum knock (CR-02) is an intentional hazard impulse, not carry. |
| 5 | Dummy module added with one folder + one registry entry; arm mesh never changes | VERIFIED | `scripts/hand/modules/dummy/` (def, module, scene) plus `ModuleRegistry.modules` explicit list; `test_hand_module` passes (dummy receives use, no pulse). No arm mesh swap in `hand_module_def`. |

**Score:** 5/5

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| HAND-01 | SATISFIED | Module def + behaviour scene + registry; dummy module test |
| HAND-02 | SATISFIED | Interactable accept contract; `test_interactable` |
| HAND-03 | SATISFIED | `remote_trigger` tap/hold pulse; `test_pulse` |
| CAM-04 | SATISFIED | Glow stages in targeting/interactable |
| CAM-05 | SATISFIED | Aim assist with hysteresis, `test_aim_target`/`test_retarget` |
| MECH-01 | SATISFIED | All listed mechanism scenes exist |
| MECH-02 | SATISFIED | logic_and/or/timer plus packed-ref round trip, `test_logic_nodes` |
| MECH-03 | SATISFIED | carry tests, human check |

All 8 IDs appear in plans and REQUIREMENTS.md; no orphans.

## Review Findings Judgement

- **CR-01 (confirmed in code):** `Mechanism.reset()` sets `signal_on = false` without re-reading `source.is_active`. Puzzle room 2's pendulum driver (`start_active = true`, `puzzle_rooms_builder.gd` around line 234) stays active, so after a FallReset the pendulum stays off. The pendulum is an optional hazard, not on the required solve path (the scripted solve passes, and a stopped pendulum only makes the room easier). No success criterion or requirement is violated. This is a real robustness defect: **WARNING**, fix recommended before the Phase 12 polish or whenever mechanisms are reused after resets (resync from source at end of reset).
- **CR-02 (confirmed in code, `pendulum.gd` `_try_knock`):** `_arm.global_basis` is applied to a tangent already in parent frame, so the knock direction flips beyond about 45 deg. The knock is a hazard feedback, and no criterion specifies its direction. SC4 concerns carry, which is verified separately. **WARNING**: fix with `global_basis * Vector3(cos, sin, 0)` or `_arm.global_basis * Vector3.RIGHT`.
- WR-01 to WR-04 and IN-01 to IN-04: no must-have impact; recommend a small fix-up pass (teleport clearing push requests, null guard in RemoteTrigger, freeing a failed module instance).

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Puzzle rooms solve | `bash attimo/tests/run.sh test_mechanism_rooms` | 165 passed, 0 failed | PASS |
| Hand module / dummy | `bash attimo/tests/run.sh test_hand_module` | 20 passed, 0 failed | PASS |
| Full suite | (orchestrator-reported last run) | PASSED, 54 files | PASS |

## Anti-Patterns

No TBD/FIXME/XXX markers found in `scripts/hand`, `scripts/mechanisms`, `tools/puzzle_rooms_builder.gd`.

## Human Verification

End-of-phase feel check (plan 04-05) was approved by the user on 2026-11-23. No open items.

## Gaps Summary

No blocking gaps. Goal achieved. Open warnings: CR-01 and CR-02 (hazard pendulum behaviour), plus review warnings, recommended as a follow-up fix pass (`/gsd-code-review-fix 4`).

_Verified: 2026-11-23_
_Verifier: Claude (gsd-verifier)_
