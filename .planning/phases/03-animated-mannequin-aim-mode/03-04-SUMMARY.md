---
phase: 03-animated-mannequin-aim-mode
plan: 04
subsystem: camera
tags: [godot, aim-camera, fov, shoulder-offset, tuning-panel, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-03 EventBus.aim_changed and PlayerController.aiming; 03-01 checkpoint items 2, 5 and 6
provides:
  - CameraRig Aim export group (aim_fov_delta, aim_shoulder_offset, aim_blend_time, aim_sensitivity_factor) and read-only aim_weight
  - Eased aim blend through the additive &"aim" FOV and offset sources, one fixed right shoulder
  - Aim-scaled mouse look, camera_recenter / recenter() / auto-follow ignored while aiming, steering offset zeroed on aim enter
  - Generated "Aim camera" section in the F2 panel (aim_row_count, set_aim_value), never persisted
  - test_aim_camera (23 checks) and a test_tuning_panel scenario for the aim rows
affects: [03-05, 03-06, 03-07, 03-08, 03-09]

actuals:
  tokens: 4100   # chars/4 over the added diff lines in attimo/ (16533 chars)
  tasks: 3
  commits: 3
plan_head_before: 7bed113410504c24b538a6e944534952d2b79d09
plan_head_after: 79e89cefb3dc6125aeaa1145359d80ef365cdb2b
commits: 3

tech-stack:
  added: []
  patterns:
    - "The rig writes the &\"aim\" sources only while aim_weight > 0 and clears them once, so hand-set sources in test_camera_rig keep working"
    - "Blend tests stop the rig's own processing before the aim press and step rig._process(1/60) by hand, so timing is tick-counted"
    - "TuningPanel._add_row and _apply take a target Object plus the slider and label dictionaries, so the same code builds MovementConfig rows and CameraRig rows"

key-files:
  created:
    - attimo/tests/smoke/test_aim_camera.gd
    - attimo/tests/smoke/test_aim_camera.gd.uid
  modified:
    - attimo/scripts/camera/camera_rig.gd
    - attimo/scripts/debug/tuning_panel.gd
    - attimo/tests/smoke/test_tuning_panel.gd
    - docs/CONVENTIONS.md

key-decisions:
  - "Aim camera rows live in their own VBoxContainer created in TuningPanel._ready, so they follow the movement rows whichever of config and rig binds first"
  - "Recenter and auto-follow are gated on _aim_target (the held intent), not aim_weight, so they are off from the very first aim tick"

requirements-completed: []

duration: about 40 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 4: Aim camera Summary

**Holding aim eases the CameraRig within 0.18 s to a 12 degree tighter FOV and a 0.6 m right-shoulder arm offset through the additive aim sources, scales mouse look by 0.8, switches recenter and auto-follow off, and the four numbers are live in a generated F2 "Aim camera" section that never reaches settings.cfg.**

CAM-02 is listed in the plan frontmatter but is deliberately not marked complete: it spans the whole phase and the orchestrator marks it at phase end.

## Accomplishments

- `CameraRig` has an `Aim` export group: `aim_fov_delta` 12.0, `aim_shoulder_offset` 0.6, `aim_blend_time` 0.18 (minimum 0.01), `aim_sensitivity_factor` 0.8, plus the read-only `aim_weight`. It connects `EventBus.aim_changed` in `_ready`.
- `_update_aim(delta)` runs in `_process` before the arm position and FOV are written: a linear progress moves toward the held goal at `delta / aim_blend_time`, `aim_weight` is its smoothstep, and the weight drives `set_fov_offset(&"aim", -aim_fov_delta * w)` and `set_offset(&"aim", Vector3(aim_shoulder_offset * w, 0, 0))`. At weight 0 the sources are cleared once. While aim was never held the rig never writes or clears `&"aim"`, so the manual sources in `test_camera_rig` still work. A camera kick source stacks on top.
- One fixed right shoulder. No `aim_shoulder_swap` action exists (grep count 0 in `camera_rig.gd` and `project.godot`) and Q stays unbound; `test_aim_camera` asserts both.
- While aiming: mouse look scale is `base_sensitivity * settings.sensitivity * lerpf(1, aim_sensitivity_factor, aim_weight)`, the `camera_recenter` press, `recenter()` and `_apply_auto_follow` do nothing, and `_on_aim_changed(true)` zeroes `_auto_offset` and stops a running recenter, so `steering_yaw()` equals `yaw` (Pitfall 9).
- `TuningPanel` builds a "- Aim camera -" header and one slider per `CameraRig` float named `aim_*` with an editor range hint (4 now), from `get_property_list()` like the movement rows. New `aim_row_count()` and `set_aim_value()`. The save path is untouched: only `CameraSettings` is written.
- `docs/CONVENTIONS.md` Camera section: aim camera note (blend, sources, sensitivity, recenter and auto-follow off, Q unbound).

## Task Commits

1. Task 1 (tracer): aim blend with FOV and right-shoulder offset - `90915bc`
2. Task 2: aim sensitivity and no recenter or auto-follow while aiming - `8edcf3d`
3. Task 3: generated Aim camera section in the F2 panel - `79e89ce`

Tracer gate: the `<verify>` is automated-only; it was re-run end to end after the commit (`SMOKE SUMMARY: tests=3 passed=111 failed=0`, `RUN.SH: PASSED`) before expanding.

## Verification

- Task 1: `bash attimo/tests/run.sh test_aim_camera,test_camera_rig,test_camera_controls` - 111 checks, 0 failed, `RUN.SH: PASSED`. Acceptance greps: `var aim_fov_delta` 1, `aim_changed.connect` 1, `_aim_sources_written` 4.
- Task 2: `test_aim_camera,test_input_map,test_conventions,test_feedback_guard,test_event_log,test_camera_controls` - 299 checks, 0 failed. `aim_sensitivity_factor` appears 2 times in `camera_rig.gd` (declaration, one use), `aim_shoulder_swap` 0. `attimo/project.godot` was not staged by any task commit. Mutation check: with the auto-follow guard removed the strafe scenario fails (yaw drifts to -0.15), so the scenario is not vacuous.
- Task 3: `test_tuning_panel,test_aim_camera,test_camera_controls` - 117 checks, 0 failed. Acceptance greps: `func aim_row_count` 1, `func set_aim_value` 1, `Aim camera` at least 1.
- After the plan: full suite `bash attimo/tests/run.sh` - 28 tests, 1202 checks, 0 failed, `RUN.SH: PASSED` (this includes the gym's TuningPanel check).

## Deviations from Plan

None - plan executed exactly as written.

Test-authoring notes, not code deviations: the first draft of the blend test let the rig keep processing while aim was pressed, so the weight already read 0.977 after `n - 2` manual steps; the rig now stops processing before the press, giving 0.926 and a real tick-counted check. `Fixtures.wait_until` is used for the release (11 physics frames).

## Issues Encountered

None. A-04-2: `attimo/project.godot` carried engine re-save churn at the start and after each run; it was never staged, and no input action was added, so no semantic change touches it.

## Known Stubs

None.

## Threat Flags

None. T-03-07: aim values are CameraRig exports and `test_tuning_panel` (7) asserts no `aim_` key in the saved settings file. T-03-08: `aim_blend_time` has a 0.01 minimum and `_update_aim` also guards with `maxf(..., 0.01)`.

## Self-Check: PASSED

Files verified present: attimo/scripts/camera/camera_rig.gd, attimo/scripts/debug/tuning_panel.gd, attimo/tests/smoke/test_aim_camera.gd, attimo/tests/smoke/test_tuning_panel.gd, docs/CONVENTIONS.md. Commits 90915bc, 8edcf3d and 79e89ce are ancestors of HEAD.
