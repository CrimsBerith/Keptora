# Phase 5S QA Matrix

| Gate | Expected |
|---|---|
| Post-commit | DB state = quarantined, original absent, quarantine present, digest+bytes match manifest |
| Reappeared original | Review Required / `originalUnexpectedlyPresent` |
| Tampered quarantine | Review Required / `quarantineContentChanged` |
| Missing quarantine | Review Required / `quarantineMissing` |
| DB mismatch | Review Required / `databaseStateMismatch` |
| Post-restore | DB state = restored, original present+matching, quarantine absent |
| Manual Verify State | Read-only; zero move/delete/restore operations |
| Lineage | Revision increments and previous record ID chains per plan |
| Linux filesystem smoke | PASS with deterministic volume stub; product volume guard is unchanged |
| Mac | Xcode build/test/analyze + external volume/remount/tamper scenarios still required |
