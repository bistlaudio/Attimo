---
phase: 03-animated-mannequin-aim-mode
reviewed: 2026-11-20T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/aim_pose_modifier.gd
  - attimo/scripts/player/procedural_pose.gd
  - attimo/scripts/player/variant_picker.gd
  - attimo/scripts/player/movement_config.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/idle.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/run.gd
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scripts/camera/camera_settings.gd
  - attimo/scripts/ui/crosshair.gd
  - attimo/scripts/debug/tuning_panel.gd
  - attimo/scripts/debug/metrics_overlay.gd
  - attimo/scripts/debug/latency_probe.gd
  - attimo/scripts/debug/event_log.gd
  - attimo/scripts/debug/hit_puffs.gd
  - attimo/tools/build_mannequin_tree.gd
  - attimo/tools/build_animation_library.gd
  - attimo/tools/clip_retargeter.gd
  - attimo/tools/conform_external_clip.gd
  - attimo/tests/smoke/test_variant_picker.gd
  - attimo/tests/smoke/test_crosshair.gd
  - attimo/tests/smoke/test_aim_pose.gd
findings:
  critical: 0
  warning: 6
  info: 10
  total: 16
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-20
**Depth:** standard
**Files Reviewed:** 25 (all GDScript under the scoped directories read in full; the remaining smoke tests were skimmed for tautological checks, shared-config mutation and flaky timing, and spot-read: test_variant_picker, test_crosshair, test_aim_pose, test_clip_variants, test_aim_layer)
**Status:** issues_found

## Summary

The phase code is carefully written: typed GDScript throughout, finite-value guards on every divisor that comes from tunable config, and the controller/animator/camera boundaries are respected (the animator only writes AnimationTree parameters, the pose node only writes the Mannequin child). I found no security vulnerabilities and no data-loss paths. The tool scripts only read compile-time constant paths, and `CameraSettings` refuses any path outside `user://`.

The issues that matter are about robustness and feel rather than correctness of the movement logic:

- the arm aim point is sampled one frame behind the camera because of node order (core-value "feel" defect),
- the editor tools hang headless instead of failing when a script error aborts `_initialize`,
- `MannequinAnimator` dereferences `_playback` without the null guard that every other optional tree member has,
- the F2 panel writes `user://settings.cfg` on every slider tick and ignores the result,
- the `CameraSettings` "forbidden syntax" filter is trivially bypassable by whitespace.

## Structural Findings (fallow)

None provided for this review.

## Warnings

### WR-01: Arm aim point is sampled one rendered frame behind the camera (node order)

**File:** `attimo/scripts/player/mannequin_animator.gd:260-290` (feed), `attimo/scripts/camera/camera_rig.gd:238-267, 307-324` (camera update and ray)
**Issue:** `MannequinAnimator._process` calls `_feed_aim_modifier()`, which calls `rig.aim_target_point()`. That method reads `camera.global_position` and `camera.global_basis`. `CameraRig._process` is what moves the rig and the camera (`rotation.y = yaw`, `pitch_node.rotation.x`, `spring_arm.position`, `camera.position`). In `scenes/test/movement_gym.tscn` the Player (which owns the animator and the AnimationTree that runs the modifier) appears before `CameraRig` in the tree (lines 1860 and 1865), and no `process_priority` is set anywhere in `scenes/` or `scripts/`. `_process` order is tree order, so the animator and the AnimationMixer/AimPoseModifier run first and read the camera transform of the previous frame. During a mouse flick the arm points at where the crosshair was one frame ago, so the hand visibly trails the reticle. The crosshair-to-arm agreement is the point of D-11, and the tests cannot see it (test_aim_pose asserts the modifier against its own recorded target, not against the live camera).
**Fix:** Make the rig update before everything that reads it, and say so in the rig:
```gdscript
# camera_rig.gd _ready()
process_priority = -100  # run before the Player's animator and AnimationTree, which read the camera in _process
```
The rig reads `target.get_global_transform_interpolated()`, which does not depend on `_process` order, so lowering the priority is safe. Add a smoke check that `aim_target_point()` called from a node placed before the rig equals the same call made after the rig's `_process`.

### WR-02: Editor tools never exit when a script error aborts `_initialize`; `run.sh --tool` has no timeout

**File:** `attimo/tools/build_animation_library.gd:89, 119`, `attimo/tools/build_mannequin_tree.gd:209, 224, 261`, `attimo/tools/conform_external_clip.gd` (whole `_initialize` chain), `attimo/tests/run.sh:90-97`
**Issue:** All four tools are `SceneTree` scripts that only call `quit()` at the end of a successful (or explicitly handled) path. Several unguarded dereferences abort `_initialize` with a runtime script error instead, after which the headless SceneTree keeps running forever:
- `build_animation_library.gd:89`: `instance.get_node("AnimationPlayer")` returns null for a source `.glb` without one, then `player.get_animation_list()` crashes.
- `build_animation_library.gd:119`: `(load(String(row["source"])) as PackedScene).instantiate()` crashes when the conformed `.scn` is missing (for example after a clip is dropped from conform but not from `RETARGETED`).
- `build_mannequin_tree.gd:209, 224`: `FALLBACK[ual_clip]` is a hard key lookup; a new `_spell_clip`/`_land_variant` caller without a FALLBACK row crashes.
- `build_mannequin_tree.gd:261`: `_library.get_animation(clip_name).length`.

`run.sh` only greps the log for `SCRIPT ERROR` after the process ends, and the `--tool` branch has no timeout, so a CI or agent run hangs instead of reporting `RUN.SH: FAILED`. The mannequin-tree tool already follows the right pattern for missing clips (`print("TREE: FAILED ...")`, `quit(1)`); the other crash points do not.
**Fix:** Guard the dereferences and fail through the existing path, for example:
```gdscript
var player := instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
if player == null:
    push_error("No AnimationPlayer in %s" % path); instance.free(); quit(1); return
...
var packed := load(String(row["source"])) as PackedScene
if packed == null:
    push_error("Conformed source missing: %s" % row["source"]); quit(1); return
...
var kaykit: StringName = FALLBACK.get(ual_clip, &"")
if kaykit == &"": print("TREE: FAILED (no fallback for %s)" % ual_clip); quit(1); return StringName...
```
and wrap the tool invocation in `run.sh` with a timeout (for example `timeout 300` or `gtimeout` on macOS, or Godot's `--quit-after N`).

### WR-03: `MannequinAnimator` calls `_playback.travel()/start()` with no null guard

**File:** `attimo/scripts/player/mannequin_animator.gd:138, 320, 335`
**Issue:** `_playback` comes from `animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback` and is null whenever the tree is inactive, has no `tree_root`, or the root has no `StateMachine` node. Every other optional piece in `_ready` is guarded (`_aim_machine`, `tree_root != null`, `root != null`, `_aim_modifier`), and `_travel_to` is reached on the first Idle to Run, Run to Jump, etc. state change. With a null `_playback` that is a script error on the first input and, because it throws inside the `state_changed` handler, it skips the rest of `_on_state_changed` (`_update_land`, the locomotion step, the time scale write). A misconfigured or re-exported Mannequin scene (the tree is a generated `.tres` that the tool rewrites) would produce this, and it is the kind of failure the project already protects against elsewhere.
**Fix:** Either assert once in `_ready` (`assert(_playback != null, "AnimationTree has no StateMachine playback")`) so the failure is immediate and explicit, or null-guard `_travel_to` and the `_playback.start` call the same way `_aim_machine` is guarded.

### WR-04: F2 panel saves `user://settings.cfg` on every slider tick and ignores the result

**File:** `attimo/scripts/debug/tuning_panel.gd:45, 86-95, 98-105, 186-189`
**Issue:** `_sensitivity_slider.value_changed` is wired directly to `set_sensitivity`, which calls `_apply_camera_settings` and therefore `CameraSettings.save_to()`. `value_changed` fires continuously while a slider is dragged, so a drag produces dozens of full read-parse-rewrite cycles of the settings file per second (`save_to` re-reads and re-parses the existing file each call). `updated.save_to(settings_path)` also discards the `Error`, so a read-only or full user directory is silent, and the panel keeps showing a value that was not persisted. The same applies to the invert and auto-follow controls (single events, so only the slider is a rate problem).
**Fix:** Apply to the rig on every tick but save on release: connect `drag_ended` (and `value_changed` only when `not slider.has_focus()`/not dragging) to the save, and `push_warning` on a non-OK result:
```gdscript
_sensitivity_slider.drag_ended.connect(func(_changed: bool) -> void: _save_current())
...
var err: Error = updated.save_to(settings_path)
if err != OK:
    push_warning("Could not save camera settings (%d)" % err)
```

### WR-05: `CameraSettings` forbidden-syntax filter is bypassed by whitespace

**File:** `attimo/scripts/camera/camera_settings.gd:18, 35, 70, 85-89`
**Issue:** The defence-in-depth check is a plain substring test for `Object(`, `Resource(`, `SubResource(`, `ExtResource(`. Godot's variant parser tokenises the identifier and the opening parenthesis separately and skips whitespace between them, so `Object (`, `Object\t(` or `ExtResource  (` pass the filter and still reach `ConfigFile.parse`. The file is the player's own `user://` file and the later per-key type checks limit what is used, so this is hardening rather than an exploitable hole, but the comment (A28, T-02-13) presents the filter as a real guard, which it is not. The `save_to` branch has the same gap (a "suspicious" file is parsed instead of being replaced).
**Fix:** Do not rely on substring matching. Either normalise whitespace before the test (`RegEx` of `(Object|Resource|SubResource|ExtResource)\s*\(`), or parse the text with `ConfigFile` and reject any value whose `typeof` is `TYPE_OBJECT` before use (the existing per-field `typeof` checks already do this for the three read keys; extend that to "any value in the file").

### WR-06: Shared-resource side effects in smoke tests rely on manual restore

**File:** `attimo/tests/smoke/test_aim_layer.gd:236-238`, `attimo/tests/smoke/test_tuning_panel.gd:96` (and following)
**Issue:** The movement tests consistently duplicate the config (`player.config = player.config.duplicate()`) and say so in their headers, but `test_aim_layer.gd` mutates the shared `movement_default.tres` (`config.run_anim_ref_speed = 0.0`, restored on the next line) and `test_tuning_panel.gd` drives `panel.set_value(&"run_speed", 9.0)` on the live shared config. If a check or `await` between mutation and restore ever fails or is cancelled, every later test in the same process runs with a corrupted resource, and the failure will point at an unrelated test. It is currently safe only because the restore is immediate.
**Fix:** Use the same pattern as the other suites: `_player.config = _player.config.duplicate() as MovementConfig` in `_begin()` for scenarios that change numbers, and in the tuning panel test restore the original values in a `finally`-style tail (or duplicate before binding the panel).

## Info

### IN-01: Dead code: `AimPoseModifier._toward` is never called

**File:** `attimo/scripts/player/aim_pose_modifier.gd:136-141`
**Issue:** `grep` finds no caller in `scripts/`, `tests/` or `tools/`. It is a leftover from the earlier "free torso rotation" solver that was replaced by the yaw-only torso twist.
**Fix:** Delete it.

### IN-02: Unreachable slide presentation (feature flag permanently off)

**File:** `attimo/scripts/player/states/dash.gd:21-25, 40`, `attimo/scripts/player/mannequin_animator.gd:79-89, 217-221, 301-307, 411, 429-430`, `attimo/tools/build_mannequin_tree.gd:77-93, 306-314`
**Issue:** `SLIDE_PRESENTATION` is a `const ... = false`, so `Dash.slide` is always false and the whole Slide path (hold timer, `SLIDE_HOLD_TIME`, `SLIDE_PLAYBACK_SCALE`, `slide_holding`, the Slide tree node and its edges, the `dash_node_for(.., slide)` branch, the `slide` checks in `ProceduralPose`) never runs. It is documented as intentional, but it is roughly 60 lines of untested-in-practice code in the hottest handler, and the comments in the tree tool still describe numbers that no longer match (see IN-04).
**Fix:** Keep it behind the flag but add one smoke case that flips the flag (or constructs the state with `slide = true`) so the hold logic is exercised, or move the slide code out until the real slide move exists.

### IN-03: `scale` local shadows the `Node3D.scale` property

**File:** `attimo/scripts/camera/camera_rig.gd:216`
**Issue:** `var scale: float = ...` inside `_unhandled_input` shadows the inherited `Node3D.scale`, which triggers `SHADOWED_VARIABLE_BASE_CLASS` and is a trap for later edits in a class that is itself a `Node3D`.
**Fix:** Rename to `look_scale`.

### IN-04: Stale numbers and counts in comments

**File:** `attimo/scripts/player/movement_config.gd:4, 135-137`, `attimo/tools/build_mannequin_tree.gd:82-83, 191-193`, `attimo/tools/build_animation_library.gd:68-69`
**Issue:**
- `movement_config.gd:4` says "Eleven groups, 49 live sliders"; the file has 12 groups (Clip variants was added) and 54 range-hinted floats.
- `movement_config.gd:135` says "Measured fall gravity about 55 m/s^2"; the defaults give `34 * 1.3 = 44.2`.
- `build_mannequin_tree.gd:82-83` says the Slide window is stretched "by a playback scale of 1.85"; the animator now uses `SLIDE_PLAYBACK_SCALE = 1.6`, and the constant block below describes a drop-only stretch.
- `build_animation_library.gd:68-69` describes the aim fallback as "raise, hold, the raise played backwards, hold", but `build_mannequin_tree.gd:191` says the reverse playback was dropped and Exit is a 0.1 s hold.
**Fix:** Update the comments (or derive the counts and values in the text from the code).

### IN-05: Overlapping node positions in the generated tree

**File:** `attimo/tools/build_mannequin_tree.gd:141, 154`
**Issue:** `LandPick` and `AimMachine` are both placed at `Vector2(520, 160)`, and `IdleBreakPick` (390, 160) sits on top of the first `IdleBreak_*` row region. The editor graph overlaps the nodes, which makes the tree hard to read and edit by hand.
**Fix:** Give `AimMachine` its own position (for example `Vector2(520, 520)`).

### IN-06: Stale diagnostics in `AimPoseModifier` after an early return

**File:** `attimo/scripts/player/aim_pose_modifier.gd:71-109`
**Issue:** `last_error_deg`, `last_twist_deg` and `last_target_dir` are only written on a full solve. The early returns (`_has_aim_point` false, missing bones, `want == ZERO`) leave the previous values, so a test or debug overlay reading them cannot tell a fresh solve from an old one.
**Fix:** Reset the three records at the top of `_process_modification_with_delta`, or add a `solve_count` that tests can compare.

### IN-07: `HitPuffs._spawn` dereferences an unchecked cast

**File:** `attimo/scripts/debug/hit_puffs.gd:64-65`
**Issue:** `_scene.instantiate() as CPUParticles3D` is used immediately (`puff.color = ...`); if `hit_puff.tscn` is ever re-rooted as `GPUParticles3D` or a plain `Node3D` the cast yields null and the next line errors.
**Fix:** `if puff == null: return` after the cast (and free the instantiated node if it is not a `CPUParticles3D`).

### IN-08: `TuningPanel._add_row` indexes the hint string without a size check

**File:** `attimo/scripts/debug/tuning_panel.gd:235-246`
**Issue:** `parts[0]` and `parts[1]` are read directly from `hint_string.split(",")`. A range hint written with `or_greater` or a suffix-only form (`"0,or_greater"`) yields `max_value = 0` for the slider silently (`"or_greater".to_float()`), and a malformed hint would index out of range. Current exports are all `min,max,step`, so this is latent.
**Fix:** Guard `parts.size() >= 2` and parse only numeric tokens, or skip rows whose hint contains non-numeric range fields.

### IN-09: `clip_retargeter.gd` couples to a gameplay class and `retarget()` is very long

**File:** `attimo/tools/clip_retargeter.gd:285-466, 333, 410`
**Issue:** `retarget()` is about 180 lines with five phases inline, which makes it hard to unit test below the whole-clip level, and it calls `AimPoseModifier.rotation_between`, so an editor/bake tool depends on a runtime player script (the tool fails to compile if the player script is renamed or has a parse error). `rotation_between` is a pure math helper.
**Fix:** Move `rotation_between` into a small shared math helper (for example `scripts/core/quat_util.gd`) used by both, and split `retarget()` into `_align_rest`, `_floor_references` and `_bake_frame`.

### IN-10: Weak assertions in `test_variant_picker` P4

**File:** `attimo/tests/smoke/test_variant_picker.gd:~88-100`
**Issue:** `check.call(first_a != &"", ...)` is trivially true for any non-empty pool, and "pool B can return pool A's last pick" passes if any one of 40 seeds happens to match, which is nearly always true by chance and does not prove independent per-pool memory. The same-seed determinism part is sound.
**Fix:** Assert the independence directly: pick `pool_a` once, then check that over many picks `pool_b` returns the same clip as the earlier `pool_a` pick at least once (a 2-option pool excludes only its own last pick).

---

_Reviewed: 2026-11-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
