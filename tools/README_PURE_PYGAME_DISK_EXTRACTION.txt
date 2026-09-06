DALEK ATTACK CHARACTER TOOL - PURE PYGAME + DISK EXTRACTION
============================================================

Requirements
------------
Python 3, Pillow and Pygame:

  python3 -m pip install pillow pygame

No Tkinter is used.

Start the UI
------------
From the repository root, with the script in tools/:

  python3 tools/dalek_character_tool.py

or:

  python3 tools/dalek_character_tool.py ui

Extract the original five characters directly from Disk.1
----------------------------------------------------------
1. Click "Choose Disk.1".
2. Select data/Disk.1.
3. Click "Extract 5 originals".
4. Choose the parent output folder.

The tool creates a folder named:

  dalek_original_characters/

containing, for each CHAR1..CHAR5:

  CHARn.bin              raw animation bank ($7080 / 28,800 bytes)
  CHARn.png              editable 288x200 indexed sprite sheet
  CHARn.iff              editable 288x200 ILBM sprite sheet
  CHARn_portrait.bin     raw menu portrait ($0200 / 512 bytes)
  CHARn_portrait.png     editable 32x32 indexed portrait
  CHARn_portrait.iff     editable 32x32 ILBM portrait

CHAR1 is loaded automatically into the preview after extraction.

The extraction is from Disk.1 itself:
- the five confirmed Pack-Ice character resources are depacked by the tool;
- the five raw $0200 portraits are extracted from their confirmed contiguous
  block in the main game image.

CLI equivalent
--------------

  python3 tools/dalek_character_tool.py disk-extract \
      data/Disk.1 \
      work/originals

Raw binaries only:

  python3 tools/dalek_character_tool.py disk-extract \
      data/Disk.1 \
      work/originals \
      --raw-only

Character format
----------------
45 frames, 32x40 each, 9x5 sheet = 288x200.
4 bitplanes / 16 indexed colours.
Raw bank size: $7080 / 28,800 bytes.

Portrait format
---------------
1 frame, 32x32.
4 bitplanes / 16 indexed colours.
Raw size: $0200 / 512 bytes.

Palette index 0
---------------
Index 0 is shown in PNG/ILBM as Amiga $F0F / RGB #FF00FF magenta for editing.
It remains binary palette index 0 when rebuilt for the game.
Do not reorder the indexed palette.
