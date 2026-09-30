# Keptora Phase 5R — Teslim Özeti

Phase 5R, Safety Plan hazırlandıktan sonra exact-review kararlarının değişmesi halinde eski planın kullanılmasını engeller.

- Sürüm: `0.9.8 (170)`
- Safety Plan karar snapshot SHA-256 fingerprint'i eklendi.
- Commit öncesinde SQLite'dan güncel cleanup candidate set'i tekrar okunuyor.
- Karar/keeper/digest/provenance/plan üyeliği değişirse plan `STALE` oluyor ve move başlamıyor.
- Aynı freshness gate `QuarantineCoordinator.commit` içinde ikinci kez uygulanıyor.
- Plan revision + previous lineage ID zinciri eklendi.
- `SafetyPlanLineage.json` local history eklendi.
- Signed cleanup manifest schema 4 lineage + decision fingerprint taşıyor.
- Safety Plan sheet CURRENT/STALE + revision gösteriyor; stale plan export/commit edilemiyor, Regenerate Plan gerekiyor.
- Similar-photo önerileri hâlâ cleanup path'ine girmiyor.
