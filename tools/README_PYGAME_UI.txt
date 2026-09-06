DALEK ATTACK CHARACTER TOOL - PURE PYGAME UI
=============================================

Dependencies
------------
Python 3, Pillow and Pygame only.

Install:
  python3 -m pip install pillow pygame

There is NO Tkinter dependency in this version.

Run
---
From the repository root, if the script is in tools/:

  python3 tools/dalek_character_tool.py

or explicitly:

  python3 tools/dalek_character_tool.py ui

File selection
--------------
All file/folder selection is handled inside the Pygame window.

The built-in browser supports:
- navigating folders
- double-clicking folders to open them
- selecting input files
- choosing an output/work folder
- typing filenames when saving rebuilt .bin files

You can also drag and drop files onto the main Pygame window:
- 28,800-byte .bin -> raw character bank
- 512-byte .bin -> raw portrait
- 288x200 PNG / corresponding ILBM -> edited character sheet
- 32x32 PNG / corresponding ILBM -> edited portrait
- dropped folder -> work/output folder

Character format
----------------
45 frames
32 x 40 pixels per frame
9 x 5 editable sheet = 288 x 200 pixels
4 bitplanes / 16 indexed colours
28,800 raw bytes = $7080

Portrait format
---------------
1 frame
32 x 32 pixels
4 bitplanes / 16 indexed colours
512 raw bytes = $0200

Palette index 0
---------------
Index 0 is displayed in editable PNG/ILBM files as:
  Amiga $F0F
  RGB #FF00FF

It remains palette INDEX 0 when converted back to game data.
Do not reorder the 16-colour palette.

CLI
---
All previous command-line functions remain available, for example:

  python3 tools/dalek_character_tool.py export tests/characters/CHAR1.bin work/CHAR1/character

  python3 tools/dalek_character_tool.py import work/CHAR1/character.png work/CHAR1/CHAR1_NEW.bin

  python3 tools/dalek_character_tool.py verify tests/characters/CHAR1.bin work/verify_CHAR1

The UI and CLI both call the same conversion routines.
