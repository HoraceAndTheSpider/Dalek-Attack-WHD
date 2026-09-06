Dalek Attack Character Tool v5 - DPaint oversized-canvas import
================================================================

Changes in this build
---------------------
1. Character sheets no longer have to be exactly 288x200 on import.
   Any PNG or 4-plane ILBM that is AT LEAST 288x200 is accepted.
   The tool crops the top-left (0,0) 288x200 area before rebuilding the game bank.

   This is intended for Deluxe Paint screen sizes such as 320x256.

2. Portraits can likewise be imported from a larger PNG/ILBM canvas.
   The top-left 32x32 area is used.

3. Import failures are shown prominently at the top of the Pygame window
   as well as in the normal Status box. Rejected imports therefore should
   no longer appear to do nothing.

4. Successful oversized imports explicitly report the crop, e.g.:
      Loaded edited sheet: CHAR6.iff - ILBM 320x256 cropped top-left (0,0) -> 288x200

DPaint workflow
---------------
For a character:
  - Start from the exported 288x200 ILBM.
  - If DPaint saves it as 320x256, leave the sprite sheet at the top-left of
    the DPaint canvas.
  - Choose Edited Sheet and select the resulting .iff.
  - The tool uses pixels x=0..287, y=0..199 only.
  - Build Character .bin produces the required 28,800-byte / $7080 bank.

For a portrait:
  - The required game area is 32x32.
  - A larger DPaint canvas is accepted, using pixels x=0..31, y=0..31.
  - Build Portrait .bin produces the required 512-byte / $0200 file.

Required formats remain
-----------------------
Character raw:
  45 frames
  32x40 each
  9x5 sheet = 288x200 used area
  4 planes / 16 indexed colours
  $7080 = 28,800 bytes

Portrait raw:
  1 frame
  32x32 used area
  4 planes / 16 indexed colours
  $0200 = 512 bytes

Palette index 0 remains the transparent/background index and is shown as
$F0F / #FF00FF for editing.

Tests performed
---------------
- exact 288x200 PNG -> raw: byte-identical
- exact 288x200 ILBM -> raw: byte-identical
- 320x256 PNG with original sheet at top-left -> raw: byte-identical
- 320x256 ILBM with original sheet at top-left -> raw: byte-identical
- 320x256 portrait PNG -> $0200 raw: byte-identical
- 320x256 portrait ILBM -> $0200 raw: byte-identical
