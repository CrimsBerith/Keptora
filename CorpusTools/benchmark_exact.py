#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, json, os, sqlite3, time

def digest(path, chunk=1024*1024):
    h=hashlib.sha256(); size=0
    with path.open('rb') as f:
        while True:
            block=f.read(chunk)
            if not block: break
            h.update(block); size+=len(block)
    return h.hexdigest(),size

def main():
    p=argparse.ArgumentParser(); p.add_argument('--corpus',required=True); p.add_argument('--out',required=True); a=p.parse_args()
    root=Path(a.corpus); started=time.perf_counter(); groups={}; files=[]
    for path in sorted(x for x in root.rglob('*') if x.is_file() and x.name!='ground_truth.jsonl'):
        d,s=digest(path); groups.setdefault((d,s),[]).append(path.name); files.append(path)
    elapsed=time.perf_counter()-started
    dup=[v for v in groups.values() if len(v)>1]
    result={'assets':len(files),'elapsed_seconds':elapsed,'assets_per_second':len(files)/elapsed if elapsed else 0,'exact_groups':len(dup),'duplicate_assets':sum(map(len,dup))}
    Path(a.out).write_text(json.dumps(result,indent=2)); print(json.dumps(result,indent=2))
if __name__=='__main__': main()
