# Phase 05.2 deferred items

Out-of-scope discoveries, logged and not fixed (executor scope boundary).

## Plan 01

- **Timing-flaky hitstop tests (pre-existing, verified at c6b035f).** `test_loader` ("d3 dash kept / spent: air control is back after loader_release_control_lock (timer 0.013)", "(release) Engine.time_scale is back at 1.0 (got 0.050)") and `test_slingshot_loader` ("(cap) / (tap) / (press) Engine.time_scale is back at 1.0 (got 0.050)") fail intermittently on this machine, a different subset on every run, in the full suite and in isolation. A clean checkout of c6b035f (before any plan 01 change) shows the same failures in `test_loader`. Cause: the hitstop and the control lock are real-time timers (`loader_hitstop_time` 0.05 s real) compared against fixed physics ticks in headless runs, so they depend on machine load. Plans 03 and 04 rewrite these Loader tests anyway (stage timing, auto release); plan 03 should make the hitstop and control-lock assertions tick-driven rather than real-time driven, or accept the flake.
- **Exit code 139 (segmentation fault) once after `SMOKE SUMMARY`** in one full-suite run (tests=82, after the last test finished); did not recur in the second full run. Headless shutdown crash, not reproducible, no test failure attached.
