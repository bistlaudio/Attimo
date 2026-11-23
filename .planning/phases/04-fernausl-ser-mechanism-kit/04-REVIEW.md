---
phase: 04-fernausl-ser-mechanism-kit
reviewed: 2026-11-23T00:00:00Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - attimo/autoload/event_bus.gd
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scripts/debug/tuning_panel.gd
  - attimo/scripts/gym/fall_reset.gd
  - attimo/scripts/hand/hand_context.gd
  - attimo/scripts/hand/hand_controller.gd
  - attimo/scripts/hand/hand_module.gd
  - attimo/scripts/hand/hand_module_def.gd
  - attimo/scripts/hand/hand_presentation.gd
  - attimo/scripts/hand/module_registry.gd
  - attimo/scripts/hand/modules/dummy/dummy_module.gd
  - attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd
  - attimo/scripts/hand/pulse_hit.gd
  - attimo/scripts/hand/targeting.gd
  - attimo/scripts/mechanisms/conveyor.gd
  - attimo/scripts/mechanisms/gear_gate.gd
  - attimo/scripts/mechanisms/interactable.gd
  - attimo/scripts/mechanisms/lift_platform.gd
  - attimo/scripts/mechanisms/logic_and.gd
  - attimo/scripts/mechanisms/logic_or.gd
  - attimo/scripts/mechanisms/logic_timer.gd
  - attimo/scripts/mechanisms/mechanism.gd
  - attimo/scripts/mechanisms/pendulum.gd
  - attimo/scripts/mechanisms/rotating_platform.gd
  - attimo/scripts/mechanisms/signal_source.gd
  - attimo/scripts/mechanisms/steam_nozzle.gd
  - attimo/scripts/mechanisms/triggers/crank.gd
  - attimo/scripts/mechanisms/triggers/energy_core.gd
  - attimo/scripts/mechanisms/triggers/lever.gd
  - attimo/scripts/mechanisms/triggers/valve.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/ui/crosshair.gd
  - attimo/tools/mechanism_rooms_builder.gd
  - attimo/tools/movement_gym_builder.gd
  - attimo/tools/puzzle_rooms_builder.gd
findings:
  critical: 2
  warning: 4
  info: 4
  total: 10
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-11-23
**Depth:** standard
**Files Reviewed:** 36 (all listed runtime scripts and tools; the diff for player_controller, camera_rig and mannequin_animator was reviewed against 472e69f)
**Status:** issues_found

## Summary

The hand, targeting and mechanism contracts are mostly careful: freed targets are guarded with `is_instance_valid`, deferred calls are used for physics-flush launches, and edge-only `set_active` prevents wiring loops. Two real defects remain. Both are reachable in the generated puzzle rooms: the reset sweep leaves any mechanism driven by an always-on source permanently off, and the pendulum knocks the player in the wrong direction in the outer part of its swing. No security issues were found. These scripts handle no external input or secrets.

## Critical Issues

### CR-01: Reset sweep desynchronises a Mechanism from a source that stays active (Pendulum in puzzle room 2 stops forever after a fall)

**File:** `attimo/scripts/mechanisms/mechanism.gd:36-37` (also `logic_and.gd:33`, `logic_or.gd:30`, `signal_source.gd:29`)
**Issue:** `Mechanism.reset()` sets `signal_on = false` directly. It does not re-read `source.is_active`, and it bypasses `_on_signal` and `mechanism_changed`. That only works when the source resets to a different value, because the source then emits `active_changed` and the mechanism catches up. A source whose load state is active emits nothing on reset, because `set_active(true)` is a no-op. The mechanism then stays at `signal_on == false` while its source reports `is_active == true`.
`puzzle_rooms_builder.gd:234-237` wires the Pendulum in PuzzleRoom_2 to exactly such a source, a `start_active` driver. After the first fall, FallReset sweeps the room. The driver stays active (no emission), `Pendulum.reset()` sets `signal_on = false`, and from then on the pendulum never swings again (RUN_WHILE_ON, factor settles to 0). The same happens to any mechanism behind a LogicAnd or LogicOr whose sources are all still active after reset. `test_mechanism_rooms.gd:375` only checks `is_active == start_active`, so it does not catch this.
**Fix:** Resynchronise from the source in `Mechanism.reset()`. Reset order then no longer matters, because a source that resets later still emits and fixes it.
```gdscript
func reset() -> void:
	signal_on = false
	if source != null and is_instance_valid(source) and source.is_active:
		set_signal(true)  # calls _on_signal(true) and emits mechanism_changed
```
Subclasses already call `super.reset()` first and then zero their own state, so `_on_signal(true)` in SteamNozzle runs before `_armed`/`_cooldown` are reset. Move the resync to the end of each subclass reset, or add a `_resync_from_source()` helper that the subclasses call last.

### CR-02: Pendulum knock direction is rotated twice and points backwards in the outer swing

**File:** `attimo/scripts/mechanisms/pendulum.gd:110`
**Issue:** `var tangent := _arm.global_basis * Vector3(cos(_angle), sin(_angle), 0.0) * signf(_omega)`. The vector `(cos a, sin a)` is already the bob's tangent in the parent frame: the bob sits at `(L sin a, -L cos a)`, and its derivative is `(L cos a, L sin a)`. `_arm.global_basis` includes `Basis(Z, _angle)`, so the tangent is rotated by the angle a second time and ends up at `(cos 2a, sin 2a)`. After the `y = 0` flattening, the horizontal component changes sign once `|a| > 45 deg`. With the default `swing_deg = 60` and `omega` still well above `MIN_KNOCK_OMEGA` at `|a| = 50 deg` (about 1.5 rad/s), the player is knocked against the swing direction there. Near the bottom the result is correct, which is why it can pass casual testing.
**Fix:** Use the parent-frame basis (this node's), or the arm's local X axis.
```gdscript
var tangent: Vector3 = (global_basis * Vector3(cos(_angle), sin(_angle), 0.0)) * signf(_omega)
# equivalent: _arm.global_basis * Vector3.RIGHT * signf(_omega)
```

## Warnings

### WR-01: LogicTimer.reset() with start_active switches off one tick later and ignores an active source

**File:** `attimo/scripts/mechanisms/logic_timer.gd:33-35`
**Issue:** `reset()` sets `_left = 0.0` and then `super.reset()` calls `set_active(start_active)`. For `start_active = true` the timer is on with `_left == 0`, so `_physics_process` switches it off on the next tick. After a reset the timer's state also does not follow an already active source, because there is no rising edge. This is the same class of problem as CR-01 on the SignalSource side.
**Fix:** Start the hold in reset when the load state is active:
```gdscript
func reset() -> void:
	_left = hold_time if start_active else 0.0
	super.reset()
```

### WR-02: Stale push requests survive teleport and can launch the respawned player

**File:** `attimo/scripts/player/player_controller.gd:180-186` (`teleport`) and `:304-345` (`push_toward`, `_apply_push_requests`)
**Issue:** `push_toward` records requests that are consumed in the player's next `_physics_process`. A nozzle ticking in the same frame as the fall-reset records a request, and the deferred `teleport()` then zeroes the velocity. The next tick applies the stale updraft or wall push to the respawned player at the marker (up to `accel * delta` of velocity along the push direction). `teleport()` also leaves `_floor_body`, `_floor_carrier` and `_carry_active` as they were. That is harmless today only because `_was_on_floor = false` short-circuits `_attach_to_carrier`. The arrays also grow without bound if the player's physics process is disabled while a nozzle keeps pushing.
**Fix:** In `teleport()`, call `_push_directions.clear()`, `_push_targets.clear()`, `_push_accels.clear()`, and set `_floor_body = null`, `_floor_carrier = null`, `_carry_active = false`.

### WR-03: RemoteTrigger dereferences `ctx.rig.camera` without a null check

**File:** `attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd:26-28`
**Issue:** `Targeting.update` and `CameraRig.aim_ray` both guard `rig.camera == null`. `on_use_released` only checks `ctx.rig != null` and then calls `ctx.rig.camera.global_basis`. A rig whose `camera` export is unset (test scenes, a rig mid-rebuild) crashes on the shot.
**Fix:** `if ctx.rig != null and ctx.rig.camera != null:`, otherwise take the chest-ray fallback branch.

### WR-04: HandController.equip leaks the instance when the cast to HandModule fails

**File:** `attimo/scripts/hand/hand_controller.gd:82-84`
**Issue:** `def.scene.instantiate() as HandModule` returns null for a scene whose root is not a HandModule, but the instantiated node is never freed. Nothing else holds it, so it leaks, and the leak repeats on every `cycle()` over a mis-registered def.
**Fix:**
```gdscript
var node: Node = def.scene.instantiate()
var module: HandModule = node as HandModule
if module == null:
	node.queue_free()
	return false
```

## Info

### IN-01: Targeting mutates a shared preloaded material every frame

**File:** `attimo/scripts/hand/targeting.gd:58-63`
**Issue:** `_process` writes `emission_energy_multiplier` on `Interactable.GLOW_TARGET_MATERIAL`, a shared `res://` resource. It is only safe because there is one Targeting instance. A second hand (a test, a second player) would fight over the value, and an editor save of the resource can persist a pulsed value.
**Fix:** Duplicate the material once in Targeting and assign it, or drive a shader parameter. At minimum, document the singleton assumption.

### IN-02: Crosshair shows a stale state for one frame when aiming starts

**File:** `attimo/scripts/ui/crosshair.gd:113-115`
**Issue:** `_on_aim_changed(true)` makes the HUD visible with the `state`, `charge` and cooldown dim left over from the previous aim. They are only refreshed in the next `_process`.
**Fix:** Call the same poll once in `_on_aim_changed(true)`, or reset `state` and `charge` when hiding.

### IN-03: Sticky aim only scales the mouse look

**File:** `attimo/scripts/camera/camera_rig.gd:226`
**Issue:** `look_sensitivity_multiplier` is applied only in the `_unhandled_input` mouse path. If the gamepad look path (stick) runs elsewhere, the multiplier has no effect there. The project plans controller support, so it will diverge.
**Fix:** Apply the multiplier in the stick path as well, or note it as mouse-only in the doc comment.

### IN-04: Minor robustness gaps

**File:** `attimo/scripts/mechanisms/gear_gate.gd:59-61`, `attimo/scripts/hand/hand_controller.gd:16-18`
**Issue:** `_box_aabb` dereferences `box.size` without checking that the shape is a `BoxShape3D`. In the tuning panel, `hand_small_range` and `hand_big_range` are independent sliders (1 to 60), so the small range can exceed the big range. That makes RemoteTrigger's `reach` and Targeting's `VALID` state disagree with the "big pulse reaches farther" rule.
**Fix:** Guard `box == null` and return an empty AABB. Clamp `hand_big_range` to at least `hand_small_range` in the controller, for example via a setter.

---

_Reviewed: 2026-11-23_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
