# Phase 5N Implementation — Safety Preview, Exclusions & Recovery Confidence

**Version:** 0.9.4 (130)

## Shipped

- Searchable Safety Plan preview before any quarantine move.
- Explicit confirmation that destination, keeper protection and recovery path were reviewed.
- JSON export of the exact pending plan for audit/support.
- Built-in scan exclusions for hidden items, package contents, `.Keptora Quarantine`, `.git` and `node_modules`.
- User-defined excluded folder names and file extensions, applied on the next scan.
- Phase 5N release validator and updated Mac release gate.

## Safety invariants

1. Plan export does not modify files or database decisions.
2. Commit stays disabled until explicit confirmation is checked.
3. Exclusions reduce discovery scope only; they never mutate or remove files.
4. Quarantine folders are always excluded from later scans to prevent re-ingestion loops.
5. Similar-photo groups remain review-only.

## Mac validation required

- Verify NSSavePanel JSON export in sandboxed Debug and Release builds.
- Test exclusion rules with case variants, external volumes, nested folders and non-ASCII names.
- Exercise Safety Plan filtering with 10K+ operations.
- Verify VoiceOver reading order and Full Keyboard Access for confirmation and commit controls.
