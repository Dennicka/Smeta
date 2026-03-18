# D-013 Migration Flow Evidence (Superseded)

Date (UTC): 2026-03-18

## Status

This document is kept only as a historical checkpoint of the **initial** D-013 migration runner rollout.

**Authoritative and current evidence for D-013 is:**
- `EVIDENCE/D013B_SCHEMA_PARITY.md`

## Important consistency note

The current repository truth is:
- schema version = **3**
- migration steps = **001_base_schema**, **002_legacy_upgrade_bridge**, **003_stage5_ops_tail_tables**
- D-013 status = **RESOLVED** (with full schema parity proof on fresh + legacy paths)

Therefore, any older references to a 2-step flow (`001/002`) or schema version `2` should be treated as historical context only, not as current state.

## Why this file remains in repo

To preserve audit trail chronology between:
1. initial deterministic migration runner introduction,
2. follow-up parity completion pass (D-013b),
3. final consolidated evidence in `EVIDENCE/D013B_SCHEMA_PARITY.md`.
