# Status and scope

## Goal

The current work extends the Amiga WHDLoad installation of **Dalek Attack** so additional playable characters can be supplied as external raw graphics while preserving the original game.

The immediate target is:

1. expose all five original characters to both Player 1 and Player 2;
2. add a sixth externally supplied character;
3. add the sixth selection portrait;
4. add any separate character-specific graphics used outside the main animation bank;
5. keep the entire character expansion optional using WHDLoad `CUSTOM2`.

## Confirmed results

### Playable character expansion

Confirmed in-game:

- Player 1 can use characters which were not originally available to Player 1.
- The five-original-character test exposed all five choices correctly.
- Player 1 was explicitly tested successfully using original `CHAR4`.
- The later six-character version loads and uses external `CHAR6.bin`.
- `CHAR6_portrait.bin` is loaded and displayed.

The reason the first five-character attempt produced:

```text
CHAR1, CHAR2, CHAR3, CHAR3, CHAR3
```

was identified and corrected. The game has **two separate graphics selections**:

- source/resource character pointers;
- already-decompressed runtime ChipRAM character pointers.

Both must be patched.

### Character extraction/editing

Confirmed byte-for-byte round trips:

- playable-character raw bank -> PNG -> raw;
- playable-character raw bank -> ILBM -> raw;
- portrait raw -> PNG -> raw;
- portrait raw -> ILBM -> raw;
- Level 1 Hoverbout raw frame -> PNG/ILBM -> raw.

The editor accepts larger DPaint canvases such as `320x256` and crops the required image from the **top-left**.

### Level 1 Hoverbout

Confirmed from `SPRITES1` data:

- the rider-on-Hoverbout artwork is separate from the normal `CHARx.bin` animation bank;
- it is `SPRITES1` descriptor `$15` / decimal 21;
- it is `32x56`, 6 frames, `$0380` bytes per frame;
- frames 0-4 are the five original riders;
- frame 5 is the empty Hoverbout.

This explains why a new sixth character can otherwise work while appearing without a rider on the Level 1 Hoverbout.

The latest Hoverbout insertion patch has been moved to the point immediately before the game's descriptor/mask builder. This latest revision is **implemented, awaiting in-game confirmation**.

## Optional patching

The current design uses:

```text
CUSTOM1 = Player 1 Infinite Lives
CUSTOM2 = Extra Characters
```

When `CUSTOM2` is off, the character expansion patch list is not applied and custom character files are not loaded.

When `CUSTOM2` is on:

```asm
_character_patch PL_START
        ; character modifications
        ...
        PL_NEXT _gamepatch

_gamepatch PL_START
        ; normal WHDLoad fixes
        ...
        PL_END
```

This keeps the original WHDLoad fixes independent of the optional character extension.

## Deliberately deferred

### Prevent both players selecting the same character

This has **not** yet been implemented.

The intended approach is to make each player's cycle routine skip the value currently selected by the other player, plus handle initial/default/random selection so a collision cannot occur.

This should remain a separate change until the six-character graphics paths are fully stable.

## Important compatibility point

The current test implementation reserves extra ChipRAM for the sixth character and portrait/Hoverbout assets.

The slave currently requests:

```asm
CHIPMEMSIZE EQU $110000
```

Although only slightly more than 1 MB is used, a real Amiga configuration will normally require **2 MB ChipRAM** to satisfy this.

The memory reservation is part of the static slave header, so it exists even when `CUSTOM2` is disabled. A later cache-based implementation could restore a strict 1 MB requirement if desired.
