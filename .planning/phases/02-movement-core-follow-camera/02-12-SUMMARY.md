---
phase: 02-movement-core-follow-camera
plan: 12
subsystem: debug-ui
tags: [godot, gdscript, tuning-panel, debug-ui, movement-config, camera-settings]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 MovementConfig (@export_range floats) and group player, 02-02 debug_tuning action, 02-08 debug overlay pattern, 02-10 CameraSettings and CameraRig.apply_settings / auto_follow_active"
provides:
  - "TuningPanel (CanvasLayer 102): hidden F2 / 8 panel with one HSlider per MovementConfig range float (39 rows), bound to the live shared resource of the player"
  - "Camera section: sensitivity slider (range from CameraSettings constants), Invert Y check box, Auto-follow OptionButton built from CameraSettings.AUTO_FOLLOW_MODES; all apply through rig.apply_settings and save with save_to(settings_path)"
  - "set_auto_follow_mode refuses values outside AUTO_FOLLOW_MODES and re-syncs the selector with the rig"
  - "Editor-only 'Save movement config' button (disabled otherwise), never writes user://"
  - "TuningPanel instance in test_scene.tscn after the MetricsOverlay"
  - "test_tuning_panel: 24 checks"
affects: [02-13, 02-14]

actuals:
  tokens: 14000
  tasks: 2
  commits: 4

commits: 4
plan_head_before: fe4860eb2dd5ac916e00d7290feb8f8e0ad7f33c
plan_head_after: ddc44d8f8c389cb3f30e432a63f7f680f57f6d85

tech-stack:
  added: []
  patterns:
    - "Rows are generated from config.get_property_list() (float + PROPERTY_USAGE_EDITOR + PROPERTY_HINT_RANGE); slider min/max/step come from the hint string, so a new MovementConfig field gets a slider with no panel change"
    - "Camera controls copy the rig's CameraSettings (plain data), change one field, call rig.apply_settings and then save_to(settings_path)"
    - "Setters use set_value_no_signal on the controls and then one explicit apply, so tests and UI take the same path without double saves"

key-files:
  created:
    - attimo/scripts/debug/tuning_panel.gd
    - attimo/scripts/debug/tuning_panel.gd.uid
    - attimo/scenes/debug/tuning_panel.tscn
    - attimo/tests/smoke/test_tuning_panel.gd
    - attimo/tests/smoke/test_tuning_panel.gd.uid
  modified:
    - attimo/scenes/test/test_scene.tscn

key-decisions:
  - "The panel binds deferred (and again on first show) to the first node in group player and to the CameraRig that owns the viewport's current camera, so scene order of panel, player and rig does not matter."
  - "Each movement slider shows a group header from the MovementConfig @export_group entries, so the 39 rows stay readable."
  - "Hiding the panel recaptures the mouse unless the display server is headless, exactly as the plan states; no extra rig check."
  - "Save is guarded twice: the button is disabled outside the editor, and the handler re-checks OS.has_feature(editor) and that the resource path starts with res://."

patterns-established:
  - "Test helper _spawn(): floor, player with a duplicated config, rig with default settings, panel with settings_path set to user://test_tuning_settings.cfg; the shared res:// config is never mutated"

requirements-completed: [MOVE-10, CAM-03]

coverage:
  - id: D1
    description: "F2 panel starts hidden, toggles on debug_tuning, has one row per MovementConfig range float (39), and set_value(run_speed, 9.0) makes the running player reach 9.00 m/s without a restart; the shared res:// config is untouched"
    requirement: "MOVE-10"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_tuning_panel (1, 2, 3)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Sensitivity, invert-Y and auto-follow mode set in the panel reach rig.settings and are saved to settings_path (reload returns 2.0, true, on/off); the sensitivity slider range is [0.1, 3.0]; the selector has items Auto, On, Off in AUTO_FOLLOW_MODES order and starts on the rig's mode; 'sideways' is refused"
    requirement: "CAM-03"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_tuning_panel (4, 5)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Save movement config is disabled when not running from the editor; the shared movement_default.tres has no diff after the full suite"
    requirement: "MOVE-10"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_tuning_panel (6) and git diff --quiet on movement_default.tres"
        status: pass
    human_judgment: false
  - id: D4
    description: "Usability of the panel in the running game: mouse freed while shown and recaptured on close, sliders acting at once, Auto-follow On/Auto/Off visibly changing the camera, settings surviving a restart"
    requirement: "MOVE-10"
    verification: []
    human_judgment: true
    rationale: "UI and live-tuning workflow judgment; the plan's F5 human-check was not run by the executor"

duration: 12 min
completed: 2026-11-05
---

# Phase 2 Plan 12: F2 Tuning Panel Summary

**F2 tuning panel with a live slider for every MovementConfig float (39 generated from the property list) plus a camera section for sensitivity, invert-Y and an Auto/On/Off auto-follow selector that persists through CameraSettings, and an editor-only Save button.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-11-05T22:12Z
- **Tasks:** 2
- **Files modified:** 6 (5 created, 1 modified)

## Accomplishments

- Moving a slider writes straight into the player's shared MovementConfig, so a `set_value(run_speed, 9.0)` made the running player reach 9.00 m/s within the test window, no restart (D-23).
- The camera section applies to the rig with `apply_settings` and saves with `save_to(settings_path)`; reloading the saved file returned 2.0 / true / on / off as set (D-19, CAM-03, A41).
- The Auto-follow items are built from `CameraSettings.AUTO_FOLLOW_MODES`, so selector and settings class cannot disagree; an unknown mode leaves rig and saved file unchanged.
- The panel is in `test_scene.tscn` after the MetricsOverlay. Full suite: 22 tests, 885 checks, 0 failed.

## Task Commits

1. **Task 1 RED: toggle, rows, live retune** - `b67b606` (test)
2. **Task 1 GREEN: panel with live sliders** - `e60077e` (feat)
3. **Task 2 RED: camera section, selector, Save** - `fe44f51` (test)
4. **Task 2 GREEN: camera section, selector, Save, test scene instance** - `ddc44d8` (feat)

## Decisions Made

See key-decisions in the frontmatter.

## Deviations from Plan

None - plan executed exactly as written. (`settings_path` was added in the Task 1 commit instead of Task 2 because the Task 1 test already assigns it; the Task 2 interface is unchanged.)

## Issues Encountered

None. A first GREEN run failed only because `_apply` was called with swapped arguments (the bound property is appended after the signal value); fixed before the commit.

## Known Stubs

None.

## Threat Flags

None. T-02-16 is mitigated: the Save button is disabled outside the editor and the handler re-checks `OS.has_feature("editor")` and a `res://` path; the grep gate for `save_to("user://` / `ResourceSaver.save(... user://` over `attimo/scripts` prints nothing; the panel only writes ConfigFile data through `CameraSettings.save_to`.

## Next Phase Readiness

Ready for 02-13 (metrics) and 02-14 (gym sign-off): all movement values, including the chain and long-jump rows from 02-11, can be tuned live with F2 / 8. The F5 usability check from the plan (mouse release and recapture, restart persistence, Auto-follow behaviour) is still open for the developer (coverage D4).

## Self-Check: PASSED

- Files: tuning_panel.gd, tuning_panel.gd.uid, tuning_panel.tscn, test_tuning_panel.gd, test_tuning_panel.gd.uid present; test_scene.tscn contains the instance
- Commits b67b606, e60077e, fe44f51, ddc44d8 are ancestors of HEAD (`git rev-list --count fe4860e..HEAD` = 4)
- `bash attimo/tests/run.sh` (full suite): tests=22 passed=885 failed=0, `RUN.SH: PASSED`; `test_tuning_panel` prints 24 PASS lines
- All acceptance greps returned the required counts; `git diff --quiet` on `movement_default.tres` exits 0; no test_*.cfg left in the user data folder
