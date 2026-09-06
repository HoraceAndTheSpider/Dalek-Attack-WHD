# Runtime address map

Quick-reference map of the principal runtime addresses identified during the character/graphics work.

## Game state

| Address/offset | Meaning |
|---|---|
| `$156(A5)` | Player 1 character selection |
| `$157(A5)` | Player 2 character selection |
| `$8A(A5)` | level/location index |
| `$55F8` | working/decompressed graphics pointer used by level sprite setup |

## Character resources

| Address | Meaning |
|---:|---|
| `$E528` | start of 23-entry RESIDENT resource pointer table |
| `$E528-$E538` | first five entries: original playable character source/resource pointers |
| `$E588-$E598` | five decompressed playable-character graphics pointers |
| `$1797A` | original portrait block base |
| `$1837A` | end of five original `$200` portraits |

## Character selector code

| Address | Meaning |
|---:|---|
| `$281E` | original Player 1 source graphics selector |
| `$2842` | P1 common continuation after source selection |
| `$2862` | original Player 2 source graphics selector |
| `$2876` | P2 common continuation after source selection |
| `$EBDC` | P1 initial/random selection area |
| `$EBDE` | immediate divisor/count patched for number of characters |
| `$EEC0` | P1 manual cycle area |
| `$EEC6` | P1 manual wrap immediate |
| `$EF98` | original P2 `BCHG #0,$157(A5)` cycle |
| `$F0B2` | P1 decompressed/runtime graphics selector |
| `$F0D0` | P1 runtime common continuation |
| `$F0FA` | P2 decompressed/runtime graphics selector |
| `$F10A` | P2 runtime common continuation |

## Character global IDs

| Address | Meaning |
|---:|---|
| `$1FB8` | P1 global character-ID setup |
| `$1FF2` | P2 global character-ID setup |
| `$1FF4` | original immediate base `3` inside P2 setup |

## Portrait selection

| Address | Meaning |
|---:|---|
| `$2518` | P1 portrait routine area |
| `$251A` | longword operand for P1 portrait base |
| `$2532` | P2 portrait routine area |
| `$2534` | longword operand for P2 portrait base |

Original bases:

```text
P1 $1797A
P2 $17F7A
```

## Ice / graphics setup

| Address | Meaning |
|---:|---|
| `$D74C` | game Ice depacker |
| `$272C` | original `JSR $0000D74C` during level sprite loading |
| `$26B2` | original `BSR.W $5562` followed by `RTS` |
| `$5562` | level sprite descriptor/pointer/mask builder |
| `$1EDA6` | master 22-byte sprite descriptor table |

## Per-level descriptor-list addresses

| Level | Address |
|---|---:|
| 1 | `$1F882` |
| 2 | `$1F8A0` |
| 3 | `$1F8B1` |
| 4 | `$1F8C7` |
| 5 | `$1F8DF` |

## Palettes

| Address | Meaning |
|---:|---|
| `$11E74` | playfield palette |
| `$11E92` | portrait/menu-HUD palette |

## Current mod-only ChipRAM

| Address | Meaning |
|---:|---|
| `$100000` | external CHAR6 raw animation bank |
| `$107080` | new six-entry portrait block |
| `$107A80` | sixth portrait |
| `$107C80` | sixth Level 1 Hoverbout frame |
| `$110000` | current requested end of base/Chip memory |

## Disk.1 runtime mapping

For the main game image:

```text
Disk.1 offset = runtime address + $17800
```

Use this only for addresses known to belong to that loaded main image.
