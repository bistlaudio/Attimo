---
date: "2026-11-12 14:00"
promoted: false
---

Group B (Produktion) / Phase 9 Style Contract: very early, BEFORE any asset is generated (Meshy hero, Blender kit), run an art-style exploration step: (1) list the feasible art styles for the Godot 4.7 Forward+ renderer, (2) pick which candidates to actually look at in-engine (spikes on the real gym/level), (3) decide the final style at the end of that step, and only then write the style contract (palette, poly budgets, Meshy settings). Candidates so far: smooth painted low-poly (current reference images), toon/cel with outlines, 3D pixel-art look via low-res SubViewport + depth/normal edge shader (spike exists on branch spike/pixel-look, attimo/spikes/pixel_look/, keys P/O/T, quick task 261112-k76), hybrid HD-2D (pixel-snapped low-res world with a sharper hero). The pixel look changes asset requirements (min thickness about 0.2 m for thin parts, fewer fine details, hero tri budget lower than 6-9k, no MSAA, Nearest filter, flat colours, Meshy remove_lighting) and the camera (texel snapping), so it must be decided before Meshy generation and before the kit is built.
