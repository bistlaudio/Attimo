<!-- GSD:project-start source:PROJECT.md -->

## Project

**Attimo (Arbeitstitel offen)**

Ein 3D-Third-Person-Platformer als Uni-Prototyp (vertikaler Slice). Die Hauptfigur ist schuld an der Apokalypse, weil in ihrem Labor etwas schiefgegangen ist, und will zurück ins Labor. Dafür muss sie durch die zerstörte, überwachsene Welt. Zentrales Werkzeug ist die Prothesen-Hand, die steampunkige Mechanismen auslöst und durch gefundene Bauteile (Module) erweitert wird.

**Core Value:** Flüssiges, schnelles Bewegungsgefühl: Laufen, Sprungkette, Dash und Dash-Hop müssen sich smooth anfühlen, und die Hand muss sich damit nahtlos verbinden. Wenn alles andere wackelt, muss das funktionieren.

### Constraints

- **Engine**: Godot 4 — Szenen und Skripte sind textbasiert und lassen sich direkt bearbeiten und versionieren
- **Input**: Maus/Tastatur zuerst, Controller später, daher Input-Actions von Anfang an
- **Umfang**: Vertikaler Slice (ein Level, ein Boss, Uni-Prototyp)
- **Assets**: Low-Poly im KayKit-Stil, importierbar als glTF

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Recommended Stack

### Core Engine

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Godot Engine (standard build, NOT .NET) | **4.7.2-stable** (released 2026-08-18) | Engine | Newest stable 4.x. 4.8 is only at beta2 (2026-10-29), no RC, so do not build on it. 4.7 has AreaLight3D, improved 3D particles (scale/rotation), nearest-neighbour 3D scaling, MeshLibrary editor. 4.6 introduced Jolt-by-default and the new SkeletonModifier3D IK framework. Pin the exact version in README and have every machine use it. | HIGH |
| GDScript (typed) | bundled | All gameplay code | Text-first, hot-reload, no .NET SDK/build step, best fit for Claude-edited `.gd`/`.tscn` files, first-class engine API docs. Use static typing (`var speed: float`, `-> void`) everywhere: catches errors early and is faster. C# gives nothing a prototype needs and adds a build step plus a larger toolchain. | HIGH |
| Jolt Physics | bundled (default for new 3D projects since 4.6) | 3D physics | Already the default in 4.7 for new projects; more stable than GodotPhysics for `CharacterBody3D` on slopes/stairs-like geometry (fewer ghost collisions on concave edges). Keep default. Use primitive/convex collision shapes for platforms (not trimesh of the visual mesh) to avoid ghost edges. | HIGH |
| Renderer: **Forward+** (Windows target uses D3D12 by default in new 4.6+ projects; fall back to Vulkan if a machine has driver issues) | bundled | Rendering | Volumetric fog, SDFGI, SSAO/SSIL, glow quality and decals are Forward+ features. This is a desktop uni prototype, so the Mobile/Compatibility renderers buy nothing. | HIGH (feature gating), MEDIUM (D3D12 vs Vulkan stability on uni PCs) |

### Character Movement (core value: smooth, fast feel)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `CharacterBody3D` + own `PlayerController` script | built-in | Walk, jump chain, dash, dash hop, wall-run | The only sensible base for tuned platformer feel: you own acceleration, gravity, coyote time, jump buffer, variable jump height. Do NOT use `RigidBody3D` or an addon controller; the feel IS the product. |
| Hand-rolled node-based state machine (`State` nodes under a `StateMachine` node: Idle, Run, Jump, LongJump, Fall, Dash, WallRun, Aim) | n/a | Movement states | Small (~100 lines), debuggable, trivial for Claude to extend per phase when the wall-run/modules land. An addon is overkill for ~6 movement states. |
| Physics interpolation (Project Settings > Physics > Common > Physics Interpolation = on) | built-in (3D since 4.4) | Smooth visuals at 60 Hz physics | Removes jitter between physics ticks so the camera and character look smooth at any monitor refresh rate. Move camera in `_process`, physics in `_physics_process`. MEDIUM (verify no artefacts with the SpringArm camera in the first spike). |
- `motion_mode = GROUNDED`, `floor_snap_length` ~0.3-0.5, `floor_max_angle` ~50 degrees, `floor_stop_on_slope = true`.
- Horizontal speed via `move_toward`/exponential smoothing with separate ground and air acceleration; there is one run speed (no sprint); extra speed comes from the dash and the dash-hop long jump.
- Coyote time ~0.1 s, jump buffer ~0.1-0.15 s, variable jump height (cut velocity on release), higher gravity when falling (fall multiplier 1.5-2x), terminal velocity clamp.
- Dash = short velocity override with a cooldown, preserves air control on exit.
- Tune against a test level with fixed-size reference geometry (see grid in Asset Pipeline) so jump height/distance map onto kit pieces.

### Camera

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Hand-built `CameraRig`**: `CameraRig` (Node3D, yaw) > `Pitch` (Node3D) > `SpringArm3D` > `Camera3D` | built-in | Centered third-person follow camera with mouse look; additive FOV/offset sources for aim mode (Phase 3) and camera kick (Phase 11) | Decided in Phase 2 discuss (D-18): own the follow feel, no 0.x addon to pin. Top_level rig with physics interpolation off, reading the interpolated player; `SpringArm3D` masks World. Framing is centered behind the character, the shoulder offset is aim-mode only (D-14). | HIGH |
| Fallback note | built-in | Per-frame shape cast inside `CameraRig` | If the `SpringArm3D` fails the 10-TPS corridor test, replace it with a per-frame shape cast inside `CameraRig` (D-18). Phantom Camera was dropped. | HIGH |

### Input (Input Map actions from day one; keyboard+mouse first, gamepad later)

| Action | KB+M default | Gamepad (add later) |
|--------|-------------|---------------------|
| `move_forward/back/left/right` | W/S/A/D | Left stick |
| `look_left/right/up/down` | (mouse motion handled separately) | Right stick |
| `jump` | Space (on landing: chain Jump 1 -> 2 -> 3) | A/Cross |
| `dash` | Left Shift (tap; dash + jump = dash hop) | B/Circle |
| `aim` (hold) | Right Mouse | L2/LT |
| `use_hand` (fire/trigger module) | Left Mouse | R2/RT |
| `interact` | E | X/Square |
| `module_next/module_prev` | Mouse wheel / 1-2-3 | Bumpers |
| `pause` | Esc | Start |

### Addons (keep this list SHORT)

| Addon | Version | Purpose | When to Use |
|-------|---------|---------|-------------|
| Debug Draw 3D (DmitriySalnikov/godot_debug_draw_3d) | 1.7.3 (2026-04-04; targets Godot 4.4.1+) | Draw raycasts, aim-assist cones, collision shapes, velocity vectors in-game | Deferred (A39): not adopted in Phase 2; revisit when aim or wall-run raycasts need visualisation. Strip from release build if adopted. MEDIUM (check for a newer tag at install time) |
| gdUnit4 | v6.2.3 (2026-11-01) | Unit tests for pure logic (module system, state transitions, coyote/buffer timers) | OPTIONAL. Only test deterministic logic, not feel. Skip if time is short. MEDIUM |
| Godot State Charts (derkork/godot-statecharts) | v0.22.5 (2026-06-26) | Hierarchical state charts | OPTIONAL, boss phases / mechanism logic only. Not for player movement. LOW-MEDIUM (docs for Godot version compat not checked) |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Language | GDScript | C# | Extra SDK/build step, slower iteration, no benefit at this scale |
| Physics | Jolt (default) | GodotPhysics3D | Jolt is the shipped default; fewer ghost collisions. Only switch if a Jolt-specific bug appears (Project Settings > Physics > 3D) |
| Engine version | 4.7.2 | 4.8-beta2 | Beta, addons may lag, no benefit for the slice |
| Engine version | 4.7.2 | 4.6.x | Fine, but 4.7 has better particles and no reason to stay behind |
| Renderer | Forward+ | Mobile / Compatibility | No volumetric fog / SDFGI / best glow; no target hardware reason |
| Camera | Hand-built `CameraRig` (D-18) | Phantom Camera (dropped by D-18) | Own the follow feel; no 0.x addon to pin; the rig exposes additive FOV/offset sources for aim and camera kick |
| Controller | Own `CharacterBody3D` script | Addon "ultimate character controller" | You cannot reach the target feel without owning the numbers |
| State machine | Own node-based FSM | Addons (State Charts, LimboAI, Beehave) | Overkill for 6-8 states; LimboAI/Beehave are AI/behaviour-tree tools, only revisit for boss |
| Kit placement | Scene instances + grid snap | GridMap | GridMap stores cells as packed int arrays in `.tscn` (unreadable/unmergeable for text tooling), poor fit for irregular floating islands |
| GI | Start with none (ambient sky + directional + SSAO), optional baked LightmapGI late | SDFGI | See Look section |

## Installation

# Engine: download "Godot 4.7.2-stable" (standard, not .NET) from https://godotengine.org/download/archive/

# Verify headless works for CI/agent checks:

# Addons (copy into res://addons/, enable in Project Settings > Plugins; commit the addon folders):


#   Debug Draw 3D   1.7.3      -> https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases

#   (optional) gdUnit4 v6.2.3  -> https://github.com/godot-gdunit-labs/gdUnit4/releases

# ASSET PIPELINE

## Poly budget & Meshy settings (apply directly)

### Verdict on the existing character ("CharMeshy": triangle topology, 3,027 faces, 3,518 vertices)

- Performance is irrelevant at this scale; the question is silhouette and readability. The reference has spiky hair, goggles on the forehead, belts/pouches, knee pads, boots and a gear-covered prosthetic arm with glowing cores. At 3k tris, much of that becomes blobs painted by texture, which breaks the "faceted low-poly" look (facets must come from geometry, not texture).
- Hands, goggles and the right arm are the gameplay hero shots (over-the-shoulder camera sees the back and the right arm constantly, aim mode puts the arm in frame). Spend triangles there.
- The actual KayKit character polycounts are not published on the asset page (only "low poly optimized", one 1024x1024 gradient atlas), so I cannot confirm an exact KayKit number (LOW confidence on any specific KayKit tri count). Treat 3k as the lower edge of the range.
- **Recommendation for the final (refined) hero: about 8,000-10,000 triangles (range 6k-12k).** Keep the current 3k model as the placeholder to build and test the rig/animation/Godot import pipeline now. It was already decided that the character will be refined in Meshy later, so nothing is wasted.

### Meshy settings for the NEXT hero generation

| Setting (API name) | Use | Why | Confidence |
|--------------------|-----|-----|------------|
| Model type (`model_type`) | `standard` (Variant A) or `smart-topology` (Variant B) | See A/B below. Do NOT use the old `lowpoly` model type: the docs state it retires 2026-10-30, i.e. already gone/retiring | HIGH |
| `ai_model` | `latest` (Meshy 7.1) for geometry; test `meshy-6` for texture (see texture row) | 7.1 is the current default and supports 4k/ultra geometry | HIGH |
| `should_remesh` | `true` (Variant A). Smart-topology ignores this | Raw (non-remeshed) output has a huge triangle count and messy surface; you want controlled count | HIGH |
| `topology` | **`quad`** for Variant A | Quad-dominant remesh gives much better edge flow for deformation than triangle decimation. Note: glTF/GLB always triangulates on export, so quad is about flow, not file format. Smart-topology only allows `triangle` and returns 400 for `quad` | HIGH (API), MEDIUM (quality claim; verify visually) |
| `target_polycount` | Variant A (quad): **4,500** faces (about 9k tris after triangulation, since 1 quad = 2 tris, consistent with the rigging docs counting a quad as 2 triangles). Variant B (t2.5): **8,000** tris (range 100-30,000; default 15,000). `meshy-t2` max is 15,000 | Targets are approximate ("result can differ"); check the actual count in Blender. Note `decimation_mode` overrides `target_polycount`: leave it unset | HIGH (ranges), MEDIUM (counts are my budget) |
| `pose_mode` | **`a-pose`** (arms about 40-45 degrees down) or `t-pose` if rigging fails | A-pose gives better shoulder/armpit weighting than T-pose; the rigger needs a clear humanoid limb structure | MEDIUM |
| Character facing | Must face **+Z** (glTF forward) or Meshy rigging returns 422 | Documented requirement of the rigging API | HIGH |
| `geometry_resolution` | `standard` is fine; `2k` ultra pass optional for finer hair/goggle silhouette before remesh (needs meshy-7.1/latest, preview only) | Only worth credits if details come out mushy | MEDIUM |
| `enable_pbr` (refine) | **`false`** (base-colour texture only) | Stylized, flat-lit look; Godot lights it. Normal/roughness/metallic maps add VRAM and fight a faceted toon look. Set metallic/roughness as constants in the Godot material | MEDIUM |
| `texture_resolution` | **`2k`** (default) | 2048x2048 is plenty; downsample to 1024 in Godot import if you want a cleaner chunky look. 4k/8k are overkill and 8k removes emission maps. 4k needs meshy-6/7.1 | HIGH |
| `remove_lighting` | `true` and use `ai_model: meshy-6` for the texture refine if baked highlights/shadows appear | This option only takes effect with `meshy-6`; it is accepted but ignored by 7.1/latest. Baked shading on the base colour conflicts with Godot's dynamic toon lighting | HIGH (API), MEDIUM (whether 7.1 already de-lights; test both) |
| `texture_prompt` | e.g. "flat colour hand-painted low-poly game texture, muted earth palette, no baked shadows, no specular highlights, turquoise glowing cores" | Steers toward the KayKit/palette look | MEDIUM |
| Emissive cores | Do NOT rely on Meshy emission maps (only generated with `meshy-6` + PBR on, not 7.1/latest, and not at 8k) | Make the cores glow in Godot: paint an emission mask in Blender (UV islands/vertex group/second material slot for cores) or use a material slot "cores" with emission colour turquoise and `emission_energy_multiplier` 2-4, which also lets you animate/pulse it per module | HIGH |
| Output format (`target_formats`) | `glb` only | Fewer formats = faster task; GLB goes through Blender anyway | HIGH |
| `auto_size` / height | Not needed; pass the real height (`height_meters` 1.4-1.7, match your capsule) to rigging | Correct scale for the rig | MEDIUM |
| Symmetry / `art_style` / `hd_texture` / `ultra_mode` | Do not send | Deprecated or ignored per docs | HIGH |
- **A:** `standard`, `should_remesh=true`, `topology=quad`, `target_polycount=4500`, `a-pose`, 2k, PBR off.
- **B:** `smart-topology` with `ai_model=meshy-t2.5` (default for that type, "sharper detail for game assets"), triangle only, `target_polycount=8000`. Docs describe `meshy-t2`/`t2.5` as cleaner topology with natively separated parts, which can make hair/goggles/arm easier to rigid-bind or give separate material slots for the cores.
- Acceptance test (do in Godot with the rigged model, before polishing anything): bend elbow to 90 degrees, raise shoulder to 90 degrees, knee to 90 degrees, twist spine +/-30, turn head. Reject the variant that shows candy-wrapper pinching, collapsing volume or holes.

### Deformation with triangle (isotropic-decimated) meshes: what to expect and how to handle it

- Triangle decimation (what the current 3,027-face mesh is) places vertices to preserve shape, not to form **edge loops around joints**. At elbows, shoulders, knees and hips there is often a single row of vertices (or none) across the bend, so auto-weights give volume collapse and "candy-wrapper" twisting. Quad remesh and smart-topology improve this but neither equals hand-authored loops. Expect to do a cleanup pass.
- **Design it out where you can (chibi proportions help):** short limbs and large head mean joint angles read small; the head and neck can be rigid (rigid-bind the head, hair and goggles to the head bone, or even to separate meshes). The mechanical prosthetic arm should be **rigid-bound per segment** (upper-arm plate, forearm, hand = 100% weight to one bone each, hide the joint with a ring/gear/sleeve). Knee pads and boots (visible in the reference) should also be rigid-bound; this removes the worst deformation zones. Because the arm mesh stays visually the same always (no swappable arm meshes), this rigid binding is permanent and cheap.
- **Fix the rest in Blender:** add 1-2 loop cuts at elbow/knee/shoulder of the cloth/leather parts, then weight-paint (smooth + normalize); or re-skin with Blender "Automatic Weights" onto Meshy's skeleton and clean. Budget about half a day for the hero.
- Check Meshy's auto-rig result for: correct finger/hand bone count, no stray weights between arm and torso in A-pose, and bone orientation/naming (needed for Godot BoneMap, see below).
- Use a **modest, loose pose range** in animations; avoid 120-degree elbow flexes that the mesh can't take.

## Poly budgets (triangles; stylized, KayKit-class, Forward+ desktop target)

| Asset class | Target tris | Hard cap | Materials | Texture | Notes |
|-------------|-------------|----------|-----------|---------|-------|
| **Hero (final)** | **8-10k** | 12k | 2 (body, emissive cores) | 2048 base colour (or 1024) | Skinned; skeleton humanoid, about 25-40 bones; rigid-bind arm/boots/goggles |
| Hero (current placeholder) | ~3k | - | 1 | existing | Use for pipeline tests |
| **Boss** | **15-30k** | 40k | 2-3 | 2048 | If boss is a "possessed object" (machine/clock/furnace): build from mostly **rigid, unskinned parts** animated by `AnimationPlayer` (cheaper, cleaner than skinning) |
| Small props (crate, lamp, valve, barrel, crystal, bolt) | 50-800 | 1,000 | palette | shared palette | Many instances, use `MultiMeshInstance3D` for repeats |
| Medium props (boiler, small gear, chimney, bench, cart) | 800-3,000 | 4,000 | palette | shared palette | |
| Large set pieces (big gear, steam engine, clock tower, gate) | 3-8k | 12k | palette (+ emissive) | shared palette | Turquoise glow parts in own material slot |
| Interactables / energy cores (gameplay-critical) | 100-500 | 800 | 1 emissive | none/flat | Must read from far away; glow, not geometry, sells it |
| **Modular env kit pieces** (platform tile, wall, railing, bridge section, pipe segment, stairs) | **150-1,200** | 2,000 | palette | shared palette | Snap to a 1 m grid in 2 m / 4 m modules; 1 collision primitive per piece |
| Floating-island chunk / rock underside | 1,500-5,000 | 8,000 | palette | shared palette | Faceted rock, flat shaded |
| Clouds / background islands | 100-1,500 | 2,500 | 1 | none | Far geometry, can be very coarse |
| **Whole visible scene** | **250k-500k tris** | ~1M | **<= 20-30 total** | | Also: aim for < 1,500 draw calls, 1 shadow-casting directional light, <= 8 non-shadowed omni/spot lights in view, <= 30 active steam emitters |

## Texturing: palette/gradient atlas approach

- KayKit's own method (verified from the asset page): ONE 1024x1024 gradient atlas shared by the whole pack (can be downsampled to 128x128). It is why the pack looks cohesive and costs almost no memory or draw calls (one material, batches well).
- **Do the same for the environment and props:** create one `palette.png` (512x512 or 1024x1024) with swatches for the Attimo palette: cream/beige accents, muted metal (grey-blue steel, dull brass/copper rather than glaring bronze), leather browns, rust, warm stone/brick, foliage greens, and the turquoise energy colour. Add a few vertical gradient strips (light-to-dark) for cheap faux-AO on tall pieces.
- Method: in Blender, UV-map every face onto a swatch centre (UV islands collapsed to small points/rects inside swatches, with at least 2-4 px margin) so no texture bleeding occurs. Optionally bake AO into **vertex colours** (Godot: material `vertex_color_use_as_albedo` and multiply) for depth without extra textures.
- Godot import for `palette.png`: Compress Mode **Lossless**, mipmaps **off** (or keep on with large margins), filter Linear or Nearest. VRAM-compression artefacts show in tiny swatches.
- Emissive turquoise: a dedicated material `m_energy` (emission turquoise, `emission_energy_multiplier` 2-4), NOT part of the palette, so glow can be tweened/pulsed per object and per module.
- Hero and boss: keep their own unique texture (Meshy output, 2048 or 1024); unify visually with shared toon lighting and colour grading. Re-texturing the hero onto the palette is optional polish, not required.
- Normal maps: skip. Faceted geometry + flat shading carries the look. Metallic/roughness as material constants (roughness 0.7-0.9; metal maybe 0.2-0.4, because high metallic looks black without reflection sources unless you add a `ReflectionProbe` or sky reflections).
- Flat shading: in Blender use Shade Flat or Auto Smooth with ~30 degrees so the facets from `World Look.png`/`Character_Look.png` survive. Meshy meshes often arrive smooth-shaded: fix this in the conform step.

## Blender (MCP) conform pipeline for every new asset

## glTF export settings (Blender -> Godot 4)

| Option | Setting | Why |
|--------|---------|-----|
| Format | **glTF Binary (.glb)** for characters/props; `glTF Separate` (+ shared `palette.png`) if you want to avoid duplicating the palette inside every GLB | Single file is simplest; separate keeps one texture file in git |
| Include | Selected Objects (or Visible Objects), Custom Properties on if you tag nodes | Deterministic scripted exports |
| Transform | **+Y Up** (default) | Godot is Y-up; Blender's -Y front becomes glTF +Z |
| Mesh: Apply Modifiers | On | Bake decimate/mirror results |
| Mesh: UVs, Normals | On | Needed |
| Mesh: Tangents | Off (no normal maps) | Saves size |
| Mesh: Vertex Colors | On if using baked AO vertex colours | Used via `vertex_color_use_as_albedo` |
| Materials | Export (or "No Export" for kit pieces and assign the palette material in Godot) | Palette approach: let Godot own the material |
| Images | Automatic/PNG for hero; None for kit pieces | |
| Compression | Off | |
| Animation | On; Mode **Actions** (one action per clip, named e.g. `run-loop`); Optimize Animation Size on | Clip names control Godot loop import |
| Armature | **Export Deformation Bones Only = On** (essential with Rigify or any control-bone rig) | Control/IK bones otherwise pollute the Godot skeleton |
| Skinning | On; limit to 4 influences (glTF/Godot default) | |
| Lights/Cameras | Off | |
- Node name suffixes: `-col` (collision shape added, mesh kept), `-colonly` (collision only, invisible), `-convcol` (convex collision), `-noimp` (not imported), `-navmesh`, `-occ`. Prefer simple box/convex proxies for platforms over `trimesh` (Jolt ghost edges, performance). MEDIUM (from established Godot behaviour, docs page not re-fetched).
- Animation names ending `-loop`/`_loop` (and `-cycle`/`_cycle`) set loop mode on import. MEDIUM.
- Never edit an imported scene in place; create an inherited/own scene (`hero.tscn` wrapping `hero.glb`) so re-exports do not destroy your changes.
- Mesh LODs and shadow meshes are generated automatically on import; leave on. Enable "Light Baking > Static Lightmaps (generate UV2)" only on meshes that will use LightmapGI.

## Rigging and animation

| Source | Use for | Notes |
|--------|---------|-------|
| **Meshy auto-rig** (`POST /openapi/v1/rigging`) | Rig the hero | Humanoid biped only, face +Z, textured GLB, up to 380,000 triangles (a quad counts as 2), `height_meters` default 1.7. Outputs rigged GLB + FBX, plus optional `basic_animations` (walk, run; GLB with skin, FBX with skin, armature-only GLB). Verified from docs. Quality of auto-weights is unverified, hence the Blender cleanup and acceptance test above. |
| **Meshy Animation API** (`action_id` / `action_ids`, library via `GET /openapi/v1/animations/library`; e.g. 0=Idle, 1=Walking_Woman, 8=Dead) | Placeholder clips: idle, walk, run, jump-ish, death | Multiple IDs return one file with one clip per animation. Good enough for prototype, character animations generally need re-timing to fit chibi proportions. |
| **Mixamo** (free, Adobe account; FBX, "in place" option) | Best source of a decent locomotion set: idle, run, sprint, jump, fall, land, roll/dash-like, climb | Bone names are `mixamorig:*`; retarget through Godot BoneMap. Chibi proportions (big head, short legs) cause foot sliding and floaty feel: tune `AnimationTree` time-scale vs speed, and accept some compromise or hand-fix. Mixamo clips may not be redistributed standalone; embedding in a game is fine. MEDIUM |
| **Blender Rigify** | Only if the Meshy rig is unusable | Cost: setup time, export deform bones only. Not the default path for this slice. |
| Hand-keyed in Blender / Godot `AnimationPlayer` | Hand ability poses (aim/point with prosthetic arm), dash, wall-run, boss attacks | Unique-to-game motion cannot come from libraries. |
| Procedural (Godot `SkeletonModifier3D`: `LookAtModifier3D`, TwoBoneIK3D, new in 4.6) | Head looks toward aim target; arm points at the target while aiming; foot placement later | Reduces authored animation count. MEDIUM (API names from 4.6 release notes; confirm in the 4.7 class reference when implementing) |
- Root `AnimationNodeStateMachine`: `Locomotion` (BlendSpace1D on horizontal speed: idle-walk-run-sprint), `Jump`, `Fall`, `Land`, `Dash`, `WallRun`.
- Upper-body layer: `AnimationNodeBlend2` with a bone filter (spine upward) for **aim pose** / hand ability poses, driven by the `aim`/`use_hand` actions, combined with `AnimationNodeOneShot` for ability triggers.
- Code sets parameters (`parameters/Locomotion/blend_position`, state travel) from the movement FSM; the movement FSM stays the source of truth. Root motion off.

# LOOK: stylized lighting and shaders in Godot 4.7

| Topic | Recommendation | Why | Confidence |
|-------|----------------|-----|------------|
| Renderer | Forward+ | Needed for volumetric fog/SDFGI/best glow | HIGH |
| Global illumination | **Phase 1: none.** Use Environment ambient from a stylized gradient sky (`ProceduralSkyMaterial` or a custom `Sky` shader) + one `DirectionalLight3D` (warm, soft shadows, 2-3 PSSM splits) + SSAO. **Optional late polish: baked `LightmapGI`** for static islands (needs UV2, generate on import) | A floating-island level in an open sky is mostly direct light + sky ambient; the look is flat/clean anyway. | MEDIUM |
| SDFGI | **Do not use** | Wasteful on huge empty-sky volumes (cascades cover mostly void), leaks and pops on thin platforms, dynamic objects (moving mechanisms, hero) do not contribute bounce. | MEDIUM-HIGH |
| VoxelGI | Optional per-area probe for an indoor lab/interior part only | Good for small enclosed spaces; manual bake per volume | MEDIUM |
| Glow | `Environment.glow_enabled = true`; HDR threshold about 1.0, intensity about 0.8, `Screen` blend; drive the turquoise cores with emission energy 2-4 | In 4.6+ glow blends before tonemapping with Screen as default. Strong bloom on cores is the main "magic" read for interactables | HIGH |
| Tonemap | Filmic baseline; try AgX (4.6 made `agx_white`/`agx_contrast` configurable) and keep the one that keeps turquoise saturated | Tuning decision, not architecture | MEDIUM |
| Fog | **Cheap depth fog with sky-colour aerial perspective** for distance haze across islands + **Volumetric fog** (low density about 0.01-0.03, Forward+ only) for sun shafts; local `FogVolume` nodes for steam vents | Atmospheric perspective gives the "islands in the clouds" depth; volumetric fog is moderately expensive: keep resolution default, test on laptop GPUs | MEDIUM |
| Clouds / cloud sea | Large low-poly cloud meshes and/or scrolling-noise plane shader below the playfield; also drives the death-pit read | Cheap and stylistically consistent with faceted look | MEDIUM |
| Steam | `GPUParticles3D`: low-poly icosphere puffs (or soft billboard quads with proximity fade), unshaded or lightly lit white-grey, scale-over-life curve, colour ramp to transparent, 16-64 particles per emitter, upward velocity + turbulence. 4.7 adds better 3D particle scale/rotation control | Matches the faceted reference puffs; GPU particles are cheap; cap emitters | MEDIUM |
| Toon shading | Use `StandardMaterial3D` with **Diffuse Mode = Toon** and **Specular Mode = Toon** for the base; add one small custom spatial shader only for: rim/fresnel on interactables, optional light ramp on the hero | You do not need a full custom toon pipeline: KayKit-style = flat colours + soft lighting. Fewer custom shaders = fewer bugs | HIGH (built-in toon modes exist), MEDIUM (look fit) |
| Outlines | Optional inverted-hull outline via `next_pass` material (cull front, slightly scaled along normals) on hero and interactables only; skip screen-space outline | Cheap and controllable; the reference images have no heavy outlines, so default OFF | MEDIUM |
| Interactable highlight | Emissive turquoise material + pulsing `emission_energy_multiplier` (Tween or shader parameter) + glow + optional rim shader; aim-assist via cone/`ShapeCast3D` towards objects in an `interactable` group, debug-drawn with Debug Draw 3D | Satisfies "everything interactive glows turquoise" with one shared material | MEDIUM |
| Anti-aliasing | MSAA 3D 4x (Forward+) ; FXAA optional | Low-poly facets have long hard edges that alias heavily | MEDIUM |
| Shadows | 1 directional shadow caster; omni/spot lights without shadows (warm lamps, glowing cores can be small `OmniLight3D` with low range) | Shadow-casting lights are the real GPU cost | MEDIUM |
| Mobile renderer | Not used | Unneeded constraint | HIGH |

## Sources

- Godot release archive and GitHub releases feed (versions/dates: 4.7.2-stable 2026-08-18, 4.8-beta2 2026-10-29): https://godotengine.org/download/archive/ , https://github.com/godotengine/godot/releases - HIGH
- Godot 4.6 release page (Jolt default for new 3D projects, IK framework, glow/AgX changes): https://godotengine.org/releases/4.6/ - HIGH
- Godot 4.7 release page (AreaLight3D, particle scale/rotation, nearest 3D scaling, MeshLibrary editor): https://godotengine.org/releases/4.7/ - HIGH
- Godot docs, Using Jolt Physics (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html - HIGH
- Phantom Camera repo and release feed (v0.11.0.4, Godot 4.4+): https://github.com/ramokz/phantom-camera - MEDIUM (not adopted, D-18)
- Debug Draw 3D releases (1.7.3, 4.4.1+): https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases - MEDIUM
- godot-statecharts releases (v0.22.5): https://github.com/derkork/godot-statecharts/releases - MEDIUM
- gdUnit4 releases (v6.2.3): https://github.com/godot-gdunit-labs/gdUnit4/releases - MEDIUM
- Meshy API docs, Text to 3D (parameters, polycount ranges, model types, texture options, lowpoly retirement): https://docs.meshy.ai/en/api/text-to-3d - HIGH
- Meshy API docs, Rigging (humanoid only, +Z, 380k tri limit, outputs): https://docs.meshy.ai/en/api/rigging-and-animation - HIGH
- Meshy API docs, Animation library (action_ids): https://docs.meshy.ai/en/api/animation-library - HIGH
- KayKit Dungeon Remastered asset page (200+ assets, 1024x1024 gradient atlas, CC0, formats): https://kaylousberg.com/game-assets/dungeon-remastered - HIGH
- Import suffixes, loop hints, BoneMap retargeting, glTF export-option choices, SDFGI/volumetric-fog trade-offs, and all poly/draw-call budgets: established Godot/Blender practice and engineering judgment, not re-verified against the docs this session (the docs "importing scenes" URL returned 404) - MEDIUM/LOW. Validate in the first asset spike.

## Open items to validate early (feeds roadmap research flags)

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

## Git Workflow (Attimo)

- All phase work happens on the `dev` branch. Never commit phase work directly to `main`.
- After a phase completes successfully (verification passed): merge `dev` into `main`, push `main` and `dev` to `origin`, then switch back to `dev`.
- Raw asset packs (`KayKit/`) are tracked in the repo root as a shared reference library, outside the Godot project folder (`attimo/`) so Godot never imports them. Only the assets actually used are copied into `attimo/assets/`.

## Communication

- The user writes in German; answer in German. Planning docs stay in English.
