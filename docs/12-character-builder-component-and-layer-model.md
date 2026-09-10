# 12 – Character Builder Component and Layer Model

## 1. Design principle

The Character Builder should behave as a **pixel-component assembler**, not as a skeletal tweening or vector-animation system.

The original artwork is low-resolution indexed pixel art. Arbitrary rotation, scaling, shearing or interpolation will damage:

- line weight;
- dithering;
- palette control;
- pixel clusters;
- silhouette consistency.

The system should therefore prefer:

- integer translation;
- exact horizontal flip;
- predefined component variants;
- explicit z-order;
- optional manual pixel correction.

---

## 2. Component model

A character does not need to use every available component. The component set should be flexible.

Recommended component classes:

### Head group

- `HEAD`
- `HAIR_REAR`
- `HAIR_FRONT`
- `HEADWEAR`
- optional `FACE_OVERLAY`

The CHAR2 experiment proves that headwear can be highly reusable across multiple frames.

### Torso group

- `TORSO_BASE`
- `TORSO_DETAIL`

`TORSO_BASE` should represent the principal shirt/jumper/t-shirt/basic upper-body artwork.

`TORSO_DETAIL` can contain:

- lapels;
- tie;
- braces;
- waistcoat;
- jacket opening;
- decorative costume features.

### Arm/hand group

Initial implementation should favour **whole arm or sleeve variants** rather than splitting at upper-arm/forearm/elbow.

Recommended:

- `FAR_ARM`
- `NEAR_ARM`
- `FAR_HAND`
- `NEAR_HAND`
- `EQUIPMENT_HAND`

Hands may remain part of arms where this is artistically cleaner.

Do not force a fixed anatomical decomposition.

### Leg/foot group

Recommended:

- `FAR_LEG`
- `NEAR_LEG`
- optional `FOOT` / `SHOE`

Whole-leg variants are preferable to thigh/shin pieces at this resolution.

Separate footwear is useful when a character's shoes/boots differ substantially but the leg geometry is reusable.

### Garment group

Recommended:

- `GARMENT_BODY`
- optional `GARMENT_REAR`
- optional `GARMENT_FRONT`
- optional `GARMENT_TAIL`
- optional `SKIRT_DRESS`
- optional `ACCESSORY`

Examples of `ACCESSORY`:

- scarf;
- bag strap;
- dangling belt;
- long hair strand;
- other character-specific overlay.

---

## 3. Coats and long garments

The user specifically raised whether coats should be split into left/right pieces to aid layering.

The research indicates that **splitting can help, but should not be mandatory**.

The preferred distinction is **depth**, not literal screen-left/screen-right:

- rear/far garment section;
- main garment body;
- front/near garment section.

For a simple pose, CHAR2 frame 0 demonstrates that a single `COAT` component can work well.

For a long coat during walking/jumping, the builder may instead use:

```text
GARMENT_REAR
TORSO_BASE / GARMENT_BODY
GARMENT_FRONT
```

This permits:

- one leg to pass behind a coat flap;
- one leg to pass in front;
- an arm to cross in front of the coat;
- tails to move independently without rebuilding the upper torso.

A garment should only be split when the pose genuinely requires an intervening layer.

### Do not over-fragment

A long coat must not automatically become many tiny pieces. The objective is to **reduce**, not increase, authored artwork.

---

## 4. Pose-specific z-order

There should not be one universal drawing order.

Each pose/template should own a z-order list.

A typical side-facing pose may resemble:

```text
HAIR_REAR
FAR_ARM
FAR_LEG
GARMENT_REAR
TORSO_BASE
TORSO_DETAIL
NEAR_LEG
GARMENT_FRONT
NEAR_ARM
HEAD
HAIR_FRONT
EQUIPMENT_HAND
ACCESSORY
```

A climb pose may use a substantially different order.

The data model should therefore store something equivalent to:

```json
{
  "frame": 3,
  "layers": [
    "far_arm",
    "far_leg",
    "garment_rear",
    "torso",
    "near_leg",
    "garment_front",
    "near_arm",
    "head"
  ]
}
```

This explicit approach is safer than trying to infer visibility automatically at runtime.

---

## 5. Anchor model

The builder requires placement anchors, not an animation skeleton.

Suggested canonical anchors:

- `HEAD`
- `NECK`
- `TORSO`
- `FAR_SHOULDER`
- `NEAR_SHOULDER`
- `FAR_HAND`
- `NEAR_HAND`
- `HIP`
- `FAR_LEG`
- `NEAR_LEG`
- `FAR_FOOT`
- `NEAR_FOOT`
- `GARMENT_WAIST`
- `GARMENT_HEM`
- `EQUIPMENT`

Each component also has its own local attachment point.

Placement is:

`pose_anchor - component_local_anchor + user_nudge`

All coordinates are integers.

The frame-0 reconstruction demonstrates that this is sufficient for real original artwork.

---

## 6. Manual nudge

Every placed component should support non-destructive:

- left;
- right;
- up;
- down;

one pixel at a time.

The resulting offset must be saved per component/per pose.

It should be possible to reset a component to its canonical anchor position.

---

## 7. Safe transformations

Default permitted transformations:

- integer translation;
- horizontal flip;
- predefined alternate component;
- possibly exact 90° rotation only where deliberately authored/tested.

Default prohibited transformations:

- arbitrary rotation;
- fractional translation;
- arbitrary scaling;
- shear;
- antialiased interpolation.

These prohibitions are important for indexed pixel accuracy.

---

## 8. Mirroring

Frames 28–44 are normally derived from 0–16.

The project data should distinguish:

- authored frame;
- derived frame;
- derived frame with manual override.

A derived frame should retain its relationship to the source so edits to the source can regenerate the counterpart unless an override has been set.

For rear/face-on pairs such as 21↔23 and 22↔24, mirror relationships may exist at a **component geometry** level without requiring the completed bitmap to be a literal mirror.

---

## 9. Equipment

The original Doctor characters may visibly hold a sonic screwdriver in some poses. Other characters use gun artwork.

Very small equipment is difficult to anchor independently.

For a sonic screwdriver, prefer combined hand variants, for example:

- `HAND_SONIC_IDLE`
- `HAND_SONIC_FIRE`
- `HAND_SONIC_RAISED`

The user-supplied CHAR2 frame-0 component confirms that a hand + sonic composite is a natural artistic unit.

Larger equipment such as a gun can optionally be separated:

- `HAND`
- `GUN`

but this is not mandatory.

The builder should support both methods.

---

## 10. Outline and seam model

The frame-0 experiment proves that a component's standalone black outline can contain pixels that disappear when components touch.

Therefore:

### Preserve

- internal intentional outlines;
- authored shadow/detail pixels;
- palette-index identity.

### Do not assume

- every standalone perimeter black pixel remains visible after assembly.

### Assembly should support

1. component layering;
2. optional seam masks/occlusion;
3. external silhouette audit;
4. highlighting missing exposed outline pixels;
5. optional manual correction.

Avoid an aggressive "outline every non-transparent pixel" routine because it will damage internal detail and joining edges.

---

## 11. Recolouring

Recolouring should be palette-index aware.

The eventual builder may define semantic colour roles such as:

- `OUTLINE`
- `SKIN_DARK`
- `SKIN_MID`
- `SKIN_LIGHT`
- `GARMENT_DARK`
- `GARMENT_MID`
- `GARMENT_LIGHT`
- `ACCENT`

These roles must map onto the fixed 16-colour Dalek Attack palette.

The builder must never silently introduce arbitrary RGB colours or reorder palette indices.

This is especially useful for:

- striped trousers;
- repeated costume shading;
- recoloured jackets;
- repeated boot/shoe treatment.

---

## 12. Hard frame constraints

Every completed frame must remain:

- exactly 32×40 pixels;
- indexed to the legal palette;
- background/index 0 retained;
- integer positioned.

If a component exceeds the frame:

- warn/highlight it;
- do not silently clip it without the user's knowledge.

Show useful guides:

- 32×40 frame boundary;
- baseline/floor;
- centre line;
- optional anchor points.

---

## 13. Flexible character decomposition

The builder should allow character-specific component sets.

CHAR2 may naturally use:

- hat;
- head;
- scarf;
- hand;
- hand+sonic;
- coat;
- leg;
- foot.

Another character may instead use:

- hair rear;
- head;
- t-shirt torso;
- complete arms;
- trousers;
- boots.

Do not force every character into the same anatomical breakdown.

This is one of the most important design conclusions from the supplied cut-up sheets.
