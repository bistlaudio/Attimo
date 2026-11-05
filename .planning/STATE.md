---
gsd_state_version: "1.0"
milestone: v0.11.0.4
current_phase: 02
current_phase_name: Movement Core & Follow Camera
status: executing
stopped_at: Completed 02-13-PLAN.md
last_updated: "2026-11-05T22:28:17.191Z"
last_activity: 2026-11-05
last_activity_desc: Phase 02 execution started
state_head: b33688227fce9a4621f89cae9e48ceb6a037ad83
progress:
  total_phases: 15
  completed_phases: 1
  total_plans: 21
  completed_plans: 20
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-02)

**Core value:** Flüssiges, schnelles Bewegungsgefühl: Laufen, Sprint, Sprung und Dash fühlen sich smooth an, und die Hand verbindet sich nahtlos damit.
**Current focus:** Phase 02 — Movement Core & Follow Camera

## Current Position

Phase: 02 (Movement Core & Follow Camera) — EXECUTING
Plan: 14 of 14
Status: Ready to execute
Last activity: 2026-11-05 — Phase 02 execution started

Progress: [█░░░░░░░░░] 7%

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 7 | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02 P01 | 30 min | 3 tasks | 14 files |
| Phase 02 P02 | 6 min | 2 tasks | 7 files |
| Phase 02 P03 | 12 min | 2 tasks | 11 files |
| Phase 02 P04 | 25 min | 2 tasks | 8 files |
| Phase 02 P05 | 25 min | 2 tasks | 9 files |
| Phase 02 P06 | 15 min | 2 tasks | 2 files |
| Phase 02 P07 | 30 min | 2 tasks | 4 files |
| Phase 02 P08 | 25 min | 2 tasks | 6 files |
| Phase 02 P09 | 12 min | 2 tasks | 10 files |
| Phase 02 P10 | 15 min | 3 tasks | 6 files |
| Phase 02 P11 | 9 min | 2 tasks | 10 files |
| Phase 02 P12 | 12 min | 2 tasks | 6 files |
| Phase 02 P13 | 15 min | 2 tasks | 7 files |

## Accumulated Context

### Decisions

Decisions are logged in the PROJECT.md Key Decisions table.
Recent decisions that affect current work:

- [Roadmap]: Two groups, 15 phases (fine granularity), vertical MVP; every phase ends playable. Group A Prototyp (Phases 1-8) runs until all mechanics are right. Group B Produktion (Phases 9-15): style contract + final hero, world building, juice + polish, controller, audio, Windows release.
- [Roadmap]: Group A uses only KayKit Prototype Bits (greybox) and the KayKit Mannequin_Medium on Rig_Medium with kit clips. No particles, no juice, no Meshy work. Missing shapes (gears, valves, conveyors, enemies, boss) are stand-ins built from Prototype Bits pieces.
- [Roadmap]: The gameplay fact bus (FEEL-01) is built in Phase 1, so juice (Phases 11-12) and audio (Phase 14) plug in without gameplay code changes. The cue catalogue (FEEL-08) waits for Phase 11.
- [Roadmap]: Latency (FEEL-06, Phase 2) and pull metrics (FEEL-10, Phase 5) stay with their mechanics. Hand-module poses (ART-04) stay in Phase 5 on the Mannequin: same Rig_Medium as the final hero, so they carry over, and module designs are checked against kit clips early.
- [Roadmap]: Style contract (FOUND-06) comes first in Group B (Phase 9), before the final hero, because the hero needs the palette, tri budget and arm-core glow decision. The world kit follows in Phase 10.
- [Roadmap]: SHOOT-04 (hit VFX and hit-stop) moved to Phase 12, because it is juice content. Phase 6 shows hits only through the target's own reaction.
- [Requirements]: No juice presets, levels or toggles (user decision). FEEL-05 and FEEL-08 reworded, FEEL-04 lost "toggleable", the juice toggle was removed from UX-03, FEEL-07 (reduce motion) and FEEL-11 (readable with juice off) moved to Out of Scope.
- [Requirements]: Added POLISH-01/02 (Phase 12) and REL-01/02/03 (Phase 15, Windows export and performance). v1 = 71.
- [Requirements]: FEEL-09 (A/B juice study) removed earlier. No playtest study, questionnaires or consent forms.
- [Phase 2]: Camera is a hand-built CameraRig with SpringArm3D (D-18); Phantom Camera dropped. The rig exposes additive FOV/offset sources for Phases 3 and 11. CAM-01 framing is centered behind the character; the shoulder offset is aim-mode only (D-14).
- [Phase 2]: Debug Draw 3D is not adopted in Phase 2 (no res://addons folder; the metrics overlay is Label-based and camera/slope/dash checks are headless). Revisit when aim-assist cones or wall-run raycasts need visual tuning (Phase 3 aim mode, v2 wall-run). Plan assumption A39.
- [Phase 2]: Floor snap stays inside D-13's 0.3-0.5 m band at the shipped 60 TPS for every speed incl. dash (snap_min 0.3, snap_max 0.5, export range 0.3-0.5); 10 TPS is a diagnostic rate only and gets no wider snap. Plan assumption A35.
- [Phase 2]: Auto-follow (D-16) has a CameraSettings mode auto (default) / on / off. Auto follows only after joypad input and stays off after mouse/keyboard input, so it is effectively off until gamepads arrive (Phase 13). The follow converges: camera-relative input steers through CameraRig.steering_yaw(), which excludes auto rotation until the move input changes. Plan assumptions A40, A41 (user decision, plan revision 2).
- [Phase 02]: Idle accelerates on its hand-over tick to Run, and Run holds until speed < 0.01 m/s, so no input tick is lost and the run clip plays through the stop
- [Phase 02]: Snap-band test asserts the clamp to snap_max above 21 m/s, not 15: the specified formula only reaches 0.5 m at about 20.1 m/s
- [Phase 02]: Camera decision D-18 recorded in CLAUDE.md and STACK.md: hand-built CameraRig, Phantom Camera dropped; per-frame shape cast is the fallback if SpringArm3D fails the 10-TPS corridor test
- [Phase 02]: Debug keys use the F-row plus top-row digits 8/9/0 as Mac-friendly alternates (A9); camera_recenter is the middle mouse button (D-17); no gamepad events before Phase 13
- [Phase 02]: Only Primitive_Slope and Primitive_Beam are copied from Prototype Bits (A37); gym stairs use Beam risers of at most 0.15 m with no step-up code (A4)
- [Phase 02]: 02-04: animator tree-travel assertions allow 15 ticks (0.1 s crossfade); the FSM state is the truth
- [Phase 02]: 02-04: MannequinAnimator gets RUNNING_STATES next to AIRBORNE_STATES
- [Phase 02]: 02-05: jump rules A6/A7/A19 held; press past coyote is the double jump, press about to land is a buffered ground jump, double jump sets the rise and obeys the release cut
- [Phase 02]: 02-06: SpringArm3D failed the 10-TPS corridor test (32 of 289 frames clipped), so CameraRig casts a sphere per frame itself (A3 fallback); node layout and API unchanged, SpringArm3D node mask is 0
- [Phase 02]: 02-07: no snap_min/snap_max/platform_carry retune needed; ramps, stairs and platforms pass with shipped values, controller untouched
- [Phase 02]: 02-07: gym stairs are Primitive_Beam instances rotated 90 degrees about Y, sunk so each top is at 0.15*n; 10 TPS ramp down is airborne 4 ticks (diagnostic, A22)
- [Phase 02]: 02-09: dash jump hand-offs apply the bounded exit carry (dash_exit_cap) before leaving Dash, so the interim normal jump cannot carry the raw dash speed; 02-11 replaces the ground branch with LongJump
- [Phase 02]: 02-09: Sprint without input hands over to Run (which brakes into Idle) to keep the running pose while sliding to a stop
- [Phase 02]: 02-10: CameraSettings reads ConfigFile keys via has_section_key (null defaults log engine errors); save_to also refuses '..' paths
- [Phase 02]: 02-10: auto-follow converges because steering_yaw() = yaw - _auto_offset excludes auto-follow and recenter rotation until the move input changes (A40); auto/on/off mode keyed to last input device (A41)
- [Phase 02]: 02-11: ground dash end holds an open chain window through dash_jump_grace so a late-grace long jump keeps its stage
- [Phase 02]: 02-11: LongJump reads the live dash speed (no exit carry before the ground-jump hand-off) and caps it with long_jump_speed_cap
- [Phase 02]: 02-12: TuningPanel rows are generated from MovementConfig.get_property_list (float + editor + range hint); camera controls copy rig settings, apply_settings, then save_to(settings_path); Save button editor-only (A15, T-02-16)
- [Phase 02]: 02-13: measure tool split into a SceneTree loader (measure_movement.gd) and a RefCounted worker (movement_metrics.gd) because a -s script compiles before the autoloads exist

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: The pull/push feel has a thin evidence base, so it needs a focused prototype and momentum test room first.
- [Phase 9]: Open style decisions: second accent colour, player arm-core glow vs the turquoise rule, final hero triangle budget (~6-9k). The Meshy licence tier is unverified; check it before the final hero is produced.
- [Phase 11]: Spike needed: `Engine.time_scale` x physics interpolation at 10 TPS before hit-stop is built.
- [Phase 15]: Performance on the weaker laptop is unmeasured until late. A first frame-rate check is planned after the world swap in Phase 10.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-11-05T22:28:17.119Z
Stopped at: Completed 02-13-PLAN.md
Resume file: None
