# Keptora Phase 5R QA Matrix

## Safety Plan freshness
- Prepare plan and commit without decision change -> commit permitted.
- Change one planned asset to Skip -> stale; commit blocked before move.
- Change keeper -> stale; commit blocked.
- Add a new exact copy to the plan after preparation -> stale; operation-count/fingerprint mismatch.
- Rescan/change digest -> freshness or existing pre-move content hash gate blocks unsafe move.
- Legacy plan without a decision fingerprint -> regenerate required.

## Lineage
- First plan for a source -> revision 1, no previous lineage ID.
- Regenerate -> revision +1 with previous lineage ID.
- Cancel -> local lineage state cancelled.
- Stale detection -> local lineage state stale.
- Successful quarantine -> local lineage state committed.
- Exported Safety Plan JSON contains fingerprint + lineage identity.
- Signed cleanup manifest schema 4 carries fingerprint + lineage fields.

## UI
- Safety Plan shows revision and CURRENT/STALE state.
- Stale state clears confirmation and disables Export/Move.
- Regenerate Plan creates a fresh revision.
- No permanent sidebar or new generic dashboard shell introduced.

## Mac-only acceptance
- Clean build + unit/UI tests under current Xcode.
- VoiceOver reads freshness state, revision, Recheck, Regenerate and Move actions in logical order.
- Test source folder on internal APFS and external removable volume.
- Change a decision while a draft exists through a controlled test hook and prove zero file moves occur.
- Archive/Analyze/StoreKit sandbox/signing/TestFlight after real release identifiers are configured.
