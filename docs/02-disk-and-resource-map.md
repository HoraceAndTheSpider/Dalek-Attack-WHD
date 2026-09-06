# Disk and resource map

Both supplied disk images are standard ADF-sized files:

```text
901,120 bytes
```

The game uses its own resource layout inside the images.

## Disk.1 — main game and playable characters

### Runtime-address mapping for the main game image

For the main executable area investigated so far:

```text
Disk.1 offset = $17800 + runtime address
```

This mapping is useful when converting a runtime address seen in disassembly into a location in `Disk.1`.

Example:

```text
runtime portrait base $1797A
+ Disk.1 base         $17800
= Disk.1 offset       $2F17A
```

### Playable animation banks

The five original playable-character banks are individual Pack-Ice streams.

| Character | Disk.1 offset | Packed size | Unpacked size |
|---|---:|---:|---:|
| CHAR1 | `$090E5C` | 15,859 | 28,800 / `$7080` |
| CHAR2 | `$094C50` | 15,475 | 28,800 / `$7080` |
| CHAR3 | `$0988C4` | 13,875 | 28,800 / `$7080` |
| CHAR4 | `$09BEF8` | 12,944 | 28,800 / `$7080` |
| CHAR5 | `$09F188` | 15,493 | 28,800 / `$7080` |

Expected original identity order:

| Global ID | Raw file | Character |
|---:|---|---|
| 0 | CHAR1 | Second Doctor |
| 1 | CHAR2 | Fourth Doctor |
| 2 | CHAR3 | Seventh Doctor |
| 3 | CHAR4 | Ace |
| 4 | CHAR5 | UNIT soldier |

### Portrait block

The five original 32x32 portraits are **not separate Ice streams**. They are already raw and contiguous in the main game image.

Runtime:

| Character | Runtime address | Size |
|---|---:|---:|
| CHAR1 | `$1797A` | `$0200` |
| CHAR2 | `$17B7A` | `$0200` |
| CHAR3 | `$17D7A` | `$0200` |
| CHAR4 | `$17F7A` | `$0200` |
| CHAR5 | `$1817A` | `$0200` |
| end | `$1837A` | — |

Derived Disk.1 offsets:

| Character | Disk.1 offset |
|---|---:|
| CHAR1 | `$2F17A` |
| CHAR2 | `$2F37A` |
| CHAR3 | `$2F57A` |
| CHAR4 | `$2F77A` |
| CHAR5 | `$2F97A` |
| end | `$2FB7A` |

## Disk.2 — level graphics

### Level sprite banks

These are **level/location sprite banks**, not the playable-character banks.

| Bank | Disk.2 offset | Packed size | Unpacked size |
|---|---:|---:|---:|
| SPRITES1 | `$013000` | 38,539 | 90,352 |
| SPRITES2 | `$031800` | 36,170 | 79,360 |
| SPRITES3 | `$04E200` | 36,452 | 88,304 |
| SPRITES4 | `$06CC00` | 41,193 | 92,680 |
| SPRITES5 | `$08C400` | 36,879 | 75,680 |

`SPRITES1` contains the separate Level 1 rider-on-Hoverbout frames.

### BLOCK tile banks

Each BLOCK bank depacks to:

```text
138,304 bytes
```

Layout:

```text
64-byte prefix
+ 1080 tiles x 128 bytes
= 138,304 bytes
```

Locations:

| Bank | Disk.2 offset | Packed size | Unpacked size |
|---|---:|---:|---:|
| BLOCK001 | `$005600` | 55,613 | 138,304 |
| BLOCK002 | `$022800` | 60,952 | 138,304 |
| BLOCK003 | `$040400` | 56,515 | 138,304 |
| BLOCK004 | `$05E000` | 60,101 | 138,304 |
| BLOCK005 | `$07C200` | 65,890 | 138,304 |

Each tile is:

```text
16 x 16 pixels
4 bitplanes
128 bytes
```

## Important distinction

Do not confuse:

```text
WHO0:RESIDENT playable-character banks
```

with:

```text
WHO1:SPRITES1..5 level/location sprite banks
```

The playable characters are the five `$7080` banks on `Disk.1`.

The level sprite banks contain scenery, enemies, effects and some special composite player graphics such as the Level 1 Hoverbout.
