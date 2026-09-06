# WHDLoad extra-character implementation

This page describes the current optional six-character patch architecture.

## WHDLoad options

Current configuration:

```asm
_config:
        dc.b "C1:X:Player 1 Infinite Lives:0;"
        dc.b "C2:X:Extra Characters:0;"
        dc.b 0
```

Tags:

```asm
_tags:
        dc.l WHDLTAG_CUSTOM1_GET
_custom1:
        dc.l 0
        dc.l WHDLTAG_CUSTOM2_GET
_custom2:
        dc.l 0
        dc.l TAG_DONE,0
```

`CUSTOM1` remains the existing trainer option.

`CUSTOM2` controls the entire character extension.

## Patch-list selection

Current `PatchGame` design:

```asm
NoTrainer:
        lea     _gamepatch(pc),a0
        lea     _custom2(pc),a1
        tst.l   (a1)
        beq.b   .ApplyPatches

        bsr     LoadCharacter6Assets
        lea     _character_patch(pc),a0

.ApplyPatches:
        suba.l  a1,a1
        move.l  _resload(pc),a2
        jsr     resload_Patch(a2)
```

Optional list:

```asm
_character_patch PL_START
        ; extra-character changes
        ...
        PL_NEXT _gamepatch
```

Normal list:

```asm
_gamepatch PL_START
        ; original WHDLoad fixes
        ...
        PL_END
```

Therefore:

### CUSTOM2 off

- no custom character files loaded;
- no expanded selectors;
- no portrait patch;
- no runtime character-table patch;
- no Hoverbout patch;
- normal WHDLoad fixes still applied.

### CUSTOM2 on

- validate/load custom assets;
- apply `_character_patch`;
- continue through `PL_NEXT _gamepatch`;
- both players have six selection values.

## Required external files

Because the slave's current directory is already `data/`, source filenames are:

```text
chars/CHAR6.bin
chars/CHAR6_portrait.bin
chars/CHAR6_hoverbout.bin
```

Installed locations:

```text
data/chars/CHAR6.bin
data/chars/CHAR6_portrait.bin
data/chars/CHAR6_hoverbout.bin
```

Exact sizes are checked before loading:

| File | Size |
|---|---:|
| `CHAR6.bin` | `$7080` / 28,800 |
| `CHAR6_portrait.bin` | `$0200` / 512 |
| `CHAR6_hoverbout.bin` | `$0380` / 896 |

A missing/wrong-size file aborts with `TDREASON_FAILMSG`.

## Extra ChipRAM layout

Current source:

```asm
CHIPMEMSIZE EQU $110000
```

Layout used:

| Address range | Use |
|---|---|
| `$100000-$10707F` | CHAR6 animation bank |
| `$107080-$107A7F` | copied original portraits 1-5 |
| `$107A80-$107C7F` | CHAR6 portrait |
| `$107C80-$107FFF` | CHAR6 Level 1 Hoverbout frame |
| `$108000-$10FFFF` | currently spare |

Constants:

```asm
CHAR6_CHIP          EQU $100000
PORTRAIT_BASE_ALL   EQU $107080
PORTRAIT6_CHIP      EQU $107A80
HOVERBOUT6_CHIP     EQU $107C80
```

## Slave-owned tables

Two six-entry tables are maintained in slave storage:

```asm
CharacterTable         ds.l 6
RuntimeCharacterTable  ds.l 6
```

Entries 0-4 are refreshed from the game's live tables.

Entry 5 points at:

```text
$100000
```

for the external raw CHAR6 bank.

## Selector patches

Current optional character patch sites:

| Address | Patch | Purpose |
|---|---|---|
| `$281E` | `PL_P SelectP1Character` | P1 source/resource selection |
| `$2862` | `PL_P SelectP2Character` | P2 source/resource selection |
| `$EBDE` | `PL_W 6` | P1 initial/random divisor |
| `$EEC6` | `PL_W 6` | P1 manual wrap |
| `$EF98` | `PL_PS CycleP2Character` | replace P2 0/1 toggle |
| `$251A` | `PL_L PORTRAIT_BASE_ALL` | P1 portrait base |
| `$2534` | `PL_L PORTRAIT_BASE_ALL` | P2 portrait base |
| `$F0B2` | `PL_P SelectP1RuntimeGraphics` | P1 decompressed graphics |
| `$F0FA` | `PL_P SelectP2RuntimeGraphics` | P2 decompressed graphics |
| `$1FB8` | `PL_PS SetP1CharacterID` | safe global ID |
| `$1FF2` | `PL_PS SetP2CharacterIDBase` | safe global ID |
| `$26B2` | `PL_P BuildLevelSprites` | Level 1 CHAR6 Hoverbout insertion |

## Portrait relocation

Original portraits are copied:

```text
source  $1797A
length  $0A00
dest    $107080
```

Then the external sixth portrait is loaded:

```text
$107A80-$107C7F
```

This creates one six-entry block usable by both original portrait-selection routines.

## Character-ID safety

Graphics selection 5 is new, but known original global character IDs are only 0-4.

Current source:

```asm
CHAR6_BEHAVIOUR_ID EQU 0
```

The new graphics remain CHAR6; only old non-graphics ID logic is mapped to a valid original ID.

This should remain explicit until all global-ID consumers have been audited.

## Memory caveat

`ws_BaseMemSize` is static.

Therefore the extra ChipRAM request remains present even with `CUSTOM2=0`, although the custom asset loads and patches are skipped.

A future memory-optimised implementation could cache only the selected custom graphics into existing working buffers instead of permanently reserving a complete additional raw bank.
