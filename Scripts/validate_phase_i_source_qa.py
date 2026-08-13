#!/usr/bin/env python3
import pathlib, re
ROOT=pathlib.Path(__file__).resolve().parents[1]
STORE=ROOT/'AppStore'
required=[STORE/'metadata_en-US.md', STORE/'APP_REVIEW_NOTES.md', STORE/'SCREENSHOT_PLAN.md', STORE/'PHASE_I_FINAL_QA_CHECKLIST.md', STORE/'PHASE_I_SUBMISSION_EVIDENCE_MATRIX.md', ROOT/'Docs'/'PhaseGHI'/'PHASE_I_APP_STORE_FINAL_QA.md', ROOT/'Docs'/'PhaseGHI'/'PHASE_H_I_EVIDENCE_PROTOCOL.md', ROOT/'Docs'/'PhaseGHI'/'PHASE_I_FINAL_CLOSURE_PROTOCOL.md', ROOT/'Scripts'/'prepare_phase_i_final_qa_bundle.sh', ROOT/'Scripts'/'validate_phase_i_final_submission.sh']
for p in required:
    if not p.exists() or p.stat().st_size==0: raise SystemExit(f'missing/empty: {p.relative_to(ROOT)}')
meta=(STORE/'metadata_en-US.md').read_text(errors='replace')
low=meta.lower()
for token in ['replace_me','your_company','example.com/privacy','example.com/support']:
    if token in low: raise SystemExit(f'placeholder metadata token: {token}')
def first(patterns):
    for pat in patterns:
        m=re.search(pat,meta,re.I|re.M)
        if m: return m.group(1).strip().strip('`').strip()
    return ''
name=first([r'^\*\*Name:\*\*\s*(.+)$',r'^## Name\s*$\n([^\n]+)',r'^\|\s*App name\s*\|\s*`?([^|`]+)`?\s*\|',r'^#\s+([^—\n]+?)\s*(?:—|-|$)'])
subtitle=first([r'^\*\*Subtitle:\*\*\s*(.+)$',r'^## Subtitle\s*$\n([^\n]+)',r'^### Subtitle\s*$\n+`?([^\n`]+)`?'])
if not name: raise SystemExit('app name missing from normalized metadata')
if len(name)>30: raise SystemExit(f'app name exceeds 30 characters: {len(name)}')
if subtitle and len(subtitle)>30: raise SystemExit(f'subtitle exceeds 30 characters: {len(subtitle)}')
# Require substantive positioning/description, but accept legacy draft structures.
if not (any(x in low for x in ['## description','### description','**positioning:**','### highlights','private by design']) or len(meta.strip()) >= 220): raise SystemExit('substantive description/positioning missing')
shots=(STORE/'SCREENSHOT_PLAN.md').read_text(errors='replace')
if 'Archive Review Studio' not in shots: raise SystemExit('screenshot identity lock missing: Archive Review Studio')
review=(STORE/'APP_REVIEW_NOTES.md').read_text(errors='replace')
if len(review.strip())<80: raise SystemExit('review notes too thin')
print('PHASE_I_SOURCE_QA_PASS app=Cullora shell=Archive Review Studio')
