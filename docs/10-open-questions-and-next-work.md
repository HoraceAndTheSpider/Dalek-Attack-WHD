# Open questions and next work

This page records items which should not be lost when development moves to a new thread.

## 1. Confirm latest CHAR6 Hoverbout patch

**Status: implemented, awaiting in-game test.**

The current revision inserts `CHAR6_hoverbout.bin` immediately before the `$5562` level-sprite descriptor/mask builder by replacing the original `$26B2` `BSR.W $5562 / RTS` sequence.

Test:

1. enable `CUSTOM2`;
2. select CHAR6;
3. reach the Level 1 Hoverbout;
4. confirm CHAR6 rider artwork appears;
5. confirm original CHAR1-5 Hoverbout frames remain unchanged;
6. confirm later levels still initialise normally.

If it still fails, inspect:

- actual live value of `$55F8` at `$26B2`;
- whether `$8A(A5)` is zero at this exact call;
- whether another copy/rebuild overwrites descriptor 21 after `$5562`;
- descriptor 21's final live graphics/mask pointers.

The raw descriptor offset `$B680` is strongly confirmed independently from the bank layout.

## 2. Prevent duplicate character selection

**Status: deliberately not implemented yet.**

Desired behaviour:

```text
Player 1 and Player 2 must never select the same character.
```

Potential implementation:

- in P1 cycle: increment/wrap, then if equal to `$157(A5)`, increment/wrap again;
- in P2 cycle: increment/wrap, then if equal to `$156(A5)`, increment/wrap again;
- ensure initial/default/random values are also collision-safe.

Need decide how initial P1 random selection and P2 starting value should interact.

Keep this change independent from graphics loading so failures are easier to isolate.

## 3. Audit remaining character-dependent branches

Known ancillary code still has original 0/1/else-style decisions in places beyond the principal graphics selectors.

Examples found during investigation include areas around:

```text
$F0B4
$F0F8
```

The important graphics and global-ID routes are patched, but remaining character-dependent logic should be classified.

Possible roles include:

- menu marker positioning;
- starting attributes;
- weapons;
- animation metadata;
- other character-specific behaviour.

Do not assume these are bugs merely because they branch by original character groups.

## 4. Character 6 behaviour identity

Current source deliberately maps new selection 5 to:

```asm
CHAR6_BEHAVIOUR_ID EQU 0
```

for old non-graphics global-ID logic.

Need determine whether:

- this is sufficient permanently;
- each added character should specify an inherited behaviour ID;
- there are more five-entry metadata tables requiring expansion rather than aliasing.

## 5. More than six characters

Current architecture uses six fixed slots.

For larger rosters, consider:

### Option A — larger slave tables

Increase selection count and maintain more externally loaded banks.

Pros:
- straightforward lookup.

Cons:
- quickly consumes ChipRAM if every raw `$7080` bank remains resident.

### Option B — dynamic cache

Keep external assets in FastRAM/disk and copy only the selected player's current bank into a reusable ChipRAM cache.

Pros:
- much lower ChipRAM use;
- potentially retains 1 MB game compatibility.

Cons:
- more lifecycle/loading logic;
- two-player mode needs at least two safe runtime destinations.

## 6. Restore strict 1 MB ChipRAM compatibility

Current test asks WHDLoad for:

```text
$110000
```

base memory.

A later production implementation should consider whether extra permanent ChipRAM is acceptable.

If not, investigate:

- use of ExpMem/FastRAM for raw custom files;
- copy into existing game working buffers only when needed;
- portrait cache in an existing safe ChipRAM area;
- Hoverbout patch direct from FastRAM if CPU-copy source is safe.

## 7. Complete level-sprite descriptor documentation

Known descriptor structure is 22 bytes, but several fields remain unnamed.

Future work:

- label every field in the descriptor table at `$1EDA6`;
- document how `$5562` derives live graphics/mask pointers;
- map descriptor IDs to named in-game objects;
- identify which special player composites exist in levels 2-5.

The Hoverbout finding proves that character-specific graphics can live in level banks, so other level-specific player graphics may also exist.

## 8. Search for other separate character artwork

Before calling character import complete, inspect:

- all level sprite banks for groups of five related player-like frames;
- menus/interstitials;
- death/transition graphics not present in the 45-frame character bank;
- special vehicles or scripted sequences.

A useful pattern is:

```text
five original frames + a sixth blank/default frame
```

because that may already contain latent indexing support for another character.

## 9. Document any future patch immediately

When a new address or format is confirmed, update:

- `02-disk-and-resource-map.md`;
- `08-runtime-address-map.md`;
- the relevant subject page;
- this status page.

This avoids allowing chat history to become the only record of the reverse engineering.
