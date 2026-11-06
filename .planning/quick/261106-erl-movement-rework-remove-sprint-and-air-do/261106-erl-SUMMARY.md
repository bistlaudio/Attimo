---
status: complete
quick_id: 261106-erl
description: Movement rework after Phase 2 gym feedback
commits: [bd3c75b, 0f1c389, 1e31757, 77c91f9, 6a0fb3f, 45e2e51, ba79847]
---

# Quick task 261106-erl: Movement rework

Sprint and the air double jump are gone. Dash is Left Shift (tap). Ground chain Jump 1 -> 2 -> 3 (salto, physics only). Dash hop: dash + jump = long jump with a 1-3 speed stack (14/16/18 m/s, apex 2.0/2.5/3.0 m). Lighter feel (run_speed 8.5, ground_accel 70, rise_gravity 34, fall_multiplier 1.3, air_accel 45). MovementConfig regrouped into 8 groups with 34 commented sliders. Debug hit puffs (placeholder particles, explicit guard exception, scenes/debug/hit_puff.tscn) show timing hits in the gym. Docs and requirement wording updated.

Suite at the end: tests=25 passed=1036 failed=0, MEASURE: PASSED.

## Open (human)
- Gym playtest of the new feel, the hop stack at 14/16/18 m/s and camera follow at sustained 18 m/s.
- Hold-vs-tap discussion, dash buffer if hop timing feels too strict.
- CAM-01 144 Hz check (unchanged from Phase 2).

## Deviations
- fall_multiplier 1.3 is below Phase 2 D-04 (1.5-2x), by user decision.
- PROJECT.md/CLAUDE.md edits touched lines inside GSD marker blocks (content only); regenerating from sources would overwrite them. Source for the input table: .planning/research/STACK.md (not updated).
