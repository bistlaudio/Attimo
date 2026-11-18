---
quick_id: 261118-okz
description: Remove long-jump stretch lean; dash lean ~20 deg, upright on dash hop
---

# Quick task 261118-okz

Gym feedback (Phase 3, plan 03-09 check): the 60 degree long-jump stretch makes the character lie almost horizontal in the air.

## Task 1: ProceduralPose lean change
- files: attimo/scripts/player/procedural_pose.gd, attimo/scripts/player/movement_config.gd (Pose group), attimo/tests/smoke/test_procedural_pose.gd, docs/MOVEMENT-METRICS.md (regenerated), docs/ANIMATION-MAP.md, docs/CONVENTIONS.md, .planning docs only where they state the stretch
- action: Ground dash keeps its ~20 degree forward lean. On dash -> LongJump hand-over the lean eases back to 0 (upright) instead of holding the 60 degree stretch until landing. Air dash stays upright. Remove or repurpose the stretch exports (`stretch_lean_deg` etc.) in MovementConfig and keep a lean-out ease time export. Pirouette (Jump 3 / long jump stage 3) and aim_lean_scale behaviour must keep working. Update tests so they assert the new behaviour (no assertion weakened beyond the removed stretch).
- verify: `bash attimo/tests/run.sh` ends with `RUN.SH: PASSED`
- done: long jump is upright; dash lean unchanged; suite green; committed on dev.
