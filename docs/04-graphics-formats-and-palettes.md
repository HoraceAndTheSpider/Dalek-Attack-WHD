# Graphics formats and palettes

Dalek Attack's graphics investigated here use 4-bitplane Amiga indexed colour.

## Common planar row layout

For the playable characters, portraits, Hoverbout composite and BLOCK tiles, data is row-planar.

For each scanline:

```text
plane 0 bytes
plane 1 bytes
plane 2 bytes
plane 3 bytes
```

Bits within each plane byte select palette indices in the normal Amiga planar manner.

## Playable character frame

```text
width             32 px
height            40 px
bitplanes          4
colours            16
bytes/row/plane    4
bytes/frame        4 x 40 x 4 = 640 = $0280
frames             45
bank size          45 x $280 = $7080 = 28,800 bytes
```

Editable sheet layout used by the tool:

```text
9 columns x 5 rows
45 frames
32 x 40 per frame
288 x 200 total useful image area
```

Frame order is:

```text
0..8
9..17
18..26
27..35
36..44
```

left-to-right, top-to-bottom.

## Portrait

```text
width       32 px
height      32 px
bitplanes    4
bytes        $0200 = 512
```

Portraits use a **different palette** from gameplay.

## Level 1 Hoverbout composite

```text
width       32 px
height      56 px
bitplanes    4
bytes        $0380 = 896
```

The Hoverbout composite uses the **playfield/gameplay palette**.

## BLOCK tile

```text
width       16 px
height      16 px
bitplanes    4
bytes        128
```

Per row:

```text
2 bytes plane 0
2 bytes plane 1
2 bytes plane 2
2 bytes plane 3
```

## Playfield palette

Runtime table:

```text
$11E74
```

Recovered Amiga 12-bit colour words:

```text
0: $000
1: $039
2: $666
3: $888
4: $642
5: $864
6: $A86
7: $264
8: $CA4
9: $26C
A: $112
B: $488
C: $444
D: $A22
E: $000
F: $EEE
```

Used for:

- playable-character animations;
- BLOCK tiles;
- normal level sprites;
- Level 1 Hoverbout composites.

## Portrait / menu-HUD palette

Runtime table begins:

```text
$11E92
```

Recovered Amiga 12-bit words:

```text
0: $000
1: $029
2: $666
3: $999
4: $642
5: $964
6: $B96
7: $264
8: $FD4
9: $BBB
A: $224
B: $499
C: $444
D: $D22
E: $000
F: $DDF
```

This palette correction was necessary because using the playfield palette on the portraits produced visibly wrong colours in comparison with the game.

## Editing transparency convention

For editing only, palette index 0 is displayed as:

```text
Amiga $F0F
RGB #FF00FF
```

This does **not** alter the raw game data.

When an edited PNG/ILBM is rebuilt:

```text
magenta display colour -> palette index 0
```

The raw bank still contains only indexed bitplane data.

## DPaint canvas handling

DPaint does not need to save the exact useful dimensions.

The tool accepts larger indexed PNG/ILBM canvases and crops from the top-left:

| Asset | Required crop |
|---|---|
| character sheet | `288x200` |
| portrait | `32x32` |
| Hoverbout | `32x56` |

A `320x256` DPaint screen is therefore valid as long as the useful artwork begins at `(0,0)`.

## Palette preservation

For round-trip editing, keep the 16 palette indices in their original order.

The tool converts by **index**, not by attempting to remap arbitrary RGB colours to a new palette. This is essential to preserve the exact raw bitplane values.
