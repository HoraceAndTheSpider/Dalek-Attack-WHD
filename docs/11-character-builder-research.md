# 11 – Character Builder Research

## 1. Purpose

The existing Dalek Attack tooling can extract, edit and re-import complete playable-character graphics. The remaining problem is artistic rather than file-format related: a new playable character currently requires a complete **45-frame, 288×200, 16-colour indexed sprite sheet**.

AI-generated sheets have been useful for character design, costume and appearance, but have not reliably preserved the original animation geometry. Correcting every frame manually is inefficient, especially for:

- striped trousers/leggings;
- long coats;
- skirts and dresses;
- scarves;
- hair;
- hands and weapons;
- frame alignment.

The proposed **Character Builder** is intended to reduce the amount of unique pixel art required. It should assemble characters from reusable pixel components placed on canonical Dalek Attack pose templates.

This research is intentionally being developed as a **separate module/concept** before integrating anything into `tools/dalek_character_tool.py`.

---

## 2. Confirmed playable-character graphic format

The complete character bank is:

- 45 frames;
- 32×40 pixels per frame;
- 4 bitplanes;
- 16 indexed colours;
- 640 bytes per frame;
- 28,800 bytes (`$7080`) per complete bank;
- editor sheet layout: 9 columns × 5 rows;
- final editor canvas: 288×200 pixels.

Frame numbering is:

- row 1: 0–8
- row 2: 9–17
- row 3: 18–26
- row 4: 27–35
- row 5: 36–44

Frame 0 is therefore the top-left sprite.

Palette index 0 is retained as the raw transparent/background index. In editor-facing material it is displayed as magenta (`$F0F` / `#FF00FF`) rather than made transparent.

---

## 3. Gameplay palette

The established 12-bit Amiga playfield palette is:

| Index | Amiga word |
|---:|---:|
| 0 | `$000` |
| 1 | `$039` |
| 2 | `$666` |
| 3 | `$888` |
| 4 | `$642` |
| 5 | `$864` |
| 6 | `$A86` |
| 7 | `$264` |
| 8 | `$CA4` |
| 9 | `$26C` |
| A | `$112` |
| B | `$488` |
| C | `$444` |
| D | `$A22` |
| E | `$000` |
| F | `$EEE` |

For editing only, index 0 should be shown as magenta. **Palette order must not change.**

Portraits use a different palette and are outside the main Character Builder geometry work.

---

## 4. Confirmed frame semantics

The frame meanings were reviewed against the original sheets and then corrected/confirmed by the user.

| Frames | Confirmed purpose |
|---:|---|
| 0–1 | idle / fire |
| 2–7 | six-phase horizontal locomotion |
| 8 | crouch |
| 9–11 | horizontal jump / fall |
| 12–15 | upward-reaching / jump-to-grab family, including traversing overhead wire |
| 16 | crouch to fire |
| 17–20 | ladder climb / face-on climb |
| 21–24 | rear-facing four-step movement family |
| 25–27 | front/back interaction family, including menu select |
| 28–44 | right-facing counterparts of 0–16 |

Specific confirmed notes:

- **25** is the front-facing pose used on the character-select screen and may also be used in doorway behaviour.
- **26** is a rear-facing/doorway interaction pose.
- **27** is the crouching pose used to find hidden objects.

---

## 5. Exact left/right mirroring

The intended animation structure is that frames **28–44 are horizontal flips of frames 0–16**.

Pair map:

| Source | Derived |
|---:|---:|
| 0 | 28 |
| 1 | 29 |
| 2 | 30 |
| 3 | 31 |
| 4 | 32 |
| 5 | 33 |
| 6 | 34 |
| 7 | 35 |
| 8 | 36 |
| 9 | 37 |
| 10 | 38 |
| 11 | 39 |
| 12 | 40 |
| 13 | 41 |
| 14 | 42 |
| 15 | 43 |
| 16 | 44 |

A raw comparison across CHAR1–CHAR5 showed that most are literally pixel-for-pixel mirrors, including palette indices.

Twelve of the seventeen pairs are exact across all five original characters. The only meaningful discrepancies were in CHAR4 for source frames 6, 7, 9, 10, 12 and 13. Some of these are extremely small; frame 9 is the larger exception.

### Builder implication

Frames 28–44 should be **derived by default** from 0–16. They should not normally be separately authored.

The project format should nevertheless support:

`derived_by_flip = true`

plus an optional:

`manual_override = true`

for a rare frame that deliberately differs from its source.

---

## 6. Additional internal mirror relationships

The face-on/rear animations also contain useful geometric symmetry:

- frame 18 ↔ frame 20: effectively mirrored, with an approximately 1-pixel horizontal offset;
- frame 21 ↔ frame 23: essentially mirrored geometry;
- frame 22 ↔ frame 24: essentially mirrored geometry.

The palette/shading is not always a literal bitmap flip in these pairs.

### Builder implication

These relationships are better represented as **mirrored component geometry** rather than automatically flipping the final composite bitmap.

---

## 7. Cross-character geometry consistency

The five original character banks were compared by occupied-pixel geometry. The figures below represent the approximate proportion of the combined pose silhouette occupied by a majority (at least three of the five characters). They are a measure of **shared pose geometry**, not colour identity.

| Family | Frames | Majority shared geometry |
|---|---:|---:|
| Ladder / face-on climb | 17–20 | ~89% |
| Front/back interaction | 25–27 | ~88% |
| Crouch | 8 | ~86% |
| Rear-facing movement | 21–24 | ~86% |
| Crouch-fire | 16 | ~84% |
| Idle/fire | 0–1 | ~84% |
| Reach/grab/wire | 12–15 | ~77% |
| Horizontal locomotion | 2–7 | ~75% |
| Jump/fall | 9–11 | ~73% |

### Interpretation

The strongest templates are:

- ladder/face-on climb;
- rear movement;
- front/back interaction;
- crouching poses.

Horizontal walking, jumping and reaching vary more because clothing, arms, equipment, hair and coat movement alter the silhouette.

Therefore the Character Builder should **not use one rigid mask for every family**. It should use:

- stronger fixed templates for face-on/rear families;
- anchor-based component placement for side-facing action families.

---

## 8. Stage 3 – CHAR2 frame-0 component experiment

The user supplied an ILBM named `char1-parts.iff`. Despite the filename, the content is **CHAR2 frame 0**.

The sheet isolates:

- All
- Hat
- Head
- Scarf
- `R.Hand` – user correction: anatomically **left hand**
- `L.Hand` – user correction: anatomically **right hand**, including the sonic screwdriver
- Coat
- Leg
- Foot

The isolated pieces were kept at the same vertical positions as the source sprite but were arbitrarily spaced horizontally.

By matching each component back against the original CHAR2 frame 0, exact source coordinates were recovered.

| Component | Isolated size | Recovered position in 32×40 frame |
|---|---:|---:|
| Hat | 12×7 | `(8,0)` |
| Head | 8×7 | `(9,3)` |
| Scarf | 9×22 | `(10,7)` |
| Left hand | 5×5 | `(15,21)` |
| Right hand + sonic | 7×8 | `(5,15)` |
| Coat | 8×24 | `(15,9)` |
| Leg | 7×12 | `(13,28)` |
| Foot | 9×6 | `(10,34)` |

These positions demonstrate that the desired builder can use simple **integer component anchors** rather than scaling, rotation or free-form deformation.

---

## 9. Frame-0 reconstruction proof

The eight supplied components were reassembled at the recovered coordinates and compared to the original CHAR2 frame 0.

Results:

- original occupied pixels: **391**
- original pixels reconstructed exactly: **384**
- exact coverage: **98.21%**
- missing original pixels: **7**
- extra standalone-component pixels: **9**
- palette-index mismatches where both source and reconstruction are occupied: **0**

The seven missing pixels are consistent with the omitted arm/sleeve/join material.

The nine extra pixels are all black pixels from the standalone scarf outline that are hidden/merged when the scarf is assembled against adjoining clothing.

### Important conclusion

The component approach works, but **standalone component outlines cannot be treated as immutable**.

There must be an assembly-time seam/outline concept:

- preserve deliberate internal black outlines;
- allow touching components to hide obsolete perimeter outline pixels;
- audit the final external silhouette;
- do not blindly surround every component with a new outline.

The generated proof is included as:

`work/character_builder_research/char2_frame0_reconstruction_proof.png`

The machine-readable component specification is:

`work/character_builder_research/char2_stage3_component_spec.json`

---

## 10. Confirmed reuse inside CHAR2

Using exact palette-index matching:

### Hat

The same frame-0 **hat bitmap is reused exactly** in:

- frames 0–8;
- frame 16;

with only position changes of approximately 0–5 pixels.

When 28–44 are derived by horizontal flip, that one side-facing hat asset effectively contributes to **20 of the 45 final frames**.

### Head

The same frame-0 **head bitmap is exact in frames 0–8**.

Frame 16 is approximately a 97% match; the small difference is consistent with an overlap/seam change rather than a completely new head drawing.

### Scarf and coat

The scarf and coat are much more pose-sensitive.

They should not be assumed to be one invariant bitmap translated around the frame. They need **pose-family variants** and, for long garments, optional depth layers.

---

## 11. Second user-supplied component reference

The user then supplied `char2-parts.iff`.

ILBM structure:

- 320×256 canvas;
- 4 bitplanes;
- 16 indexed colours;
- ByteRun1 compressed;
- no mask plane;
- white horizontal lines are user-created vertical/floor references.

The sheet contains five requested representative CHAR2 source poses, arranged **top to bottom**:

1. frame 3 – locomotion;
2. frame 9 – horizontal jump/fall;
3. frame 12 – upward reach/grab/wire;
4. frame 17 – ladder/face-on climb;
5. frame 25 – front/menu pose.

Columns are labelled at the top:

- ALL
- HAT
- HEAD
- SCARF
- L.HA
- R.HA
- COAT
- LEG
- FOOT

Important user notes:

- all component rows are vertically registered to the same reference/floor logic;
- horizontal positions are arbitrary;
- the top labels identify component type;
- some component boundaries may overlap marginally where dark borders meet;
- blank entries are intentional:
  - **frame 3 right hand** is obscured by the coat;
  - **frame 17 head** is obscured by scarf and hat;
- the left/right-hand label convention must be reconciled against the first reference, because the first supplied sheet's textual R.Hand/L.Hand labels were reversed relative to anatomical left/right.

### Status

This second sheet has been visually confirmed and is ready to be used as the next analysis input, but the full cross-correlation/component extraction pass had **not yet been completed at handover**.

That should be the first research action in the next thread.

---

## 12. Research conclusion so far

The evidence supports a Character Builder based on:

1. a canonical Dalek Attack pose map;
2. reusable indexed pixel components;
3. integer anchors;
4. pose-specific layer order;
5. horizontal flip derivation;
6. optional component variants;
7. manual one-pixel nudge/override;
8. assembly-time seam/outline handling.

It does **not** support a conventional skeletal-animation approach involving arbitrary limb rotation or scaling.

The intended result is fewer unique drawings while retaining the original game's exact 32×40 alignment and pixel-art character.
