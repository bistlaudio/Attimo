---
phase: 05-energy-arm-loader
reviewed: 2026-11-24T19:50:21Z
depth: standard
files_reviewed: 44
files_reviewed_list:
  - attimo/autoload/event_bus.gd
  - attimo/autoload/time_fx.gd
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scripts/core/bone_attach.gd
  - attimo/scripts/debug/tuning_panel.gd
  - attimo/scripts/gym/energy_drain_plate.gd
  - attimo/scripts/gym/fall_reset.gd
  - attimo/scripts/hand/hand_controller.gd
  - attimo/scripts/hand/hand_module.gd
  - attimo/scripts/hand/hand_presentation.gd
  - attimo/scripts/hand/modules/dummy/dummy_module.gd
  - attimo/scripts/hand/modules/extractor/extractor.gd
  - attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd
  - attimo/scripts/hand/pulse_hit.gd
  - attimo/scripts/hand/shot_projectile.gd
  - attimo/scripts/hand/targeting.gd
  - attimo/scripts/mechanisms/energy_source.gd
  - attimo/scripts/mechanisms/interactable.gd
  - attimo/scripts/player/arm_energy.gd
  - attimo/scripts/player/arm_energy_presentation.gd
  - attimo/scripts/player/loader_math.gd
  - attimo/scripts/player/loader_preview.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/movement_config.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/procedural_pose.gd
  - attimo/scripts/player/states/air_state.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/ground_state.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/loader.gd
  - attimo/scripts/player/states/run.gd
  - attimo/scripts/player/states/wall_run.gd
  - attimo/scripts/ui/crosshair.gd
  - attimo/scripts/ui/energy_hud.gd
  - attimo/scripts/ui/loader_look.gd
  - attimo/scripts/ui/loader_vignette.gdshader
  - attimo/scripts/ui/placeholder_tone.gd
  - attimo/tools/energy_area_builder.gd
  - attimo/tools/loader_room_builder.gd
  - attimo/tools/mechanism_rooms_builder.gd
  - attimo/tools/movement_gym_builder.gd
  - attimo/tools/movement_metrics.gd
  - attimo/tools/puzzle_rooms_builder.gd
findings:
  critical: 1
  warning: 5
  info: 8
  total: 14
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-11-24T19:50:21Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Reviewed the Phase 5 diff (`20fb078^..HEAD`) for the energy system (ArmEnergy, EnergySource, Extractor), the Loader (LoaderState, LoaderMath, preview, look, camera hooks), TimeFx, the projectile shot (RemoteTrigger, ShotProjectile), the aim-mode removal and the gym/metrics tools.

The stated invariants hold:
- Only `autoload/time_fx.gd` writes `Engine.time_scale`. A grep for `Engine.time_scale =` and `set_time_scale(` outside `tests/` finds no other writer.
- No `.aiming`, `aim_changed`, `GlowStage.AIM`, `look_sensitivity_multiplier` or `hand_sticky*` reference is left.
- The movement FSM still drives the animator. `STATE_TO_ANIM` has a `Loader` entry, and the arm layer reads `HandController.arm_out`.

The exit paths that restore the time scale (Loader exit, `_exit_tree`, teleport) look correct.

The main defects:
- Energy is destroyed silently when the module changes mid-charge (BLOCKER).
- The real-time delta conversion is off on the frame the time scale changes.
- The ground Loader can bypass the "one use per airborne stretch" rule.
- `ArmEnergy.drain` floods the EventBus every tick.
- The LoaderLook vignette jumps on release.

## Critical Issues

### CR-01: [BLOCKER] Shot energy is destroyed when the module changes during a charge

**File:** `attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd:25-31, 63-64, 111-114`, `attimo/scripts/hand/hand_controller.gd:102-106`
**Issue:** `on_use_pressed` pays `hand_shot_cost_min` (10) up front, and `on_use_held` drains up to `hand_shot_cost_max` (25 in total). `HandController.equip()` handles a switch mid-hold like this:
- It sets `_use_active = false` and calls only `active_module.deactivate()`.
- It never calls `on_use_released()`.
- `RemoteTrigger.deactivate()` only sets `_active = false`.

A mouse-wheel or 1/2 key press while left click is held therefore deletes up to 25 energy (a full core) with no shot, no refund and no fact on the bus. Nothing in the 05-04 plan specifies this loss. The plan only says "switching modules mid-hold calls deactivate".

`_fire()` has the same problem. When it returns early (null projectile, no parent, non-finite direction), it has already reset `_spent` and started the cooldown, so the energy is gone there too.

ArmEnergy is the single owner of the core resource, and this path breaks its "all or nothing" contract.
**Fix:** Settle the paid energy in `deactivate()`, either by firing the shot or by refunding it. Refunding avoids a surprise shot:
```gdscript
func deactivate() -> void:
	if _active and _spent > 0.0 and ctx != null and ctx.player != null:
		ctx.player.arm_energy.gain(_spent, &"shot_refund")
	_active = false
	_spent = 0.0
```
In `_fire()`, check `projectile`, `parent` and `direction` before resetting `_spent` and starting the cooldown, and refund on the early return. Add a test case to test_hand_module: switch mid-charge and expect the energy to be unchanged, or a shot to be fired.

## Warnings

### WR-01: [WARNING] `TimeFx.unscaled(delta)` gives a wrong real delta on every frame the time scale changes

**File:** `attimo/autoload/time_fx.gd:64-65` (consumers: `camera_rig.gd:237`, `states/loader.gd:61`, `loader_look.gd:43`, `crosshair.gd`, `arm_energy_presentation.gd:127`, `mannequin_animator.gd`, `placeholder_tone.gd:78`, `energy_hud.gd:67`)
**Issue:** `unscaled()` divides `delta` by the *current* `Engine.time_scale`. This rests on one engine fact: Godot's `Main::iteration()` reads `time_scale` once at the start of the iteration and scales every physics step and the process step of that frame with it. A `request`, `release` or `pulse` made during a physics tick therefore changes the divisor but not the delta that was already scaled. Examples:
- **Loader enter (1.0 to 0.25):** `_process` of that frame gets `dt * 1.0`, and every real-time consumer reads 4x the real time. The camera follow weight, the pitch-limit ease, the pull-back and the LoaderLook fade all jump.
- **Release with hitstop (0.25 to 0.05):** that frame reads `dt * 0.25 / 0.05`, which is 5x real time. The camera follow lurches exactly when Rino is thrown at up to 22 m/s, so the core-value move gets a visible hitch.
- **Several physics steps in one frame** (frame rate below the tick rate): the first Loader tick after `enter()` counts `delta / 0.25`. `hold_real` and the skid then over-count by 4x for that tick.

Tests do not catch this because they assert `Engine.time_scale`, not per-frame real deltas.
**Fix:** Make the divisor match the scale that produced the delta. Two options:
- TimeFx keeps `_frame_scale`, refreshed at the start of each iteration (for example an early `process_priority` callback, plus a physics-side mirror), and `unscaled()` divides by `_frame_scale`.
- `_apply()` defers its write with `call_deferred` / `set_deferred("time_scale")` to the start of the next frame, so a change never lands mid-iteration.

The simplest robust fix for `_process` consumers is to measure real time directly (`Time.get_ticks_usec()` delta, cached once per frame in TimeFx).

### WR-02: [WARNING] A ground Loader discharge can leave the floor without spending `loader_available` (D-02 bypass)

**File:** `attimo/scripts/player/states/loader.gd:64-70, 117-118`
**Issue:** `loader_available` is spent for a ground entry only when `velocity.y > 0.0` at the release. There are two ways around this:
- The third-person camera usually looks slightly down, so a forward ground discharge often has `velocity.y <= 0`. When that throw carries Rino over a ledge (the Loader_Gap station is built for exactly this), he is airborne with `loader_available == true`. He can hold a second Loader in the same airborne stretch.
- With a ground entry, gravity stays on during the hold. If the skid carries Rino off a ledge mid-hold, he discharges in the air and keeps the air use too.

Both break "one use per airborne stretch".
**Fix:** Decide at the release from the actual contact state, and also treat a ground entry that is no longer grounded as an air use:
```gdscript
if grounded_entry and (velocity.y > 0.0 or not actor.is_grounded()):
	actor.loader_available = false
```
For a downward throw that walks off an edge later, also clear `loader_available` in `_leave_floor()` when `loader_cooldown_timer` or a "just discharged" flag is set. Another option: always spend it on a ground discharge and give it back in `_land()`, which already restores it.

### WR-03: [WARNING] `ArmEnergy.drain` emits `energy_spent` on every physics tick and floods the EventBus and the EventLog

**File:** `attimo/scripts/player/arm_energy.gd:54-63`; callers `states/wall_run.gd:59`, `modules/remote_trigger/remote_trigger.gd:45`
**Issue:** The class header promises quantisation (T-05-09) so that 60 Hz energy changes never flood the EventLog, but only `energy_changed` is quantised. `drain()` emits `EventBus.energy_spent(taken, reason)` on every call. A paid wall run (up to `wall_run_time` minus 0.6 s) and every shot charge (about 0.8 s) therefore emit 60 facts per second at 60 TPS, and 120 at 120 TPS. `scripts/debug/event_log.gd:17-18` connects to every EventBus signal, so the debug log fills with `energy_spent` lines. Later audio and juice listeners would fire per tick.
**Fix:** Do what `tick()` already does for the charge button. Accumulate the drained amount per run and emit one `energy_spent(total, reason)` when the run ends: the wall run's `exit()`, and the shot's release or deactivate. Alternatively, give `drain()` a `silent` flag and have the caller report the total.

### WR-04: [WARNING] The LoaderLook vignette and desaturation get stronger on an early release instead of fading out

**File:** `attimo/scripts/ui/loader_look.gd:53`
**Issue:** GDScript's ternary binds loosest, so `level * (0.5 + 0.5 * ratio if holding else level)` parses as `level * ((0.5 + 0.5 * ratio) if holding else level)`. A worked example with a short hold, `ratio = 0.1` and `level = 1.0`:
- Last held frame: the amount is `1.0 * 0.55 = 0.55`.
- First released frame: `level` is about 0.86 and the amount is `level * level`, about 0.74.

The vignette and the grey therefore jump *up* by about a third at the moment of release, then fade. That breaks the class's own "eases, never a cut" rule (D-04), and it happens on every quick tap.
**Fix:** Keep the last hold ratio and fade the product:
```gdscript
if holding:
	_last_ratio = ratio
_apply(level * (0.5 + 0.5 * _last_ratio))
```

### WR-05: [WARNING] A tapped Moto Perpetuo Jump 3 is lower than a tapped normal Jump 3

**File:** `attimo/scripts/player/states/jump.gd:16-21`, `air_state.gd:45-50`
**Issue:** The buffed Jump 3 raises `gravity_scale` to `moto_jump_gravity_scale` (1.45), but `apply_jump_cut()` still clamps the rise to `config.cut_speed()`, which is tuned for scale 1.0. The tap height is `cut^2 / (2 * g * scale)`, so a released button under Moto reaches only about 69% of the normal tap height. The buffed jump becomes *worse* than the unbuffed one whenever the player does not hold jump to the apex. This contradicts D-10 ("Moto buffs Jump 3") and hurts the core-value jump chain.
**Fix:** While the scale is active, scale the cut speed with the gravity factor so the tap apex is preserved. For example, in `apply_jump_cut` use `cut * sqrt(actor.gravity_scale)` when `gravity_scale > 1.0`, or add a `moto_cut_speed()` to MovementConfig that is derived the same way as the take-off speed.

## Info

### IN-01: [INFO] HandController hard-codes the shot module id

**File:** `attimo/scripts/hand/hand_controller.gd:219`
**Issue:** `_update_shot_ready` compares `active_def.id == &"remote_trigger"`, although the class header says it "names no module class". A second shooting module would never light SHOT_READY.
**Fix:** Add a virtual `HandModule.shot_cost() -> float` (INF for none), or a `fires_shots` flag on HandModuleDef, and ask the active module.

### IN-02: [INFO] An evicted or invalid ShotProjectile frees itself without `pulse_fired`

**File:** `attimo/scripts/hand/shot_projectile.gd:35-36, 42-45`
**Issue:** The MAX_LIVE eviction (`pop_front().queue_free()`) and the `setup()` failure path free the projectile without `_finish()`. The paid shot then ends with no `pulse_fired`, which contradicts the EventBus doc ("emitted when it ends ... valid or not").
**Fix:** Call `_finish(global_position, false)` instead of a bare `queue_free()` on eviction, and guard `_finish` against a double call through `_done`.

### IN-03: [INFO] HandPresentation runs on scaled time, unlike every other Phase 5 presentation

**File:** `attimo/scripts/hand/hand_presentation.gd:71-73`
**Issue:** `_time` and the palm flash decay use the raw `delta`. During the Loader hold (scale 0.25) the near-contact pulse and the shot flash last 4x longer than in normal time. During the 0.05 hitstop they freeze. ArmEnergyPresentation, the crosshair and the HUD all use `TimeFx.unscaled`.
**Fix:** Use `var real: float = TimeFx.unscaled(delta)` for both, after fixing WR-01.

### IN-04: [INFO] The shot charge, tap window and cooldown run on scaled time during the Loader slow motion

**File:** `attimo/scripts/hand/hand_controller.gd:160, 204`, `remote_trigger.gd:40-45`
**Issue:** `on_use_held(delta)` receives the scaled physics delta. A shot charged during a Loader hold therefore takes 4x the real time (3.2 s instead of 0.8 s), and the crosshair ring turns in real time while it fills in slow time. This may be intended, but no decision records it.
**Fix:** Decide it explicitly. If the charge should feel the same, pass `TimeFx.unscaled(delta)` into the charge accounting.

### IN-05: [INFO] `hand_shot_big_energy` above `hand_shot_cost_max` makes a BIG shot unreachable without warning

**File:** `attimo/scripts/hand/hand_controller.gd:33, 43`, `pulse_hit.gd:28-29`
**Issue:** Both values are independent F2 sliders (1..100). When `hand_shot_big_energy` is tuned above `hand_shot_cost_max`, no shot can open a heavy mechanism (the Valve), and nothing reports it.
**Fix:** Clamp the BIG threshold to the cost maximum where it is used (`minf(hand_shot_big_energy, hand_shot_cost_max)`), or add a check to test_shot.

### IN-06: [INFO] The Loader preview differs from the real flight

**File:** `attimo/scripts/player/loader_preview.gd:15, 55-61`, `loader_math.gd:30-37`
**Issue:** There are two differences:
- The arc starts 0.9 m above the body origin, while the discharge moves the origin (the feet).
- `LoaderMath.step` ignores `_zone_gravity_scale` (LowGravityZone) and the player's capsule (ray only).

So in a low-gravity zone, or near a lip, the preview no longer matches the release. That weakens "what the preview promises is what the release does".
**Fix:** Pass the current zone gravity factor into `trajectory()`. Document the 0.9 m offset as the body centre, or start the arc at the origin plus the capsule centre (1.0 m).

### IN-07: [INFO] TimeFx `release()` does not clear the pulse id of that source

**File:** `attimo/autoload/time_fx.gd:51-53`
**Issue:** The sequence `pulse(A)`, then `release(A)`, then `request(A)` leaves `_pulse_ids[A]` set. The old pulse's timer then releases the newer manual request. This does not happen today, because `&"loader_hitstop"` is only ever pulsed, but the guard in `_end_pulse` claims more than it covers.
**Fix:** Add `_pulse_ids.erase(source)` in `release()` and in `request()`.

### IN-08: [INFO] ArmEnergyPresentation disconnects in `_exit_tree` but connects only in `_ready`

**File:** `attimo/scripts/player/arm_energy_presentation.gd:74, 121-123`
**Issue:** If the node is removed from the tree and added back (reparenting, or a scene swap that keeps the node), `_ready` does not run again. The refusal flicker then stops working without any error. Godot already drops connections to freed objects, so the manual disconnect is unnecessary.
**Fix:** Remove the `_exit_tree` disconnect, or connect in `_enter_tree` with an `is_connected` guard.

---

_Reviewed: 2026-11-24T19:50:21Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
