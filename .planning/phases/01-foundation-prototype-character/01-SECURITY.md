---
phase: "01"
slug: "foundation-prototype-character"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-11-04"
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Engine download -> local machine | Godot 4.7.2 zip fetched once and extracted to `$HOME/Applications/Godot_4.7.2` | Third-party binary |
| KayKit reference library -> `attimo/assets/` | Whitelisted files copied byte-identical from the tracked root `KayKit/` | Third-party art/animation assets |
| Input devices -> game | Keyboard and mouse via the Input Map only | Player input |
| Debug overlay -> release build | Event log scene and `debug_event_log` action | Gameplay fact stream |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | Engine zip / installed Godot | high | mitigate | SHA-512 pin in README (matches official SHA512-SUMS), `run.sh` version gate (exit 3), in-engine version assert | closed |
| T-01-02 | Tampering | Wrong Godot version rewriting project files | medium | mitigate | Version gate runs before `--import`; README forbids other versions | closed |
| T-01-03 | Repudiation | False-green test runs | medium | mitigate | `run.sh` log grep for script errors, non-zero exit propagation, filter-miss fails | closed |
| T-01-04 | Tampering | Copied Mannequin and Rig_Medium GLBs | low | mitigate | Byte-identical to tracked originals; originals must stay tracked (`run.sh`) | closed |
| T-01-05 | Elevation of Privilege | `tools/*.gd` builders | low | mitigate | Constant `res://` paths only, no exec/network/FileAccess calls | closed |
| T-01-06 | Spoofing | Raw input polling | low | mitigate | Named Input Map actions only; scanned by `test_input_map` | closed |
| T-01-07 | Tampering | Input handling outside Input Map | low | mitigate | Forbidden-token scan, device -1, key/mouse only | closed |
| T-01-08 | Tampering | Config/doc drift | low | mitigate | `test_conventions` asserts layers, constants, Player layer/mask | closed |
| T-01-09 | Tampering | Copied Prototype Bits | low | mitigate | Byte-identical to tracked originals; whitelist test | closed |
| T-01-10 | Information Disclosure | Event log overlay in release | low | mitigate | Not an autoload, hidden by default, `debug_` action; stripping tracked as REL-03 (Phase 15) | closed |
| T-01-11 | Tampering | Test guard scanning files | low | accept | Read-only `FileAccess`/`DirAccess` on fixed `res://` folders | closed (accepted) |
| T-01-12 | Tampering | Unvetted files under `attimo/assets/` | medium | mitigate | Exact 25-file whitelist, no KayKit dir/.fbx/.obj, KayKit tracked, no LFS | closed |
| T-01-13 | Information Disclosure | Debug event log in test scene | low | accept | Hidden by default; REL-03 strips it from release | closed (accepted) |
| T-01-SC | Tampering | Package/addon installs | low | accept | No addons or packages installed in Phase 1 | closed (accepted) |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-01-11 | Test guard only reads fixed `res://` folders; writes and executes nothing (01-06-PLAN) | plan-time disposition, verified by auditor | 2026-11-04 |
| AR-02 | T-01-13 | Debug event log intentionally present in the test scene; hidden by default; stripped from release in Phase 15 (REL-03) | plan-time disposition, verified by auditor | 2026-11-04 |
| AR-03 | T-01-SC | No packages or addons installed in Phase 1; engine covered by T-01-01 | plan-time disposition, verified by auditor | 2026-11-04 |

---

## Residual Observations (non-blocking)

- Raw-input scan token list is narrow (review IN-05); no violations today.
- Doc-sync checks are mostly substring matches (review WR-02); no drift today.
- `run.sh` has no timeout (review WR-05).
- Release stripping of debug scene/action is not implemented by design; re-verify in Phase 15.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-04 | 14 | 14 | 0 | gsd-security-auditor |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed

**Approval:** verified 2026-11-04
