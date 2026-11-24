---
status: partial
phase: 05-energy-arm-loader
source: [05-VERIFICATION.md]
started: 2026-11-24T19:54:00Z
updated: 2026-11-24T19:54:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Loader tracer feel: hold RMB on ground and in air, release
expected: 0.25x slow motion, free camera, ring + dashed preview, discharge matches preview; smooth, no camera lurch on release (WR-01)
result: [pending]

### 2. Geladen cues (vignette, desaturation, pull-back, hitstop, hum) at 60/120/10 TPS; tap the Loader quickly
expected: Eases in/out; vignette does not jump up on early release (WR-04)
result: [pending]

### 3. F2 Loader tuning panel
expected: Sliders change min push, bonus, cap, hold time, slow factor live and sensibly
result: [pending]

### 4. Forearm core readability (offsets on lowerarm.r unverified) and Moto glow
expected: 4 cores readable on the arm in third person; Moto glow visible
result: [pending]

### 5. Refused air dash feedback with empty arm
expected: Air dash does not fire and a grey flicker shows; base moves fall back silently
result: [pending]

### 6. HUD readability and turquoise body glow
expected: Energy HUD top left readable; body glow reads Moto state
result: [pending]

### 7. Passive charge and dash-hop cost motivation (Moto run 9.52 m/s is under the 10 m/s charge start)
expected: Energy income feels reachable by running; costs motivate Loader/capsule use
result: [pending]

### 8. Shot as visible ball, full-charge tell; shot ring vs Loader ring distinguishable without colour
expected: Clear, distinguishable
result: [pending]

### 9. Hip-fire snap/bend while dash-hopping; Extractor feel
expected: No unpleasant snap; Extractor drain readable
result: [pending]

### 10. Tuning guesses (7 deg, 540 deg/s, 40 m/s, 4 m)
expected: Accepted or retuned
result: [pending]

### 11. West-wing gym walkthrough of the 'Erwartet:' stations; Phase 04.1 UAT re-check for changed Ausloeser stations/puzzle rooms
expected: Each station behaves as its sign says; 04.1 behaviours not regressed
result: [pending]

### 12. 4 m jump to reach the Loader door (keep vs bridge)
expected: Decision: keep or add a bridge
result: [pending]

### 13. Switch module mid-charge (CR-01) and Moto Jump 3 tap (WR-05)
expected: No energy lost; tapped Moto Jump 3 not lower than normal
result: [pending]

### 14. WR-02 fix check at Loader_Gap: ground throw -> over ledge -> air Loader; ground throw -> jump -> air Loader; ground throw -> (Moto) run -> late walk-off -> air Loader
expected: first refused; second and third still work
result: [pending]

## Summary

total: 14
passed: 0
issues: 0
pending: 14
skipped: 0
blocked: 0

## Gaps
