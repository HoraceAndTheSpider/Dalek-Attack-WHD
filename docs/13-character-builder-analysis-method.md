# 13 – Character Builder Analysis Method

## 1. Purpose

This document records the analysis method so that another thread/developer can continue the research without repeating earlier work or making unsupported assumptions.

The immediate outstanding input is the user-supplied:

`char2-parts.iff`

It contains representative component cut-ups for CHAR2 frames 3, 9, 12, 17 and 25.

---

## 2. Source data to use

Primary original sources:

- `work/CHAR1.bin` / `.png`
- `work/CHAR2.bin` / `.png`
- `work/CHAR3.bin` / `.png`
- `work/CHAR4.bin` / `.png`
- `work/CHAR5.bin` / `.png`

Primary user component references:

- `work/character_builder_research/char1-parts.iff`
  - despite the filename, contains CHAR2 frame 0;
- `work/character_builder_research/char2-parts.iff`
  - contains CHAR2 frames 3, 9, 12, 17 and 25.

Existing parser logic is already present in:

`tools/dalek_character_tool.py`

Relevant logic includes:

- IFF/ILBM chunk parsing;
- BMHD;
- CMAP;
- BODY;
- ByteRun1;
- planar 4-bitplane decoding;
- indexed PNG/ILBM writing.

Do not create a separate incompatible palette/file decoder unless needed for isolated research scripts.

---

## 3. Correct frame decoding

Each raw playable-character frame is 640 bytes:

`32 × 40 × 4 bitplanes / 8`

Each character bank is:

`45 × 640 = 28,800 bytes`

Decode raw data as 4-plane indexed pixels and compare **palette indices**, not rendered RGB approximations.

---

## 4. Analysis of user cut-up ILBMs

The cut-up sheets are not formal sprite atlases.

Important rules:

- horizontal spacing is arbitrary;
- vertical registration is intentional;
- white horizontal lines in `char2-parts.iff` are reference/floor guides, not sprite pixels;
- text labels are metadata drawn into the image;
- blank component cells may be intentionally obscured in the original;
- dark/black edge pixels may overlap slightly between manually isolated components.

Do not use OCR as the primary parsing method. The layouts are small enough to define/confirm row/column regions explicitly.

---

## 5. Recovering original X placement

Because the user retains vertical registration but moves components horizontally, recover X placement by matching each component against the known original frame.

For each candidate component:

1. preserve its exact indexed pixel values;
2. ignore transparent/index-0 pixels;
3. slide it across the 32-pixel source frame at the known/likely Y;
4. score exact palette-index matches;
5. choose the unique/best location;
6. report ambiguous matches rather than guessing.

The frame-0 experiment successfully recovered exact positions this way.

---

## 6. Component comparison across poses

Once components from frames 3, 9, 12, 17 and 25 have been mapped back into their original coordinates, compare each component class against frame 0 and against each other.

Classify each relationship as:

- `EXACT_TRANSLATION`
- `EXACT_MIRROR`
- `NEAR_DUPLICATE_SEAM`
- `POSE_VARIANT`
- `VIEW_VARIANT`
- `OBSCURED`
- `ABSENT`

Do not treat a high occupied-pixel match as proof of semantic identity.

For exact reuse, require exact indexed pixels after translation/flip, allowing only explicitly documented seam pixels if classed as `NEAR_DUPLICATE_SEAM`.

---

## 7. Occlusion and z-order inference

The component cut-up can help infer layering.

For a component mapped back onto the original assembled frame:

- component pixel exists but source frame has another colour -> candidate occlusion/overlap;
- component black outline exists but source frame has adjoining clothing colour -> standalone seam outline;
- source frame pixel is missing from all supplied components -> component not isolated or hidden join material.

Use these differences to derive **ordering constraints**, for example:

`coat behind near arm`

or:

`scarf in front of torso but behind headwear`.

A complete z-order should be set per pose rather than inferred dynamically during normal builder use.

---

## 8. Coat split decision test

Do not pre-emptively split every coat.

For each representative pose:

1. reconstruct with one `GARMENT_BODY`;
2. identify any pixels that must sit both in front of and behind another component;
3. only then split into:
   - `GARMENT_REAR`
   - `GARMENT_FRONT`
   - optional `GARMENT_TAIL`.

If a single coat component reconstructs correctly, retain it as one asset.

---

## 9. Head/hat reuse test

The frame-0 CHAR2 analysis already found:

- hat exact in 0–8 and 16;
- head exact in 0–8;
- head frame 16 near-identical with a small seam/overlap difference.

The new representative frames should determine whether side-view head/hat assets are still applicable to:

- jumping;
- reaching;
- face-on climbing;
- front-facing select pose.

Expect front/rear/face-on views to require dedicated variants.

---

## 10. Derived-frame testing

For each original character, verify:

`flip(frame 0–16) == frame 28–44`

Record:

- exact matches;
- differing pixel count;
- difference bounding box.

Known CHAR4 exceptions should not invalidate the default flip model.

The builder should reproduce the intended relationship and preserve manual override capability.

---

## 11. Quantifying the reduced asset library

Only calculate an "authored component count" after semantic component masks are known.

Do not estimate a precise asset count from whole-sprite similarity alone.

Useful final metrics:

- number of unique head views;
- number of unique headwear views;
- number of torso/coat variants;
- number of arm/hand variants;
- number of leg variants;
- number of foot variants;
- number of equipment-hand variants;
- number of automatically derived right-facing assets;
- number of manually overridden derived frames.

The objective is not the smallest theoretical number. The objective is the smallest **practical and editable** set that preserves the original animation quality.

---

## 12. Reconstruction proof progression

Recommended proof order:

### Proof A – complete
CHAR2 frame 0 reconstructed from supplied components.

Result: 98.21% exact occupied-pixel coverage, no indexed-colour mismatches.

### Proof B – next
Reconstruct representative frames:

- 3
- 9
- 12
- 17
- 25

using the second supplied cut-up ILBM.

### Proof C
Build the remaining CHAR2 authored source frames 0–27 from reusable variants.

### Proof D
Generate 28–44 automatically by horizontal flip.

### Proof E
Compare complete generated CHAR2 bank against original:

- per-frame exact pixel count;
- missing pixels;
- extra pixels;
- palette differences;
- frame boundary violations.

### Proof F
Repeat enough of the process against another structurally different original character to ensure the model is not over-fitted to CHAR2.

---

## 13. Analysis outputs worth committing

Suggested generated research outputs:

- `char2_component_map.json`
- `char2_pose_component_matrix.csv`
- `char2_layer_rules.json`
- `char2_reconstruction_diff/`
- `component_reuse_report.md`

These should initially be research artefacts, not required runtime files.

Only promote stable data into the real builder format after the reconstruction proof succeeds.
