# Character extraction and editing tool

The current Python tool provides both CLI functions and a Pygame interface.

Dependencies:

```bash
python3 -m pip install pillow pygame
```

Tkinter is deliberately **not used**. Earlier use of Tk native file dialogs caused a macOS version/Tk framework error, so file browsing is now handled inside Pygame.

## Input disks

Character animations and portraits:

```text
data/Disk.1
```

Level 1 Hoverbout composites:

```text
data/Disk.2
```

Both expected disk sizes:

```text
901,120 bytes
```

## Extract original characters from Disk.1

CLI:

```bash
python3 tools/dalek_character_tool.py disk-extract \
    data/Disk.1 \
    work/originals
```

This produces, for CHAR1-CHAR5:

```text
CHARn.bin
CHARn.png
CHARn.iff
CHARn_portrait.bin
CHARn_portrait.png
CHARn_portrait.iff
```

Raw-only option:

```bash
python3 tools/dalek_character_tool.py disk-extract \
    data/Disk.1 \
    work/originals \
    --raw-only
```

## Extract Level 1 Hoverbout frames from Disk.2

```bash
python3 tools/dalek_character_tool.py hoverbout-extract \
    data/Disk.2 \
    work/hoverbouts
```

Outputs:

```text
CHAR1_hoverbout.*
...
CHAR5_hoverbout.*
CHAR6_hoverbout_template.*
```

The sixth template is the original empty Hoverbout frame.

## Character bank commands

Export raw:

```bash
python3 tools/dalek_character_tool.py export \
    CHAR6.bin \
    work/CHAR6 \
    --format both
```

Import edited PNG/ILBM:

```bash
python3 tools/dalek_character_tool.py import \
    work/CHAR6.iff \
    data/chars/CHAR6.bin
```

Verify:

```bash
python3 tools/dalek_character_tool.py verify \
    CHAR1.bin \
    work/verify_CHAR1
```

## Portrait commands

Export:

```bash
python3 tools/dalek_character_tool.py portrait-export \
    CHAR6_portrait.bin \
    work/CHAR6_portrait \
    --format both
```

Import:

```bash
python3 tools/dalek_character_tool.py portrait-import \
    work/CHAR6_portrait.iff \
    data/chars/CHAR6_portrait.bin
```

## Hoverbout commands

Export:

```bash
python3 tools/dalek_character_tool.py hoverbout-export \
    CHAR6_hoverbout.bin \
    work/CHAR6_hoverbout \
    --format both
```

Import:

```bash
python3 tools/dalek_character_tool.py hoverbout-import \
    work/CHAR6_hoverbout.iff \
    data/chars/CHAR6_hoverbout.bin
```

Verify:

```bash
python3 tools/dalek_character_tool.py hoverbout-verify \
    CHAR1_hoverbout.bin \
    work/verify_hoverbout
```

## Pygame UI behaviour

The UI supports:

- selecting `Disk.1`;
- extracting the five original characters/portraits;
- selecting `Disk.2`;
- extracting the original Hoverbout frames;
- loading raw `.bin` files;
- loading edited PNG/ILBM sheets;
- previewing character, portrait and Hoverbout data;
- building raw `.bin` output;
- verification;
- internal file browsing and drag/drop.

Selecting a new raw `.bin` clears the previous edited-preview source so the displayed preview updates to the newly selected bank.

Import failures are displayed explicitly rather than failing silently.

## DPaint workflow

Recommended character editing:

```text
1. Export CHARn.iff.
2. Load in DPaint.
3. If needed, use a 320x256 screen.
4. Keep the useful 288x200 sheet at top-left.
5. Save indexed ILBM.
6. Import with the tool.
7. Build CHAR6.bin.
```

Portrait useful area:

```text
32x32 at top-left
```

Hoverbout useful area:

```text
32x56 at top-left
```

## Exact raw sizes

| Asset | Exact size |
|---|---:|
| character animation bank | `$7080` / 28,800 |
| portrait | `$0200` / 512 |
| Hoverbout composite | `$0380` / 896 |

The tool rejects incorrectly sized raw files.

## Editing palettes

Character and Hoverbout:

```text
playfield palette
```

Portrait:

```text
menu/HUD palette
```

Index 0 is displayed as magenta `$F0F` only for editing.

## Round-trip requirement

For unchanged source art:

```text
raw -> PNG/ILBM -> raw
```

must reproduce the original bytes exactly.

This has been used as the primary regression test for the converter.
