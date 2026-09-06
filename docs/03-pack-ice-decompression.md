# Pack-Ice decompression

Dalek Attack uses the classic `Ice!` packed-resource format for many game assets.

A working decoder was produced by matching the game's embedded 68000 depacker.

## Container header

An Ice resource begins:

```text
offset +0   4 bytes   "Ice!" or "ICE!"
offset +4   4 bytes   packed size, big-endian
offset +8   4 bytes   unpacked size, big-endian
```

The packed-size value includes the Ice container.

## Game depacker

The game's Ice depacker is at runtime:

```text
$D74C
```

An important property for the character-extension work is that the routine checks for the Ice signature. If the source is already raw and does not begin `Ice!`, it returns without performing an Ice decode.

That is why an external `CHAR6.bin` can be supplied directly as a raw `$7080` bank.

## Decoder direction

The implementation is a **backwards decoder**:

- the packed source is read backwards;
- the 32-bit bitstream is consumed backwards;
- output is written from the end of the destination backwards.

This is important: simpler forward Ice implementations did not reproduce the game resources correctly.

## 32-bit bit reader

The decoder maintains a 32-bit value equivalent to the game's `D7`.

When the shifted bit-buffer becomes empty, another longword is read backwards from the source.

The refill behaviour preserves a marker bit:

```text
new D7 = (new_longword << 1) | 1
```

## Tables recovered for this game

Length tables:

```python
LEN_EXTRA = [9, 1, 0, -1, -1]
LEN_BASE  = [8, 4, 2, 1, 0]
```

Distance tables:

```python
DIST_EXTRA = [11, 4, 7]
DIST_BASE  = [0x120, 0, 0x20]
```

Literal table:

```python
LIT_TABLE = [
    (1,  0x0003,   1),
    (1,  0x0003,   4),
    (2,  0x0007,   7),
    (7,  0x00FF,  14),
    (14, 0x7FFF, 269),
]
```

The integer in the first field is a DBRA-style count, so the decoder actually reads `n + 1` bits.

## Optional picture transform

Old Ice data can include an optional picture bit-transpose after normal decompression.

The working decoder checks the picture flag after the main stream and, when active, scatters packed words into four bitplane words.

The default historical group count is:

```text
$0F9F + 1 = $0FA0 groups
```

unless a 16-bit count follows.

The tool only applies the transform when the signalled count is plausible for the output size.

## Resources currently decoded successfully

The same decoder is used successfully for:

- all five playable character animation banks;
- `SPRITES1..5`;
- `BLOCK001..005`;
- Level 1 Hoverbout extraction from `SPRITES1`.

## Validation strategy

For any newly identified Ice resource:

1. check bytes 0-3 for `Ice!`/`ICE!`;
2. read packed/unpacked sizes from the header;
3. ensure packed size remains inside the source file;
4. depack;
5. confirm the output length exactly matches the header;
6. only then interpret the resulting graphics structure.

Do not infer dimensions merely from a visually plausible first few tiles or frames; earlier investigation showed that incorrect dimensions can appear superficially valid before progressively corrupting the output.
