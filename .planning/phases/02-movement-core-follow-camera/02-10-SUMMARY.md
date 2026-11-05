---
phase: 02-movement-core-follow-camera
plan: 10
subsystem: camera
tags: [godot, gdscript, camera, settings, configfile, auto-follow, input-device, recenter]

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 steering_yaw() hook read by PlayerController.input_direction(), 02-02 camera_recenter action, 02-06 CameraRig with mouse look and wall-safe arm"
provides:
  - "CameraSettings (class_name, RefCounted): sensitivity, invert_y, auto_follow_mode on user://settings.cfg [camera] via ConfigFile; load_from() type-checks and clamps, save_to() refuses paths outside user://"
  - "CameraRig.apply_settings(): mouse look scaled by settings.sensitivity, invert-Y flips the pitch sign (CAM-03, D-19)"
  - "Converging auto-follow (D-16, A40): heading-angle law with a steering latch, so a held sideways or diagonal key swings the camera behind the run and then settles"
  - "Device-aware auto/on/off auto-follow mode (A41) via CameraRig._input and last_input_device"
  - "CameraRig.recenter() (D-17): camera behind the character's facing within recenter_time, cancelled by mouse look, held direction not re-steered"
  - "Fixtures.spawn_camera_rig applies default CameraSettings so no test reads the developer's user://settings.cfg"
affects: [02-12, 02-14, phase-07, phase-13]

actuals:
  tokens: 10700
  tasks: 3
  commits: 6

commits: 6
plan_head_before: 86d313dab7e14f832425b34b2f8613794390e0e1
plan_head_after: c742baf7e615c03dc3d307884025b570454855ae

tech-stack:
  added: []
  patterns:
    - "Settings are plain ConfigFile data: reject object syntax in the text first, then type-check, finite-check and clamp each key; nothing is loaded from user:// with load() or ResourceLoader"
    - "Camera-relative steering reads steering_yaw() = yaw - _auto_offset; every rotation the rig adds on its own (auto-follow, recenter) is added to _auto_offset, mouse look is not"
    - "Device tracking in _input (never consumed), so UI that eats events cannot hide a device change"

key-files:
  created:
    - attimo/scripts/camera/camera_settings.gd
    - attimo/scripts/camera/camera_settings.gd.uid
    - attimo/tests/smoke/test_camera_controls.gd
    - attimo/tests/smoke/test_camera_controls.gd.uid
  modified:
    - attimo/scripts/camera/camera_rig.gd
    - attimo/tests/fixtures.gd

key-decisions:
  - "ConfigFile.get_value logs an engine error for a null default when the key is absent, so CameraSettings reads through has_section_key first (_read helper) and the tests run without log noise"
  - "save_to also refuses user:// paths containing '..' and replaces (instead of parsing) an existing file that contains object syntax"
  - "Recenter is gated like mouse look: with mouse capture required it only acts while the mouse is captured; otherwise the middle click falls through to the re-capture branch"
  - "Auto-follow step is capped at the remaining error, so a very long frame cannot overshoot the target yaw"

patterns-established:
  - "test_camera_controls._hold(): holds actions for wall-clock seconds, samples yaw and the player's horizontal heading every frame, optionally sends one mouse pixel per frame"
  - "Tests that need a first scenario to run inside the tree await one process frame before spawning (the runner calls tests from _initialize)"

requirements-completed: [CAM-03, CAM-01]

coverage:
  - id: D1
    description: "Mouse right lowers yaw, mouse up raises pitch, sensitivity 2.0 doubles both, invert-Y flips the vertical sign"
    requirement: "CAM-03"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenario a)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Settings round-trip through user://settings.cfg with other sections kept; tampered values (string, nan, 1e9, -5, wrong types, unknown mode, Object( syntax, missing file) load clamped or default; saving outside user:// is refused"
    requirement: "CAM-03"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenarios b, c, d)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Auto-follow converges: after a held sideways key and after a held diagonal the yaw changes by under 0.02 rad over the last second of 3 s, the camera ends within 0.1 rad of the heading (0.030 and 0.029 measured), the player's heading stays fixed (0.000), and a changed key is relative to the current view (dot 1.000)"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenarios h, i)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Auto-follow never fights the mouse (yaw equals the mouse contribution over 363 events), waits auto_follow_delay, and leaves straight runs and runs toward the camera alone"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenarios f, g, j)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Auto mode follows only after joypad input and stops mid-swing after a key event; on follows always; off never; stick noise below 0.2 is ignored"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenarios e, k, l, m)"
        status: pass
    human_judgment: false
  - id: D6
    description: "camera_recenter turns the camera behind the character within recenter_time, mouse motion cancels it, and a held direction keeps its heading (largest heading turn 0.0000 rad)"
    requirement: "CAM-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_camera_controls (scenarios n, o, p)"
        status: pass
    human_judgment: false
  - id: D7
    description: "Auto-follow swing speed and comfort, and recenter speed and feel (D-16, D-17)"
    verification: []
    human_judgment: true
    rationale: "Feel judgments; the plan's human-checks (F5 in the test scene, with the F2 Auto-follow selector from 02-12) are checked at phase end"

duration: ~15min
completed: 2026-11-05
status: complete
---

# Phase 2 Plan 10: Camera Settings, Converging Auto-Follow and Recenter Summary

**ConfigFile-backed CameraSettings (sensitivity, invert-Y, auto/on/off follow mode) with clamping and tamper rejection, a heading-angle auto-follow that swings behind a held sideways or diagonal run and then settles because steering excludes the follow rotation, device-aware auto mode, and a mouse-cancellable recenter.**

## Performance

- **Duration:** about 15 min
- **Completed:** 2026-11-05
- **Tasks:** 3 (all `auto`, `tdd="true"`: RED test commit, then GREEN feature commit per task; Task 2's RED and GREEN are separate commits, Task 1's RED is a combined settings and mouse-look test)
- **Files:** 4 created (camera_settings.gd, test_camera_controls.gd and their .uid), 2 modified

## Accomplishments

- `CameraSettings`: `load_from()` returns defaults for a missing, unparsable or object-syntax file (`Object(`, `Resource(`, `SubResource(`, `ExtResource(`), accepts `sensitivity` only as a finite int/float clamped to 0.1..3.0, `invert_y` only as bool, `auto_follow_mode` only as one of `auto`/`on`/`off`. `save_to()` keeps other sections, refuses anything outside `user://` (and `..`) with `ERR_INVALID_PARAMETER`. No `load()` or `ResourceLoader` on `user://` anywhere in `scripts/` or `autoload/`.
- `CameraRig`: mouse look multiplies by `base_sensitivity * settings.sensitivity` and flips the pitch sign for invert-Y; `apply_settings()` swaps the settings (the 02-12 panel and Phase 7 use it).
- Auto-follow (A40): the follow term is the angle from camera forward to the player's horizontal heading (CharacterBody3D velocity, else the interpolated position delta). Each step is added to `yaw` and `_auto_offset`; `steering_yaw()` returns `yaw - _auto_offset`, so a held key keeps its world heading and the error shrinks into the 0.03 rad dead zone. The offset is dropped when the move input goes between neutral and held or turns by more than 0.35 rad. Measured: sideways 3 s hold, last-second yaw change 0.0000 rad, camera 0.030 rad from the heading, heading drift 0.000; diagonal likewise (0.029 rad).
- Auto mode (A41): `_input` records JOYPAD for `InputEventJoypadButton` and `InputEventJoypadMotion` at 0.2 or more, KEYBOARD_MOUSE for key, mouse button and mouse motion events. With keyboard and mouse the yaw stays exactly unchanged (0.000000), after a simulated joypad button the camera swings (0.570 rad in the first 0.4 s of following), and a key event stops it mid-swing.
- Recenter (D-17): `recenter()` aims at `atan2(-f.x, -f.z)` of the VisualRoot's +Z, `lerp_angle` over `recenter_time` (0.15 s), the rotation also goes into `_auto_offset`, and mouse motion cancels it. Yaw 0.5 lands at PI within 0.0000 rad; while running right the camera ends 0.000 rad from the heading and the heading never turns.
- Sanity check of the test power: with `steering_yaw()` temporarily returning plain `yaw` (the non-converging behavior), 6 convergence checks fail (last-second yaw change 1.40 rad, heading turn 2.8 rad); restored before commit.

## Task Commits

1. **Task 1 RED:** `27ddb8f` (test) - settings round-trip, tampering, refusals, mouse look signs
2. **Task 1 GREEN:** `f840468` (feat) - CameraSettings, sensitivity and invert-Y in the rig, default settings in `Fixtures.spawn_camera_rig`
3. **Task 2 RED:** `1da6d43` (test) - device detection, forced-on mouse/delay, convergence, straight runs, auto/on/off
4. **Task 2 GREEN:** `5b4fb2d` (feat) - converging device-aware auto-follow with steering latch
5. **Task 3 RED:** `24965a9` (test) - recenter scenarios
6. **Task 3 GREEN:** `c742baf` (feat) - camera_recenter without re-steering a held direction

Plan metadata (this SUMMARY, STATE, ROADMAP, REQUIREMENTS) is committed separately.

## Verification

- Task gates: `run.sh test_camera_controls,test_camera_rig` (Task 1) and `test_camera_controls,test_camera_rig,test_ground_movement` (Tasks 2 and 3) all end `RUN.SH: PASSED`; `test_camera_controls` prints 25 PASS lines after Task 1, 54 after Task 2, 59 after Task 3 (criteria: 12, 25, 28).
- Plan-end gate: full `bash attimo/tests/run.sh` -> `tests=20 passed=820 failed=0`, `RUN.SH: PASSED`, no `FAIL [` line.
- `user://` after the suite holds no `test_*.cfg` files.
- Acceptance greps: `class_name CameraSettings` 1, `ConfigFile` 6, `clampf` 1, `ERR_INVALID_PARAMETER` 2, `AUTO_FOLLOW_MODES` 3, `auto_follow_mode` 4, `CameraSettings.new()` in fixtures 1, `load("user://` hits 0; rig: `func notify_look_activity` 1, `func auto_follow_active() -> bool` 1, `angle_difference` 1, `_auto_offset` 6, `InputEventJoypadButton` 1, `InputEventJoypadMotion` 2, `lateral` 0, `func recenter` 1, `camera_recenter` 2, `lerp_angle` 1.

## Deviations from Plan

None - plan executed exactly as written.

Choices inside the plan's latitude:

- `CameraSettings` reads keys through `has_section_key` before `get_value`, because `get_value(..., null)` logs an engine error for absent keys (the first GREEN run printed it; the test logs are clean now).
- `save_to` additionally refuses paths containing `..`, and an existing file with object syntax is overwritten rather than parsed.
- The first test scenario awaits one process frame so the root is inside the tree (the runner calls tests from `_initialize`).
- The recenter action is ignored while mouse capture is required but not active, so the first middle click still just re-captures the mouse.

## Known Stubs

None.

## Threat Flags

None. T-02-13 to T-02-15 and T-02-23 are covered by `test_camera_controls` (scenarios c and d) and the `load("user://` grep. No new endpoints, file access outside `user://settings.cfg`, or trust boundaries.

## Issues Encountered

None. The human-checks (F5: auto/on/off sideways, diagonal, straight and toward-the-camera runs; recenter standing and while running) are not run by the executor; they are recorded as `human_judgment: true` (D7) for the verifier. The F2 Auto-follow selector they mention comes from 02-12.

## Next Phase Readiness

Ready for 02-12 (tuning panel): `CameraSettings` exposes `sensitivity`, `invert_y`, `auto_follow_mode` and `AUTO_FOLLOW_MODES` (selector order), `save_to()` for persistence, and `CameraRig.apply_settings()` applies a changed instance live. The rig exports `auto_follow_delay`, `auto_follow_rate`, `auto_follow_gain`, `auto_follow_dead_zone`, `auto_follow_max_angle`, `auto_follow_min_speed`, `steer_rebase_angle` and `recenter_time` for feel tuning.

## Self-Check: PASSED

- Created files exist: camera_settings.gd, camera_settings.gd.uid, test_camera_controls.gd, test_camera_controls.gd.uid (FOUND).
- Commits `27ddb8f`, `f840468`, `1da6d43`, `5b4fb2d`, `24965a9`, `c742baf` are ancestors of HEAD (FOUND).
