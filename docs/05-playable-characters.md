# Playable characters

## Original playable set

The original game has five global character IDs:

| ID | Character |
|---:|---|
| 0 | Second Doctor |
| 1 | Fourth Doctor |
| 2 | Seventh Doctor |
| 3 | Ace |
| 4 | UNIT soldier |

Original selection split:

```text
Player 1: IDs 0,1,2
Player 2: IDs 3,4
```

The mod's current `CUSTOM2` mode exposes IDs/selections 0-5 to both players, with selection 5 representing external `CHAR6`.

## Raw animation banks

Each original playable bank is:

```text
45 frames
32x40
4 bitplanes
$7080 bytes raw
```

The original five are Pack-Ice resources on `Disk.1`. `CHAR6.bin` is supplied already raw.

## Source/resource pointer table

At runtime the game creates a larger **23-longword RESIDENT resource pointer table** beginning at:

```text
$E528
```

The first five entries happen to be the playable-character resources:

```text
$E528  character ID 0
$E52C  character ID 1
$E530  character ID 2
$E534  character ID 3
$E538  character ID 4
$E53C  next unrelated RESIDENT resource
```

This is **not** a standalone five-entry table and must not be enlarged in place.

The mod therefore uses a six-entry slave-owned `CharacterTable`.

## Runtime/decompressed pointer table

A second set of five contiguous longwords points to the already-decompressed character graphics in ChipRAM:

```text
$E588  CHAR1 -> $2E1D0
$E58C  CHAR2 -> $35250
$E590  CHAR3 -> $3C2D0
$E594  CHAR4 -> $43350
$E598  CHAR5 -> $4A3D0
```

This second selector was the reason the first expansion attempt displayed:

```text
1,2,3,3,3
```

for Player 1.

The source/resource selector was already reaching values 3 and 4, but the later runtime selector still had original logic:

```text
0 -> first pointer
1 -> second pointer
else -> third pointer
```

The mod therefore also maintains a six-entry slave-owned `RuntimeCharacterTable`.

## Selection bytes

Player selection state:

```text
$156(A5)  Player 1 selection
$157(A5)  Player 2 selection
```

## Original Player 1 selection logic

Source selector around runtime `$281E`:

```text
0 -> $E528
1 -> $E52C
else -> $E530
```

Common continuation:

```text
$2842
```

Manual cycle around `$EEC0`:

```asm
ADDQ.B  #1,$156(A5)
CMPI.B  #3,$156(A5)     ; immediate word at $EEC6
BNE     ...
SF.B    $156(A5)
```

Initial/random selection around `$EBDC` uses:

```asm
DIVU.W  #3,D0           ; immediate word at $EBDE
```

Both counts are patched to 6 in extra-character mode.

## Original Player 2 selection logic

Source selector around runtime `$2862`:

```text
0 -> $E534
nonzero -> $E538
```

Common continuation:

```text
$2876
```

Manual cycle at `$EF98` is originally:

```asm
BCHG #0,$157(A5)
```

This only toggles 0/1, so the mod replaces it with an increment-and-wrap routine.

## Runtime graphics selectors

Original hard-coded selectors:

```text
Player 1: $F0B2
Player 2: $F0FA
```

Patched continuations:

```text
Player 1 -> $F0D0
Player 2 -> $F10A
```

Both now index `RuntimeCharacterTable`.

## Portrait selection

The five original portraits are one contiguous block beginning:

```text
$1797A
```

Original Player 1:

```text
base $1797A
index $156(A5)
```

Original Player 2:

```text
base $17F7A
index $157(A5)
```

The mod creates a new contiguous six-entry portrait block and patches both base operands:

```text
$251A  Player 1 portrait LEA operand
$2534  Player 2 portrait LEA operand
```

## Global character ID

The selector value is not only a graphics index; the game also stores a global character ID in the player structure.

### Player 1

Original code around `$1FB8` effectively stores:

```asm
MOVE.B $156(A5),$2B(A0)
```

### Player 2

Original code around `$1FF2` effectively forms:

```text
global ID = 3 + $157(A5)
```

because Player 2 originally owns only IDs 3 and 4.

When both players were expanded to the common ID range, this had to be corrected.

### New selection 5

The original game only has known non-graphics IDs 0-4.

Allowing literal ID 5 to flow into old five-entry metadata tables is unsafe, so current source uses:

```asm
CHAR6_BEHAVIOUR_ID EQU 0
```

Selection 5 still uses CHAR6 graphics and portrait, but old non-graphics character-ID paths are aliased to a valid original ID.

This is a safety measure, not proof that every character-specific behaviour has been fully identified.

## Copy/depack behaviour

The game copies the selected source to a working buffer and processes exactly:

```text
$7080 bytes
```

The Ice depacker at `$D74C` checks the source signature, which means an external raw `$7080` bank can pass through without needing to be repacked as Ice.
