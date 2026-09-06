# Dalek Attack WHDLoad reverse-engineering notes

This directory records the reverse engineering carried out for the Amiga version of **Dalek Attack** and the current WHDLoad character-expansion work.

The purpose of these notes is to preserve exact offsets, formats, patch points and current status so work can move between threads or contributors without having to rediscover the same information.

## Documentation index

| Page | Contents |
|---|---|
| [01-status-and-scope.md](01-status-and-scope.md) | Current project state, confirmed results, outstanding work |
| [02-disk-and-resource-map.md](02-disk-and-resource-map.md) | Disk offsets, resource locations, runtime mapping and sizes |
| [03-pack-ice-decompression.md](03-pack-ice-decompression.md) | `Ice!` container and the backwards Pack-Ice decompressor |
| [04-graphics-formats-and-palettes.md](04-graphics-formats-and-palettes.md) | Bitplane layouts, palettes, editable PNG/ILBM conventions |
| [05-playable-characters.md](05-playable-characters.md) | Character banks, portraits, IDs, selectors and pointer tables |
| [06-level-sprites-and-hoverbout.md](06-level-sprites-and-hoverbout.md) | Level sprite descriptors and the separate Level 1 Hoverbout artwork |
| [07-whdload-extra-characters.md](07-whdload-extra-characters.md) | Current `CUSTOM2` architecture and six-character patch |
| [08-runtime-address-map.md](08-runtime-address-map.md) | Quick reference for important runtime addresses and patch sites |
| [09-character-tool-workflow.md](09-character-tool-workflow.md) | Python/Pygame extraction, editing and round-trip workflow |
| [10-open-questions-and-next-work.md](10-open-questions-and-next-work.md) | Unresolved items and sensible next investigations |

## Confidence convention

These pages use the following wording deliberately:

- **Confirmed** — established from the game data/code and/or tested in-game.
- **Implemented, awaiting test** — source has been prepared but the latest change has not yet been confirmed in-game.
- **Inferred** — strongly indicated by code/data but not yet fully proven.
- **Unknown** — field or behaviour has not yet been identified.

## Current repository layout assumed by the mod

```text
Dalek-Attack-WHD/
    data/
        Disk.1
        Disk.2
        chars/
            CHAR6.bin
            CHAR6_portrait.bin
            CHAR6_hoverbout.bin

    src/
        DalekAttack.asm

    tools/
        dalek_character_tool.py

    docs/
        ...
```

WHDLoad file names are relative to the existing `data/` current directory. Therefore the source uses `chars/CHAR6.bin`, **not** `data/chars/CHAR6.bin`.

## Snapshot date

These notes describe the state reached on **6 September 2026**.
