---
status: complete
quick_id: 261123-l8y
date: 2026-11-23
commit: 5c550d6
---

# Quick Task 261123-l8y: Camera auto-follow while strafing (keyboard and mouse)

Planning was skipped at the developer's request.

**Finding:** The D-16 auto-follow (A40 convergent swing, A41 mode) already rotates the CameraRig behind the character while A/D is held. It is suppressed for `auto_follow_delay` (1 s) after mouse look, off while aiming, and ignores straight runs and runs toward the camera. The default mode `"auto"` only enabled it after joypad input, so with keyboard and mouse nothing happened.

**Change:** `CameraSettings.DEFAULT_AUTO_FOLLOW_MODE` is now `"on"`. `"auto"` and `"off"` remain selectable in the F2 tuning panel (persisted in user://settings.cfg). The default-fallback assertions in `test_camera_controls.gd` now compare against the constant.

**Tuning knobs (CameraRig exports):** `auto_follow_delay`, `auto_follow_rate`, `auto_follow_gain`, `auto_follow_dead_zone`, `auto_follow_max_angle`, `auto_follow_min_speed`.

**Verification:** `bash attimo/tests/run.sh`: RUN.SH: PASSED.
