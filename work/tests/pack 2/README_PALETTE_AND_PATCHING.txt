Dalek Attack (Amiga) – palette recovery and character-expansion notes
=====================================================================
Sources: Disk.1 and Disk.2 supplied by the user.
Main game binary mapping used below: Disk.1 file offset $17800 -> runtime $000000.
Therefore, for code/data physically in that main image, Disk.1 offset = runtime + $17800.

1. GAMEPLAY PALETTES – NOW POSITIVELY IDENTIFIED
-------------------------------------------------
Main gameplay / upper playfield palette:
  runtime table $11E74 (Disk.1 $29674)
  The routine at runtime $3820 copies 15 words to copper COLOR01..COLOR15.
  COLOR00 is black in the copper list and is not included in this 15-word copy.

  index : Amiga 12-bit RGB
    0 : $000
    1 : $039
    2 : $666
    3 : $888
    4 : $642
    5 : $864
    6 : $A86
    7 : $264
    8 : $CA4
    9 : $26C
   10 : $112
   11 : $488
   12 : $444
   13 : $A22
   14 : $000
   15 : $EEE

Lower/HUD palette:
  runtime table $11E92 (Disk.1 $29692)
  The routine at runtime $383A copies all 16 words into the lower-screen copper palette.

  [$000,$029,$666,$999,$642,$964,$B96,$264,
   $FD4,$BBB,$224,$499,$444,$D22,$000,$DDF]

Other palettes found, but NOT used for the gameplay character/tile renders:
  title/intro runtime $F6BE:
    [$000,$DDD,$CCF,$8AC,$68C,$46A,$14A,$048,
     $FCC,$FAA,$CAA,$A88,$A66,$866,$644,$422]
  menu/special-screen candidate runtime $10EC2:
    [$000,$4D1,$DFF,$06B,$0CB,$2A1,$261,$08D,
     $204,$206,$229,$42B,$B92,$500,$940,$000]

The corrected character, BLOCK and level-SPRITES previews in this pack use the main
playfield palette. Amiga 12-bit colours are expanded to 8-bit RGB by multiplying each
nibble by 17.

2. PLAYABLE CHARACTER FORMAT
----------------------------
Animation bank:
  45 frames
  32 x 40 pixels
  4 bitplanes
  640 bytes/frame ($280)
  28,800 bytes/bank ($7080)

For every scanline:
  plane 0 bytes, plane 1 bytes, plane 2 bytes, plane 3 bytes
For width 32 this is 4 bytes/plane = 16 bytes/scanline.

This exact raw format is accepted by the game. Runtime routine $F31A copies exactly $7080
bytes from the selected source to working buffer $55F8. Runtime $D74C then tests the copied
buffer for the longword 'Ice!'. Its BNE at $D756 goes directly to restore/RTS at $D7D0.
Therefore an externally supplied RAW $7080 bank does not need Pack-Ice compression.

3. SELECTION PORTRAITS – SECOND CHARACTER-SPECIFIC ASSET FOUND
---------------------------------------------------------------
There is also one 32 x 32, 4-plane portrait per selectable character, exactly $200 bytes.
These are the pictures used by the player-selection UI.

P1 portrait table:
  choice 0: runtime $1797A
  choice 1: runtime $17B7A
  choice 2: runtime $17D7A

P2 portrait table:
  choice 0: runtime $17F7A
  choice 1: runtime $1817A

The selection/drawing code at runtime $2518 / $2532 calculates:
  portrait_address = table_base + selector * $200

So merely increasing the selector limit without patching this path would make new selector
values read beyond the five original portraits. New characters therefore need either:
  (a) their own 32x32/$200 portrait, or
  (b) an explicit mapping to an existing portrait as a first proof-of-concept.

The supplied dalek_character_tool.py now round-trips BOTH the $7080 animation bank and
$0200 portrait through indexed PNG and ILBM.

4. VERIFIED ROUND-TRIP EDITING
------------------------------
For all five original character sets:
  binary -> indexed PNG -> binary    : byte-for-byte identical
  binary -> 4-plane ILBM -> binary   : byte-for-byte identical
  portrait PNG/ILBM round trip       : byte-for-byte identical

The ILBM BODY byte order is identical to the game byte order for these 32-pixel-wide assets,
so ILBM is especially useful for an Amiga-native editing workflow.

Recommended editable unit for a new character:
  animation bank : $7080 bytes
  portrait       : $0200 bytes
  total payload  : $7280 bytes (29,312 decimal)

Keep them as separate files in the first WHDLoad implementation; that matches the game's
separate use of animation graphics and portrait data and makes validation easier.

5. SELECTOR LIMITS / PATCH POINTS
---------------------------------
P1 selector byte: $156(A5)
P2 selector byte: $157(A5)

P1 cycling code:
  $EEC0  ADDQ.B #1,$156(A5)
  $EEC4  CMPI.B #3,$156(A5)       ; 6-byte instruction
  $EECA  BNE.B  ...
  $EECC  SF.B   $156(A5)          ; wraps to 0 when selector == 3

Simplest fixed-count patch:
  change immediate word at runtime $EEC6 from 3 to P1_COUNT.
For example P1_COUNT=4 gives choices 0..3.

If the limit is to live in slave code instead, $EEC4 is an ideal six-byte PL_PS/JSR hook.
The replacement routine can end with the equivalent CMPI.B instruction and RTS; RTS does not
alter the comparison flags, so the original BNE/SF wrap code continues unchanged.

P2 cycling code:
  $EF98  BCHG #0,$157(A5)         ; 6 bytes, hard-coded 0 <-> 1 toggle

This is an ideal six-byte PL_PS/JSR hook. Replacement logic can be:
  ADDQ.B #1,$157(A5)
  CMPI.B #P2_COUNT,$157(A5)
  BNE.B  .ok
  CLR.B  $157(A5)
.ok
  RTS

P1 initial selector is also generated as modulo 3:
  $EBDC  DIVU.W #3,D0
  $EBE0  SWAP D0
  $EBE2  MOVE.B D0,$156(A5)
Changing the immediate at $EBDE can include extra characters in the initial/random choice.
It is optional: leaving it at 3 simply means the menu initially starts on an original P1.

6. GAMEPLAY BANK-SELECTION HOOKS
--------------------------------
Original P1 source selection:
  $281E TST.B $156(A5)
  selector 0 -> longword pointer stored at $E528
  selector 1 -> longword pointer stored at $E52C
  selector 2/other -> longword pointer stored at $E530
  common copy/depack path begins at $2842

Original P2 source selection:
  $2862 TST.B $157(A5)
  selector 0 -> longword pointer stored at $E534
  selector 1/other -> longword pointer stored at $E538
  common path begins at $2876

The first six bytes at $281E and $2862 are each exactly TST.B + BEQ.B. They are clean PL_P
(JMP) hook sites. A slave routine can select A0 itself and then jump back to the existing common
path ($2842 for P1, $2876 for P2).

For original selectors, preserve the existing pointer-slot lookup because those slots point at
the game's own character resources. For additional selectors, return A0 pointing at a raw
$7080 custom bank loaded by WHDLoad. The existing $F31A copy then moves it to ChipRAM $55F8;
$D74C sees that it is not Ice-compressed and returns without changing it.

7. MENU FULL-SPRITE PREVIEW HOOKS
---------------------------------
The player-selection screen has another direct character-bank lookup:

P1 preview selection starts at $F0B2; common renderer starts at $F0D0.
Original direct raw-bank pointer variables used by that code are:
  selector 0 -> pointer at $E58C
  selector 1 -> pointer at $E588
  selector 2 -> pointer at $E590

P2 preview selection starts at $F0FA; common renderer starts at $F10A.
  selector 0 -> pointer at $E594
  selector 1 -> pointer at $E598

Those pointer variables are initialised around $ECC0. Their raw banks live in ChipRAM:
  $E588 = $2E1D0
  $E58C = $35250
  $E590 = $3C2D0
  $E594 = $43350
  $E598 = $4A3D0
Each is separated by $7080.

This matters for WHDLoad expansion memory: menu rendering can feed these banks to Amiga DMA/
blitter code, so a custom bank held only in normal Fast/ExpMem should NOT simply be returned to
the original renderer.

Recommended compatibility design:
  - use ExpMem only as storage for external custom files;
  - copy the currently selected custom P1 bank into the existing P1 raw preview slot at $3C2D0
    (the slot normally used by P1 selector 2) before rendering it;
  - copy the currently selected custom P2 bank into $4A3D0 (P2 selector 1 slot);
  - back up those two original raw banks to ExpMem before first overwrite and restore them when
    selectors 2 / 1 are selected again;
  - then the existing renderer always receives a ChipRAM pointer.

This deliberately keeps the v1.2 WHDLoad fix intact: the official install history says graphics
sprite bugs were fixed by using ChipRAM instead of expansion memory. Extra banks may live in
ExpMem as storage because the CPU copies them to ChipRAM before the game/blitter uses them.

8. PORTRAIT PATCH / CHIPRAM CACHE
---------------------------------
At $2518 the P1 code uses base $1797A + selector*$200.
At $2532 the P2 code uses base $17F7A + selector*$200.
The portrait data may be used as a blitter source, so the same FastRAM warning applies.

A low-ChipRAM-cost solution mirrors the preview cache design:
  P1 custom portrait scratch: reuse original portrait slot $17D7A (choice 2)
  P2 custom portrait scratch: reuse original portrait slot $1817A (choice 1)
Back up each original $200 block before first overwrite. For a custom selection, CPU-copy the
custom $200 portrait from ExpMem into the corresponding scratch slot and make A4 point there.
Restore the original when the scratch-owner selector is selected.

This means an arbitrary number of custom characters can share two existing $7080 preview slots
and two existing $0200 portrait slots; only the currently selected custom character for each
player needs to be present in ChipRAM.

9. SUGGESTED WHDLOAD MEMORY / FILE MODEL
-----------------------------------------
Current official v1.2 slave: 1 MiB ChipRAM, 0 ExpMem.
For the mod, request ExpMem purely for custom asset storage. Each custom character consumes:
  $7280 = 29,312 bytes
so 256 KiB holds 8 full extra sets with room for tables/backups; 512 KiB gives ample room.

At slave startup, use resload_LoadFile:
  A0 = relative filename
  A1 = destination in ExpMem
  JSR (resload_LoadFile,A2)
Validate D0 == expected file size ($7080 or $200) so a malformed edit cannot overrun later code.

Example file naming:
  data/P1_03.bin
  data/P1_03_portrait.bin
  data/P1_04.bin
  data/P1_04_portrait.bin
  data/P2_02.bin
  data/P2_02_portrait.bin

10. PATCH ORDER RECOMMENDED
---------------------------
Proof stage A:
  1. Patch P1 count 3 -> 4 and replace P2 toggle with a 3-way counter.
  2. Keep extra selectors mapped to an existing original graphics bank/portrait.
     This proves all other game logic tolerates selector values 3 / 2.

Proof stage B:
  3. Hook gameplay source selectors at $281E/$2862.
  4. Load one raw $7080 custom bank through WHDLoad and prove gameplay animations.

Proof stage C:
  5. Hook/copy custom selection-preview graphics to the existing ChipRAM cache slots.
  6. Hook/copy the custom $200 portrait to the portrait cache slots.

Only after these are proven should the loader be generalised to an arbitrary number of external
character files.

The reason for separating A/B/C is that a larger selector is used in more places than just the
$281E/$2862 bank lookup. In particular the $2518/$2532 portrait code is a confirmed dependent
path and must not be allowed to index beyond the original portrait tables.
