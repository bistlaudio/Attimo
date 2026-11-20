---
quick_id: 261120-dik
description: Dash lockouts, blocked-dash feedback, no dash in aim, softer dash blends
---
# Quick task 261120-dik
Developer decisions (2026-11-20, after Phase 3):
1. No dash while aiming (can_dash false). Aimed dashes DashLeft/Right/Back from 03-07 become dormant (kept, unreachable, documented; amends D-12).
2. Dash is locked during: Jump 3 / long-jump stage 3 pirouette until it ends, the landing window (~0.1 s after touchdown), the first ~0.1 s after take-off. NO input buffer: a locked press is consumed.
3. A locked press gives blocked-input feedback: a tiny non-moving "twitch" (small forward lean kick ~6 deg for ~0.1 s via ProceduralPose, no Dodge pose, no velocity, no cooldown consumed) and an EventBus.dash_blocked signal for later juice/SFX.
4. Softer animation blends: entry into Dash ~0.06 s from ground, ~0.08 s from Jump/Fall; exit ~0.15 s; landing overlay and idle break fade out rather than vanish.
5. All times are MovementConfig exports (F2 "Clip playback"/"Pose"): dash_block_takeoff, dash_block_landing, dash_blocked_twitch_deg, dash_blocked_twitch_time, dash_in_blend, dash_in_blend_air, dash_out_blend.
- Latency and dash feel unchanged otherwise; F4 latency rows must still say Target met (test_latency).
- verify: `bash attimo/tests/run.sh` ends `RUN.SH: PASSED`
