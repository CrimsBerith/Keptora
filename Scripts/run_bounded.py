#!/usr/bin/env python3
"""Bound build/runner startup as well as test execution; retain the complete log."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--timeout', type=float, required=True)
parser.add_argument('--log', type=Path, required=True)
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ['--'] else args.command
if args.timeout <= 0 or not command:
    parser.error('a positive timeout and command are required')
args.log.parent.mkdir(parents=True, exist_ok=True)
with args.log.open('wb') as output:
    process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        result = process.wait(timeout=args.timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        result = 124 if isinstance(error, subprocess.TimeoutExpired) else 130
        print(f'Command stopped ({result}); log: {args.log}', file=sys.stderr)
        for sig, grace in ((signal.SIGINT, 20), (signal.SIGTERM, 5), (signal.SIGKILL, 5)):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                break
            try:
                process.wait(timeout=grace)
                break
            except subprocess.TimeoutExpired:
                continue
print(f'Command exit {result}; log: {args.log}')
sys.exit(result if result >= 0 else 128 - result)
