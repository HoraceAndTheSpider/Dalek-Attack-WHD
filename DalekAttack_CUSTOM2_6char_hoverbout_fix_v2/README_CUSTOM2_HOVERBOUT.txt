Dalek Attack - CUSTOM2 6-character Hoverbout fix v2
===================================================

This revision keeps the working six-character / CUSTOM2 implementation and
changes only the Level 1 CHAR6 Hoverbout insertion point.

Finding confirmed
-----------------
SPRITES1 uses the Level 1 descriptor list beginning:

    0C, 0F, 06, 0B, 03, 0A, 02, 04, 11, 13, 15, ...

Descriptor $15 (decimal 21) is:

    32 x 56
    6 frames
    $0380 bytes per frame

The raw data sizes of the preceding descriptors sum to $A500, so descriptor
$15 begins at $A500. Its sixth frame is therefore:

    $A500 + (5 * $0380) = $B680

The first five frames contain CHAR1-CHAR5 on the Hoverbout.
The sixth original frame is the empty Hoverbout.

Why the patch point changed
---------------------------
The previous revision wrapped the Ice depacker at runtime $272C.

The corrected revision instead patches runtime $26B2. The original bytes are:

    $26B2  BSR.W $5562
    $26B6  RTS

$5562 is the routine that consumes the freshly-decompressed SPRITES bank,
sets the live descriptor graphics pointers and generates the sprite masks.

At $26B2:

    - SPRITES1 is already decompressed;
    - $55F8 still points at the raw bank start;
    - descriptor/mask processing has not happened yet.

The optional patch therefore uses:

    PL_P $26b2,BuildLevelSprites

PL_P replaces the original BSR.W + RTS (6 bytes) with JMP. The wrapper:

    1. checks $8A(A5) == 0 (Level 1 / SPRITES1);
    2. copies chars/CHAR6_hoverbout.bin to [$55F8] + $B680;
    3. calls resload_FlushCache;
    4. JMPs to the original $5562 builder.

Because the wrapper was entered by JMP, the RTS at the end of $5562 returns
directly to the original caller, matching the original BSR.W + RTS sequence.

Required asset
--------------
    data/chars/CHAR6_hoverbout.bin

Exact size:
    $0380 / 896 bytes
    32 x 56
    4 bitplanes
    gameplay/playfield palette

CUSTOM2
-------
Unchanged:

CUSTOM2 off:
    normal _gamepatch only

CUSTOM2 on:
    LoadCharacter6Assets
    _character_patch
    PL_NEXT _gamepatch

Same-character selection is still intentionally left for the next stage.
