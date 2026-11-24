---
phase: 05-energy-arm-loader
verified: 2026-11-24T21:00:00Z
status: human_needed
score: 6/6 roadmap success criteria verified in code (feel parts pending human)
overrides_applied: 0
gaps: []
advisory_defects:
  - id: CR-01
    severity: blocker-per-review, not a roadmap SC break
    note: "RemoteTrigger.deactivate() only sets _active=false; HandController.equip() never calls on_use_released(). Switching module while left click is held after the 10-energy press loses up to 25 energy with no shot/refund. Confirmed in remote_trigger.gd:25-31,111-114 and hand_controller.gd:102-106. Recommend fixing (refund _spent in deactivate, ~5 lines + test) before merging dev to main."
  - id: WR-02
    note: "Ground Loader discharge with velocity.y <= 0 keeps loader_available (D-02 'one use per airborne stretch' bypass)."
  - id: WR-05
    note: "Tapped Moto Jump 3 is ~69% of the tapped normal Jump 3 (cut speed not scaled with gravity_scale 1.45); the buff only holds when jump is held."
  - id: WR-01
    note: "TimeFx.unscaled(delta) is off on frames where time_scale changes (Loader enter and release hitstop): camera/vignette hitch. Feel risk, not a logic break."
  - id: WR-03_WR-04
    note: "drain() emits energy_spent per tick (EventLog flood); LoaderLook vignette jumps up on early release."
human_verification:
  - test: "Loader tracer feel: hold RMB on ground and in air, release"
    expected: "0.25x slow motion, free camera, ring + dashed preview, discharge matches preview; smooth, no camera lurch on release (WR-01)"
    why_human: "Feel and visual smoothness"
  - test: "Geladen cues (vignette, desaturation, pull-back, hitstop, hum) at 60/120/10 TPS; tap the Loader quickly"
    expected: "Eases in/out; vignette does not jump up on early release (WR-04)"
    why_human: "Frame-rate dependent visuals"
  - test: "F2 Loader tuning panel"
    expected: "Sliders change min push, bonus, cap, hold time, slow factor live and sensibly"
    why_human: "Tuning UX"
  - test: "Forearm core readability (offsets on lowerarm.r unverified) and Moto glow"
    expected: "4 cores readable on the arm in third person; Moto glow visible"
    why_human: "Visual"
  - test: "Refused air dash feedback with empty arm"
    expected: "Air dash does not fire and a grey flicker shows; base moves fall back silently"
    why_human: "Feedback clarity"
  - test: "HUD readability and turquoise body glow"
    expected: "Energy HUD top left readable; body glow reads Moto state"
    why_human: "Visual"
  - test: "Passive charge and dash-hop cost motivation (Moto run 9.52 m/s is under the 10 m/s charge start)"
    expected: "Energy income feels reachable by running; costs motivate Loader/capsule use"
    why_human: "Design feel; possible tuning mismatch"
  - test: "Shot as visible ball, full-charge tell; shot ring vs Loader ring distinguishable without colour"
    expected: "Clear, distinguishable"
    why_human: "Visual"
  - test: "Hip-fire snap/bend while dash-hopping; Extractor feel"
    expected: "No unpleasant snap; Extractor drain readable"
    why_human: "Feel"
  - test: "Tuning guesses (7 deg, 540 deg/s, 40 m/s, 4 m)"
    expected: "Accepted or retuned"
    why_human: "Feel"
  - test: "West-wing gym walkthrough of the 'Erwartet:' stations; Phase 04.1 UAT re-check for changed Ausloeser stations/puzzle rooms"
    expected: "Each station behaves as its sign says; 04.1 behaviours not regressed"
    why_human: "Interactive playthrough"
  - test: "4 m jump to reach the Loader door (keep vs bridge)"
    expected: "Decision: keep or add a bridge"
    why_human: "Design decision"
  - test: "Switch module mid-charge (CR-01) and Moto Jump 3 tap (WR-05)"
    expected: "No energy lost; tapped Moto Jump 3 not lower than normal"
    why_human: "Confirm defect impact / retest after fix"
---

# Phase 5: Energy Arm & Loader Verification Report

**Goal:** speed turns into energy and energy into more speed via the arm cores and the RMB Loader.
**Re-verification:** No, initial.
**Status:** human_needed

## Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 0-100 energy in 4 cores of 25, readable; Moto from 50 (faster run, buffed Jump 3, brighter arm); respawn = 1 core | VERIFIED (visuals human) | arm_energy.gd (CORE_SIZE 25, CORE_COUNT 4, MAX 100, moto hysteresis); is_moto() used in player_controller.gd:148 (run) and states/jump.gd:16 (stage 3); player_controller.gd:200 calls reset_to_checkpoint(); arm_energy_presentation.gd drives the cores |
| 2 | Income without enemies: passive above ~dash exit speed, capsules/machines via Extractor, slow charge button | VERIFIED | ArmEnergy.passive_rate/tick, energy_charge_rate 5.0, energy_source.gd and extractor.gd present; test_energy_income, test_extractor |
| 3 | Base free, injected cost; air dash refuses when empty; hop 2-3 cost; wall run free window then cost | VERIFIED | player_controller.gd:295 (refuse), :342 (spend), :549 (stage>=2 try_spend with fallback); wall_run.gd:57-59 drain after wall_run_free_time; test_energy_costs |
| 4 | RMB hold: ~0.25x slow motion, cap 1.2 s, free camera, ring, dashed preview; release at max(stored, min push) + bonus costing one core; empty arm redirects with cooldown | VERIFIED (feel human) | loader.gd (hold_real, cap, try_spend bonus at release, redirect cooldown), loader_math.gd, loader_preview.gd, TimeFx sole time_scale owner; movement_config loader_slow_factor 0.25, hold_cap 1.2 |
| 5 | Aim mode gone; crosshair and aim assist stay; Loader room exists; metrics tuned | VERIFIED | grep of scripts/ and scenes/ for aiming, aim_changed, hand_sticky, pull_push: no hits; test_aim_removed; loader_room_builder.gd; movement_metrics.gd Loader rows; docs/MOVEMENT-METRICS.md |
| 6 | Gym reworked: aim stations removed, Loader and energy area added | VERIFIED (walkthrough human) | energy_area_builder.gd, loader_room_builder.gd, test_energy_gym, test_loader_room |

**Score:** 6/6 verified in code. Orchestrator ran `bash attimo/tests/run.sh`: 73 tests PASSED.

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| HAND-04 | SATISFIED | Truth 4 |
| FEEL-10 | SATISFIED (tuning human) | Truth 5, metrics rows |
| ENRG-01 | SATISFIED | Truth 1 |
| ENRG-02 | SATISFIED | Truth 2 |
| ENRG-03 | SATISFIED | Truth 3 |
| ENRG-04 | SATISFIED | Truth 5 |
| ENRG-05 | SATISFIED (readability human) | energy_hud.gd, test_energy_hud |

All 7 IDs are marked Complete in REQUIREMENTS.md. No orphaned requirements for Phase 5 were found (grep of the ENRG/HAND-04/FEEL-10 rows).

## Anti-Patterns

No TODO/FIXME/XXX/TBD markers found in scripts, autoload or tools.

## Review findings weighed

- **CR-01 (confirmed in code):** a real energy-loss bug, but it sits on the edge path (module switch mid-charge) and does not contradict any roadmap success criterion, so it is not recorded as a failed truth. It violates the ArmEnergy "all or nothing" contract; fix before merging (refund in `deactivate()`, plus a test).
- **WR-02, WR-05:** break design decisions D-02 and D-10 in edge cases; they do not break the ROADMAP SCs (Moto Jump 3 is still buffed when jump is held). Recommend fixing, as WR-05 touches the core-value jump chain.
- **WR-01, WR-03, WR-04:** feel and log hygiene. They fall into the feel checks above.

## Gaps Summary

No roadmap truth failed. The phase goal is implemented and wired. The status is human_needed because of the skipped feel checkpoints, and the CR-01 fix is strongly recommended before the dev to main merge.

---
_Verified: 2026-11-24_
_Verifier: Claude (gsd-verifier)_
