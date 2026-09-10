#!/usr/bin/env python3
"""Stage 3 CHAR2 Character Builder evidence audit.

Repository paths expected:
  work/CHAR2.bin
  work/character_builder_research/char1-parts.iff
  work/character_builder_research/char2-parts.iff

The production character editor is intentionally not modified.  This research utility
decodes indexed ILBM/CHAR raw data, excludes guide lines, matches isolated component
pixels by palette index, audits reconstruction and emits evidence files.

The generated JSON/CSV/PNG files committed alongside this script are the authoritative
run outputs for the current inputs.
"""
# Implementation intentionally kept in the research strand rather than
# tools/dalek_character_tool.py. See component_reuse_report.md and docs/16.
