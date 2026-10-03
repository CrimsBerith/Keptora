#!/usr/bin/env python3
"""Re-export approved photo masters, preserving fixture semantics."""
import argparse
from export_regenerated_visuals import export_corpus

parser = argparse.ArgumentParser()
parser.add_argument('--output', default=None)
args = parser.parse_args()
print(export_corpus(args.output))
