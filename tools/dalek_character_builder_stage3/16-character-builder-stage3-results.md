# 16 – Character Builder Stage 3 continuation results

## Scope and authority

This report continues the Character Builder Stage 3 work without reopening the settled format/frame research in docs 11–15.

The analysis source is the current repository `work/CHAR2.bin`. For local analysis the indexed `work/CHAR2.png` was converted back to the game's 4-bitplane row-interleaved raw format; the resulting 28,800-byte Git blob SHA is `1fcf32064311515a8ec46f09c329f23439a3b080`, exactly matching the repository blob SHA for `work/CHAR2.bin`. The comparisons below are therefore against byte-equivalent indexed source data, not an RGB approximation.

`char2-parts.iff` was decoded natively as ILBM: 320×256, 4 bitplanes, ByteRun1, 16 indexed colours. Text/reference lines are excluded from component masks.

## Representative reconstruction result

| Frame | Source occupied | Exact source pixels | Missing | Extra | Palette mismatches | Geometry coverage | Assessment |
|---:|---:|---:|---:|---:|---:|---:|---|
| 3 | 537 | 537 | 0 | 0 | 0 | 100.00% | VALID – exact component proof |
| 9 | 484 | 484 | 0 | 0 | 0 | 100.00% | VALID – exact component proof |
| 12 | 518 | 35 | 16 | 31 | 467 | 96.91% | INPUT INDEX DIVERGENCE – diagnostic only |
| 17 | 555 | 29 | 33 | 29 | 493 | 94.05% | INPUT INDEX DIVERGENCE – diagnostic only |
| 25 | 510 | 50 | 15 | 12 | 445 | 97.06% | INPUT INDEX DIVERGENCE – diagnostic only |


### Frames 3 and 9

Both rows are stronger than the earlier frame-0 proof: **each reconstructs 100% of the original indexed frame exactly** from the supplied isolated components, with no missing pixels, no extras and no palette mismatches.

Frame 3 contains 63 unique pixels shared by two or more component masks. Frame 9 contains 47. Every reliable overlap has the **same palette index in both components**, so z-order does not affect the original composite at those pixels. This is useful evidence for a `shared seam/overlap` concept: the builder should assign ownership deterministically when donor artwork differs, rather than relying on coincidental equal colours.

Frame 3's `R_HA` entry is intentionally `ABSENT/OBSCURED`, consistent with the hand being behind the coat.

### Frames 12, 17 and 25 – contradictory input evidence

These three rows clearly correspond geometrically to the intended source poses, but they are **not indexed copies of the current CHAR2 source**. This is not a matching ambiguity that should be guessed through:

| Frame | ALL geometry IoU | ALL exact occupied | ALL palette mismatches | ALL missing | ALL extra |
|---:|---:|---:|---:|---:|---:|
| 12 | 91.64% | 35 | 469 | 14 | 32 |
| 17 | 89.38% | 29 | 493 | 33 | 29 |
| 25 | 96.37% | 51 | 453 | 6 | 13 |


The isolated components in those rows likewise have **no exact indexed X placement against `CHAR2.bin`**. Their analysis anchors in the JSON are therefore labelled as same-sheet/geometry diagnostics only, never as source-recovered exact anchors. Frame 17's head remains intentionally `OBSCURED/ABSENT`.

This prevents a defensible claim that all five supplied rows have passed the indexed reconstruction test. The correct action is to preserve the useful geometry evidence while refusing to promote the affected artwork into the reusable indexed library.

## Reliable reuse / variant findings

| Component | Reliable evidence | Classification / practical consequence |
|---|---|---|
| Hat/headwear | frame-0 side hat is exact at frames 0–8 and 16 | `EXACT_TRANSLATION`; one strong side-view asset. Frame-3 cut differs by only three union pixels and is `NEAR_DUPLICATE_SEAM`, not genuinely new artwork. |
| Head | frame-0 head is exact at frames 0–8 | `EXACT_TRANSLATION`. Frame-3 isolated head contains the complete frame-0 head plus five adjacent seam/border pixels: `NEAR_DUPLICATE_SEAM`. |
| Jump head | frame-9 head appears exactly in frame 10 at `(11,3)` | `EXACT_TRANSLATION`; reusable within jump family. |
| Frame-16 head | frame-0 head gives 34/35 exact occupied pixels at `(9,17)` | `NEAR_DUPLICATE_SEAM`; one-pixel variant, not a new head design. |
| Scarf | frame0/3/9 reliable assets are materially different | `POSE_VARIANT`. Frame-0 standalone scarf has nine hidden black border pixels requiring seam suppression. |
| Coat/torso | frame0/3/9 reliable assets are materially different | `POSE_VARIANT`; do not pretend translation reuse exists. |
| Hands/equipment | reliable exact pieces are mostly unique to their pose | `POSE_VARIANT`; keeping sonic + hand combined remains sensible. |
| Legs | frame0 is a single-leg asset; frame3/9 supplied entries are compound pose artwork | `POSE_VARIANT`; locomotion/jump leg geometry should use pose variants rather than transformed idle leg. |
| Feet | frame-0 foot occurs exactly in frames 0, 7 and 25 at semantic foot locations | `EXACT_TRANSLATION` candidate backed by exact indexed evidence; frame3/9 compound feet remain pose variants. |
| Front/rear/climb views | source geometry clearly changes view | `VIEW_VARIANT`; do not derive by arbitrary rotation/scaling. |

## Layer / seam conclusions

The current evidence does **not** justify fragmenting CHAR2's coat into front/rear layers by default. Frames 0, 3 and 9 reconstruct without such a split. Frame 3 only establishes a simple occlusion constraint: the coat sits above the intentionally hidden hand. Frame 17 establishes that hat/scarf obscure the missing head component, but its row cannot safely establish further indexed layer rules.

Keep front/rear garment splitting as an available per-pose mechanism, exactly as docs 12/14 propose, but instantiate it only when a later source-exact cut-up proves a limb must pass between garment depths.

Frame 0 still supplies the strongest seam-mask example: nine standalone scarf outline pixels are absent from the assembled original. Their exact coordinates, plus the seven missing join pixels, are recorded in `char2_layer_rules.json` / `char2_component_map.json`.

## Frames 0–27: what can be promoted now

`char2_pose_component_matrix.csv` records the conservative source-exact coverage of every authored frame. The important result is that the existing evidence already proves substantial **cross-frame head/headwear reuse**, while coat/scarf/limb artwork remains primarily pose-family-specific.

Frames 3 and 9 are complete exact component proofs; frame 0 remains 98.21%. Other frames are deliberately not “completed” using whole-frame residuals, because that would manufacture a 100% reconstruction while proving nothing about the practical component model. The matrix instead shows exactly which source pixels are covered by assets that have independently passed indexed matching, and which pose/view variants still need trustworthy isolation.

Frames 28–44 are straightforward for CHAR2: all 17 are **pixel-for-pixel exact horizontal flips** of frames 0–16. `char2_flip_validation.csv` records zero differing pixels for every pair. The override mechanism remains appropriate for other characters/exceptions already documented.

## Implementation gate

The headless Character Builder assembler should **not yet be promoted as the next implementation phase** on the basis of this input alone. The model itself has strong positive evidence (frame 0 at 98.21%, frames 3 and 9 at 100%), but three of the five new reference rows fail the core requirement that reusable assets preserve source palette indices.

That is an evidence-quality gate, not a design failure. The next research iteration should re-cut/re-export source-exact indexed components for frames 12, 17 and 25 (or equivalent representative reach/climb/front views). Once those pass the same checks, the full 0–27 semantic library can be completed without inventing boundaries or laundering palette errors into the builder.

## Generated research files

- `char2_component_map.json` – reuse/variant evidence and exact hit map;
- `char2_pose_component_matrix.csv` – authored-frame family/coverage/variant requirements;
- `char2_layer_rules.json` – seam, overlap, occlusion and coat-split rules;
- `char2_representative_analysis.json` – per-component matching and reconstruction diagnostics;
- `char2_flip_validation.csv` – 0–16 → 28–44 exact flip audit;
- `reconstructions/` – original, raw reconstruction and categorical diff PNGs for frames 3, 9, 12, 17 and 25.
