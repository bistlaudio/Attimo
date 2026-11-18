---
quick_id: 261118-okz
status: complete
commits: 1
plan_head_before: 5319cdc
plan_head_after: 5c00a93858902a8d015d626451dce6e367ceda87
---

# Quick task 261118-okz: Remove long-jump stretch lean

**One-liner:** ProceduralPose now leans only on a ground dash (`dash_lean_deg`, 20 degrees); the dash hop eases the lean to 0 over `lean_out_time` and the long jump stays upright.

## Changes
- `attimo/scripts/player/procedural_pose.gd`: removed the `_stretch` flag and the stretch target; `_lean_target_deg` returns `dash_lean_deg` only in a ground Dash, else 0. Ease rate is now `dash_lean_deg / lean_in_time` (in) and `/ lean_out_time` (out), with a 1 degree floor on the reference. Pirouette and `aim_lean_scale` untouched.
- `attimo/scripts/player/movement_config.gd`: removed export `stretch_lean_deg`; `lean_in_time` / `lean_out_time` kept (docs now refer to the dash lean).
- `attimo/tests/smoke/test_procedural_pose.gd`: stretch scenario (s1) replaced by `_scenario_hop_upright` (lean never above dash lean, only eases out after LongJump starts, 0 within lean_out_time + 3 ticks, upright through Fall and at landing, no spin at stage 1); (l3) nesting comparison now uses a synthetic lean since the long jump is upright.
- `docs/ANIMATION-MAP.md`, `docs/MOVEMENT-METRICS.md` (stretch row removed by hand, no latency noise).

## Deviations
- [Rule 1] (l3) test needed a synthetic lean because the long jump no longer leans.
- Side effect: the dash lean now builds up over `lean_in_time` (0.05 s, about 3 ticks) instead of reaching 20 degrees in one tick, because the ease rate was previously derived from the 60 degree stretch. The dash lean target is unchanged at 20 degrees. The ease-out of the dash lean is slower (0.12 s instead of about 0.04 s).

## Verification
`bash attimo/tests/run.sh`: tests=33 passed=1464 failed=0, `RUN.SH: PASSED`.

## Self-Check: PASSED
