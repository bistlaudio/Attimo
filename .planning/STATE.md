---
gsd_state_version: 1.0
milestone: v0.11.0.4
milestone_name: milestone
status: executing
stopped_at: Completed 05.1-06-PLAN.md
last_updated: "2026-11-25T05:38:17.532Z"
last_activity: 2026-11-25 -- Plan 05.1-06 complete (gym cutover: kit layer areas steampunk / energy / nature behind the hall east door; old mechanism rooms, lift, crank, pressure plate deleted)
progress:
  total_phases: 17
  completed_phases: 6
  total_plans: 66
  completed_plans: 52
  percent: 35
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-02)

**Core value:** Flüssiges, schnelles Bewegungsgefühl: Laufen, Sprint, Sprung und Dash fühlen sich smooth an, und die Hand verbindet sich nahtlos damit.
**Current focus:** Phase 05.1 — kit rework

## Current Position

Phase: 05.1
Plan: 7 of 20 (05.1-01 to 05.1-06 complete)
Status: Ready to execute
Last activity: 2026-11-25 -- Plan 05.1-06 complete (gym cutover: kit layer areas steampunk / energy / nature behind the hall east door; old mechanism rooms, lift, crank, pressure plate deleted)

Progress: [████████░░] 79%

## Performance Metrics

**Velocity:**

- Total plans completed: 41
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 7 | - | - |
| 02 | 14 | - | - |
| 03 | 10 | - | - |
| 04 | 5 | - | - |
| 05 | 5 | - | - |

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
| Phase 02 P14 | 35 min | 2 tasks | 6 files |
| Phase 03 P01 | 1h | 3 tasks | 12 files |
| Phase 03 P02 | 15 min | 2 tasks | 8 files |
| Phase 03 P10 | 25 min | 2 tasks | 2 files |
| Phase 03 P03 | 35 min | 2 tasks | 9 files |
| Phase 03 P04 | 40min | 3 tasks | 6 files |
| Phase 03 P05 | 7 min | 2 tasks | 9 files |
| Phase 03 P06 | 35min | 3 tasks | 10 files |
| Phase 03 P07 | 40min | 3 tasks | 7 files |
| Phase 03 P08 | 25 min | 2 tasks | 6 files |
| Phase 03 P09 | 30min | 3 tasks | 14 files |
| Phase 04 P01 | ~1h | 3 tasks | 40 files |
| Phase 04 P04-02 | 90min | 3 tasks | 20 files |
| Phase 04 P03 | 35min | 3 tasks | 22 files |
| Phase 04 P04-04 | 150min | - tasks | - files |
| Phase 04 P05 | n/a | 3 tasks | 9 files |
| Phase 04.1 P01 | 40 min | 3 tasks | 15 files |
| Phase 04.1 P04 | 75min | 2 tasks | 45 files |
| Phase 04.1 P05 | 95min | 3 tasks | 9 files |
| Phase 05 P05-04 | single session | 3 tasks | 30 files |
| Phase 05.1 P01 | 40min | 3 tasks | 24 files |
| Phase 05.1 P02 | 55min | 3 tasks | 30 files |
| Phase 05.1 P03 | 55min | 3 tasks | 30 files |
| Phase 05.1 P04 | 60 min | 3 tasks | 23 files |
| Phase 05.1 P06 | 60 min | 3 tasks | 31 files |

## Accumulated Context

### Decisions

Decisions are logged in the PROJECT.md Key Decisions table.
Recent decisions that affect current work:

- [Phase 05.1-06]: Kit showroom = three layer areas behind the hall east door (Zone_KitSteampunk x 43..151, Zone_KitEnergy x 155..227, Zone_KitNature x 231..291, corridor z -4..4), shell in kit_area_shell.gd; old mechanism rooms, lift, crank, pressure plate deleted
- [Phase 05.1-04]: The D-07 floor fix is geometric: Timed motion stations stand at TimedMotion.min_pivot_height (floor + 0.3 + reach*sin(limit) + thickness; hand 5.39 m, plate 2.80 m)
- [Phase 05.1-04]: A take-off off a reference-frame carrier keeps the deck's vertical chord (clamped +-6 m/s, PlayerController.MAX_DECK_TAKEOFF_SPEED); engine-carried floors unchanged
- [Phase 05.1-04]: RotatingPlatform folded into TimedMotion (Profile SWEEP/TILT, Timing ALWAYS_ON/SWITCHED) with unchanged values; LYING gear cut
- [Phase 05.1-05]: Loader presentation is source-aware: ARM unchanged, CAGE = still brass pressure gauge + one brass arc + brass vignette (LoaderPreview.BRASS_COLOR = look_brass albedo), FIXED = no ring, preview or LoaderLook
- [Phase 05.1-05]: Kit steam cues are optional SteamPuff / SteamBlast child meshes timed in real time by CatchLaunch (0.25 s / 0.22 s), no particles
- [Phase 05.1-05]: F2 Kit section binds the nearest kit_block within 8 m (scan every 0.25 s real time) and edits only node-local configs (resource_path configs refused)
- [Phase 05.1-03]: Wall-run head clearance is a pose-only geometric clamp in ProceduralPose (WALL_RUN_HEAD_CLEARANCE 0.45 m, lean 4.38 deg); wall_run_lean_deg stays 18
- [Phase 05.1-03]: Wall-jump twin layout rule WallSurface.TWIN_FACE_GAP_MIN 6 m between faces, JUMP_PAD_HEIGHT_MIN 8 m; no wall_jump_* retune
- [Phase 05.1-03]: Wall surfaces are always-on kit blocks; SteamNozzle keeps only UPDRAFT; Geyser moved to Hoch slot (0,1)
- [Phase 05.1-02]: Cannon path LoaderState FIXED (35 code lines, under the 40-line fallback); the Capture state is deleted
- [Phase 05.1-02]: The FIXED discharge emits launched, refills only the Loader use and never calls TimeFx (no slow motion, no hitstop)
- [Phase 05.1-02]: Phase 4 puzzle rooms removed (D-29); gym station SteamCannon (kind kit, yaw only), Slingshot moved to Werfen slot (1,1)
- [Phase 05.1-01]: The cage press latch counts is_action_just_released too, so a same-tick tap fires at once
- [Phase 05.1-01]: KitBlock joins groups mechanism and kit_block in NOTIFICATION_READY (survives a subclass _ready without super)
- [Phase 05.1-01]: New gym station kind 'kit' (block + sign, no Driver source) because KitBlock has no source (D-13)
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
- [Phase 02]: Movement gym tool split into launcher plus worker; random unique_id values stripped after pack for a reproducible scene (02-14)
- [Phase 03]: 03-01: Animation root is a generated BlendTree (StateMachine -> TimeScale -> Land OneShot); every state edge ENABLED + IMMEDIATE, Jump -> Fall included
- [Phase 03]: 03-01 checkpoint item 2: no shoulder swap action, Q stays unbound, fixed single aim shoulder (aim_shoulder_offset 0.6); items 3-6 defaults
- [Phase 03]: 03-02: Dodge root position pinned to key 0 by build_animation_library.gd (ROOT_PINNED); root rotation kept for strafe yaw; AnimationTree root motion not used
- [Phase 03]: 03-10: air-dash pose hold lives in MannequinAnimator behind air_dash_hold_time() (start 0.35 s); a ground dash that ends airborne never holds
- [Phase 03]: 03-03: aim facing is pinned to rig.yaw in PlayerController._tick_aim before the states; face()/face_now() no-op while aiming; aim ground speed via ground_target_speed (0.75, back 0.6)
- [Phase 03]: 03-04: aim camera uses one fixed right shoulder; recenter and auto-follow gated on held aim intent; aim rows generated from CameraRig aim_* range floats and never persisted
- [Phase 03]: 03-05: Crosshair is a CanvasLayer (layer 10) with a full-rect Reticle Control drawing dot and ring via its draw signal; set_locked() is the reserved Phase 4 lock hook
- [Phase 03]: 03-06: ProceduralPose finds the StateMachine via get_node (Player @onready is set after children ready) and exposes pose_basis() for the nesting switch test
- [Phase 03]: 03-07: dash clip lengths read per dash node (DASH_CLIPS); strafe blend divisor is ground_target_speed of the velocity direction
- [Phase 03]: 03-08: AimPoseModifier closes the arm error with the upper arm after the torso budget (spine_share 0.4, max_twist_deg 70); measured error 0.000 deg in every locomotion case and at both pitch limits
- [Phase 04]: [04-01] GearGate holds open only once opening started; room-2 floor starts x 43 with threshold beam; module switching only while aiming
- [Phase 04]: [04-02] arm_out lives on HandController; animator uses it only for Aim layer weight and solver target, aim edge/strafe/dash stay on player.aiming
- [Phase 04]: [04-02] Targeting holds only valid targets; exact hits on invalid Interactables only set reticle state INVALID
- [Phase 04]: 04-03: Array[SignalSource] exports survive pack when typed at the set site; Valve wheel turns forward per toggle; Crank wind/decay exclusive per tick
- [Phase 04]: 04-04: rotating-platform carry is a reference-frame attach (rider re-placed at the same local point each tick, engine carry off, platform ticks after the player); the plan's velocity based primary and fallback failed the spike gate
- [Phase 04]: 04-04: room 2 extended to x 43..115 for the moving stations; puzzle rooms (04-05) start behind x 115
- [Phase 04]: 04-05: Puzzle rooms start after x 115, 24 m wide; FallReset reset_root sweeps mechanism nodes; SignalSource start_active
- [Phase 04.1]: Zone gravity factor is a per-tick request (request_gravity_scale, clamped 0.05..1.0, cleared after the move); Dash-owned gravity_scale untouched
- [Phase 04.1]: Conveyor carry fixed in conveyor.tscn (belt top 0.05 m above node origin), not in PlayerController: belt top was coplanar with the floor tile
- [Phase 04.1]: MechanismLook hooks on NOTIFICATION_READY (subclasses override _ready without super)
- [Phase 04.1-05]: D-12 fallback not needed (13 s to 12 s filtered gym run); room 2 stays 120 m x 72 m, nine zones, 33 stations on a 12 m slot grid
- [Phase 05]: 05-04: shot bends toward the locked target instead of a snapped ray; pulse_fired fires at projectile impact, shot_fired at launch

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: The pull/push feel has a thin evidence base, so it needs a focused prototype and momentum test room first.
- [Phase 9]: Open style decisions: second accent colour, player arm-core glow vs the turquoise rule, final hero triangle budget (~6-9k). The Meshy licence tier is unverified; check it before the final hero is produced.
- [Phase 11]: Spike needed: `Engine.time_scale` x physics interpolation at 10 TPS before hit-stop is built.
- [Phase 15]: Performance on the weaker laptop is unmeasured until late. A first frame-rate check is planned after the world swap in Phase 10.
- CAM-01 success criterion 1: 144 Hz camera judder not verified (developer has only a Mac); open human-verification gap, needs a 144 Hz display

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261106-erl | Movement rework: no sprint, no air jump, Shift dash, jump chain 1-2-3, dash hop stack, lighter feel | 2026-11-06 | ba79847 | [261106-erl-movement-rework-remove-sprint-and-air-do](./quick/261106-erl-movement-rework-remove-sprint-and-air-do/) |
| 261118-okz | Remove long-jump stretch lean: dash lean 20 deg then upright on dash hop | 2026-11-18 | 5c00a93 | [261118-okz-remove-long-jump-stretch-lean-dash-lean-](./quick/261118-okz-remove-long-jump-stretch-lean-dash-lean-/) |
| 261118-qbt | Retargeted Mixamo Running_Slide on the unaimed ground dash (generic Mixamo/UAL retarget pipeline), closer lower-third camera with vertical jump lock, crosshair ray aim target | 2026-11-18 | 0624af2 | [261118-qbt-slide-animation-from-running-slide-fbx-c](./quick/261118-qbt-slide-animation-from-running-slide-fbx-c/) |
| 261118-qi3 | Animation variations (idle breaks, sprint blend, Jump 2/long jump takes, landing variants, VariantPicker) and UAL clips via retarget gate; Spell clips dropped, aim keeps Ranged_1H_Aiming | 2026-11-18 | f051bba | [261118-qi3-animation-variations-mario-style-and-spe](./quick/261118-qi3-animation-variations-mario-style-and-spe/) |
| 261120-d4x | Fix phase 03 review warnings WR-01 to WR-06 | 2026-11-20 | 67ae159 | [261120-d4x-fix-phase-03-review-warnings-wr-01-to-wr](./quick/261120-d4x-fix-phase-03-review-warnings-wr-01-to-wr/) |
| 261120-dik | Dash lockouts, blocked-dash feedback, no dash in aim, softer dash blends | 2026-11-20 | 6ea364e | [261120-dik-dash-lockouts-and-blocked-dash-feedback-](./quick/261120-dik-dash-lockouts-and-blocked-dash-feedback-/) |
| 261120-ef9 | Remove dash lockouts for pirouette, landing, takeoff; keep aim block and soft blends | 2026-11-20 | 3b53279 | [261120-ef9-remove-dash-lockouts-for-pirouette-landi](./quick/261120-ef9-remove-dash-lockouts-for-pirouette-landi/) |
| 261123-l8y | Camera auto-follow on by default (also keyboard and mouse): camera swings behind the character while strafing A/D | 2026-11-23 | 5c550d6 | [261123-l8y-camera-auto-yaw-camerarig-gently-rotates](./quick/261123-l8y-camera-auto-yaw-camerarig-gently-rotates/) |

### Roadmap Evolution

- Phase 04.1 inserted after Phase 4: Mechanism kit extension (movement mechanisms A-K + steampunk extras, wall-run MOVE-12 into scope, conveyor carry fix) and HUD polish (always-on crosshair, E prompt, expectation signs, showcase sub-zones, lens restyle) (URGENT)
- Phase 5 edited: rescoped to Energy Arm & Loader (docs/GAME-DESIGN.md); edited fields: title, goal, requirements, success_criteria, notes
- Phase 05.1 inserted after Phase 5: Kit Rework: 8 logic blocks + 4 components + looks, three layers (docs/GAME-DESIGN.md section 6)
- Phase 6 edited: adapted to the energy-momentum design (docs/GAME-DESIGN.md)
- Phase 7 edited: adapted to the energy-momentum design (docs/GAME-DESIGN.md)
- Phase 8 edited: adapted to the energy-momentum design (docs/GAME-DESIGN.md)

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-11-25T05:38:13.044Z
Stopped at: Completed 05.1-05-PLAN.md
Resume file: None
