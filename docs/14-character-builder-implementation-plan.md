# 14 – Character Builder Implementation Plan

## 1. Architecture

Keep the Character Builder isolated from the current working character editor during initial implementation.

Suggested structure:

```text
tools/
    dalek_character_tool.py          # existing tool; keep stable

    character_builder/
        __init__.py
        pose_spec.json
        component_model.py
        assembler.py
        palette.py
        validation.py
        project_io.py

        analysis/
            analyse_components.py
            compare_reconstruction.py

        templates/
        reference/
```

The exact filenames may change, but the separation is important.

### Data flow

```text
component assets
      +
pose/anchor specification
      +
character project
      |
      v
Character Builder
      |
      v
45 × 32×40 indexed frames
      |
      v
288×200 indexed sprite sheet
      |
      v
existing dalek_character_tool.py
      |
      v
28,800-byte raw CHAR bank / PNG / ILBM
```

The existing import/export path should remain authoritative for the final Dalek Attack raw format.

---

## 2. Project file

A builder project should be non-destructive and human-readable.

Example concept:

```json
{
  "character": "example",
  "palette": "dalek_playfield",
  "components": {
    "head_side": {
      "file": "components/head_side.iff",
      "anchor": [2, 3]
    }
  },
  "frames": {
    "0": {
      "layers": [
        {"component": "coat_side", "at": [15, 9]},
        {"component": "head_side", "at": [9, 3]}
      ]
    },
    "28": {
      "derived_from": 0,
      "transform": "flip_x"
    }
  }
}
```

Project data must record manual nudges and derived-frame overrides.

---

## 3. Phase 1 – research utilities

Before GUI work:

- decode component-sheet ILBMs;
- recover source X positions;
- write component masks;
- compare translated/mirrored components;
- generate reconstruction diagnostics;
- generate per-frame diff reports.

Acceptance:

- repeat the CHAR2 frame-0 reconstruction deterministically from saved metadata;
- produce identical indexed output on repeated runs.

---

## 4. Phase 2 – headless assembler

Implement a small assembler capable of:

- loading indexed component assets;
- placing at integer coordinates;
- z-ordering;
- horizontal flipping;
- composing into 32×40 frames;
- generating derived frames;
- detecting overflow;
- checking palette indices;
- saving a 288×200 sheet.

No GUI is required for this phase.

Acceptance:

- reconstruct selected original CHAR2 frames from component data;
- preserve exact pixel indices.

---

## 5. Phase 3 – CHAR2 full reconstruction proof

Before building a user-facing Character Builder:

1. create the minimum practical CHAR2 component library;
2. author frames 0–27;
3. derive 28–44;
4. compare generated sheet/bank to original;
5. resolve seams/layering;
6. document intentional differences.

A high-quality original reconstruction is the proof that the model works.

Do not skip directly to a new Doctor/assistant character.

---

## 6. Phase 4 – project editor UI

Only after the headless model is stable.

The eventual UI may be a separate page/section from the existing character editor.

Required functions:

- load existing 45-frame character as reference;
- load/import component PNG/ILBM;
- select component;
- select component variant;
- integer nudge controls;
- flip component;
- set layer order;
- hide/show component;
- edit/recolour component;
- toggle reference/underlay;
- show frame boundary;
- show floor/baseline;
- show anchors;
- show palette;
- mark frame as derived/manual;
- regenerate derived frames;
- preview final 9×5 sheet.

---

## 7. Pixel editing

A small indexed-pixel editor is desirable but should remain simple.

Functions:

- pencil;
- erase to index 0;
- palette-index picker;
- eyedropper;
- one-pixel grid zoom;
- optional flood fill;
- undo/redo.

No RGB painting.

---

## 8. Component extraction/import workflow

Useful later feature:

1. open an existing sprite/frame or external donor;
2. select pixels/region;
3. create component;
4. choose semantic type;
5. choose local anchor;
6. save indexed component;
7. place in current frame.

This supports the user's preferred workflow of extracting one useful element from an otherwise imperfect AI-generated sheet.

---

## 9. AI artwork role

AI-generated sheets should be treated as **design donors**, not animation authority.

Useful donor content:

- head/hair;
- costume design;
- coat detail;
- boots;
- scarf;
- sleeve;
- hand;
- colour treatment.

Canonical geometry should continue to come from:

- the original five Dalek Attack character banks;
- validated pose templates;
- manual pixel placement.

An optional underlay mode could display donor art beneath the canonical frame at reduced opacity for manual harvesting/nudging.

---

## 10. Recolour workflow

Future implementation can support semantic recolouring without repainting every frame.

Example:

- user recolours `TROUSER_DARK`, `TROUSER_MID`, `TROUSER_LIGHT`;
- all leg variants using those semantic roles update.

However:

- semantic mapping must still resolve to the fixed 16-colour palette;
- outlines should normally remain outline colour;
- per-component override should be possible.

---

## 11. Validation

The builder should run validation continuously or on demand.

### Frame validation

- exactly 32×40;
- no non-indexed colours;
- no invalid palette indices;
- no unintended clipping;
- index 0 handled correctly.

### Sheet validation

- exactly 45 frames;
- 9×5 order;
- 288×200 final sheet;
- derived-frame relationships known;
- complete raw export expected to be 28,800 bytes.

### Visual validation

- baseline/floor alignment;
- silhouette overflow;
- exposed missing outline;
- suspicious seams;
- left/right derived-frame differences.

---

## 12. Testing strategy

Maintain reference tests using original characters.

Minimum tests:

1. ILBM/PNG/raw round-trip remains lossless.
2. CHAR2 frame-0 reconstruction produces the recorded result or better.
3. Known exact 0–16/28–44 original mirror pairs reproduce exactly.
4. Builder-generated 28–44 are byte/pixel flips of their sources unless overridden.
5. Illegal RGB/palette input is rejected or explicitly converted through controlled mapping.
6. Components outside 32×40 cause visible validation failure.
7. Saving/reloading a builder project does not alter output.
8. Regeneration never overwrites a manual override silently.

---

## 13. Integration with current editor

Do not modify the working editor merely to prove the builder concept.

Once stable, sensible options are:

- a second page/tab in the same Pygame application;
- a separate Character Builder executable/module launched from the existing tool.

The existing character editor remains useful as a final pixel-level check after assembly.

Recommended final workflow:

```text
Builder -> assemble
        -> inspect/edit in existing Character Editor
        -> export raw/ILBM/PNG
```

---

## 14. Definition of first usable milestone

A Character Builder milestone is reached when it can:

- load a saved component project;
- reconstruct one original character with high fidelity;
- generate the right-facing half automatically;
- allow manual layer/nudge corrections;
- save a legal 288×200 16-colour sheet;
- pass that sheet through the existing raw import/export tooling unchanged.

Only after this should effort move toward convenience features and large reusable component libraries.
