---
phase: quick-261106-erl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - attimo/project.godot
  - attimo/scripts/player/movement_config.gd
  - attimo/resources/player/movement_default.tres
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/states/air_state.gd
  - attimo/scripts/player/states/ground_state.gd
  - attimo/scripts/player/states/run.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/long_jump.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scenes/player/player.tscn
  - attimo/autoload/event_bus.gd
  - attimo/scripts/debug/metrics_overlay.gd
  - attimo/scripts/debug/latency_probe.gd
  - attimo/tools/movement_metrics.gd
  - attimo/tools/measure_movement.gd
  - attimo/tests/fixtures.gd
  - attimo/tests/smoke/test_ground_movement.gd
  - attimo/tests/smoke/test_jump.gd
  - attimo/tests/smoke/test_long_jump.gd
  - attimo/tests/smoke/test_dash.gd
  - attimo/tests/smoke/test_input_map.gd
  - attimo/tests/smoke/test_conventions.gd
  - attimo/tests/smoke/test_movement_metrics.gd
  - docs/CONVENTIONS.md
  - docs/MOVEMENT-METRICS.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
files_deleted:
  - attimo/scripts/player/states/sprint.gd
  - attimo/scripts/player/states/sprint.gd.uid
  - attimo/scripts/player/states/double_jump.gd
  - attimo/scripts/player/states/double_jump.gd.uid
autonomous: true
requirements: [MOVE-01, MOVE-02, MOVE-03, MOVE-05, MOVE-06, MOVE-07, MOVE-10, FOUND-02]
tags: [movement, rework, jump-chain, long-jump, tuning]

estimate:
  tokens: 130000
  raw_tokens: 130000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - "Left Shift (tap) is the only dash key and there is no sprint: a real Left Shift key event while running starts exactly one Dash, the Input Map has no sprint action, the player scene has no Sprint or DoubleJump state node (U1, U2, U3)"
    - "One run speed: holding a direction from standing reaches config.run_speed (default 8.5 m/s) within ceil(run_speed / ground_accel * 60) + 1 ticks (default ground_accel 70 m/s^2, about 0.12 s) (U1, U6)"
    - "No air jump: a jump press in the air outside coyote time never adds rise; it fires only as a ground jump on the landing tick when the body lands within jump_buffer_time (U2, MOVE-05)"
    - "Jump 1 -> Jump 2 -> Jump 3 inside landing_window: held apexes match jump_height, jump_2_height, jump_3_height (2.0 / 2.6 / 3.4 m) within 0.1 m and rise strictly; chain_stage_changed reports 1, 2, 3; a missed window, standing still, a ground dash or a long jump resets the chain; a fourth jump inside the window is Jump 1 again (U4)"
    - "Exactly one air dash per airtime, also after the Jump 3 salto (U2, U4)"
    - "Dash then jump is long jump stage 1 at long_jump_speed_1 (14 m/s, above run speed) with an apex near long_jump_height_1 (2.0 m); each clean repeat (ground dash started inside landing_window after a long-jump touchdown, jump during that dash or its grace) climbs to stage 2 and 3 (16 / 18 m/s, 2.5 / 3.0 m) and then stays at 3; a miss resets to stage 1; no long jump ever moves faster than 22 m/s (U5)"
    - "Lighter, snappier jump and more air control: rise_gravity 34 and fall_multiplier 1.3 give a fall gravity of 44.2 m/s^2 (was 48.2) and a 2.0 m apex in about 0.34 s (was 0.37 s); the fall stays heavier than the rise; air_accel 45 (U6, MOVE-03)"
    - "MovementConfig is one resource with 34 range floats in 8 commented groups, every one a live F2 slider; docs/MOVEMENT-METRICS.md is regenerated from it and the full suite passes (U7, U8)"
  prohibitions:
    - requirement_id: "MOVE-05"
      category: "scope"
      status: "resolved"
      verification: "test"
      statement: "MUST NOT add any air jump, glide, dive or ground-pound; the only airborne verb besides falling is the one air dash"
    - requirement_id: "CAM-01"
      category: "scope"
      status: "resolved"
      verification: "git diff"
      statement: "MUST NOT change attimo/scripts/camera/ or the 144 Hz human-verification item; the open CAM-01 gap stays as it is"
  artifacts:
    - path: "attimo/scripts/player/movement_config.gd"
      provides: "the regrouped tunable resource with jump chain and long-jump stage rows"
      contains: "long_jump_speed_3"
    - path: "attimo/scripts/player/player_controller.gd"
      provides: "jump chain (chain_stage 0..3), long-jump stack (long_jump_stage 0..3), shared combo_timer"
      contains: "long_jump_stage"
    - path: "attimo/scripts/player/states/long_jump.gd"
      provides: "LongJump sized by the long-jump stack"
      contains: "advance_long_jump_stage"
    - path: "docs/MOVEMENT-METRICS.md"
      provides: "regenerated metrics including Jump 3 and long jump stages 1-3"
      contains: "Jump 3 (salto)"
  key_links:
    - from: "attimo/project.godot"
      to: "attimo/scripts/player/states/ground_state.gd"
      via: "dash action bound to physical Left Shift, polled with is_action_just_pressed"
      pattern: "is_action_just_pressed\\(&\"dash\"\\)"
    - from: "attimo/scripts/player/states/jump.gd"
      to: "attimo/scripts/player/movement_config.gd"
      via: "jump_height_for_stage(stage) for stages 1..3"
      pattern: "jump_height_for_stage"
    - from: "attimo/scripts/player/states/long_jump.gd"
      to: "attimo/scripts/player/player_controller.gd"
      via: "advance_long_jump_stage() returns the stage 1..3 and resets the jump chain"
      pattern: "advance_long_jump_stage"
---

## Overview for approval

**In one sentence:** sprint and the air double jump go away, Left Shift becomes the dash, ground jumps chain Jump 1 -> 2 -> 3 (salto), dash + jump becomes a high long jump that stacks speed over three stages, run and jump feel faster and lighter, and MovementConfig is regrouped for tuning.

**States.** Removed: `Sprint`, `DoubleJump` (scripts, scene nodes, animator entries, the `double_jumped` fact). Kept: `Idle`, `Run`, `Jump` (stages 1-3, stage 3 = salto, physics only; the flip animation is Phase 3), `LongJump` (now the dash hop with a 1-3 stack), `Fall`, `Dash`. No new state, no glide, dive, ground-pound or air jump (MOVE-05).

**Rules.**
- Jump chain: a ground jump inside the landing window (0.35 s after touchdown) advances 1 -> 2 -> 3. After Jump 3, a missed window, standing still, a ground dash or a long jump, the next ground jump is Jump 1.
- Dash hop: dash, then jump during the dash or up to 0.15 s after it = long jump stage 1. Land, dash again inside the landing window, jump = stage 2, then 3; more clean hops stay at 3. A miss (window runs out, standing still, or a normal jump in between) resets the stack: the next long jump is stage 1. The long-jump speed is set per stage, not carried from the dash, so the stack can never go above the stage-3 value.
- A jump pressed in the air does nothing, unless coyote time is left or you land within the jump buffer (then it fires on the landing tick). One air dash per airtime, also after the salto.

**Input map.** `sprint` action deleted (with its gamepad slot). `dash` = Left Shift only (tap, physical key, left side); Q and Left Ctrl removed; gamepad slot B / Circle unchanged. Debug keys unchanged (F2/8, F4/9, F6/0).

**New MovementConfig** (one resource, 8 groups, 34 F2 sliders; was 6 groups, 39):

| Group | Fields and proposed defaults (old value in brackets) |
|---|---|
| Run | `run_speed` 8.5 (7.0; sprint 10.5 gone), `ground_accel` 70 (40), `ground_decel` 55, `turn_decel` 90, `turn_rate` 14 |
| Air | `air_accel` 45 (35), `air_decel` 0 |
| Gravity | `rise_gravity` 34 m/s^2 (new, replaces reference height 2.5 + apex time 0.42 = 28.3), `fall_multiplier` 1.3 (1.7), `terminal_speed` 40 |
| Jump chain | `jump_height` 2.0 (Jump 1), `jump_2_height` 2.6 (renamed), `jump_3_height` 3.4 (new, salto), `jump_min_height` 0.8 (tap) |
| Dash | `dash_speed` 22, `dash_time` 0.18, `dash_cooldown` 0.4, `dash_exit_speed` 12 (new, replaces carry 0.5 + exit cap 12, which always gave 12), `air_dash_gravity_scale` 0 |
| Long jump (dash hop) | `long_jump_height_1/2/3` 2.0 / 2.5 / 3.0 (1.0 / 1.2 / 1.4), `long_jump_speed_1/2/3` 14 / 16 / 18 m/s, slider max 22 (the separate speed cap is gone) |
| Timing windows | `coyote_time` 0.10, `jump_buffer_time` 0.12, `landing_window` 0.35 (renamed, now shared by chain and hop), `dash_jump_grace` 0.15, `combo_reset_speed` 0.5 (renamed) |
| Floor and platforms | `snap_min` 0.3, `snap_max` 0.5, `floor_max_angle_deg` 50, `platform_carry` 1.0 |

**Expected numbers (estimates; the metrics tool measures the real ones):** full speed in about 0.12 s (was 0.18 s); running jump about 5.5 m (was 4.8 m); 2.0 m apex reached in 0.34 s (was 0.37 s); Jump 2 / Jump 3 about 6.2 / 7.1 m at 2.6 / 3.4 m; long jump stages about 9 / 11.5 / 14 m at 2.0 / 2.5 / 3.0 m (was 10.6 / 11.7 / 12.5 m at 1.0 / 1.2 / 1.4 m).

**Files.**
- Delete: `attimo/scripts/player/states/sprint.gd` and `double_jump.gd` (with their `.uid` files).
- Modify, game: `attimo/project.godot`, `movement_config.gd`, `movement_default.tres`, `player_controller.gd`, states `air_state`, `ground_state`, `run`, `dash`, `jump`, `long_jump`, `mannequin_animator.gd`, `player.tscn`, `autoload/event_bus.gd`, debug `metrics_overlay.gd` and `latency_probe.gd`, tools `movement_metrics.gd` and `measure_movement.gd`.
- Modify, tests: `fixtures.gd`, `test_ground_movement`, `test_jump`, `test_long_jump`, `test_dash`, `test_input_map`, `test_conventions`, `test_movement_metrics`.
- Modify, docs: `docs/CONVENTIONS.md`, `docs/MOVEMENT-METRICS.md` (regenerated), `.planning/REQUIREMENTS.md` (MOVE-02, MOVE-05, MOVE-07, MOVE-09, FEEL-02), `.planning/ROADMAP.md` (Phase 2 line, goal, criteria 1-3; Phase 3 criterion 1; Phase 12 criteria 2-3).
- Not touched: camera code (CAM-01 144 Hz gap stays open), the gym, the tuning panel code (rows are generated), `CLAUDE.md`, `PROJECT.md`, the Phase 2 VERIFICATION report.

**Risks.**
1. Speed stack balance: 14 / 16 / 18 m/s are first guesses. A hop streak at stage 3 averages about 18-19 m/s, and stage 3 clears more than the gym's widest gap (12 m). Tune in F2.
2. Camera at higher speed: the camera code is not touched. Long-jump speeds are capped at 22 m/s (slider maximum), the speed the camera and tunnelling tests already cover. Follow lag at sustained 18 m/s still needs your eyes in the gym.
3. Hop timing: the dash must be pressed after touchdown. A dash pressed just before landing becomes the air dash (there is no dash buffer). If that feels too strict, a dash buffer is a follow-up.
4. Tests rewritten: 3 sprint scenarios (test_ground_movement), 6 double-jump scenarios (test_jump), almost all of test_long_jump, 2 combo scenarios and the exit-speed checks (test_dash), plus test_input_map, test_conventions and test_movement_metrics. The check count of the suite changes (1009 today).
5. `fall_multiplier` 1.3 is below the 1.5-2x band of Phase 2 decision D-04; your "less heavy" decision overrides it. The fall stays heavier than the rise (MOVE-03; the slider minimum is 1.0).
6. Superseded Phase 2 decisions: D-03 (sprint), D-05/D-06 (chain feeds the long jump), D-08 (double jump), and the deferred "Odyssey triple jump / tempo stage" idea is now taken.
7. Left for you: the core value line in `PROJECT.md` and `CLAUDE.md` still says "Laufen, Sprint, Sprung und Dash", and the `CLAUDE.md` input table still lists sprint and Ctrl/Q. Your own text, not changed here. Say so if I should update it.

**Choices I made (change them before approval if you disagree):** a miss resets the stack fully to stage 1 (not one level down); chain and hop share one `landing_window`; a ground dash breaks the jump chain; an air dash during a hop streak does not break the streak; the long-jump speed is set per stage, never carried.

**Order.** 4 tasks. Each one ends with a green full suite and a regenerated metrics doc, so the work can stop safely after any task: (1) sprint out, Shift dash, faster run, (2) air jump out, Jump 1-2-3 salto chain, (3) dash-hop speed stack, (4) lighter jump, final MovementConfig layout, requirement and roadmap wording.

---

<objective>
Rework the Phase 2 movement after the gym feedback, following the user's final decisions U1-U8 (from the planning context, 2026-11-06): remove sprint (U1) and the air double jump (U2), move the dash to Left Shift (U3), add the ground chain Jump 1 -> 2 -> 3 salto (U4) and the dash-hop long jump with a three-stage speed stack (U5), make the run-up faster and the jump lighter with more air control (U6), regroup MovementConfig for tuning (U7), and keep tests, metrics doc and requirements in sync (U8).

Purpose: the core value is the movement feel; the gym sign-off showed sprint, the double jump and the flat long jump do not deliver it.
Output: reworked states and controller, one regrouped MovementConfig, Left Shift dash, rewritten tests, regenerated docs/MOVEMENT-METRICS.md, updated CONVENTIONS, REQUIREMENTS and ROADMAP wording.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@docs/CONVENTIONS.md
@docs/MOVEMENT-METRICS.md
@attimo/scripts/player/movement_config.gd
@attimo/scripts/player/player_controller.gd

Facts the executor needs (checked at planning time):
- Run tests with `bash attimo/tests/run.sh [filter,filter]` (substring filter; `test_jump.gd` targets test_jump only, `test_jump` also matches test_jump_fact). Regenerate the metrics doc with `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` (prints `MEASURE: PASSED`). test_movement_metrics fails on a stale config snapshot, so regenerate after every config change.
- The suite prints one line per check; when reading output, filter it, for example with `grep -E 'FAIL|SMOKE SUMMARY|RUN.SH|MEASURE:'`.
- Running the engine rewrites `attimo/project.godot` and some `.import` files. After each run, check `git diff --stat` and revert engine noise; keep only intended edits.
- test_feedback_guard scans gameplay code including comments for feedback tokens (Tween, shake, particles, audio); new comments must avoid those words.
- TuningPanel builds one slider per float with a range hint from `MovementConfig.get_property_list()` and a header per `@export_group`; it needs no code change. Keep every tunable a ranged float.
- `Fixtures.send_action_event` sends InputEventAction events; real key events go through `Input.parse_input_event` plus `Input.flush_buffered_events()`.
- Typed GDScript is enforced (untyped declarations are parse errors). Deleted scripts must lose their `.uid` file and their `ext_resource` line in `attimo/scenes/player/player.tscn`.
- Work on branch `dev`; commit after each task. Do not commit PLAN, SUMMARY or STATE files (the quick orchestrator does that).
</context>

<tasks>

<!-- planner-discipline-allow: sprint -->
<!-- planner-discipline-allow: double_jump -->
<!-- planner-discipline-allow: DoubleJump -->
<!-- planner-discipline-allow: double_jumped -->
<!-- planner-discipline-allow: air_jump_available -->
<!-- planner-discipline-allow: will_land_within -->
<!-- planner-discipline-allow: long_jump_speed_cap -->
<!-- planner-discipline-allow: dash_exit_cap -->
<!-- planner-discipline-allow: dash_carry -->
<!-- planner-discipline-allow: take_chain_for_long_jump -->
<!-- planner-discipline-allow: refresh_chain_window -->
<!-- planner-discipline-allow: hold_chain_through_grace -->
<!-- planner-discipline-allow: chain_window -->
<!-- planner-discipline-allow: chain_reset_speed -->
<!-- planner-discipline-allow: chain_timer -->
<!-- planner-discipline-allow: reference_jump_height -->
<!-- planner-discipline-allow: reference_apex_time -->

<task type="tracer">
  <name>Task 1 (tracer): Left Shift dashes, there is no sprint, one faster run speed</name>
  <files>attimo/project.godot, attimo/scripts/player/movement_config.gd, attimo/resources/player/movement_default.tres, attimo/scripts/player/states/run.gd, attimo/scripts/player/states/dash.gd, attimo/scripts/player/states/ground_state.gd, attimo/scripts/player/states/sprint.gd (delete), attimo/scripts/player/states/sprint.gd.uid (delete), attimo/scripts/player/mannequin_animator.gd, attimo/scenes/player/player.tscn, attimo/tests/smoke/test_ground_movement.gd, attimo/tests/smoke/test_input_map.gd, attimo/tests/smoke/test_conventions.gd, attimo/tests/smoke/test_movement_metrics.gd, attimo/tools/movement_metrics.gd, docs/CONVENTIONS.md, docs/MOVEMENT-METRICS.md</files>
  <read_first>attimo/project.godot (the dash and sprint blocks of [input]), attimo/scripts/player/states/run.gd, attimo/scripts/player/states/dash.gd, attimo/scripts/player/mannequin_animator.gd, attimo/scenes/player/player.tscn, attimo/tests/smoke/test_ground_movement.gd (scenarios g, h, i), attimo/tests/smoke/test_input_map.gd, attimo/tools/movement_metrics.gd (grep sprint for the affected lines; do not read the whole file)</read_first>
  <action>
Wire one path end to end: physical Left Shift key -> dash action -> Dash state -> dash_started fact, with no sprint anywhere (U1, U3).

1. Input map (U3): in attimo/project.godot delete the whole sprint action block. Replace the two dash events (physical Q and physical Left Ctrl) with exactly one InputEventKey: physical_keycode 4194325 (Shift), location 1 (left), shift_pressed false, every other field as in the existing key events. shift_pressed stays false on purpose: a binding without modifier flags matches the Shift press whatever modifier state the OS reports for the Shift key itself. The dash stays a tap because all states poll is_action_just_pressed.
2. Config (U1, U6): in movement_config.gd delete sprint_multiplier and sprint_accel. Set run_speed default 8.5 and ground_accel default 70. Update the run_speed comment to say it is the one run speed (no separate fast run). Mirror the values in movement_default.tres and delete the two removed keys there.
3. States: delete sprint.gd and sprint.gd.uid. run.gd: drop the hand-over at the end of _ground_update and rewrite the class comment (Run accelerates to run_speed, skids, brakes). dash.gd _finish: drop the branch that returned the removed state; with input return Run, without input Idle. ground_state.gd: the class comment lists Idle and Run only. mannequin_animator.gd: remove the removed state from STATE_TO_ANIM and from RUNNING_STATES. player.tscn: remove the node and its ext_resource line (id 12_sprint).
4. Tests: test_input_map: drop sprint from ACTIONS, replace the Q, Ctrl and Shift-sprint checks with: dash has exactly one event, it is physical Shift with location KEY_LOCATION_LEFT, and InputMap.has_action for the removed action is false. test_conventions: drop it from ACTIONS. test_ground_movement: replace scenarios (g), (h), (i) by one tracer scenario (g): run to run_speed, then send a real InputEventKey (physical_keycode KEY_SHIFT, location KEY_LOCATION_LEFT, pressed true, shift_pressed true as an OS reports it) through Input.parse_input_event and flush; assert Dash within 2 ticks and exactly one dash_started while the key is held for 30 ticks (tap, no repeat); send the release event (pressed false, shift_pressed false); assert the state returns to Run and the speed settles at run_speed; assert the StateMachine has no child named after the removed state. Also assert in (a) that run_speed is reached within ceil(run_speed / ground_accel * 60) + 1 ticks.
5. Metrics: in movement_metrics.gd remove the fast-run part of _measure_ground, the full_sprint flight, the RELEASE_ACTIONS entry, the _run_up flag (always plain run) and the doc rows "Sprint speed", "Full jump (sprint)", grid row "Sprint jump". test_movement_metrics: drop "Sprint speed" and "Full jump (sprint)" from ROW_LABELS.
6. Docs: docs/CONVENTIONS.md Input Map table: delete the sprint row; dash row becomes Left Shift (tap, left side only), gamepad slot B / Circle, note "single binding, decided after the gym sign-off (U3)". Regenerate docs/MOVEMENT-METRICS.md with the tool.
No comment anywhere in attimo/scripts, attimo/autoload, attimo/scenes or attimo/tools may mention the removed action or state name (the gate greps comments).
  </action>
  <reversibility rating="costly">Action names are referenced from code (Phase 1 D-15); the user settled removal and the new binding (U1, U3), so no checkpoint.</reversibility>
  <verify>
    <automated>! grep -rniq 'sprint' attimo/scripts attimo/autoload attimo/scenes attimo/tools attimo/project.godot && test ! -e attimo/scripts/player/states/sprint.gd && bash attimo/tests/run.sh test_ground_movement,test_input_map,test_conventions,test_dash,test_scene_run,test_mannequin_animation,test_feedback_guard && bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh</automated>
  </verify>
  <done>Baseline at HEAD: the sprint grep finds 40+ lines and sprint.gd exists. After the task: no match, the file is gone, a real Left Shift key press dashes exactly once, running reaches 8.5 m/s in about 0.12 s, MOVEMENT-METRICS.md shows one run speed, MEASURE: PASSED and RUN.SH: PASSED. Committed on dev.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: No air jump; ground chain Jump 1 -> Jump 2 -> Jump 3 (salto)</name>
  <files>attimo/scripts/player/movement_config.gd, attimo/resources/player/movement_default.tres, attimo/scripts/player/player_controller.gd, attimo/scripts/player/states/air_state.gd, attimo/scripts/player/states/jump.gd, attimo/scripts/player/states/dash.gd, attimo/scripts/player/states/double_jump.gd (delete), attimo/scripts/player/states/double_jump.gd.uid (delete), attimo/scripts/player/mannequin_animator.gd, attimo/scenes/player/player.tscn, attimo/autoload/event_bus.gd, attimo/scripts/debug/metrics_overlay.gd, attimo/scripts/debug/latency_probe.gd, attimo/tests/fixtures.gd, attimo/tests/smoke/test_jump.gd, attimo/tests/smoke/test_long_jump.gd, attimo/tests/smoke/test_dash.gd, attimo/tests/smoke/test_conventions.gd, attimo/tests/smoke/test_movement_metrics.gd, attimo/tools/movement_metrics.gd, docs/CONVENTIONS.md, docs/MOVEMENT-METRICS.md</files>
  <read_first>attimo/scripts/player/states/air_state.gd, attimo/scripts/player/states/jump.gd, attimo/scripts/player/states/double_jump.gd, attimo/tests/smoke/test_jump.gd, attimo/tests/smoke/test_long_jump.gd (chain scenarios c1-c6 and l8, helpers), attimo/tests/smoke/test_dash.gd (scenarios 6a, 6b), attimo/tools/movement_metrics.gd (_measure_jumps, _double_jump, _measure_dashes, _check_invariants, _write_doc jump rows)</read_first>
  <behavior>
    - An air press after the coyote window, far from the ground: no jumped fact, vertical speed keeps falling, and no jump fires on the later landing (the press expired).
    - A press a few ticks past coyote after walking off a ledge does not jump.
    - A press shortly before landing (Fixtures.will_land_within(jump_buffer_time * 0.5)) fires one ground jump on the landing tick and keeps the horizontal speed.
    - Jump 1 -> land -> Jump 2 -> land -> Jump 3, all held: apexes within 0.1 m of jump_height, jump_2_height, jump_3_height and strictly rising; chain_stage_changed gives 1, 2, 3.
    - A tapped Jump 3 is stage 3 but cut to about jump_min_height; a buffered press advances the chain too.
    - Window timeout and a standing landing reset to Jump 1; a fourth jump inside the window after Jump 3 is Jump 1.
    - After Jump 3 exactly one air dash fires; a jump press during or after an air dash adds no rise.
  </behavior>
  <action>
Remove the air jump (U2) and grow the chain to three ground jumps (U4). Write the new and changed test scenarios first, see them fail, then implement.

1. Config: delete double_jump_height. Rename chain_jump_height to jump_2_height (2.6) and add jump_3_height (3.4, range 0.5-6.0, comment: Jump 3, the salto, the highest ground jump). Add func jump_height_for_stage(stage: int) -> float returning jump_height, jump_2_height or jump_3_height for stage 1, 2, 3 (clamped). Mirror in movement_default.tres.
2. Controller: delete the air-jump flag (field and refill in _land), will_land_within and _probe. advance_chain_for_ground_jump returns chain_stage + 1 when chain_stage is 1 or 2 and the window is open, otherwise 1 (stage 3 starts a new chain, as the old stage 2 did). Update the doc comments to stages 0..3.
3. AirState: _airborne_jump_decision keeps only the coyote rule (return Jump); any other press stays buffered and either fires on the landing tick through the existing grounded branch or expires. Rewrite the rules comment block without an air jump. jump.gd: height = config.jump_height_for_stage(stage); class comment names Jump 1, 2 and 3 (salto; physics only per U4, the flip animation is Phase 3 MOVE-09). dash.gd: delete the airborne jump hand-off in physics_update (a jump press during an air dash does nothing beyond the buffer) and fix the class comment.
4. Delete double_jump.gd and its .uid; remove the node and ext_resource 11_double_jump from player.tscn and the entries from STATE_TO_ANIM and AIRBORNE_STATES in mannequin_animator.gd.
5. EventBus: delete the air-jump signal and its comment; chain_stage_changed comment says 1..3, 0 on reset. metrics_overlay.gd and latency_probe.gd: drop the connection, the handler and the comment mention.
6. Tests: move the landing prediction into attimo/tests/fixtures.gd as static func will_land_within(player: PlayerController, seconds: float) -> bool with the same math as the deleted controller method (not rising, test_move along current horizontal velocity plus the fall drop under gravity times fall_multiplier, floor normal within floor_max_angle). test_jump: keep (a)-(e) (switch (d) to the fixture helper, drop the unspent-air-jump check in (c)), delete (f)-(k), add the no-air-jump scenarios from the behavior block. test_long_jump: rewrite c1-c6 for three stages per the behavior block, add c7 (salto then one air dash), change l8 to "air dash plus jump: no long_jumped and no extra rise". Leave l1-l7 as they are; the long jump changes in Task 3. test_dash: replace 6a and 6b by one scenario: jump -> air dash -> jump press gives one airborne dash_started and no rise. test_conventions: the EventBus signal-count threshold becomes at least 6.
7. Metrics: movement_metrics.gd drops the air-jump flight, its recorder, TAKEOFF_KINDS entry and rows, measures Jump 1 -> Jump 2 -> Jump 3 with landing-tick presses, writes rows "Jump 2 (chain)" and "Jump 3 (salto)" and grid row "Jump 3 salto", adds the invariant Jump 1 apex below Jump 2 below Jump 3, and fixes the air-dash measurement comment. test_movement_metrics ROW_LABELS: drop "Double jump", add "Jump 3 (salto)". docs/CONVENTIONS.md event bus table: delete the air-jump row, jumped covers Jump 1, 2 and 3, chain_stage_changed 1..3. Regenerate docs/MOVEMENT-METRICS.md.
Comments in game code, autoload, scenes and tools say "air jump" where needed, never the removed state or fact name (the gate greps comments).
  </action>
  <verify>
    <automated>! grep -rniqE 'double.?jump|air_jump_available' attimo/scripts attimo/autoload attimo/scenes attimo/tools && ! grep -rnq 'will_land_within' attimo/scripts && bash attimo/tests/run.sh test_jump.gd,test_long_jump,test_dash,test_conventions,test_metrics_overlay,test_latency,test_feedback_guard && bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh</automated>
  </verify>
  <done>Baseline at HEAD: the air-jump grep finds 40+ lines. After the task: no match, double_jump.gd is gone, the chain reaches a 3.4 m salto, an air press never adds rise, MOVEMENT-METRICS.md has "Jump 3 (salto)" and no air-jump row, MEASURE: PASSED and RUN.SH: PASSED. Committed on dev.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Dash hop: long jump stages 1-3 with a speed stack</name>
  <files>attimo/scripts/player/movement_config.gd, attimo/resources/player/movement_default.tres, attimo/scripts/player/player_controller.gd, attimo/scripts/player/states/long_jump.gd, attimo/scripts/player/states/dash.gd, attimo/scripts/player/states/ground_state.gd, attimo/autoload/event_bus.gd, attimo/scripts/debug/metrics_overlay.gd, attimo/tests/smoke/test_long_jump.gd, attimo/tests/smoke/test_dash.gd, attimo/tests/smoke/test_movement_metrics.gd, attimo/tools/movement_metrics.gd, attimo/tools/measure_movement.gd, docs/CONVENTIONS.md, docs/MOVEMENT-METRICS.md</files>
  <read_first>attimo/scripts/player/states/long_jump.gd, attimo/scripts/player/states/dash.gd, attimo/tests/smoke/test_long_jump.gd (l1-l7 and the _dash_jump helper), attimo/tests/smoke/test_dash.gd (scenarios 3 and 7), attimo/tools/movement_metrics.gd (_measure_long_jumps, _long_jump, _dash_jump, _grace_jump, _check_invariants, long-jump doc rows)</read_first>
  <behavior>
    - From a run, dash + jump on one tick: long_jumped stage 1, take-off speed within 0.1 of long_jump_speed_1 and above run_speed, apex within 0.15 of long_jump_height_1, farther than a running Jump 1.
    - Dash + jump on the landing tick of each long jump: stages 1, 2, 3 with take-off speeds and apexes matching the rows, distances strictly rising; a fourth clean hop is stage 3 again.
    - Waiting past landing_window after a long-jump touchdown, or a normal ground jump in between, makes the next long jump stage 1.
    - A jump in the last tick of dash_jump_grace is a long jump at its stage row speed; after the grace it is a normal Jump.
    - A duplicated config with dash_speed 30 still takes off at the stage row (speed is set, not carried); no tick of any long jump exceeds 22 m/s + 0.1, and every long_jump_speed row is at most 22.
    - A long jump and a ground dash each reset the jump chain (chain_stage_changed 0).
    - Dash exit speed equals maxf(run_speed, dash_exit_speed) within 0.01 on the ground and in the air.
  </behavior>
  <action>
Build the dash hop (U5) on the existing LongJump. Tests first (rewrite l1-l7 per the behavior block, keep l8), then the implementation.

1. Config: replace the six long-jump rows and the long-jump speed cap with long_jump_height_1/2/3 (2.0 / 2.5 / 3.0, range 0.5-6.0) and long_jump_speed_1/2/3 (14 / 16 / 18, range 5.0-22.0; comment: 22 m/s is the speed the camera and tunnelling tests cover, do not raise it without re-running them). long_jump_height(stage) and long_jump_speed(stage) take stage 1..3 (clamped). Replace dash_carry and dash_exit_cap with dash_exit_speed (12.0, range 5.0-22.0). Rename chain_window to landing_window (0.35; comment: seconds after touchdown in which the next ground jump advances the chain or the next ground dash keeps the long-jump stack) and chain_reset_speed to combo_reset_speed (0.5). Mirror in movement_default.tres.
2. Controller: add long_jump_stage (0 none, 1..3 the stage of the last long jump while the stack lives). Rename chain_timer to combo_timer: _land opens it with landing_window when chain_stage or long_jump_stage is above 0. The renamed _tick_combo runs on the ground only, does not count down while the current state is Dash, and at 0, or when standing below combo_reset_speed outside a dash, resets the chain (emitting chain_stage_changed 0) and sets long_jump_stage to 0. advance_chain_for_ground_jump also sets long_jump_stage to 0 (a normal jump is a miss). Replace take_chain_for_long_jump with advance_long_jump_stage() -> int: stage = mini(long_jump_stage + 1, 3) when long_jump_stage is above 0, else 1; store it, reset the jump chain to 0, close combo_timer, return the stage. Replace refresh_chain_window with on_ground_dash_started(): resets the jump chain to 0 and leaves the long-jump stack alone. Replace hold_chain_through_grace with hold_combo_through_grace(): when long_jump_stage is above 0 and combo_timer is open, combo_timer = maxf(combo_timer, dash_jump_grace).
3. long_jump.gd: stage = actor.advance_long_jump_stage(); horizontal speed = config.long_jump_speed(stage) along the dash direction, set, never added and never taken from the dash; vertical speed = jump_speed(long_jump_height(stage)); air_speed_cap = maxf(run_speed, speed); release cut unchanged; emit long_jumped(position, stage) with stage 1..3. Rewrite the class comment. dash.gd: on a ground start call on_ground_dash_started(); exit speed = maxf(config.run_speed, config.dash_exit_speed); on a ground finish call hold_combo_through_grace(). ground_state.gd: comment only if it names removed helpers.
4. EventBus comment and docs/CONVENTIONS.md: long_jumped stage is 1 (first dash hop), 2, 3 (top of the stack). metrics_overlay.gd: add lines "Long jump stage: N" (read from the player's long_jump_stage) and "Speed: x.x m/s" (horizontal speed).
5. test_dash: checks (3) and (7) compare the exit speed with maxf(run_speed, dash_exit_speed) within 0.01.
6. Metrics: movement_metrics.gd measures a hop streak (run up, dash + jump, then dash + jump on each landing tick) for stages 1, 2, 3 and a fourth hop (stays 3), plus one last-grace-tick long jump at stage 1. Rows "Long jump stage 1", "Long jump stage 2", "Long jump stage 3", "Long jump stage 3 (repeat)", "Long jump (last grace tick)"; timing row "Landing window" replaces the chain-window row; grid rows for the three stages; section text explains the stack and the 22 m/s envelope. Invariants: distances and apexes strictly rising over stages 1-3, take-off speed equals the stage row within 0.1, no sample above 22 m/s + CAP_SLACK. Fix the header comment of measure_movement.gd. test_movement_metrics ROW_LABELS: the three stage rows and "Landing window" replace the small/mid/max rows and "Chain window". Regenerate docs/MOVEMENT-METRICS.md.
  </action>
  <verify>
    <automated>! grep -rnqE 'long_jump_(height|speed)_(small|mid|max)|long_jump_speed_cap|dash_exit_cap|dash_carry|take_chain_for_long_jump|refresh_chain_window|hold_chain_through_grace|chain_window|chain_reset_speed|chain_timer' attimo/scripts attimo/autoload attimo/scenes attimo/tools attimo/resources attimo/tests && bash attimo/tests/run.sh test_long_jump,test_dash,test_jump.gd,test_metrics_overlay,test_tuning_panel,test_feedback_guard && bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh</automated>
  </verify>
  <done>Baseline at HEAD: the old-name grep finds 69 lines. After the task: no match, a hop streak measures stages 1-3 at 14 / 16 / 18 m/s with apexes near 2.0 / 2.5 / 3.0 m and stays at 3, a miss restarts at 1, no long jump exceeds 22 m/s, MEASURE: PASSED and RUN.SH: PASSED. Committed on dev.</done>
</task>

<task type="auto">
  <name>Task 4: Lighter jump, final MovementConfig layout, requirement and roadmap wording</name>
  <files>attimo/scripts/player/movement_config.gd, attimo/resources/player/movement_default.tres, attimo/scripts/player/player_controller.gd, attimo/tests/fixtures.gd, attimo/tests/smoke/test_jump.gd, docs/MOVEMENT-METRICS.md, .planning/REQUIREMENTS.md, .planning/ROADMAP.md</files>
  <read_first>attimo/scripts/player/movement_config.gd (as left by Task 3), .planning/REQUIREMENTS.md (lines 20-31, 86), .planning/ROADMAP.md (lines 33, 76-86, 112-116, 230-237)</read_first>
  <action>
1. Gravity (U6, U7): replace reference_jump_height and reference_apex_time with rise_gravity (34.0 m/s^2, range 10.0-80.0; comment: gravity while rising and on the ground; higher = snappier rise, jump heights stay as set). Delete func gravity(); add func fall_gravity() -> float returning rise_gravity * fall_multiplier; jump_speed(height) uses rise_gravity. fall_multiplier default 1.3 (range stays 1.0-3.0 so the fall can never be lighter than the rise, MOVE-03). air_accel default 45. Update the callers: player_controller.gd _integrate, the fixture will_land_within (fall_gravity()), test_jump scenario (b) tolerance (rise_gravity).
2. Final layout (U7): order movement_config.gd into exactly these 8 @export_group blocks: Run, Air, Gravity, Jump chain, Dash, Long jump (dash hop), Timing windows, Floor and platforms, holding the 34 fields of the overview table (coyote_time, jump_buffer_time, landing_window, dash_jump_grace and combo_reset_speed move to Timing windows). Every field gets a one-line ## comment with unit and what raising it feels like. The class comment explains the groups, that gravity is set directly, and that every divisor keeps a strictly positive minimum (T-02-02). Helpers stay at the bottom. Rewrite movement_default.tres in the same order with the overview defaults.
3. Wording (U1, U2, U4, U5, U8): REQUIREMENTS.md: MOVE-02 becomes "Player runs at one tunable run speed (no separate sprint); extra speed comes from the dash and the dash-hop long jump"; MOVE-05 becomes "Ground jumps chain Jump 1 -> Jump 2 -> Jump 3 (salto, highest) inside a landing window; there is no air jump, glide, dive or ground-pound"; MOVE-07 gains "(dash + jump = long jump; clean repeats on landing stack its speed over three stages)"; MOVE-09 drops the fast-run clip clause and names the flip as "Jump 3 salto (Jump_Start re-cut + procedural flip)"; FEEL-02 lists "landing, jump, Jump 3 salto, dash, long jump". ROADMAP.md: Phase 2 list line and goal name run, the Jump 1-2-3 chain, dash and dash hop instead of the removed verbs; criterion 1 ends with "at one tunable run speed"; criterion 2 replaces the air-jump sentence with the Jump 1 -> 2 -> 3 chain and "there is no air jump"; criterion 3 gains the long-jump stack clause; Phase 3 criterion 1 lists idle, run, jump start/air/land, the Jump 3 salto flip, the long jump, the ground dash and the held air-dash pose; Phase 12 criteria 2 and 3 name the salto and the long jump instead of the removed verbs. Keep checkbox states and the historical plan-list lines of Phase 2 unchanged.
4. Regenerate docs/MOVEMENT-METRICS.md, run the full suite, then confirm movement_default.tres has no diff left by the suite.
  </action>
  <verify>
    <automated>! grep -rnqE 'reference_jump_height|reference_apex_time|config\.gravity\(\)|func gravity\(' attimo/scripts attimo/tools attimo/tests attimo/resources && test "$(grep -c '^@export_group' attimo/scripts/player/movement_config.gd)" = "8" && test "$(grep -c '^@export_range' attimo/scripts/player/movement_config.gd)" = "34" && ! grep -qE 'MOVE-02\*\*: Player can sprint|MOVE-05\*\*: Player can double jump' .planning/REQUIREMENTS.md && ! grep -qE 'Exactly one double jump|and can sprint' .planning/ROADMAP.md && bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh && git diff --quiet -- attimo/resources/player/movement_default.tres</automated>
    <human-check>
      Play the movement gym (F5) on the Mac and judge, then report values worth changing:
      1. Left Shift dashes once per tap, nothing else is on Shift, Q and Ctrl do nothing.
      2. The run-up feels immediate; the jump feels lighter and snappier; air steering is a bit stronger.
      3. Jump 1 -> 2 -> 3 in rhythm: the salto is clearly higher; missing the rhythm gives Jump 1; one air dash works after the salto.
      4. Dash hops: the first already feels faster, stages 2 and 3 are visibly faster and higher, a miss drops back; the camera keeps up at stage 3 speed.
      5. F2 (or 8) shows 8 readable groups with 34 sliders; changes act at once.
    </human-check>
  </verify>
  <done>Baseline at HEAD: the reference-gravity grep finds 10 lines, 6 export groups and 39 ranged floats, MOVE-02/MOVE-05 and ROADMAP criteria 1-2 name the removed verbs. After the task: no reference-gravity names, 8 groups, 34 floats, reworded requirements and roadmap, MEASURE: PASSED, RUN.SH: PASSED, movement_default.tres untouched by the suite. Committed on dev. Human-check results go into the SUMMARY.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| keyboard -> Input Map -> FSM | local player input; only named actions reach gameplay code |
| F2 panel -> res:// MovementConfig | live tuning in memory; saving is editor-only (unchanged from 02-12) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261106-01 | Denial of service | LongJump speed stack (physics, camera) | medium | mitigate | stage speed is set per row, never added or carried; long_jump_speed rows have an export maximum of 22 m/s, the envelope the tunnelling and camera tests cover; test_long_jump and the metrics invariants fail above 22 m/s + 0.1 |
| T-261106-02 | Tampering | attimo/project.godot rewritten by the engine during test runs | low | mitigate | executor checks git diff after every run and keeps only the input map edit; test_input_map pins the single Left Shift dash binding |
| T-261106-03 | Tampering | movement_default.tres via the F2 Save button | low | accept | unchanged editor-only save path (T-02-16); the suite must leave the file without diff (Task 4 gate) |
| T-261106-SC | Tampering | package installs | low | accept | no package, addon or plugin installs in this plan |
</threat_model>

<verification>
- `bash attimo/tests/run.sh` ends with RUN.SH: PASSED after every task.
- `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` prints MEASURE: PASSED and docs/MOVEMENT-METRICS.md matches movement_default.tres.
- `git diff --stat -- attimo/scripts/camera` is empty (CAM-01 untouched).
- The negative greps of Tasks 1-4 all pass.
</verification>

<success_criteria>
- No sprint and no air jump exist in code, scene, input map or docs; Left Shift is the only dash key.
- Jump 1 -> 2 -> 3 (salto) and the long-jump stack 1 -> 2 -> 3 behave as the overview rules state and are pinned by tests.
- MovementConfig has 34 ranged floats in 8 commented groups, all live in F2.
- Run-up, jump and air control use the new defaults; metrics regenerated; full suite green.
- REQUIREMENTS.md and ROADMAP.md describe the reworked movement.
</success_criteria>

<output>
Create `.planning/quick/261106-erl-movement-rework-remove-sprint-and-air-do/261106-erl-SUMMARY.md` with `status: complete` in its frontmatter when done, including the measured metrics (run-up time, jump heights, long jump stages) and the human-check results.
</output>
