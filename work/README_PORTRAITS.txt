Dalek Attack portrait sheets/raw overview

Each playable character has a separate menu portrait.

Raw format per portrait:
- 32 x 32 pixels
- 4 bitplanes
- 16 indexed colours
- 1 frame only
- 128 bytes per bitplane
- 512 bytes total ($0200)

Storage layout:
- scanline by scanline
- for each scanline: plane 0 bytes, plane 1 bytes, plane 2 bytes, plane 3 bytes
- width 32 pixels = 4 bytes per plane per row
- 4 planes x 4 bytes x 32 rows = 512 bytes total

Editing/display notes:
- palette index 0 is the transparent/background index used by the game
- in the supplied PNG/ILBM editing versions, index 0 is shown as magenta (#FF00FF / Amiga $F0F) so it is visible
- when re-imported, those pixels remain palette index 0 in the raw binary
- keep the palette indexed and do not reorder it

Files supplied here:
- CHARn_portrait.png  = editable indexed PNG preview/sheet
- CHARn_portrait.iff  = ILBM equivalent
- CHARn_portrait.bin  = original raw 512-byte binary
