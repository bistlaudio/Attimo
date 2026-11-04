---
phase: 01-foundation-prototype-character
reviewed: 2026-11-04T00:00:00Z
depth: standard
files_reviewed: 42
files_reviewed_list:
  - README.md
  - docs/CONVENTIONS.md
  - attimo/project.godot
  - attimo/autoload/event_bus.gd
  - attimo/scenes/debug/event_log.tscn
  - attimo/scenes/player/mannequin.tscn
  - attimo/scenes/player/mannequin_state_machine.tres
  - attimo/scenes/player/player.tscn
  - attimo/scenes/proto/primitive_cube_small.tscn
  - attimo/scenes/proto/primitive_floor.tscn
  - attimo/scenes/proto/primitive_pillar.tscn
  - attimo/scenes/proto/primitive_wall.tscn
  - attimo/scenes/test/test_scene.tscn
  - attimo/scripts/core/physics_layers.gd
  - attimo/scripts/core/state.gd
  - attimo/scripts/core/state_machine.gd
  - attimo/scripts/debug/event_log.gd
  - attimo/scripts/player/mannequin_animator.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/fall.gd
  - attimo/scripts/player/states/idle.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/run.gd
  - attimo/tests/fixtures.gd
  - attimo/tests/run.sh
  - attimo/tests/run_smoke.gd
  - attimo/tests/smoke/test_animation_library.gd
  - attimo/tests/smoke/test_asset_hygiene.gd
  - attimo/tests/smoke/test_conventions.gd
  - attimo/tests/smoke/test_dash_fact.gd
  - attimo/tests/smoke/test_event_log.gd
  - attimo/tests/smoke/test_feedback_guard.gd
  - attimo/tests/smoke/test_input_map.gd
  - attimo/tests/smoke/test_jump_fact.gd
  - attimo/tests/smoke/test_mannequin_animation.gd
  - attimo/tests/smoke/test_movement_facts.gd
  - attimo/tests/smoke/test_project_settings.gd
  - attimo/tests/smoke/test_proto_pieces.gd
  - attimo/tests/smoke/test_scene_run.gd
  - attimo/tools/build_animation_library.gd
  - attimo/tools/build_mannequin_state_machine.gd
findings:
  critical: 0
  warning: 6
  info: 9
  total: 15
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-11-04
**Depth:** standard
**Files Reviewed:** 42 (frontmatter lists every file in scope)
**Status:** issues_found

## Summary

The Phase 1 code is small, typed throughout and consistent with the project rules. All declarations carry types, `untyped_declaration=2` is set in `project.godot`, input goes through Input Map actions only, collision is box-based, Jolt is set, and no movement physics or feedback effects are present (D-09 and FEEL-01 are respected). I found no security issue and no hardcoded absolute path. `run.sh` has `set -euo pipefail`, a version gate that runs before the project is touched, and correct `PIPESTATUS` handling. I verified the `PIPESTATUS` handling by running it, because the nested `if` looked suspicious.

No defect rises to BLOCKER. The concerns are:
- Several test assertions cannot detect the regression they claim to guard.
- The AnimationTree locomotion blend snaps instead of blending.
- Unknown-state handling in the FSM depends on `assert`, which is stripped in release builds.
- `run.sh` has no timeout.
- Tests leak bus connections and pressed actions.

The "Jump to Fall timer vs Idle timer" race in the 01-02 summary no longer exists in the code. Jump now hands over to Fall (jump.gd:21), and the tree's `Jump -> Fall` AT_END edge and the FSM's `travel(Fall)` target the same node. That note is stale and should be corrected, but it is not a code defect.

## Warnings

### WR-01: Event-log eviction assertion cannot detect wrong-end eviction

**File:** `attimo/tests/smoke/test_event_log.gd:49-52`
**Issue:** After 4 distinct facts and 20 more `jumped` emits, the test asserts `not lines[0].contains("landed")`.
- If `_on_fact` evicted the newest line (`pop_back()` instead of `pop_front()`), `lines[0]` would still be the first `jumped` line.
- The assertion would pass, so it cannot fail for the bug it names ("oldest line was dropped").
- Line 51 only checks the size.

**Fix:** After the 20 emits no original fact may survive, and the last line must be the newest.
```gdscript
for line: String in log_node.lines:
    check.call(not line.contains("landed") and not line.contains("dash_started"), "original facts were evicted")
bus.emit_signal(&"landed", Vector3.ZERO, 1.0)
check.call(log_node.lines[-1].contains("landed"), "newest line is kept at the end")
```

### WR-02: Doc-sync guard asserts mostly tautologies

**File:** `attimo/tests/smoke/test_conventions.gd:63-70`
**Issue:** `docs/CONVENTIONS.md:10` claims these tests "fail if this document, project.godot and PhysicsLayers drift apart".
- `doc.contains("player")` is true for any text mentioning the player at all.
- `doc.contains(action)` is a bare substring test: `jump`, `aim`, `pause` and `sprint` match any prose.
- `doc.contains(layer_name)` has the same weakness.
- Changing a binding or bitmask in the doc table cannot fail any of these.

**Fix:** Parse the markdown tables and compare rows to the engine state. Alternatively, assert on the exact table cells, for example `"| `jump` | Space |"` and `"| 2 | Player | 2 | `PLAYER` |"`. Otherwise soften the claim in CONVENTIONS.md:10.

### WR-03: Locomotion blend snaps (no smoothing) and unknown states silently map to Idle

**File:** `attimo/scripts/player/mannequin_animator.gd:26,32`
**Issue:**
- `blend_position` is set directly to 1.0 or 0.0 on every state change. The 0.1 s xfade in the state machine only applies between machine nodes, and Idle and Run are the same `Locomotion` node. Idle to Run therefore pops the pose instantly. This is the "smooth feel" the project calls its core value, even if Phase 1 is a demo.
- Entering Jump or Dash from Run also resets the blend to 0.0 while the Locomotion node is still crossfading out. The legs visibly pop to idle during the fade.
- `test_movement_facts.gd:42,46` assert exactly 1.0 and 0.0, which locks the snap in.
- `STATE_TO_ANIM.get(to_state, &"Locomotion")` plus `else 0.0` means a state added in Phase 2 (Sprint, WallRun) silently shows the idle pose with no warning.

**Fix:**
- Only touch `blend_position` when entering Idle or Run, and tween or `move_toward` it per frame, for example in `_process` toward a `_target_blend`.
- Use `STATE_TO_ANIM[to_state]` guarded with `assert(STATE_TO_ANIM.has(to_state))` or `push_warning` instead of a silent default.

### WR-04: Unknown-state validation uses `assert` only (stripped in release and exported builds)

**File:** `attimo/scripts/core/state_machine.gd:21,35`
**Issue:** A state returning a misspelled name hits `_states[next]` and gets `null`. `current.exit()` has already run on the old state and `current.enter()` is then called on null, so the game crashes with a Nil call and the FSM is left half-transitioned. In a release export the `assert` is removed, so this path is unguarded. In `setup()`, a missing `initial_state` fails the same way at line 22.

**Fix:**
```gdscript
func transition_to(next: StringName) -> void:
    if not _states.has(next):
        push_error("StateMachine: unknown state '%s' requested from '%s'" % [next, current.name])
        return
    ...
```

### WR-05: `run.sh` has no timeout, so a stuck test hangs the harness forever

**File:** `attimo/tests/run.sh:75,91,95,97`
**Issue:** Several tests `await` conditions that never resolve if something breaks, for example `await player.tree_exited` in `test_dash_fact.gd:102` and `test_movement_facts.gd:110`, and `await scene.tree_exited` in `test_scene_run.gd:39`. A headless Godot that blocks there never exits. Neither the import nor the run step has a timeout, so CI or an agent run blocks indefinitely.

**Fix:** Wrap the engine calls, using `timeout` or `gtimeout` when available.
```bash
RUN_TIMEOUT="${RUN_TIMEOUT:-300}"
timeout "$RUN_TIMEOUT" "$GODOT" --headless ...   # exit 124 -> "FAILED (timeout)"
```
Alternatively add a watchdog `Timer` in `run_smoke.gd` that calls `quit(2)`.

### WR-06: Tests leak bus connections and pressed actions on early exit

**File:** `attimo/tests/smoke/test_jump_fact.gd:11-12` (also `fixtures.gd:27-30`)
**Issue:**
- `test_jump_fact` connects two lambdas to the long-lived EventBus autoload and never disconnects them.
- The lambdas stay connected for the rest of the run and keep appending to captured arrays.
- `test_dash_fact` and `test_movement_facts` do disconnect (in `_end`), so the pattern is inconsistent.
- In every scenario that uses `Input.action_press(...)` (for example `test_dash_fact.gd:24`, `test_movement_facts.gd:36,78`, `test_scene_run.gd:144`), a failed or aborted scenario leaves the action pressed. That state then leaks into later tests, because it is process-global.

**Fix:** Disconnect the two callables at the end of `test_jump_fact`. Add a `Fixtures.release_all()` that calls `Input.action_release` for every action, and call it at the start of each test and in the runner between tests.

## Info

### IN-01: EventLog misses the initial `'' -> Idle` fact and would swallow mouse clicks when visible

**File:** `attimo/scripts/debug/event_log.gd:16-19`, `attimo/scenes/debug/event_log.tscn:12`, `attimo/scenes/test/test_scene.tscn:177-180`
**Issue:**
- In the test scene the Player is ordered before EventLog. `StateMachine.setup()` emits `movement_state_changed("", "Idle")` in the Player's `_ready`, before EventLog connects, so the log never shows the first state.
- `PanelContainer` defaults to `mouse_filter = STOP`. When the overlay is visible it consumes mouse events over its area, so Phase 2+ `_unhandled_input` mouse handling would not see them.

**Fix:** Place `EventLog` before `Player` in the scene, or have `StateMachine` emit the initial fact deferred. Set `mouse_filter = 2` (IGNORE) on `PanelContainer` and `Lines`.

### IN-02: `travel(Locomotion)` from `Land` goes through an AT_END edge

**File:** `attimo/tools/build_mannequin_state_machine.gd:30`, `attimo/scripts/player/mannequin_animator.gd:30-32`
**Issue:** The only `Land -> Locomotion` edge is the AUTO plus AT_END one. If the player lands (Fall to Idle plays Land) and presses a move key within roughly 0.67 s, the FSM goes to Run and calls `travel(&"Locomotion")` from Land. Depending on how `travel` treats an AT_END edge, the run pose is delayed until Land ends. No test covers Idle to Run during Land (test (d) lands straight into Run).

**Fix:** Verify the behaviour in a test. If it lags, add a manual `Land -> Locomotion` edge in the tool script next to the other direct edges.

### IN-03: Dash from Fall re-enters Fall with a fresh timer, so `landed` can be postponed indefinitely

**File:** `attimo/scripts/player/states/fall.gd:16-17`, `attimo/scripts/player/states/dash.gd:30-31`
**Issue:** Fall to Dash to Fall to Dash resets `_timer`. Spamming dash keeps the player airborne forever and never emits `landed`. This is intended to be capped in Phase 2 (air-dash limit, MOVE-06/07). It is a state-chain hazard worth a tracking note, since tests assert `landed` exactly once only for non-spamming input.

**Fix:** Track it in the Phase 2 plan for MOVE-07, or add a one-air-dash flag now.

### IN-04: `run.sh` is macOS-biased, duplicates the version pin, and its exit codes collide

**File:** `attimo/tests/run.sh:9,13,17,113`
**Issue:**
- The default `GODOT` path is macOS-only (`Contents/MacOS/Godot`). Other machines must export it. The README documents this, so it is only a note.
- `EXPECTED_VERSION` (including the commit hash) is duplicated in `README.md:8` and `test_project_settings.gd:13`. A pin bump needs three edits.
- `exit "$RUN_RC"` propagates the engine's raw exit code. A Godot exit code of 3 or 4 would be indistinguishable from the harness codes "wrong engine" and "repo check failed".

**Fix:** Normalise the engine failure to exit 1, for example `exit 1` after printing the code. Optionally derive the expected version from one file.

### IN-05: Raw-input scan misses several polling APIs and event-class checks

**File:** `attimo/tests/smoke/test_input_map.gd:14-16`
**Issue:** The token list is `Input.is_key_pressed`, `is_physical_key_pressed`, `is_mouse_button_pressed` and `get_joy`. It does not match `is_joy_button_pressed`, `get_mouse_button_mask`, `event is InputEventKey` / `.keycode ==` in `_input` handlers, or `InputEventJoypad*` usage. It gives false assurance that game code never touches raw input.

**Fix:** Add `is_joy_button_pressed`, `get_mouse_button_mask`, `.keycode`, `.physical_keycode`, `InputEventKey` and `InputEventJoypad` to `FORBIDDEN_TOKENS`, and exempt the tests folder as it does now.

### IN-06: `build_animation_library.gd` ignores failures

**File:** `attimo/tools/build_animation_library.gd:26,31,22-24`
**Issue:**
- `instance.get_node("AnimationPlayer")` is cast with `as` and used without a null check, so a source GLB without an AnimationPlayer crashes the tool with a script error.
- `library.add_animation(clip, ...)` returns an Error that is dropped. A clip name present in two source GLBs is silently kept from the first one.
- On the load-failure path, `quit(1); return` happens without freeing earlier instances (negligible, but unclean).

**Fix:** `get_node_or_null` plus a `push_error` and `quit(1)`. Check `add_animation == OK`, and fail on duplicates.

### IN-07: Wall ring has open 1 m corners

**File:** `attimo/scenes/test/test_scene.tscn:108-166`
**Issue:** North and south walls span x in [-10, 10] at z of +-10.5. East and west walls span z in [-10, 10] at x of +-10.5. The four corner squares, 1 m by 1 m, are open. `test_scene_run._check_walls` only checks that walls do not overlap and does not check that the ring is closed. This is harmless while nothing moves, but it is a hole once Phase 2 adds movement (the capsule diameter is 1.0, and the floor ends at 10 so it is mostly void anyway).

**Fix:** Extend the east and west walls by one tile, or add four corner cubes. Add a ring-closure assertion.

### IN-08: Brittle or low-value assertions and duplicated dash handling

**File:** `attimo/tests/smoke/test_asset_hygiene.gd:52`, `attimo/tests/smoke/test_dash_fact.gd:75-77`, `attimo/scripts/player/states/*.gd`
**Issue:**
- `WHITELIST.size() == 25` compares a constant list to a literal. It only fails when someone edits the list, and the file comment says that is the intent.
- `test_dash_fact` scenario 3 relies on frame counts with a margin of about two physics frames: DASH_TIME is 24 frames of accumulated float, tested at 28.
- `Input.is_action_just_pressed(&"dash")` to `Dash` is copy-pasted across idle, run, jump and fall, with slightly different ordering relative to `face()`. In `Run` it comes after `face()`, elsewhere before.

**Fix:** Assert on observable state (wait until state is Fall with a bounded loop) instead of fixed frame counts. Move the shared air and ground dash checks into a `State` helper such as `try_dash() -> StringName`.

### IN-09: `run_smoke.gd` cannot notice a test that aborts mid-run

**File:** `attimo/tests/run_smoke.gd:59-69`
**Issue:** If a test's `run` hits a runtime script error, the function stops with no `FAIL` increment, `count` still increments, and the summary reports whatever passed so far. The suite is only caught by `run.sh`'s log grep for `SCRIPT ERROR`. Running the runner directly (`godot -s res://tests/run_smoke.gd`) exits 0 with partial coverage.

**Fix:** Have each test return a completion marker, or compare the number of checks per test against a minimum. Alternatively document that `run.sh` is the only supported entry point.

---

_Reviewed: 2026-11-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
