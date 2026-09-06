# Level sprites and the Level 1 Hoverbout

## Level sprite banks

`SPRITES1..5` are level/location sprite banks. They are separate from the playable-character animation banks.

The current mapping is:

```text
level/location index = $8A(A5)
```

with zero corresponding to Level 1 / `SPRITES1`.

## Descriptor table

The master level-sprite descriptor table is at runtime:

```text
$1EDA6
```

Each descriptor is:

```text
22 bytes
```

Fields confirmed so far:

| Offset | Meaning |
|---:|---|
| `+0` | width in pixels |
| `+2` | height |
| `+4` | frame count |
| `+6` | bytes per bitplane per frame |
| `+8` | runtime pointer field populated by setup code |
| `+12` | runtime pointer field populated by setup code |
| others | not yet fully named |

The descriptor/mask builder routine is at:

```text
$5562
```

## Per-level descriptor lists

Known runtime addresses:

| Level | Descriptor list |
|---|---:|
| 1 | `$1F882` |
| 2 | `$1F8A0` |
| 3 | `$1F8B1` |
| 4 | `$1F8C7` |
| 5 | `$1F8DF` |

These lists select/order descriptor IDs for the current level.

## Level 1 Hoverbout discovery

The Level 1 list includes descriptor:

```text
$15 = decimal 21
```

Descriptor 21 is:

```text
width            32
height           56
frames            6
bytes/bitplane/
frame            $00E0
total bytes/frame $0380
```

Its raw graphics start inside decompressed `SPRITES1` at:

```text
$A500
```

Frames:

```text
frame 0  original CHAR1 rider + Hoverbout
frame 1  original CHAR2 rider + Hoverbout
frame 2  original CHAR3 rider + Hoverbout
frame 3  original CHAR4 rider + Hoverbout
frame 4  original CHAR5 rider + Hoverbout
frame 5  empty Hoverbout
```

The sixth frame starts:

```text
$A500 + 5 * $0380
= $B680
```

This is why a new selector value 5 naturally displays the empty Hoverbout: the game is already selecting a valid sixth frame.

No additional Hoverbout frame-index rewrite is required.

## Disk extraction

`SPRITES1` is an Ice resource on `Disk.2`:

```text
Disk.2 offset    $013000
packed size      38,539
unpacked size    90,352
```

After depacking:

```text
Hoverbout set starts  $A500
six frames x $0380    $1500 bytes total
```

The Python tool exports:

```text
CHAR1_hoverbout.bin/.png/.iff
...
CHAR5_hoverbout.bin/.png/.iff
CHAR6_hoverbout_template.bin/.png/.iff
```

The sixth template is the original empty Hoverbout and is the preferred starting point for drawing the new rider.

## Current WHDLoad Hoverbout implementation

Required external file:

```text
data/chars/CHAR6_hoverbout.bin
```

Raw format:

```text
32x56
4 bitplanes
$0380 / 896 bytes
playfield palette
```

The file is loaded into reserved ChipRAM:

```text
HOVERBOUT6_CHIP = $107C80
```

### First attempted insertion point

The first implementation wrapped the Ice depacker call at runtime:

```text
$272C: JSR $0000D74C
```

The custom frame did not appear in the user's initial test.

### Current insertion point

The patch was moved later, immediately before the game consumes the raw level-sprite bank.

Original runtime code:

```text
$26B2  BSR.W $5562
$26B6  RTS
```

Current optional patch:

```asm
PL_P $26b2,BuildLevelSprites
```

At this point:

- `SPRITES1` has already been decompressed;
- `$55F8` still points at the raw level-sprite bank;
- `$5562` has not yet built the descriptor pointers/masks.

The wrapper, for Level 1 only:

```text
source      = $107C80
destination = [$55F8] + $B680
length      = $0380
```

then calls `resload_FlushCache` and jumps to the original `$5562` builder.

This current revision is **implemented, awaiting in-game confirmation**.

## Why `$55F8` matters

During level-sprite loading, `$55F8` is the working pointer used for the decompressed level sprite data.

The Hoverbout patch deliberately occurs before `$5562` advances/repurposes this state during descriptor setup.
