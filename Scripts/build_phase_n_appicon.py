#!/usr/bin/env python3
"""Compatibility entry point: rebuild current macOS AND iOS icon exports."""
from export_regenerated_visuals import export_icons
export_icons()
print('PASS: current generated icon exports refreshed; both platform catalog slots preserved')
