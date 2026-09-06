DALEK ATTACK CHARACTER TOOL - QUICK GUIDE
=========================================

PURPOSE
-------
The tool works on ONE playable character at a time.

A character animation bank is:
  45 frames
  32 x 40 pixels per frame
  4 bitplanes / 16 colours
  28,800 bytes total ($7080)

The editable sprite sheet is:
  9 columns x 5 rows
  288 x 200 pixels
  frame order 0..44, left-to-right then top-to-bottom.

Palette index 0 is the game's transparent/background index.
For editing, the tool deliberately displays index 0 as:
  Amiga $F0F
  RGB #FF00FF
so the transparent area is obvious.

The raw reconstructed bank still contains palette INDEX 0.
No magenta colour is inserted into the game graphics.

REQUIREMENTS
------------
Python 3 and Pillow.

Install Pillow once:
  python3 -m pip install pillow

WHERE THE TOOL EXPECTS FILES
----------------------------
NOWHERE FIXED.

Every input/output path is supplied on the command line.
You can put the tool wherever you want.

For your current GitHub repository I suggest:

  Dalek-Attack-WHD/
    data/
      Disk.1
      Disk.2
    src/
      DalekAttack.asm
    tests/
      characters/
        CHAR1.bin
        CHAR2.bin
        CHAR3.bin
        CHAR4.bin
        CHAR5.bin
    tools/
      dalek_character_tool.py
    work/
      CHAR1/
      CHAR6/
      ...

Your repository already contains tests/characters/CHAR1.bin ... CHAR5.bin,
so those are convenient known-good sources.

RUN COMMANDS FROM THE REPOSITORY ROOT
-------------------------------------

1. Export ONE existing character as one editable PNG + ILBM sheet:

  python3 tools/dalek_character_tool.py export tests/characters/CHAR1.bin work/CHAR1/character

This creates:
  work/CHAR1/character.png
  work/CHAR1/character.iff

To create PNG only:

  python3 tools/dalek_character_tool.py export tests/characters/CHAR1.bin work/CHAR1/character --format png

2. Edit work/CHAR1/character.png in your graphics editor.

IMPORTANT:
  Keep the image at exactly 288 x 200.
  Keep it indexed / 16 colours if possible.
  Do not reorder the palette.
  Palette entry 0 must remain magenta #FF00FF.
  Each frame remains exactly 32 x 40.
  Do not move frames between the 9 x 5 cells unless you intend to change
  which animation frame they represent.

3. Convert the edited sheet back to game data:

  python3 tools/dalek_character_tool.py import work/CHAR1/character.png work/CHAR1/CHAR1_NEW.bin

Output:
  work/CHAR1/CHAR1_NEW.bin

It must be exactly 28,800 bytes ($7080).

4. ILBM works in the same way:

  python3 tools/dalek_character_tool.py import work/CHAR1/character.iff work/CHAR1/CHAR1_NEW.bin

5. Prove the tool round-trips an original character byte-for-byte:

  python3 tools/dalek_character_tool.py verify tests/characters/CHAR1.bin work/verify_CHAR1

Expected output contains:
  png OK
  ilbm OK

SELECTION PORTRAIT
------------------
The separate menu portrait is 32 x 32, 4 planes, 512 bytes ($0200).

Export:
  python3 tools/dalek_character_tool.py portrait-export tests/portraits/CHAR1_portrait.bin work/CHAR1/portrait

Import:
  python3 tools/dalek_character_tool.py portrait-import work/CHAR1/portrait.png work/CHAR1/CHAR1_portrait_NEW.bin

If the portrait binaries are stored somewhere else, just change the path.
The tool does not require a particular directory name.

COMPLETE CHARACTER SET
----------------------
If both bank and portrait are available:

  python3 tools/dalek_character_tool.py set-export \
      tests/characters/CHAR1.bin \
      tests/portraits/CHAR1_portrait.bin \
      work/CHAR1

This produces:
  work/CHAR1/character.png
  work/CHAR1/character.iff
  work/CHAR1/portrait.png
  work/CHAR1/portrait.iff

Rebuild both:

  python3 tools/dalek_character_tool.py set-import \
      work/CHAR1 \
      work/CHAR1/CHAR1_NEW.bin \
      work/CHAR1/CHAR1_portrait_NEW.bin

FOR A BRAND-NEW CHARACTER
-------------------------
The easiest workflow is:

  1. Export an existing character as a template.
  2. Copy the whole work/CHAR1 folder to work/CHAR6.
  3. Edit character.png and portrait.png.
  4. Import them to:
       CHAR6.bin              ($7080)
       CHAR6_portrait.bin     ($0200)
  5. WHDLoad can load those raw files directly; they do not need Ice packing.

WHY THE MAGENTA BACKGROUND IS SAFE
----------------------------------
The PNG/ILBM editing palette displays index 0 as #FF00FF.

The game graphics are not RGB data. They store 4-bit palette INDEX values.
When imported, every magenta index-0 pixel becomes binary palette index 0
again. The game therefore sees exactly the expected transparent/background
index.

The magenta is an editing aid only.
