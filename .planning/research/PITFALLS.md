# Pitfalls Research

**Domain:** Godot 4 3D third-person platformer vertical slice (Attimo) with AI-generated assets (Meshy character, Blender-MCP props), ability-gated "Metroidvania-lite" hand modules
**Researched:** 2026-11-02
**Confidence:** MEDIUM-HIGH (Godot API behavior and Meshy parameters verified against official docs; game-feel and art-pipeline numbers are practitioner heuristics, marked as such)

**Project context applied (from coordinator):**
- Meshy character is a **placeholder: 3,027 tris, triangle topology**, to be refined later. Treat it as a pipeline-test asset, not final.
- The **prosthetic arm stays visually fixed**; modules are **abilities only** (no per-module mesh swapping, no bone attachments per module). This removes a whole class of rig/attachment pitfalls, so do NOT build a visual module-attachment system.

---

## Critical Pitfalls

### Pitfall 1: Camera and body jitter from mixing `_process` and `_physics_process`

**What goes wrong:**
The player capsule or the camera stutters, especially at 120/144 Hz monitors, even though the game "runs at 60 FPS." Looks like a hitch every few frames; ruins the Core Value (smooth movement feel).

**Why it happens:**
Physics runs at a fixed tick (default 60 TPS) while rendering runs at monitor rate. `CharacterBody3D.move_and_slide()` in `_physics_process` plus a camera that follows in `_process` (or the reverse) produces beat frequencies. Godot 4.4+ added 3D physics interpolation (Project Settings > Physics > Common > Physics Interpolation, off by default), but it only works if ALL movement of interpolated nodes happens on the physics tick. Setting transforms of interpolated nodes in `_process` (head bob, recoil offsets, camera lag, tweens, AnimationPlayer in idle mode that moves a parent) causes incorrect interpolation and jitter that may not show on the dev machine but appears on other displays. Forum reports on 4.4.x show camera-only jitter persisting at 144 Hz when the camera rotates in `_physics_process` or when a Camera3D child of an interpolated body rotates.

**How to avoid:**
- Decide the policy in phase 1 and write it down: **Enable physics interpolation. All gameplay motion in `_physics_process`. Camera RIG (yaw/pitch input accumulation, SpringArm length, FOV easing) is updated in `_process` on a node that is NOT a child of the interpolated body** (top-level / `top_level = true`), following the body's *interpolated* position (e.g. `Node3D.get_global_transform_interpolated()` in 4.4+ - verify against the exact Godot version in use - or follow the interpolated visual node), OR let the camera rig be physics-interpolated itself and keep only input-to-rotation in `_unhandled_input`. Pick ONE of these two patterns and test it; do not mix.
- Never put the Camera3D as a direct rotating child of the CharacterBody3D. Keep body (collision) and camera rig as siblings.
- After any teleport/respawn/checkpoint: set the transform, then call `reset_physics_interpolation()` (order matters, or you get a one-frame streak across the level).
- Test early with Physics Ticks Per Second temporarily set to 10; any node that visibly steps is moving incorrectly. Also test on a 144 Hz display or with V-Sync off and frame cap at 144.
- Note: physics-interpolated collision shapes in debug view appear ahead of the mesh; that is expected, not a bug.

**Warning signs:**
Editor warning "Interpolated Camera3D triggered from outside physics process"; jitter that appears only when moving AND turning; jitter gone when V-Sync is off or FPS is exactly 60; character looks fine but world/props "shimmer" while the camera follows.

**Phase to address:** Phase 1/2 (movement + camera foundation). Make a 10-TPS interpolation test part of the movement phase's acceptance check.

---

### Pitfall 2: Floaty or stiff jumps and "mushy" acceleration (the Core Value killer)

**What goes wrong:**
Jump feels floaty, jump height is inconsistent, or the character feels like it is on ice or, opposite, snaps instantly with no weight. Sprint/dash do not blend, so "smooth and fast" is not achieved.

**Why it happens:**
Using plain gravity (-9.8) with a velocity impulse produces a symmetric, floaty parabola. Designers tune `jump_velocity` but not gravity. No variable jump height, no fall gravity multiplier, no coyote time or jump buffer (these ARE in the requirements, but are often added late and interact badly with the state machine). Acceleration is either instant (`velocity.x = dir * speed`) or `lerp` with frame-rate-dependent factors. Air control is either zero or full.

**How to avoid:**
- Derive jump from design numbers, not guesswork: choose jump height H and time-to-apex T, then `gravity = 2H/T^2`, `jump_velocity = 2H/T`. Use a **heavier fall gravity (about 1.5x to 2x)** and **jump-cut** (release early = multiply upward velocity). Cap terminal velocity.
- Implement coyote time (~0.1 s) and jump buffer (~0.1-0.15 s) as timers decremented in `_physics_process`, in the base state before any ability logic.
- Use `move_toward` with separate ground/air acceleration and deceleration values; never `lerp(v, target, 0.1)` per tick without accounting for delta.
- Keep ALL tuning in one exported `Resource` (`MovementConfig`) so tuning happens in the inspector at runtime, not in code edits. Expose live in a debug overlay.
- Write a "movement metrics" table (max jump height, max jump distance walk/sprint, dash distance, dash-jump distance) from the real tuned values; level design must use it (see Pitfall 9).
- Keep animation separate from physics: do not let animation root motion drive the capsule for a platformer.

**Warning signs:**
Playtesters say "floaty"/"slippery"; jump heights differ when frame rate changes; you cannot reliably make a 3-unit gap; you keep changing gravity globally to fix feel.

**Phase to address:** Movement phase (first gameplay phase). Do NOT start hand modules or levels before movement is signed off with the metrics table.

---

### Pitfall 3: Slope, step, and floor-snap bugs with `CharacterBody3D`

**What goes wrong:**
Character launches off the top of ramps, jitters/bounces going downhill, slides on slopes when idle, gets stuck on tiny ledges or seams between floor pieces, or sticks to walls while jumping.

**Why it happens:**
Verified defaults: `floor_snap_length = 0.1`, `floor_max_angle = 45 degrees`, `floor_stop_on_slope = true`, `floor_constant_speed = false`, `safe_margin = 0.001`, `motion_mode = GROUNDED`. Snapping only works when not moving upward, so jump logic that zeroes/sets `velocity.y` carelessly breaks it. Running fast downhill with a 0.1 snap length leaves the ground (character becomes airborne, coyote timer starts, animation flips to "fall"). With `floor_constant_speed = false` you go faster downhill and slower uphill, which feels inconsistent. Godot has no built-in stair stepping, so Blender-made stairs/ledges/modular tiles with tiny height differences cause snags. Seams between adjacent box colliders can cause "ghost" bumps depending on physics engine.

**How to avoid:**
- Raise `floor_snap_length` in proportion to max speed (start ~0.3-0.4 for a fast sprinter) and **disable snap on jump frames** (set `floor_snap_length = 0` or skip while `velocity.y > 0`), re-enable on landing. Use `apply_floor_snap()` for forced re-snap after e.g. platform exits.
- Set `floor_constant_speed = true` for platformer feel, and keep slopes in the level at <= ~35 degrees; set `floor_max_angle` slightly above the steepest intended walkable slope. Make steep surfaces clearly steep (visually read as wall).
- Set `platform_on_leave = ADD_UPWARD_VELOCITY` so jumping off a lowering moving platform (steampunk lifts, conveyors) does not eat jump height.
- Design the level on a **grid with ledge-height rules** (no 1-5 cm lips); build collision as simplified boxes/convex hulls (not the visual mesh), merge coplanar floor colliders. If step-up is wanted, implement it explicitly (test_move up + forward), do not rely on capsule radius.
- Use a capsule (not box) for the player collider, with radius bigger than the visual feet.
- Evaluate Jolt Physics (built into Godot since 4.4 as selectable 3D engine; check which is default in the Godot version used) for more stable character/seam behavior; pick one engine in phase 1 and never switch mid-project, because collision behavior differs.
- Test scene early: ramps at 15/30/44/46 degrees, 2 cm / 10 cm / 40 cm steps, seam between two floor tiles, moving platform, conveyor.

**Warning signs:**
`is_on_floor()` flickering true/false in the debug overlay while running downhill; character stops dead on tiny ledges; idle slide on slopes; "snaps to ceiling/wall" behavior.

**Phase to address:** Movement phase (build the test gym scene here); re-verify when the level blockout starts.

---

### Pitfall 4: Dash through walls / out of the level

**What goes wrong:**
Dash tunnels through thin walls, ends inside geometry, launches the player off the map edge, or conserves unbounded speed into a jump.

**Why it happens:**
Dash implemented by setting `global_position` (teleport), by a `Tween` on position, or by a huge one-frame velocity. These bypass swept collision. `move_and_slide()` itself is swept, so using it is safe against static colliders; tunneling comes from bypassing it, from very thin/single-sided concave trimesh colliders, or from per-tick travel larger than the thinnest collider. Also: dash end velocity is not clamped, so dash into a jump gives a super-jump; dash ignores slopes/ledges, drops through floor snap.

**How to avoid:**
- Implement dash as a **timed state that sets `velocity` and calls `move_and_slide()` every physics tick** (dash speed x duration = distance; keep per-tick travel less than half the thinnest wall's thickness; all walls >= 0.5 m thick colliders).
- Never move the player via Tween/teleport except respawn (then `reset_physics_interpolation()`).
- Clamp velocity on dash exit (carry only a configurable fraction of dash speed).
- Define dash vs. air: air dash count, reset on landing, optional gravity suspension; define what happens on ledge edges (no auto-snap into void).
- Add a kill-plane / respawn volume under the level so a bug never means a stuck player.
- Add a debug raycast test: dash into every wall type in the gym scene.

**Warning signs:**
Occasional falls out of the world at high frame times; dash feels fine except at specific walls; a hitch spike (alt-tab) lets you through walls.

**Phase to address:** Movement phase (dash story); regression-test again in level blockout.

---

### Pitfall 5: Third-person camera clipping, bad aim transitions, and input handling

**What goes wrong:**
Camera goes through walls/floors, shows the inside of the character's head, snaps harshly when entering/leaving aim mode, mouse feels laggy/inconsistent, camera rotation speed changes with frame rate, or sensitivity feels wrong.

**Why it happens:**
- No collision on the camera arm, or `SpringArm3D` collides with the player's own capsule/trigger bodies (must `add_excluded_object` or use collision masks), or its shape is a ray (zero thickness) so the lens pokes through corners (use a small `SphereShape3D`).
- Camera `near` plane is too far (default 0.05 is fine; changing it larger hides near geometry badly) and no fade of the character when the arm collapses.
- Aim mode toggled by hard-setting `spring_length`, `h_offset`, FOV, and character facing in one frame; pop. Character does not rotate to camera yaw in aim mode, so crosshair and hand direction disagree.
- Mouse look: multiplying `InputEventMouseMotion.relative` by `delta` (a classic bug: makes sensitivity frame-rate-dependent), applying smoothing/lerp to mouse input (adds lag), reading mouse in `_process` polling instead of events, not clamping pitch, mouse mode not captured or not re-captured after focus loss/Esc menu.
- Motion sickness: strong FOV kick on sprint/dash, camera shake on every landing, head bob, rolling the camera, heavy camera lag/rubber-banding, narrow FOV (< 70 degrees vertical for third person).

**How to avoid:**
- Camera rig: `Node3D (yaw) > Node3D (pitch) > SpringArm3D (SphereShape3D r~0.2-0.3, margin ~0.1-0.2, collision mask = world only, exclude player) > Camera3D`. Clamp pitch ~-60/+70 degrees.
- Mouse look in `_unhandled_input`: `rotation += -relative * sensitivity` (radians per pixel, NO delta). Use `Input.mouse_mode = MOUSE_MODE_CAPTURED` (raw relative motion on desktop). No smoothing on raw mouse; smooth only the *camera position* follow. Expose sensitivity and invert-Y in settings; handle `NOTIFICATION_APPLICATION_FOCUS_OUT` / pause to release mouse.
- Aim mode as a blended state: tween a single `aim_blend` (0..1) driving spring_length, h_offset (shoulder), FOV, and sensitivity multiplier (aim sensitivity ~0.6-0.8x); duration ~0.12-0.2 s; character yaw lerps to camera yaw during aim; crosshair fades in. Allow shoulder swap only if levels need it (otherwise cut it).
- Fade or dither the player mesh when the arm length drops below a threshold.
- Motion sickness defaults: FOV 75-90, tiny FOV change on sprint (<= +8 degrees), no head bob, no roll, shake off by default or minimal, option toggles in settings.

**Warning signs:**
Camera sees the void behind walls; character head visible in aim; sensitivity feels different at 60 vs 144 FPS; pop when pressing the aim key; testers feel nauseated after 10 minutes.

**Phase to address:** Camera phase (immediately after/with movement). Aim-mode transitions get a dedicated acceptance test with the crosshair + first hand module.

---

### Pitfall 6: Aim assist and interactable highlighting that fight each other (and the art direction)

**What goes wrong:**
Crosshair "sticks" to the wrong target, flickers between two targets, targets things behind walls, or the beam/ray origin disagrees with the crosshair (parallax). Players cannot tell what is interactable, because turquoise crystals are everywhere in the art direction.

**Why it happens:**
- Ray cast from the *hand* instead of from the *camera center*, so shots land beside the crosshair. Or raycast only (no tolerance), so aiming at a small valve is frustrating; or sticky magnetism without hysteresis, so target switches every frame.
- Assist ignores line of sight, range, or "already activated" state.
- The world references (floating islands, glowing crystals and pipes in `World Look.png`) use the same green-turquoise glow as the interactable energy cores. Highlight loses meaning. Bloom also bleeds glow into everything.
- Per-object material duplication to toggle highlight breaks batching/memory; or an outline shader that fails on thin meshes.

**How to avoid:**
- Aim ray from camera through screen center to find the aim point; then the hand's beam originates at the hand and targets that point (and re-check occlusion from hand to point). Use a `ShapeCast3D` (sphere ~0.15-0.4 m, scaled by distance) or a screen-space cone test over an `interactables` group, scoring by angular distance to crosshair and distance, requiring line of sight.
- Add **hysteresis**: keep the current target until it leaves a larger angle than the acquire angle (e.g., acquire 4 degrees, release 7 degrees). Light, optional "soft magnetism" only (nudge, never steal camera). Make assist strength a tunable resource and disable-able.
- **Reserve the turquoise hue for interactables ONLY.** Decorative crystals/pipes use a different hue or no emission, or a distinct non-pulsing look. Define 3 states: dormant (dim), targetable in range (pulse/outline), active/used (steady warm). Document in an art "affordance sheet". Check in grayscale and for color-blind (green vs turquoise is a weak distinction; add shape/motion cue, e.g., pulse + rotating ring).
- Implement highlight with a single shared shader using `instance_shader_parameter` (per-instance uniform) or an emission `next_pass`, not duplicated materials. Keep Glow (bloom) threshold high so only emissive cores bloom.
- Provide an on-screen reticle state change (idle/target-valid/out-of-range).

**Warning signs:**
Testers shoot at decorative crystals; testers miss obvious targets at distance; crosshair-beam mismatch visible when aiming at a nearby wall; highlight flickers when two cores are near each other.

**Phase to address:** Hand framework phase (aim/targeting) and Environment/art phase (affordance sheet). Establish the turquoise-reservation rule BEFORE props are generated.

---

### Pitfall 7: Ability-gating soft locks and unclear affordances

**What goes wrong:**
Player gets permanently stuck (soft lock) or does not understand what a module does / where to use it. Sequence breaks make gated areas reachable without the ability or make required items unreachable.

**Why it happens:**
- Time-rewind / stasis / push-style mechanisms can leave puzzle objects in unrecoverable states (stuck in pit, frozen in the only path, consumed one-shot).
- Gate based on a gap that can be crossed with sprint+dash+jump variants nobody tested; or the ability is acquired in a place from which one cannot go back.
- Module found with no safe teaching moment; first use appears in a hazard situation. No "teach, test, twist" progression.
- Over-engineered module framework before two real modules exist.
- Checkpoints missing or save positions inside unrecoverable states.

**How to avoid:**
- Every puzzle needs a **reset path**: a reset-able object (respawns to origin on use of a nearby switch, or after leaving the room), no one-way destroyable required objects, and a fall-respawn point at each area.
- Gate with **hard, measurable thresholds from the movement metrics table** (gaps beyond the best non-ability jump + margin 25%), and block alternate routes with geometry the same way you gate; run a dedicated "sequence-break pass" playtesting with all movement tech but without modules.
- Each module: **one clear input, one clear effect, one first-use room** (safe, single mechanism, obvious target lit turquoise) then a test room, then a twist. Document in a one-line "module contract": input, effect, range, cooldown, where taught, where required, how it fails.
- Build the module framework (Resource-per-module, signals, simple `activate/deactivate`) from TWO concrete modules, not abstractly. Since the arm is visually fixed, modules need no mesh/bone attachment, only an ability + HUD icon + FX.
- Keep ability state in a single autoload/resource and save it at checkpoints; define behavior when two modules are active.
- Never require the ability to escape a place you can enter without it (always make the entrance one-way only AFTER the ability is acquired).

**Warning signs:**
A tester reaches a dead end and restarts the game; testers ask "what does this do?" after getting the module; designers rely on "they'll figure it out"; a puzzle object can be pushed/frozen into a corner.

**Phase to address:** Hand framework phase (contract, reset), Level design phase (gate and sequence-break pass), Boss phase (boss must require modules fairly and fail-safe).

---

### Pitfall 8: Meshy character is unusable (poly budget, topology, rig) at the production stage

**What goes wrong:**
The final Meshy character deforms badly, rigs wrongly, looks off-style next to Blender props, or is too heavy/too thin for Godot animation. The current placeholder (3,027 tris, triangle topology) is mistaken for final or its parameters are locked in.

**Why it happens (verified against Meshy docs):**
- Meshy's output is a single triangle mesh; remesh `target_polycount` range 100-300,000 and **"the result can differ from the target"**. Small accessories (goggles, straps, the prosthetic's cores) can disappear or be merged when the budget is low; non-manifold edges can create holes after remeshing.
- Auto-rigging needs a **T-pose or A-pose with clear gaps between limbs**; >300k faces must be remeshed first; rigging failures documented: markers misplaced, bones in wrong place if pose isn't close to T/A, mesh clipping through itself when topology is too dense/uneven, poor limb deformation with non-human proportions. **The chibi proportions (big head, short limbs) are exactly the "far from standard human" case.**
- Auto-rig gives Mixamo-style skeleton, walk/run only; no facial bones, no custom bones. Meshy's `smart-topology` models limit remesh/topology options (triangle only).
- Triangulated topology with stretched, uneven triangles produces candy-wrapper deformation at shoulders, elbows, hips, and neck; the big-head chibi neck is a weak spot.
- The style mismatch: Meshy textures are painterly/noisy and may contain baked shading, while the target is KayKit-like clean facets (see Pitfall 10).

**How to avoid:**
- Treat the 3,027-tri placeholder as the **pipeline smoke test**: run it through import -> skeleton -> animation -> in-game movement before generating any final version. Record the specific Meshy settings (model/version, `should_remesh`, `topology`, `target_polycount`, `pose_mode`) used per generation in an `ASSET_LOG.md` for reproducibility.
- Decide the budget by role (heuristics, MEDIUM confidence): hero character 3-6k tris (4-5k w/ separate eyes/goggles OK), enemies/boss 5-10k, hero props 300-1.5k, set pieces/environment modules 50-800 each, background tiles < 300. Hand/prosthetic stays inside the character mesh. With a 3k placeholder you are at the low end: fine for this style, risky for goggles/cores detail.
- Generate with `pose_mode = a-pose` or `t-pose`, `symmetry` preserved, clean silhouette with limb gaps; keep prosthetic arm separated from torso in the pose.
- For the final, either (a) Meshy remesh + manual cleanup, or (b) **retopologize/rebuild in Blender with quads** around joints (shoulder, elbow, wrist, hip, knee, neck) and bake the Meshy texture onto it. Consider using the Meshy model only as a sculpt/reference. Budget time for this; it is the expensive step.
- Rigging: if Meshy's auto-rig fails or needs custom bones (fixed prosthetic glow, optional goggles), **re-rig in Blender** (Rigify or manual) with a standard humanoid layout so Godot's BoneMap retargeting works. Check weight painting at extremes (arms up, run cycle, jump, dash lean).
- Test with 5 required poses/animations before approving: idle, run, sprint, jump (up/fall), dash. If the rig fails any, the model is rejected.
- Never commit the 100k+ face high-poly or 4k/8k textures to the project (repo bloat; Godot import time).

**Warning signs:**
Shoulders collapse or stretch when the arm moves; goggles clip into head in run cycle; character reads as a different art style than the props; rig bones lie outside the mesh; textures > 1 MB per prop.

**Phase to address:** Asset pipeline phase (rules + smoke test) EARLY; Character finalization phase before polish. Pipeline rules should be settled before any additional AI assets are generated.

---

### Pitfall 9: Level geometry built without movement metrics ("blockout drift")

**What goes wrong:**
Platforms are spaced by eye, then movement is retuned and the whole level breaks. Or level art (AI props) is built before the blockout is fun, so changes are expensive.

**Why it happens:**
Two moving targets (movement tuning and level layout) tuned independently; art-first workflow because the AI assets are exciting.

**How to avoid:**
- Freeze the movement metrics table before blockout; commit it as `docs/movement-metrics.md` and a gizmo scene showing jump arcs/distances. Use a 1 m grid and CSG/gray-box placeholders; art replaces boxes only after the blockout passes a "fun without art" test.
- Build the blockout from reusable modular pieces with consistent snapping (e.g., 2 m grid) so Blender-generated modules fit.
- Retuning movement after blockout requires re-running the metrics check (a scripted test scene that jumps/dashes across each gap).

**Warning signs:**
Gaps that are "just barely" doable; level geometry has non-grid positions; art assets were placed while the blockout still changes weekly.

**Phase to address:** Level blockout phase (before art pass).

---

### Pitfall 10: Style inconsistency between Meshy and Blender-MCP assets

**What goes wrong:**
Hero character has painterly noisy textures, soft normals, baked shadows; Blender props use flat colors; the world looks like a collage. Baked lighting in textures looks wrong in the engine's real lighting. The facetted, flat-shaded look from `Character_Look.png` is lost.

**Why it happens:**
Different generators and no shared constraints. Meshy textures from image-to-3D come with lighting/shadows baked into base color unless `remove_lighting` is on (default `true`, but docs say it takes effect only with the `meshy-6` model; returns an error with `meshy-6-lite` and Smart Topology). PBR maps (`enable_pbr`) add AI-hallucinated normal/roughness detail that fights low-poly facets. Textures arrive at 2k-8k, far above the KayKit-style 128-512 px palette textures.

**How to avoid:**
- Define a **style contract** (one page): 1 shared palette (cream-beige accents, muted metal, warm wood/brick, turquoise reserved for interactables), flat/faceted shading rule (flat normals or hard-edge angle ~30 degrees), max texture size per class (hero 1024, props 256-512 or palette-only), no normal maps for props, and roughness set to a constant range (~0.6-0.9).
- Preferred approach for coherence: **palette/gradient-atlas texturing** — one shared 256x256 or 512x512 palette texture; UV islands snapped onto palette cells (or vertex colors); apply the same to the Meshy character via re-projection/bake in Blender. This is what makes KayKit look consistent.
- Generate Meshy with `enable_pbr = false` (default), `remove_lighting = true` on a model that supports it, `image_enhancement` set deliberately, `texture_resolution` low; then inspect the albedo alone (Godot: unshaded debug view / Blender: Emission-only) for baked shadows, highlights, specular streaks.
- Fixes if baked lighting persists: re-texture, paint over, or bake a new palette texture from Meshy vertex colors; add a simple shared Godot shader (toon ramp/rim light) or a unified material applied to ALL assets via an override to hide differences; set `shading_mode` consistently (all per-pixel or all per-vertex).
- One reference lineup scene in Godot containing character + 5 reference props + a KayKit sample (for reference only, check license) viewed under the final lighting; every new asset must pass "fits in the lineup" before acceptance.
- Unify through lighting/post: same WorldEnvironment (warm key, tonemapper, color grading), light fog; a unified outline or posterize is a cheap harmonizer, but keep it optional.

**Warning signs:**
Character looks "photoreal-painted" next to flat props; dark patches follow the model when lit from another direction; some assets have visible texture swim; color temperature varies per asset.

**Phase to address:** Asset pipeline phase (style contract + lineup scene), enforced at every asset-making phase.

---

### Pitfall 11: Blender-MCP assets with wrong scale, orientation, pivots, normals and topology

**What goes wrong:**
Props import 100x too big/small, rotated 90 degrees, with pivots in odd places, flipped normals, non-manifold meshes, n-gons, or huge triangle counts from Blender-MCP code (boolean/subdivision/array modifiers left unapplied).

**Why it happens:**
AI/MCP-generated scripts use arbitrary units, forget to apply transforms/modifiers, mix metric units and Blender's default unit scale, and produce one big joined mesh. Imported library or generated models "arrive at arbitrary scale" (even the Blender MCP notes this).

**How to avoid:**
- Rules in the pipeline doc: **1 Blender unit = 1 meter, Unit Scale 1.0, Z-up in Blender with glTF export "+Y Up" (default)**; player height defined (e.g., ~1.2 m for chibi), door/step/platform sizes from the grid. Apply Location/Rotation/Scale before export (Ctrl+A); origin at base-center for props, bottom-corner for modular tiles.
- Give the MCP a **mandatory post-generation checklist script**: apply modifiers, triangulate-count readout, remove doubles, recalc normals outward, check non-manifold, report bounding box, report tri count vs budget, name objects consistently, ensure one material (or palette atlas).
- Validate with `look` renders and a scripted "height ruler" next to the player-size reference in Blender. Reject if bbox is off.
- Name collision helpers (`-col`, `-convcol`) per Godot import conventions and author collision separately (simple boxes/convex), never from the visual mesh.

**Warning signs:**
First import shows tiny or giant model; model faces +X instead of -Z; seams/dark faces from flipped normals; collision generated from a 20k tris trimesh.

**Phase to address:** Asset pipeline phase (rules, checklist script); every asset batch.

---

### Pitfall 12: glTF import in Godot 4 misconfigured (scale, materials, animations, root motion, skeleton)

**What goes wrong:**
Duplicated materials per asset, embedded textures with default compression, wrong scale, stray root transforms, animations that don't share between skeletons, characters that drift/offset when animated, bone tracks that drag the capsule, huge `.import` churn.

**Why it happens (verified against docs):**
- `Apply Root Scale` off means root scale multiplies the root node scale and stays in the scene; on bakes it into meshes/animations. Mixed settings between assets produce inconsistent scale.
- Blender glTF exported without applying transforms leaves the Skeleton with a transform on its node, breaking animation sharing/retargeting. Blender bones carry Edit-Bone orientation as rest rotation, which differs from other exporters; mismatched rest poses break shared animation libraries even with identical bone names.
- Godot 4 bone pose includes the rest (unlike Godot 3); animations from old sources behave differently.
- `SkeletonProfileHumanoid` expects a T-pose facing +Z, Y-up, no root transform; for A-pose models enable "Overwrite Axis" / use the right option. Position tracks live where root motion lives; "Normalize Position Tracks" and "Remove Tracks" (keep only Root/Hips) matter for sharing.
- Embedded textures can be left embedded, uncompressed or Basis-compressed incorrectly; default import creates materials inside the scene unless extracted.
- Animation FPS sampling (>30 rarely helps) and unremoved immutable tracks add size.
- Lightmap UV2 generation / LOD / shadow-mesh options can slow imports or alter geometry (not a problem unless enabled).

**How to avoid:**
- Standardize: export `.glb` from Blender with Apply Modifiers on, +Y Up, transforms applied, only selected objects, animations as actions (NLA/push-down), no cameras/lights. Keep one import preset per asset class (Character, Prop, Modular, Collision-only) saved as import defaults, committed.
- Extract materials to `.tres` files and use shared palette materials; extract textures; set VRAM compression for the large ones and "lossless/uncompressed" for the palette; use `Detect 3D` for textures.
- Character: if animations come from Meshy/Mixamo, use a **BoneMap + SkeletonProfileHumanoid**, check the BoneMap for magenta/red (missing/duplicate bones), enable Normalize Position Tracks when sharing, "Remove Tracks" keep only Root/Hips positions. Do not use root motion for the player (the capsule moves via physics); use an in-place animation set and drive speed from velocity via AnimationTree blend space.
- Check animation loops (idle/run/sprint must be marked loop in import or AnimationPlayer), constant foot sliding is fixed by matching animation speed to ground speed (`speed_scale`).
- Keep an import-validation scene that instantiates each class; run it after every asset batch. Commit `.import` files appropriately (they are text; keep `.godot/` ignored).

**Warning signs:**
Magenta BoneMap; character floats or sinks; foot slide; imported scene has `Skeleton3D` with non-identity transform; every prop has its own material duplicates; import takes minutes.

**Phase to address:** Asset pipeline phase (presets) and Character animation phase (retarget).

---

### Pitfall 13: Performance traps from "pretty" features (draw calls, shadows, GI, steam)

**What goes wrong:**
Frame drops (stutter, shader compile hitches), especially when the floating-island level, dense props, steam, and glow combine. Hitches on first-time effects.

**Why it happens:**
- Hundreds of separate MeshInstance3D props with unique materials = many draw calls; per-instance material duplicates break batching.
- Many shadow-casting lights, big directional shadow distance, high shadow atlas resolution; omni lights per mechanism glow.
- GI: SDFGI/VoxelGI/LightmapGI chosen without budgeting; SDFGI is expensive and tends to leak/light-pop on tiny floating islands over open sky.
- Steam via lots of GPUParticles3D with transparent sorting and large overdraw; each emitter has its own process material; first-time particle shader compile hitches.
- SSR/SSAO/volumetric fog/glow at high settings. Large transparent quads for fog/steam overdraw.
- Vulkan pipeline compile stutter on first appearance of materials.

**How to avoid:**
- Budgets (heuristics, MEDIUM): <= 1,500 draw calls in view target (profile the real number), <= 300k visible triangles, <= 1 directional light with shadows, <= 4-6 shadow-casting dynamic lights in view, others unshadowed; turquoise cores emissive-only (+ glow), not real lights, except for one at a time near the player.
- Prefer **baked GI** (LightmapGI for static island pieces) or simple ambient + a single directional + emissive cores over SDFGI. Decide in the art phase and lock it. Watch UV2 lightmap needs: enable "Static Lightmaps" in import only for those assets and be aware that increases import time.
- Share materials (palette atlas = one material for most props). Use `MultiMeshInstance3D` for repeated rivets/pipes/bricks/grass; use visibility ranges (`visibility_range_end`) for small props; occlusion culling only if profiling shows need.
- Steam: a few GPUParticles3D with small particle counts (20-60), billboard unshaded alpha-scissor/dither or additive texture sheet, short lifetimes, `fixed_fps`, `visibility_aabb` set, one shared process material; emitters off-screen are frozen by visibility. Pre-warm the effect once at level load behind a loading screen to avoid hitches (also helps shader compile). Prefer 1-2 steam types.
- Check performance with the Godot Profiler/Monitors + Rendering "Draw Calls", "Objects in frame", and Vulkan "Visible Information"; run on the weakest target machine early (university laptop/integrated GPU is a likely demo environment). Use the Compatibility renderer only if you need it; decide the renderer (Forward+ vs Mobile vs Compatibility) in phase 1 because effects differ.

**Warning signs:**
FPS dips when turning the camera toward the dense areas; hitching the first time steam/boss FX play; big spikes when many mechanisms are in view; RAM growth from textures.

**Phase to address:** Phase 1 (renderer + GI decision), Art/environment phase (budget checks), Polish phase (profiling pass).

---

### Pitfall 14: Scope creep in a university vertical slice

**What goes wrong:**
Time goes into wall-run, many modules, shiny VFX, the "perfect" AI asset, and the boss, leaving no polished playable slice. Out-of-scope items return in disguise ("just one more module," "just a cutscene").

**Why it happens:**
Low friction from AI assets and an open module list (Rücklauf-Uhrwerk, Stasis-Hemmung, Dampfstoß-Kolben, Magnet-Greifhaken); movement polish is a rabbit hole; wall-run is already marked "evtl." (maybe) in requirements.

**How to avoid:**
- Cap content: **1 level, 1 boss, 2 modules (3 max if time allows), 1 steam effect type, 1 hero character, ~15-25 unique props**. Choose the modules by "what reuses mechanisms and the movement metrics" (e.g., remote trigger beam + Dampfstoß/boost; defer time-rewind and stasis because they create the most soft-lock/reset complexity).
- Wall-run: cut by default; only add after movement signed off AND a time-boxed spike (<= 2 days) proves it feels good with the camera. Controller support: out of scope except Input Actions.
- Define a "vertical slice done" checklist and a **cut list** in the roadmap, decided up front; put a "stop adding content" date before polish.
- Time-box asset generation: each prop gets max 2 generation attempts before falling back to a simple Blender primitive-based build. Reuse a modular kit instead of unique pieces.
- Playable at all times: keep a main branch where the game starts and is playable; blockout -> art-replace workflow.
- Only build what the single boss needs; reuse existing mechanisms; boss = 3 phases max, no custom animation rig (use scripted transforms / rigid pieces since it is an enemy "object").

**Warning signs:**
New feature in the roadmap each week; assets polished before the level is fun; no playable build for 2+ weeks; module count > 3.

**Phase to address:** Roadmap/planning (cut list), enforced in every phase transition.

---

## Moderate Pitfalls

### Pitfall 15: Input mapping and menu/pause pitfalls
**What goes wrong:** Hard-coded keys (`KEY_W`) instead of Input Actions; controller later requires rewrite; actions mixed between `_input` and `_unhandled_input` so UI swallows gameplay input; `Input.get_vector` dead zones ignored; pause leaves mouse captured.
**Prevention:** Define all actions up front (`move_*`, `jump`, `sprint`, `dash`, `aim`, `interact`/`fire_hand`, `pause`) with dead zones; use `Input.get_vector`; read gameplay in `_physics_process` via `Input.is_action_*`/events in `_unhandled_input`; pause mode set properly for menus; mouse mode toggled by pause.

### Pitfall 16: Animation state machine entangled with movement code
**What goes wrong:** Animations drive state; foot sliding; dash/jump animations lag behind input; blend jitter.
**Prevention:** Single movement state machine (Idle, Run, Sprint, Jump, Fall, Dash, Aim) is the source of truth; AnimationTree reads from it; blend times <= 0.1-0.15 s; animation speed scaled by ground speed; input buffering independent from animation events.

### Pitfall 17: Mechanisms as scene-specific scripts instead of shared contracts
**What goes wrong:** Each valve/gear/conveyor has bespoke script; hand module logic must know all of them; adding a module touches every mechanism.
**Prevention:** One `Interactable` interface (group + signals e.g., `triggered(source, module)`), data-driven properties; mechanisms expose state and "reset"; modules call a method, not individual node types. Add a mechanism library scene set (valve, lever, gear, conveyor).

### Pitfall 18: Moving platforms/conveyors fight interpolation and floor logic
**What goes wrong:** Player jitters on moving platforms; conveyor speed applied twice; AnimatableBody3D moved in `_process`.
**Prevention:** Move platforms with `AnimatableBody3D` in `_physics_process` (`sync_to_physics`); conveyors as constant velocity offset on the player (not physics friction); test `platform_on_leave` and `reset_physics_interpolation()` on platform-spawned objects.

### Pitfall 19: Collision layers chaos
**What goes wrong:** Beam hits player/decor/triggers; camera collides with enemies; aim assist picks up trigger volumes.
**Prevention:** Name layers early: world, player, interactable, hazard, camera-blocker, projectile, enemy; document the mask for camera, beam, aim assist.

### Pitfall 20: Audio and feedback left for the end
**What goes wrong:** Movement and module use feel unresponsive without sound/FX; hits and jumps lack feedback; steam gets no sound.
**Prevention:** Put placeholders (footsteps, jump, land, dash whoosh, beam tick, mechanism clank) in the movement and module phases; they are cheap game-feel multipliers. Landing dust and squash-less feedback.

### Pitfall 21: Git/Repo hygiene with binary assets
**What goes wrong:** Large `.glb`/`.png`/`.blend` bloat; `.import` and `.godot` committed incorrectly; two people editing the same `.tscn`; AI-source files lost.
**Prevention:** `.gitignore` for `.godot/`, keep `*.import` committed, Git LFS for `.blend`/`.png` > 1 MB (or keep `.blend` out and commit only exported `.glb`), `assets/source/` vs `assets/exported/`, keep `ASSET_LOG.md` with prompt/settings/seed per asset, small scenes, scripts in `.gd`. Note the two untracked reference PNGs in the repo root should move to `docs/reference/`.

### Pitfall 22: AI-generated asset licensing and provenance
**What goes wrong:** Unknown licensing of generated assets (Meshy plan terms: free plan content is typically CC BY-restricted; paid plan grants ownership) and reuse of KayKit assets without credit.
**Prevention:** Record plan/tier used for each Meshy generation; check Meshy's current terms before submission; credit KayKit if any actual asset is used (only the style reference is planned); note AI usage in the project README (many universities require disclosure).

---

## Minor Pitfalls

### Pitfall 23: Overlong tutorial text and HUD clutter
**What goes wrong:** No dialogue/cutscene rule means teaching must be visual; players don't know controls.
**Prevention:** Minimal prompts (icon + key) shown contextually at first use; reticle and module icon only; no text walls.

### Pitfall 24: Inconsistent time/units in tuning
**What goes wrong:** Mix of per-second and per-tick values; `velocity * delta` misuse (velocity is already units per second for `move_and_slide`).
**Prevention:** All speeds in m/s, all durations in seconds, use `delta` only for accumulations (timers, acceleration).

### Pitfall 25: Shadow acne / light leaking on low-poly flat shading
**What goes wrong:** Banding on faceted surfaces, light leaks at thin walls and floating islands.
**Prevention:** Tune directional light shadow bias/normal bias; make walls at least 0.2 m thick; avoid single-sided planes as occluders.

### Pitfall 26: Web/Export surprises
**What goes wrong:** Demo machine differs; export templates missing; project works in editor but not in exported build (paths, case sensitivity, missing import).
**Prevention:** Make a Windows export in the first weeks and re-export weekly; test on a second machine; keep paths case-correct.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-coded tuning constants in scripts | Fast iteration at first | Retuning requires code edits; no live tuning; metrics drift | Never past the first movement prototype; move to `MovementConfig` resource immediately |
| Camera as child of player body | Zero-setup follow | Jitter with physics interpolation, rotation coupling | Only in the first 1-day spike |
| Using the visual mesh as collision | No collision authoring | Heavy trimesh, ghost bumps, wrong aim hits | Never for the player's walkable surfaces |
| Per-asset unique materials/textures from Meshy | Zero texture work | Draw calls, style mismatch, memory | Only for the hero character; props use shared palette |
| Keeping Meshy 3,027-tri placeholder as final | Saves time | Deformation, off-style, missing details | Only if it passes the 5-pose rig test and style lineup |
| Abstract module framework before modules exist | Feels "clean" | Wrong abstractions, rewrite | Never; extract from the first two modules |
| Teleport-based dash | Simple code | Wall tunneling, slope glitches | Never |
| Skipping reset paths for puzzles | Faster puzzle creation | Soft locks | Never |
| Dynamic lights for every glowing core | Looks good in editor | Shadow/light cost | Only for 1-2 hero lights |
| Ignoring `.import` / LFS hygiene | None | Merge pain, bloat | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Meshy (web/API) | Default settings, high poly, PBR on, result accepted as-is | Set `pose_mode`, topology, `target_polycount` (result is only approximate), `enable_pbr=false` for stylized props, `remove_lighting=true` where supported (meshy-6 only); keep `save_pre_remeshed_model` if you may re-decimate; record settings |
| Meshy rig/animations | Rig on dense mesh; expect facial/tail bones; non-humanoid | Remesh first, T/A-pose, humanoid only; custom bones need Blender; Smart Rig models cannot use the animation library and export GLB only |
| Meshy Remesh vs Smart Topology | Assuming quad output always | Smart Topology supports only triangle topology; quad only with standard + remesh |
| Blender MCP | Trusting generated geometry; unapplied modifiers; inconsistent scale | Run a post-generation checklist script; render with `look`; validate bounding box and tri count; one Blender file per asset class |
| Blender -> Godot glTF | Default export, transforms unapplied, unwanted cameras/lights | Standard export preset, apply transforms, +Y Up, selected only, animations as actions |
| Godot import | Embedded materials; no import presets | Extract materials; shared palette material; import defaults per asset class |
| Godot Input | Raw key checks | Input Map actions, `get_vector`, capture mouse, handle focus loss |
| Jolt vs Godot Physics | Switching mid-project | Decide in phase 1 and test movement gym on the chosen engine |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unique materials per prop | Draw calls > budget, GPU-bound with simple meshes | Shared palette atlas material; `MultiMesh` for repeats | ~300+ unique material instances in view |
| Many shadow-casting omni lights | Big FPS drop near mechanisms | Emissive cores + glow; 1-2 real lights | > 4-6 shadow lights in view |
| SDFGI on floating islands | Light pop, leaks, cost | LightmapGI or baked/ambient + directional | Immediately on integrated GPUs |
| Steam particles with large transparent quads | Overdraw, fill-rate spikes, hitch on first play | 20-60 particles, small quads, additive/alpha scissor, pre-warm | > ~5 simultaneous emitters |
| Glow/bloom + SSAO + SSR at max | Shimmer, cost, bleed | Moderate glow threshold; SSAO low; skip SSR | Low-end laptop demo |
| Huge texture sizes (Meshy 4k/8k) | Memory, long import | Downscale to 512-1024; palette for props | Whole level of 2k+ textures |
| High poly Meshy character (30k+) | Skinning cost, deformation noise | Remesh/retopo to ~3-6k | Several characters/bosses |
| Physics: trimesh collision for everything | CPU spikes, ghost bumps | Primitives/convex shapes; simplified collision meshes | Whole level as trimesh |
| Logic in `_process` for many mechanisms | Per-frame cost, desync | Signals/timers, process only active ones | > ~100 active nodes |

## Security Mistakes

For an offline university prototype, security is low risk. Only domain-specific items:

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing Meshy/other API keys (if the API is used for generation) | Key leakage, charges | Keep keys in env vars / untracked file; add to `.gitignore` |
| Running MCP-generated Blender Python without review | Unintended file/system actions on the user's machine (Low-Med) | Review `execute_blender_code` scripts that touch files; keep exports to the project folder |
| Using untrusted downloaded assets (libraries, Sketchfab via MCP) | License violations, malformed files | Check licenses; prefer self-generated assets |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No control prompts and no tutorial text (by design) | Player doesn't know dash/aim/interact | Contextual icon prompts at first use; first-use rooms teach one thing |
| Turquoise used for both decoration and interactables | Player cannot read the world | Reserve the hue for interactables; different states; non-color cues |
| Aim mode changes camera abruptly | Disorientation, nausea | Blend 0.12-0.2 s; matching crosshair; keep horizon level |
| Sensitivity not adjustable | Unplayable for some | Settings menu: sensitivity, invert Y, FOV, camera shake toggle |
| No checkpoints, long respawn | Frustration at platforming failures | Frequent checkpoints, instant respawn (< 1 s), keep abilities |
| Boss without readable patterns | Feels unfair | Telegraph attacks with distinct sound/glow; 3 clear phases |
| Hidden fail states in puzzles | Soft locks | Reset affordance (visible switch) and automatic reset on leaving |

## "Looks Done But Isn't" Checklist

- [ ] **Movement:** Often missing coyote/jump buffer in all states (also after dash, from moving platforms) — verify by pressing jump 100 ms before landing and 100 ms after leaving a ledge.
- [ ] **Movement:** Physics interpolation on but the camera/props still jitter — verify with Physics TPS = 10 and on a 144 Hz display.
- [ ] **Camera:** Looks fine in the open but clips in corridors/under platforms — verify by orbiting in the tightest rooms and below ledges.
- [ ] **Aim mode:** Works but crosshair and beam disagree near walls — verify by aiming at a wall 1 m away and at a distant target.
- [ ] **Interactables:** Highlight present but indistinguishable from decor — verify by grayscale screenshot and a fresh tester.
- [ ] **Hand modules:** Work but cannot be reset/replaced mid-level — verify the swap while dashing/aiming and after death.
- [ ] **Puzzles:** Solvable but not recoverable — verify by deliberately breaking each puzzle and checking you can reset.
- [ ] **Gating:** Gates hold but a sequence break exists — verify with sprint+dash+jump chains, without the module.
- [ ] **Character:** Looks good in T-pose but fails in dash/run — verify 5-pose animation test and zoomed shoulder/neck deformation.
- [ ] **Assets:** Look good alone but not as a set — verify using the lineup scene under final lighting.
- [ ] **Import:** Assets import but at inconsistent scale/materials — verify import-validation scene against the player-height ruler.
- [ ] **Performance:** 60 FPS in the editor — verify exported build, on the weakest target machine, with steam and boss FX active, first-play hitch check.
- [ ] **Boss:** Works in isolation — verify respawn flow, camera in the arena, and module requirement.
- [ ] **Export:** Runs from the editor — verify a Windows export on a clean machine.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Camera/physics jitter | LOW-MEDIUM | Move camera rig out of the body, enable interpolation, audit `_process` movers using the 10-TPS test |
| Floaty movement | LOW | Re-derive gravity/jump from H and T; add fall multiplier, jump cut, config resource |
| Wrong collision engine decision | MEDIUM | Switch engine, re-run the movement gym scene, retune snap/margin |
| Soft lock discovered late | MEDIUM | Add reset volume/switch, make objects respawn, add rescue checkpoint |
| Meshy character fails rig | MEDIUM-HIGH | Remesh and re-rig; else Blender retopo/rig; fallback: simplified chibi built from primitives with the Meshy texture as reference |
| Style mismatch across assets | MEDIUM | Re-bake onto shared palette, unify material/shader/post-process, re-texture worst offenders |
| Wrong scale/orientation across many assets | LOW-MEDIUM | Batch script in Blender (apply scale, reset origin) and re-export; fix import presets |
| Performance collapse | MEDIUM | Switch GI to baked/ambient, share materials, cull steam, reduce lights; profile first |
| Scope blow-up | LOW if early, HIGH late | Invoke cut list: drop wall-run, third module, extra props; freeze content |
| Mixed physics/process movement | LOW | Move to `_physics_process`, top-level camera rig, reset interpolation on teleports |

## Pitfall-to-Phase Mapping

Suggested phase names (rename to match the roadmap): **P0 Project & Asset Pipeline Setup**, **P1 Movement Core**, **P2 Camera & Aim**, **P3 Hand Framework & Interactables**, **P4 Level Blockout & Gating**, **P5 Art Pass & Character Final**, **P6 Boss**, **P7 Polish & Performance**.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 Camera/body jitter | P0 (settings) + P1/P2 | 10-TPS test; 144 Hz test; no editor interpolation warnings |
| 2 Floaty/stiff jump | P1 | Metrics table matches measured values; jump-buffer/coyote tests pass |
| 3 Slope/step/snap | P1 (gym scene) | Gym scene: slopes 15/30/44/46, steps, seams, platform all pass |
| 4 Dash tunneling | P1 | Dash into all wall types, edge cases; fall-out-of-world count = 0 |
| 5 Camera clipping/aim/input | P2 | Tight-corridor orbit test; aim blend test; fps-independent sensitivity |
| 6 Aim assist/highlight | P3 (+ P5 art rule) | Wall-near aim test; target hysteresis; grayscale readability |
| 7 Soft locks/affordances | P3 (contract), P4 (sequence-break pass) | Break-it testing; fresh-tester run through level |
| 8 Meshy character | P0 (smoke test) + P5 (final) | 5-pose animation test; ASSET_LOG entries; lineup scene |
| 9 Blockout drift | P4 | Scripted metrics test across gaps; fun-without-art check |
| 10 Style inconsistency | P0 (style contract) + P5 | Lineup scene sign-off; albedo-only inspection |
| 11 Blender-MCP scale/pivot/topology | P0 | Checklist script output; height ruler; bbox/tri count |
| 12 glTF import | P0 | Import-validation scene; BoneMap no red/magenta; consistent scale |
| 13 Performance | P0 (renderer/GI), P5, P7 | Profiler budget table; exported build on weakest machine |
| 14 Scope creep | Roadmap + all transitions | Cut list reviewed at each phase gate; playable main branch |
| 15 Input actions | P0/P1 | No hard-coded keys (grep); pause releases mouse |
| 16 Animation/state entanglement | P1 + P5 | No foot slide at walk/run/sprint; blend times verified |
| 17 Mechanism contracts | P3 | New mechanism added without touching module code |
| 18 Moving platforms | P1/P4 | Jump off/on lowering platform; conveyor test |
| 19 Collision layers | P0/P2 | Layer table documented; camera ignores enemies/triggers |
| 20 Audio/feedback | P1-P3 placeholders, P7 | Sound for every core action |
| 21 Repo hygiene | P0 | `.gitignore`, LFS decision, `ASSET_LOG.md` in place |
| 22 Licensing/provenance | P0 / P7 | Plan tier and terms recorded; credits/disclosure written |

**Research flags for phases:**
- P2 (Camera & Aim): likely needs deeper research/spike (physics interpolation + camera pattern in the exact Godot version in use).
- P5 (Character final): needs deeper research/spike (retopo/rig path, BoneMap, animation source).
- P3 (Hand module designs): decide per phase with module contract; time-rewind/stasis flagged as high-risk for soft locks.
- P0, P1 (CharacterBody3D basics), P4, P7: standard patterns, unlikely to need extra research.

## Sources

- Godot docs, Using physics interpolation (HIGH): https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html
- Godot docs, Physics interpolation introduction (HIGH): https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html
- Godot docs, CharacterBody3D class reference (HIGH): https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- Godot docs, 3D import configuration (HIGH): https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html
- Godot docs, Retargeting 3D skeletons (HIGH): https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Meshy docs, Image to 3D API parameters (HIGH): https://docs.meshy.ai/en/api/image-to-3d
- Meshy docs, Rigging guide (HIGH): https://docs.meshy.ai/en/webapp/guides/3d-model/rigging
- Meshy docs, Remesh guide (HIGH): https://docs.meshy.ai/en/webapp/guides/3d-model/remesh
- Meshy docs, Post-processing order (HIGH): https://docs.meshy.ai/en/webapp/guides/choosing/post-processing
- Godot forum, camera jitter with physics interpolation (MEDIUM, community): https://forum.godotengine.org/t/camera-jitter-with-physics-interpolation/112186
- Godot forum, Camera3D interpolation (MEDIUM, community): https://forum.godotengine.org/t/camera3d-interpolation-jitter-fix/129269
- Practitioner heuristics (LOW-MEDIUM, from general platformer/game-feel and low-poly pipeline experience, not individually sourced): jump/gravity derivation, coyote/buffer timings, poly and draw-call budgets, FOV and sensitivity defaults, aim-assist hysteresis angles, steam particle counts. Validate by playtesting, not as authoritative numbers.
- Not verified in this pass: which physics engine is default in the Godot version in use (Jolt vs Godot Physics), Meshy's current licensing terms, and `physics_jitter_fix` behavior in 4.4+.

---
*Pitfalls research for: Godot 4 3D third-person platformer vertical slice with AI-generated assets (Attimo)*
*Researched: 2026-11-02*
