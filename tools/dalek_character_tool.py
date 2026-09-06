#!/usr/bin/env python3
"""
Dalek Attack (Amiga) playable-character sprite-sheet round-trip tool.

One character animation bank:
    45 frames
    32 x 40 pixels per frame
    4 bitplanes / 16 colours
    640 bytes per frame
    28,800 bytes total ($7080)

Editable sprite sheet:
    9 columns x 5 rows
    288 x 200 pixels
    frame order is left-to-right, top-to-bottom: 0..44
    Larger PNG/ILBM canvases (e.g. DPaint 320x256) are accepted and
    automatically cropped from top-left (0,0) to 288x200 on import.

IMPORTANT:
    Palette index 0 is still the game's transparent/background index.
    For EDITING ONLY it is displayed as Amiga $F0F / RGB #FF00FF magenta.
    Import converts by palette INDEX, so index 0 remains index 0 in the
    reconstructed game bank. No magenta colour is added to the game data.

Commands:
    disk-extract Disk.1 OUTDIR [--raw-only]
    export BANK.bin OUTBASE [--format png|ilbm|both]
    import SHEET.png OUT.bin
    import SHEET.iff OUT.bin
    verify BANK.bin WORKDIR

Optional 32x32 selection portrait (menu/HUD palette):
    portrait-export PORTRAIT.bin OUTBASE [--format png|ilbm|both]
    portrait-import PORTRAIT.png OUT.bin
    portrait-import PORTRAIT.iff OUT.bin

Level 1 hoverbout composite (playfield palette):
    32 x 56 pixels, 4 bitplanes, 896 bytes ($0380)
    hoverbout-extract Disk.2 OUTDIR
    hoverbout-export HOVER.bin OUTBASE [--format png|ilbm|both]
    hoverbout-import HOVER.png OUT.bin
    hoverbout-import HOVER.iff OUT.bin

Complete character set:
    set-export BANK.bin PORTRAIT.bin OUTDIR [--format png|ilbm|both]
    set-import INDIR BANK_OUT.bin PORTRAIT_OUT.bin [--format auto|png|ilbm]
    set-verify BANK.bin PORTRAIT.bin WORKDIR

The tool has NO fixed input directory. Every path is supplied on the command
line. Relative paths are relative to the directory you run the command from.
"""

from __future__ import annotations
import argparse
import hashlib
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("error: Pillow is required. Install with: python3 -m pip install pillow",
          file=sys.stderr)
    raise SystemExit(2)

FRAME_W = 32
FRAME_H = 40
FRAMES = 45
SHEET_COLS = 9
SHEET_ROWS = 5
SHEET_W = FRAME_W * SHEET_COLS
SHEET_H = FRAME_H * SHEET_ROWS
PLANES = 4
FRAME_BYTES = (FRAME_W // 8) * PLANES * FRAME_H
BANK_BYTES = FRAME_BYTES * FRAMES

PORTRAIT_W = 32
PORTRAIT_H = 32
PORTRAIT_BYTES = (PORTRAIT_W // 8) * PLANES * PORTRAIT_H

HOVERBOUT_W = 32
HOVERBOUT_H = 56
HOVERBOUT_BYTES = (HOVERBOUT_W // 8) * PLANES * HOVERBOUT_H

# Original playable-character resources in Disk.1.
# The five animation banks are Pack-Ice streams; their unpacked size is $7080.
# The five selection portraits are already raw and contiguous in the main game
# image: runtime $1797A maps to Disk.1 offset $2F17A (Disk.1 + $17800).
DISK1_EXPECTED_SIZE = 901120
ORIGINAL_CHARACTER_ICE_OFFSETS = [
    0x090E5C,
    0x094C50,
    0x0988C4,
    0x09BEF8,
    0x09F188,
]
ORIGINAL_PORTRAIT_OFFSET = 0x02F17A
ORIGINAL_CHARACTER_COUNT = 5

# Level 1 hoverbout composites live in Disk.2 SPRITES1, descriptor 21.
# SPRITES1 depacks to 90352 bytes. Descriptor 21 begins at $A500 and is
# 6 x 32x56 frames ($380 bytes each): the five original riders followed by
# the empty hoverbout sixth frame.
DISK2_EXPECTED_SIZE = 901120
SPRITES1_ICE_OFFSET = 0x013000
SPRITES1_EXPECTED_UNPACKED = 90352
HOVERBOUT_SET_OFFSET = 0x0A500
HOVERBOUT_FRAME_COUNT = 6

# Pack-Ice 32-bit backward-bit-reader tables used by Dalek Attack.
ICE_LEN_EXTRA = [9, 1, 0, -1, -1]
ICE_LEN_BASE = [8, 4, 2, 1, 0]
ICE_DIST_EXTRA = [11, 4, 7]
ICE_DIST_BASE = [0x120, 0, 0x20]
ICE_LIT_TABLE = [
    (1, 0x0003, 1),
    (1, 0x0003, 4),
    (2, 0x0007, 7),
    (7, 0x00FF, 14),
    (14, 0x7FFF, 269),
]

class IceError(Exception):
    pass

class IceDecoder:
    def __init__(self, src: bytes, packed_size: int, out_size: int):
        self.src = src
        self.a5 = packed_size
        self.d7 = 0
        self.out = bytearray(out_size)
        self.wpos = out_size
        self.out_size = out_size

    def read_byte_back(self):
        self.a5 -= 1
        if self.a5 < 0:
            raise IceError("source underrun")
        return self.src[self.a5]

    def prime(self):
        if self.a5 < 4:
            raise IceError("source underrun at prime")
        self.a5 -= 4
        self.d7 = int.from_bytes(self.src[self.a5:self.a5 + 4], "big")

    def bit(self):
        shifted = self.d7 << 1
        b = (shifted >> 32) & 1
        self.d7 = shifted & 0xFFFFFFFF
        if self.d7 == 0:
            if self.a5 < 4:
                raise IceError("source underrun on bit refill")
            self.a5 -= 4
            nw = int.from_bytes(self.src[self.a5:self.a5 + 4], "big")
            b = (nw >> 31) & 1
            self.d7 = ((nw << 1) | 1) & 0xFFFFFFFF
        return b

    def bits(self, dbra_n):
        v = 0
        for _ in range(dbra_n + 1):
            v = (v << 1) | self.bit()
        return v

    def write(self, v):
        if self.wpos <= 0:
            raise IceError("output overflow")
        self.wpos -= 1
        self.out[self.wpos] = v & 255

    def literal_extra(self):
        for n, target, add in ICE_LIT_TABLE:
            v = self.bits(n)
            if v != target:
                return v + add
        return v + ICE_LIT_TABLE[-1][2]

    def unary(self, start, count):
        d = start
        for _ in range(count):
            if self.bit() == 0:
                return d
            d -= 1
        return d

    def match_code(self):
        d2 = self.unary(3, 4)
        idx = d2 + 1
        ex = ICE_LEN_EXTRA[idx]
        v = self.bits(ex) if ex >= 0 else 0
        return ICE_LEN_BASE[idx] + v

    def distance(self):
        d2 = self.unary(1, 2)
        idx = d2 + 1
        return self.bits(ICE_DIST_EXTRA[idx]) + ICE_DIST_BASE[idx]

    def reduced_distance(self):
        if self.bit() == 0:
            return self.bits(5)
        return self.bits(8) + 0x40

    def scatter(self, groups):
        a3 = self.out_size
        for _ in range(groups):
            regs = [0, 0, 0, 0]
            for _ in range(4):
                a3 -= 2
                if a3 < 0:
                    raise IceError("picture scatter underrun")
                w = (self.out[a3] << 8) | self.out[a3 + 1]
                for r in range(4):
                    regs[r] = ((regs[r] << 1) | ((w >> 15) & 1)) & 0xFFFF
                    w = (w << 1) & 0xFFFF
            pos = a3
            for w in regs:
                self.out[pos:pos + 2] = w.to_bytes(2, "big")
                pos += 2

    def run(self, picture_mode="auto"):
        self.prime()
        while True:
            first = self.bit()
            lit = None
            if first:
                lit = 0 if self.bit() == 0 else self.literal_extra()
            if lit is not None:
                for _ in range(lit + 1):
                    self.write(self.read_byte_back())
                if self.wpos <= 0:
                    break
            d4 = self.match_code()
            dist = self.reduced_distance() if d4 == 0 else self.distance()
            mlen = d4 + 2
            spos = self.wpos + 2 + d4 + dist
            for _ in range(mlen):
                if spos > self.out_size:
                    raise IceError(f"match source out of range {spos}>{self.out_size}")
                spos -= 1
                self.write(self.out[spos] if spos < self.out_size else 0)
            if self.wpos <= 0:
                break

        # Optional old-Ice picture transpose. Character banks do not require
        # forcing this; auto matches the game's own format handling.
        if picture_mode != "never":
            flag = self.bit()
            if flag:
                groups = 0x0FA0
                if self.bit():
                    groups = self.bits(15) + 1
                if groups * 8 > self.out_size:
                    if picture_mode == "force":
                        raise IceError(f"picture scatter count {groups} too large")
                else:
                    self.scatter(groups)
        return bytes(self.out)


def ice_depack(blob: bytes, picture_mode="auto") -> bytes:
    if len(blob) < 12 or blob[:4] not in (b"Ice!", b"ICE!"):
        raise IceError("not an Ice container")
    packed = int.from_bytes(blob[4:8], "big")
    unpacked = int.from_bytes(blob[8:12], "big")
    if packed < 12 or packed > len(blob):
        raise IceError(f"bad packed size {packed} for blob {len(blob)}")
    return IceDecoder(blob[:packed], packed, unpacked).run(picture_mode)


def extract_originals_from_disk1(disk1: Path, outdir: Path, editable=True):
    """Extract all five original playable characters + portraits from Disk.1.

    Writes CHAR1.bin..CHAR5.bin and CHAR1_portrait.bin..CHAR5_portrait.bin.
    If editable=True, also writes PNG + ILBM for every character and portrait.
    """
    disk = disk1.read_bytes()
    if len(disk) != DISK1_EXPECTED_SIZE:
        raise ValueError(
            f"Disk.1 must be {DISK1_EXPECTED_SIZE} bytes, got {len(disk)}: {disk1}"
        )
    outdir.mkdir(parents=True, exist_ok=True)
    results = []

    for i, off in enumerate(ORIGINAL_CHARACTER_ICE_OFFSETS, 1):
        if disk[off:off + 4] not in (b"Ice!", b"ICE!"):
            raise ValueError(f"CHAR{i}: no Ice! stream at Disk.1 offset ${off:06X}")
        packed = int.from_bytes(disk[off + 4:off + 8], "big")
        unpacked = int.from_bytes(disk[off + 8:off + 12], "big")
        if unpacked != BANK_BYTES:
            raise ValueError(
                f"CHAR{i}: expected unpacked size ${BANK_BYTES:04X}, got ${unpacked:X}"
            )
        bank = ice_depack(disk[off:off + packed])
        if len(bank) != BANK_BYTES:
            raise ValueError(f"CHAR{i}: depacked to {len(bank)} bytes, expected {BANK_BYTES}")
        bank_path = outdir / f"CHAR{i}.bin"
        bank_path.write_bytes(bank)

        poff = ORIGINAL_PORTRAIT_OFFSET + (i - 1) * PORTRAIT_BYTES
        portrait = disk[poff:poff + PORTRAIT_BYTES]
        if len(portrait) != PORTRAIT_BYTES:
            raise ValueError(f"CHAR{i}: portrait slice is short")
        portrait_path = outdir / f"CHAR{i}_portrait.bin"
        portrait_path.write_bytes(portrait)

        if editable:
            export_bank(bank_path, outdir / f"CHAR{i}", "both")
            export_portrait(portrait_path, outdir / f"CHAR{i}_portrait", "both")

        results.append((bank_path, portrait_path))
    return results

def extract_hoverbouts_from_disk2(disk2: Path, outdir: Path, editable=True):
    """Extract Level 1 descriptor-21 hoverbout composites from Disk.2.

    Writes CHAR1_hoverbout.bin .. CHAR5_hoverbout.bin and
    CHAR6_hoverbout_template.bin.  The sixth original frame is the empty
    hoverbout and is the correct template for a custom sixth rider.
    """
    disk = disk2.read_bytes()
    if len(disk) != DISK2_EXPECTED_SIZE:
        raise ValueError(
            f"Disk.2 must be {DISK2_EXPECTED_SIZE} bytes, got {len(disk)}: {disk2}"
        )
    off = SPRITES1_ICE_OFFSET
    if disk[off:off + 4] not in (b"Ice!", b"ICE!"):
        raise ValueError(f"no SPRITES1 Ice! stream at Disk.2 offset ${off:06X}")
    packed = int.from_bytes(disk[off + 4:off + 8], "big")
    unpacked = int.from_bytes(disk[off + 8:off + 12], "big")
    if unpacked != SPRITES1_EXPECTED_UNPACKED:
        raise ValueError(
            f"SPRITES1 expected unpacked size {SPRITES1_EXPECTED_UNPACKED}, got {unpacked}"
        )
    bank = ice_depack(disk[off:off + packed])
    outdir.mkdir(parents=True, exist_ok=True)
    results = []
    for i in range(HOVERBOUT_FRAME_COUNT):
        start = HOVERBOUT_SET_OFFSET + i * HOVERBOUT_BYTES
        raw = bank[start:start + HOVERBOUT_BYTES]
        if len(raw) != HOVERBOUT_BYTES:
            raise ValueError(f"hoverbout frame {i} slice is short")
        name = f"CHAR{i+1}_hoverbout" if i < 5 else "CHAR6_hoverbout_template"
        bp = outdir / f"{name}.bin"
        bp.write_bytes(raw)
        if editable:
            export_hoverbout(bp, outdir / name, "both")
        results.append(bp)
    return results

# Two distinct 16-colour palettes are used by the game.
#
# Character animation frames use the main playfield palette copied from
# runtime $11E74 into COLOR01..COLOR15 (COLOR00 is black).
# Selection portraits are displayed in the menu/HUD region and use the
# second palette beginning at runtime $11E92.
#
# For EDITING ONLY, palette index 0 is shown as Amiga $F0F / #FF00FF in
# both palettes so transparent/background pixels are easy to see. The raw
# game data still stores index 0.
AMIGA12_PLAYFIELD = [
    0x000, 0x039, 0x666, 0x888, 0x642, 0x864, 0xA86, 0x264,
    0xCA4, 0x26C, 0x112, 0x488, 0x444, 0xA22, 0x000, 0xEEE,
]

AMIGA12_PORTRAIT = [
    0x000, 0x029, 0x666, 0x999, 0x642, 0x964, 0xB96, 0x264,
    0xFD4, 0xBBB, 0x224, 0x499, 0x444, 0xD22, 0x000, 0xDDF,
]

def amiga12_rgb(c: int):
    return (((c >> 8) & 0xF) * 17, ((c >> 4) & 0xF) * 17, (c & 0xF) * 17)

GAME_RGB_PLAYFIELD = [amiga12_rgb(c) for c in AMIGA12_PLAYFIELD]
GAME_RGB_PORTRAIT = [amiga12_rgb(c) for c in AMIGA12_PORTRAIT]
EDITOR_RGB_PLAYFIELD = GAME_RGB_PLAYFIELD.copy()
EDITOR_RGB_PLAYFIELD[0] = (255, 0, 255)  # Amiga $F0F
EDITOR_RGB_PORTRAIT = GAME_RGB_PORTRAIT.copy()
EDITOR_RGB_PORTRAIT[0] = (255, 0, 255)  # Amiga $F0F

def pil_palette(rgb):
    flat = []
    for c in rgb:
        flat.extend(c)
    return flat + [0] * (768 - len(flat))

EDITOR_PAL_PLAYFIELD = pil_palette(EDITOR_RGB_PLAYFIELD)
EDITOR_PAL_PORTRAIT = pil_palette(EDITOR_RGB_PORTRAIT)

def load_exact(path: Path, size: int, label: str) -> bytes:
    raw = path.read_bytes()
    if len(raw) != size:
        raise ValueError(f"{label} must be exactly {size} bytes, got {len(raw)}: {path}")
    return raw

def encode_indices(indices, width: int, height: int) -> bytes:
    if len(indices) != width * height:
        raise ValueError("wrong pixel count")
    if width % 16:
        raise ValueError("width must be a multiple of 16")
    row_bytes = width // 8
    out = bytearray()
    for y in range(height):
        row = indices[y * width:(y + 1) * width]
        for plane in range(PLANES):
            for xb in range(row_bytes):
                v = 0
                for bitpos in range(8):
                    x = xb * 8 + bitpos
                    v |= ((row[x] >> plane) & 1) << (7 - bitpos)
                out.append(v)
    return bytes(out)

def decode_planar(raw: bytes, width: int, height: int) -> list[int]:
    if width % 16:
        raise ValueError("width must be a multiple of 16")
    row_bytes = width // 8
    expected = row_bytes * PLANES * height
    if len(raw) != expected:
        raise ValueError(f"planar data must be {expected} bytes, got {len(raw)}")
    indices = [0] * (width * height)
    off = 0
    for y in range(height):
        planes = [raw[off + p * row_bytes:off + (p + 1) * row_bytes]
                  for p in range(PLANES)]
        off += row_bytes * PLANES
        for x in range(width):
            bi = x >> 3
            bit = 7 - (x & 7)
            v = 0
            for p in range(PLANES):
                v |= ((planes[p][bi] >> bit) & 1) << p
            indices[y * width + x] = v
    return indices

def indexed_image(indices, width: int, height: int, editor_rgb):
    im = Image.new("P", (width, height), 0)
    im.putpalette(pil_palette(editor_rgb))
    im.putdata(indices)
    # Deliberately DO NOT set PNG transparency.
    # Index 0 must be visibly magenta while editing.
    return im

def _crop_top_left_indices(indices: list[int], src_w: int, src_h: int,
                           width: int, height: int) -> list[int]:
    """Crop an indexed canvas to the required game area from (0,0)."""
    if src_w < width or src_h < height:
        raise ValueError(
            f"image is {src_w}x{src_h}; it must be at least {width}x{height}"
        )
    if src_w == width and src_h == height:
        return indices
    out = []
    for y in range(height):
        row = y * src_w
        out.extend(indices[row:row + width])
    return out

def image_to_indices(im: Image.Image, width: int, height: int,
                     editor_rgb, game_rgb, palette_name: str) -> list[int]:
    """Read an editable PNG/image and return the required game-sized indices.

    Oversized canvases are supported deliberately for Deluxe Paint and similar
    editors.  The required game area is cropped from the TOP-LEFT (0,0).
    Thus a 320x256 DPaint character picture becomes the 288x200 game sheet.
    """
    src_w, src_h = im.size
    if src_w < width or src_h < height:
        raise ValueError(
            f"image is {src_w}x{src_h}; expected {width}x{height} or a larger canvas to crop"
        )

    if im.mode == "P":
        vals = list(im.getdata())
        if any(v > 15 for v in vals):
            raise ValueError("indexed image contains palette index > 15")

        pal = im.getpalette()
        if pal:
            got = [tuple(pal[i*3:i*3+3]) for i in range(16)]
            if got[1:16] != editor_rgb[1:16]:
                raise ValueError(
                    f"palette entries 1..15 differ from the Dalek Attack {palette_name} palette; "
                    "keep the image indexed and do not optimise/reorder its palette"
                )
            if got[0] not in (editor_rgb[0], game_rgb[0]):
                raise ValueError(
                    "palette index 0 must remain editor magenta #FF00FF or game black #000000"
                )
        return _crop_top_left_indices(vals, src_w, src_h, width, height)

    # RGB/RGBA import is allowed, but only exact known editor colours.
    # This is intentionally strict: no nearest-colour conversion.
    rgba = im.convert("RGBA")
    cmap = {(*rgb, 255): i for i, rgb in enumerate(editor_rgb)}
    vals = []
    for px in rgba.getdata():
        if px[3] == 0:
            vals.append(0)
            continue
        key = (px[0], px[1], px[2], 255)
        if key not in cmap:
            raise ValueError(
                f"RGB colour {px[:3]} is not an exact Dalek Attack {palette_name} editor-palette colour"
            )
        vals.append(cmap[key])
    return _crop_top_left_indices(vals, src_w, src_h, width, height)

def bank_to_sheet_indices(bank: bytes) -> list[int]:
    if len(bank) != BANK_BYTES:
        raise ValueError(f"bank must be {BANK_BYTES} bytes")
    sheet = [0] * (SHEET_W * SHEET_H)
    for f in range(FRAMES):
        frame_raw = bank[f*FRAME_BYTES:(f+1)*FRAME_BYTES]
        frame = decode_planar(frame_raw, FRAME_W, FRAME_H)
        fx = (f % SHEET_COLS) * FRAME_W
        fy = (f // SHEET_COLS) * FRAME_H
        for y in range(FRAME_H):
            src = y * FRAME_W
            dst = (fy + y) * SHEET_W + fx
            sheet[dst:dst+FRAME_W] = frame[src:src+FRAME_W]
    return sheet

def sheet_indices_to_bank(sheet: list[int]) -> bytes:
    if len(sheet) != SHEET_W * SHEET_H:
        raise ValueError("bad sheet pixel count")
    out = bytearray()
    for f in range(FRAMES):
        fx = (f % SHEET_COLS) * FRAME_W
        fy = (f // SHEET_COLS) * FRAME_H
        frame = []
        for y in range(FRAME_H):
            src = (fy + y) * SHEET_W + fx
            frame.extend(sheet[src:src+FRAME_W])
        out.extend(encode_indices(frame, FRAME_W, FRAME_H))
    if len(out) != BANK_BYTES:
        raise AssertionError(len(out))
    return bytes(out)

def _chunk(tag: bytes, data: bytes) -> bytes:
    return tag + struct.pack(">I", len(data)) + data + (b"\0" if len(data) & 1 else b"")

def write_ilbm_indices(indices, path: Path, width: int, height: int, editor_rgb):
    raw = encode_indices(indices, width, height)
    # masking=0: keep index 0 visibly magenta in normal ILBM viewers/editors.
    bmhd = struct.pack(">HHhhBBBBHBBhh",
                       width, height, 0, 0, PLANES, 0, 0, 0, 0, 10, 11, width, height)
    cmap = bytes(v for rgb in editor_rgb for v in rgb)
    payload = b"ILBM" + _chunk(b"BMHD", bmhd) + _chunk(b"CMAP", cmap) + _chunk(b"BODY", raw)
    path.write_bytes(b"FORM" + struct.pack(">I", len(payload)) + payload)

def byterun1_decode(data: bytes, expected: int) -> bytes:
    out = bytearray()
    i = 0
    while len(out) < expected:
        if i >= len(data):
            raise ValueError("truncated ByteRun1 BODY")
        n = struct.unpack("b", data[i:i+1])[0]
        i += 1
        if 0 <= n <= 127:
            count = n + 1
            if i + count > len(data):
                raise ValueError("truncated ByteRun1 literal")
            out.extend(data[i:i+count])
            i += count
        elif -127 <= n <= -1:
            count = 1 - n
            if i >= len(data):
                raise ValueError("truncated ByteRun1 repeat")
            out.extend(data[i:i+1] * count)
            i += 1
        else:
            pass
    if len(out) != expected:
        raise ValueError("ByteRun1 overrun")
    return bytes(out)

def ilbm_info(path: Path):
    """Return (width, height, planes) from an ILBM BMHD."""
    b = path.read_bytes()
    if len(b) < 12 or b[:4] != b"FORM" or b[8:12] != b"ILBM":
        raise ValueError(f"{path}: not an ILBM")
    pos = 12
    end = min(len(b), 8 + int.from_bytes(b[4:8], "big"))
    while pos + 8 <= end:
        tag = b[pos:pos+4]
        n = int.from_bytes(b[pos+4:pos+8], "big")
        pos += 8
        data = b[pos:pos+n]
        pos += n + (n & 1)
        if tag == b"BMHD":
            if len(data) < 20:
                raise ValueError("ILBM BMHD is truncated")
            vals = struct.unpack(">HHhhBBBBHBBhh", data[:20])
            return vals[0], vals[1], vals[4]
    raise ValueError("ILBM missing BMHD")

def _decode_ilbm_planar(body: bytes, width: int, height: int, nplanes: int) -> list[int]:
    """Decode standard ILBM plane-row layout, including 16-pixel row padding."""
    rowbytes = ((width + 15) // 16) * 2
    expected = rowbytes * height * nplanes
    if len(body) != expected:
        raise ValueError(f"ILBM BODY is {len(body)} bytes; expected {expected}")
    indices = [0] * (width * height)
    off = 0
    for y in range(height):
        planes = [body[off + p*rowbytes:off + (p+1)*rowbytes] for p in range(nplanes)]
        off += rowbytes * nplanes
        for x in range(width):
            bi = x >> 3
            bit = 7 - (x & 7)
            v = 0
            for p in range(nplanes):
                v |= ((planes[p][bi] >> bit) & 1) << p
            indices[y * width + x] = v
    return indices

def read_ilbm_indices(path: Path, width: int, height: int) -> list[int]:
    """Read 4-plane ILBM and crop oversized canvases from top-left.

    This intentionally accepts DPaint screen sizes such as 320x256 when the
    required character sheet is 288x200.
    """
    b = path.read_bytes()
    if len(b) < 12 or b[:4] != b"FORM" or b[8:12] != b"ILBM":
        raise ValueError(f"{path}: not an ILBM")
    pos = 12
    chunks = {}
    end = min(len(b), 8 + int.from_bytes(b[4:8], "big"))
    while pos + 8 <= end:
        tag = b[pos:pos+4]
        n = int.from_bytes(b[pos+4:pos+8], "big")
        pos += 8
        chunks[tag] = b[pos:pos+n]
        pos += n + (n & 1)

    if b"BMHD" not in chunks or b"BODY" not in chunks:
        raise ValueError("ILBM missing BMHD/BODY")
    vals = struct.unpack(">HHhhBBBBHBBhh", chunks[b"BMHD"][:20])
    w, h, _, _, nplanes, masking, compression, _, _, _, _, _, _ = vals
    if nplanes != PLANES:
        raise ValueError(f"ILBM must use {PLANES} bitplanes / 16 colours; got {nplanes} planes")
    if w < width or h < height:
        raise ValueError(
            f"ILBM is {w}x{h}; expected {width}x{height} or a larger canvas to crop"
        )
    if masking not in (0, 2):
        raise ValueError("ILBM mask plane is not supported")

    rowbytes = ((w + 15) // 16) * 2
    expected = rowbytes * h * nplanes
    body = chunks[b"BODY"]
    if compression == 0:
        if len(body) < expected:
            raise ValueError("short ILBM BODY")
        body = body[:expected]
    elif compression == 1:
        body = byterun1_decode(body, expected)
    else:
        raise ValueError(f"unsupported ILBM compression {compression}")

    indices = _decode_ilbm_planar(body, w, h, nplanes)
    return _crop_top_left_indices(indices, w, h, width, height)

def graphic_dimensions(path: Path):
    """Return (w,h,kind) for PNG or ILBM without importing it."""
    ext = path.suffix.lower()
    if ext == ".png":
        with Image.open(path) as im:
            return im.size[0], im.size[1], "PNG"
    if ext in (".iff", ".ilbm"):
        w, h, _ = ilbm_info(path)
        return w, h, "ILBM"
    raise ValueError("graphic must be PNG or ILBM")

def crop_note(path: Path, width: int, height: int) -> str:
    w, h, kind = graphic_dimensions(path)
    if (w, h) == (width, height):
        return f"{kind} {w}x{h}"
    return f"{kind} {w}x{h} cropped top-left (0,0) -> {width}x{height}"

def export_bank(bankpath: Path, outbase: Path, fmt: str):
    bank = load_exact(bankpath, BANK_BYTES, "character bank")
    indices = bank_to_sheet_indices(bank)
    outbase.parent.mkdir(parents=True, exist_ok=True)

    if fmt in ("png", "both"):
        p = outbase if outbase.suffix.lower() == ".png" else outbase.with_suffix(".png")
        indexed_image(indices, SHEET_W, SHEET_H, EDITOR_RGB_PLAYFIELD).save(p)

    if fmt in ("ilbm", "both"):
        p = outbase if outbase.suffix.lower() in (".iff", ".ilbm") else outbase.with_suffix(".iff")
        write_ilbm_indices(indices, p, SHEET_W, SHEET_H, EDITOR_RGB_PLAYFIELD)

def import_bank(inpath: Path, outpath: Path):
    ext = inpath.suffix.lower()
    if ext == ".png":
        indices = image_to_indices(Image.open(inpath), SHEET_W, SHEET_H, EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield")
    elif ext in (".iff", ".ilbm"):
        indices = read_ilbm_indices(inpath, SHEET_W, SHEET_H)
    else:
        raise ValueError("input must be .png, .iff or .ilbm")
    outpath.parent.mkdir(parents=True, exist_ok=True)
    outpath.write_bytes(sheet_indices_to_bank(indices))

def export_portrait(portraitpath: Path, outbase: Path, fmt: str):
    raw = load_exact(portraitpath, PORTRAIT_BYTES, "portrait")
    indices = decode_planar(raw, PORTRAIT_W, PORTRAIT_H)
    outbase.parent.mkdir(parents=True, exist_ok=True)

    if fmt in ("png", "both"):
        p = outbase if outbase.suffix.lower() == ".png" else outbase.with_suffix(".png")
        indexed_image(indices, PORTRAIT_W, PORTRAIT_H, EDITOR_RGB_PORTRAIT).save(p)

    if fmt in ("ilbm", "both"):
        p = outbase if outbase.suffix.lower() in (".iff", ".ilbm") else outbase.with_suffix(".iff")
        write_ilbm_indices(indices, p, PORTRAIT_W, PORTRAIT_H, EDITOR_RGB_PORTRAIT)

def import_portrait(inpath: Path, outpath: Path):
    ext = inpath.suffix.lower()
    if ext == ".png":
        indices = image_to_indices(Image.open(inpath), PORTRAIT_W, PORTRAIT_H, EDITOR_RGB_PORTRAIT, GAME_RGB_PORTRAIT, "portrait/menu")
    elif ext in (".iff", ".ilbm"):
        indices = read_ilbm_indices(inpath, PORTRAIT_W, PORTRAIT_H)
    else:
        raise ValueError("portrait input must be .png, .iff or .ilbm")
    outpath.parent.mkdir(parents=True, exist_ok=True)
    outpath.write_bytes(encode_indices(indices, PORTRAIT_W, PORTRAIT_H))

def export_hoverbout(hoverpath: Path, outbase: Path, fmt: str):
    raw = load_exact(hoverpath, HOVERBOUT_BYTES, "hoverbout frame")
    indices = decode_planar(raw, HOVERBOUT_W, HOVERBOUT_H)
    outbase.parent.mkdir(parents=True, exist_ok=True)

    if fmt in ("png", "both"):
        p = outbase if outbase.suffix.lower() == ".png" else outbase.with_suffix(".png")
        indexed_image(indices, HOVERBOUT_W, HOVERBOUT_H, EDITOR_RGB_PLAYFIELD).save(p)

    if fmt in ("ilbm", "both"):
        p = outbase if outbase.suffix.lower() in (".iff", ".ilbm") else outbase.with_suffix(".iff")
        write_ilbm_indices(indices, p, HOVERBOUT_W, HOVERBOUT_H, EDITOR_RGB_PLAYFIELD)

def import_hoverbout(inpath: Path, outpath: Path):
    ext = inpath.suffix.lower()
    if ext == ".png":
        with Image.open(inpath) as im:
            indices = image_to_indices(
                im, HOVERBOUT_W, HOVERBOUT_H,
                EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield"
            )
    elif ext in (".iff", ".ilbm"):
        indices = read_ilbm_indices(inpath, HOVERBOUT_W, HOVERBOUT_H)
    else:
        raise ValueError("hoverbout input must be .png, .iff or .ilbm")
    outpath.parent.mkdir(parents=True, exist_ok=True)
    outpath.write_bytes(encode_indices(indices, HOVERBOUT_W, HOVERBOUT_H))

def verify_hoverbout(hoverpath: Path, workdir: Path):
    original = load_exact(hoverpath, HOVERBOUT_BYTES, "hoverbout frame")
    workdir.mkdir(parents=True, exist_ok=True)
    for fmt, ext in (("png", ".png"), ("ilbm", ".iff")):
        base = workdir / f"hoverbout_{fmt}"
        export_hoverbout(hoverpath, base, fmt)
        rebuilt = workdir / f"roundtrip_{fmt}.bin"
        import_hoverbout(base.with_suffix(ext), rebuilt)
        if rebuilt.read_bytes() != original:
            raise ValueError(f"{fmt.upper()} hoverbout round-trip failed")

def export_set(bankpath: Path, portraitpath: Path, outdir: Path, fmt: str):
    outdir.mkdir(parents=True, exist_ok=True)
    export_bank(bankpath, outdir / "character", fmt)
    export_portrait(portraitpath, outdir / "portrait", fmt)
    (outdir / "README.txt").write_text(
        "Dalek Attack editable character set\n\n"
        "character.png / character.iff : 45 animation frames, 9x5 grid\n"
        "portrait.png / portrait.iff   : 32x32 menu portrait\n"
        "Character sheet uses the playfield palette; portrait uses the menu/HUD palette.\n"
        "Palette index 0 is shown as #FF00FF / Amiga $F0F for editing.\n"
        "It still becomes transparent/background index 0 in the raw game data.\n",
        encoding="utf-8"
    )

def import_set(indir: Path, bankout: Path, portraitout: Path, fmt: str):
    if fmt == "auto":
        cp = indir / "character.png"
        ci = indir / "character.iff"
        pp = indir / "portrait.png"
        pi = indir / "portrait.iff"
        if cp.exists() and pp.exists():
            c, p = cp, pp
        elif ci.exists() and pi.exists():
            c, p = ci, pi
        else:
            raise ValueError(
                "need character.png + portrait.png, or character.iff + portrait.iff"
            )
    elif fmt == "png":
        c, p = indir / "character.png", indir / "portrait.png"
    else:
        c, p = indir / "character.iff", indir / "portrait.iff"

    import_bank(c, bankout)
    import_portrait(p, portraitout)

def verify_bank(bankpath: Path, workdir: Path):
    original = load_exact(bankpath, BANK_BYTES, "character bank")
    workdir.mkdir(parents=True, exist_ok=True)
    print("original", hashlib.sha256(original).hexdigest())
    for fmt, ext in (("png", ".png"), ("ilbm", ".iff")):
        base = workdir / f"character_{fmt}"
        export_bank(bankpath, base, fmt)
        rebuilt = workdir / f"roundtrip_{fmt}.bin"
        import_bank(base.with_suffix(ext), rebuilt)
        rb = rebuilt.read_bytes()
        print(fmt, "OK" if rb == original else "FAIL", hashlib.sha256(rb).hexdigest())
        if rb != original:
            raise SystemExit(1)

def verify_set(bankpath: Path, portraitpath: Path, workdir: Path):
    bank = load_exact(bankpath, BANK_BYTES, "character bank")
    portrait = load_exact(portraitpath, PORTRAIT_BYTES, "portrait")
    workdir.mkdir(parents=True, exist_ok=True)
    for fmt in ("png", "ilbm"):
        d = workdir / f"set_{fmt}"
        export_set(bankpath, portraitpath, d, fmt)
        bo = workdir / f"bank_roundtrip_{fmt}.bin"
        po = workdir / f"portrait_roundtrip_{fmt}.bin"
        import_set(d, bo, po, fmt)
        bok = bo.read_bytes() == bank
        pok = po.read_bytes() == portrait
        print(fmt, "bank", "OK" if bok else "FAIL",
              "portrait", "OK" if pok else "FAIL")
        if not (bok and pok):
            raise SystemExit(1)



def launch_ui():
    """Launch the pure-Pygame front-end.

    No Tk/Tkinter is used. File and folder selection is handled by a small
    browser rendered inside the Pygame window, so the UI only depends on
    Pygame + Pillow.
    """
    try:
        import pygame
    except ImportError:
        print(
            "error: Pygame is required for the UI. Install with: "
            "python3 -m pip install pygame pillow",
            file=sys.stderr,
        )
        raise SystemExit(2)

    pygame.init()
    pygame.display.set_caption("Dalek Attack Character Tool")
    screen = pygame.display.set_mode((1320, 900), pygame.RESIZABLE)
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 24)
    small = pygame.font.Font(None, 20)
    tiny = pygame.font.Font(None, 17)
    title_font = pygame.font.Font(None, 34)

    state = {
        "disk1": None,
        "disk2": None,
        "bank": None,
        "portrait": None,
        "hoverbout": None,
        "sheet": None,
        "portrait_edit": None,
        "hoverbout_edit": None,
        "workdir": Path.cwd() / "work",
        "browser_dir": Path.cwd(),
        "status": [
            "Choose Disk.1 for characters/portraits and Disk.2 for the Level 1 hoverbout templates.",
            "Characters + hoverbout use playfield palette; portraits use menu/HUD. Index 0 is shown as magenta ($F0F).",
        ],
        "notice": "Ready",
        "notice_error": False,
    }

    class Button:
        def __init__(self, x, y, w, h, text, callback):
            self.rect = pygame.Rect(x, y, w, h)
            self.text = text
            self.callback = callback
            self.hover = False

        def draw(self, surf):
            bg = (78, 84, 96) if not self.hover else (98, 106, 122)
            pygame.draw.rect(surf, bg, self.rect, border_radius=5)
            pygame.draw.rect(surf, (170, 176, 190), self.rect, 1, border_radius=5)
            label = small.render(self.text, True, (245, 245, 248))
            surf.blit(label, label.get_rect(center=self.rect.center))

        def handle(self, event):
            if event.type == pygame.MOUSEMOTION:
                self.hover = self.rect.collidepoint(event.pos)
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if self.rect.collidepoint(event.pos):
                    self.callback()

    def add_status(msg):
        lines = str(msg).splitlines() or [""]
        state["status"].extend(lines)
        state["status"] = state["status"][-8:]
        # Always surface the most recent result at the top of the UI as well
        # as in the scrolling status box.  Rejected imports therefore cannot
        # fail silently.
        state["notice"] = lines[-1]
        state["notice_error"] = str(lines[-1]).upper().startswith("ERROR")

    def shortpath(p, maxlen=74):
        if not p:
            return "(not selected)"
        t = str(p)
        return t if len(t) <= maxlen else "..." + t[-(maxlen - 3):]

    def draw_text_clipped(surface, text, pos, maxw, colour=(230, 230, 234), fnt=None):
        fnt = fnt or tiny
        shown = str(text)
        if fnt.size(shown)[0] > maxw:
            while shown and fnt.size("..." + shown)[0] > maxw:
                shown = shown[1:]
            shown = "..." + shown
        surface.blit(fnt.render(shown, True, colour), pos)

    def browser(title, mode="open", extensions=None, initial_name=""):
        """Pure-Pygame file/folder browser.

        mode: open, save, dir
        extensions: iterable like {'.bin'}; None means all files.
        """
        current = state.get("browser_dir") or Path.cwd()
        try:
            current = current.resolve()
        except Exception:
            current = Path.cwd()
        selected = None
        filename = initial_name
        scroll = 0
        last_click_item = None
        last_click_time = 0
        pygame.key.start_text_input()

        def entries():
            try:
                items = list(current.iterdir())
            except Exception:
                return []
            dirs = sorted([x for x in items if x.is_dir()], key=lambda x: x.name.lower())
            files = sorted([x for x in items if x.is_file()], key=lambda x: x.name.lower())
            if extensions:
                exts = {e.lower() for e in extensions}
                files = [x for x in files if x.suffix.lower() in exts]
            return dirs + files

        while True:
            winw, winh = screen.get_size()
            panel = pygame.Rect(max(30, (winw-900)//2), max(20, (winh-650)//2), min(900, winw-60), min(650, winh-40))
            list_rect = pygame.Rect(panel.x+20, panel.y+100, panel.w-40, panel.h-205 if mode == "save" else panel.h-160)
            row_h = 26
            visible = max(1, list_rect.h // row_h)
            items = entries()
            max_scroll = max(0, len(items)-visible)
            scroll = max(0, min(scroll, max_scroll))

            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    pygame.key.stop_text_input()
                    return None
                if ev.type == pygame.KEYDOWN:
                    if ev.key == pygame.K_ESCAPE:
                        pygame.key.stop_text_input()
                        return None
                    if ev.key == pygame.K_BACKSPACE and mode == "save":
                        filename = filename[:-1]
                    elif ev.key == pygame.K_RETURN:
                        if mode == "dir":
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return current
                        if mode == "save" and filename.strip():
                            out = current / filename.strip()
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return out
                        if mode == "open" and selected and selected.is_file():
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return selected
                    elif ev.key == pygame.K_UP:
                        scroll = max(0, scroll-1)
                    elif ev.key == pygame.K_DOWN:
                        scroll = min(max_scroll, scroll+1)
                elif ev.type == pygame.TEXTINPUT and mode == "save":
                    # Avoid path separators so save stays in selected folder.
                    filename += ev.text.replace("/", "").replace("\\", "")
                elif ev.type == pygame.MOUSEWHEEL:
                    scroll = max(0, min(max_scroll, scroll - ev.y*3))
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    mx, my = ev.pos
                    up_rect = pygame.Rect(panel.x+20, panel.y+58, 80, 30)
                    select_rect = pygame.Rect(panel.right-260, panel.bottom-46, 110, 30)
                    cancel_rect = pygame.Rect(panel.right-140, panel.bottom-46, 110, 30)
                    if up_rect.collidepoint(mx, my):
                        parent = current.parent
                        if parent != current:
                            current = parent
                            selected = None
                            scroll = 0
                    elif cancel_rect.collidepoint(mx, my):
                        pygame.key.stop_text_input()
                        return None
                    elif select_rect.collidepoint(mx, my):
                        if mode == "dir":
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return current
                        if mode == "save" and filename.strip():
                            out = current / filename.strip()
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return out
                        if mode == "open" and selected and selected.is_file():
                            state["browser_dir"] = current
                            pygame.key.stop_text_input()
                            return selected
                    elif list_rect.collidepoint(mx, my):
                        idx = scroll + int((my-list_rect.y)//row_h)
                        if 0 <= idx < len(items):
                            item = items[idx]
                            now = pygame.time.get_ticks()
                            if item == last_click_item and now-last_click_time < 450:
                                if item.is_dir():
                                    current = item
                                    selected = None
                                    scroll = 0
                                elif mode == "open":
                                    state["browser_dir"] = current
                                    pygame.key.stop_text_input()
                                    return item
                                elif mode == "save":
                                    filename = item.name
                            else:
                                selected = item
                                if mode == "save" and item.is_file():
                                    filename = item.name
                            last_click_item = item
                            last_click_time = now

            screen.fill((18, 20, 25))
            pygame.draw.rect(screen, (34, 37, 45), panel, border_radius=8)
            pygame.draw.rect(screen, (120, 126, 140), panel, 1, border_radius=8)
            screen.blit(font.render(title, True, (245, 245, 248)), (panel.x+20, panel.y+18))
            draw_text_clipped(screen, current, (panel.x+115, panel.y+65), panel.w-150, (210,214,222), tiny)

            up_rect = pygame.Rect(panel.x+20, panel.y+58, 80, 30)
            pygame.draw.rect(screen, (75, 81, 93), up_rect, border_radius=4)
            screen.blit(small.render("Up", True, (245,245,248)), small.render("Up", True, (245,245,248)).get_rect(center=up_rect.center))

            pygame.draw.rect(screen, (20, 22, 28), list_rect)
            pygame.draw.rect(screen, (88, 94, 107), list_rect, 1)
            for j, item in enumerate(items[scroll:scroll+visible]):
                rr = pygame.Rect(list_rect.x+2, list_rect.y+j*row_h+1, list_rect.w-4, row_h-1)
                if item == selected:
                    pygame.draw.rect(screen, (72, 83, 105), rr)
                prefix = "[DIR] " if item.is_dir() else "      "
                draw_text_clipped(screen, prefix+item.name, (rr.x+6, rr.y+5), rr.w-12, (232,234,240), tiny)

            if mode == "save":
                label_y = list_rect.bottom + 18
                screen.blit(tiny.render("Filename:", True, (210,214,222)), (panel.x+20, label_y+5))
                field = pygame.Rect(panel.x+100, label_y, panel.w-140, 30)
                pygame.draw.rect(screen, (15,17,22), field)
                pygame.draw.rect(screen, (110,116,130), field, 1)
                draw_text_clipped(screen, filename+"|", (field.x+6, field.y+7), field.w-12, (245,245,248), tiny)

            select_rect = pygame.Rect(panel.right-260, panel.bottom-46, 110, 30)
            cancel_rect = pygame.Rect(panel.right-140, panel.bottom-46, 110, 30)
            for rr, label in ((select_rect, "Select" if mode != "save" else "Save"), (cancel_rect, "Cancel")):
                pygame.draw.rect(screen, (75,81,93), rr, border_radius=4)
                pygame.draw.rect(screen, (145,151,164), rr, 1, border_radius=4)
                lab = small.render(label, True, (245,245,248))
                screen.blit(lab, lab.get_rect(center=rr.center))
            hint = "Double-click a folder to open it. ESC cancels."
            if mode == "dir":
                hint = "Navigate to the folder, then click Select. ESC cancels."
            elif mode == "save":
                hint = "Navigate, type a filename, then click Save. ESC cancels."
            screen.blit(tiny.render(hint, True, (165,171,184)), (panel.x+20, panel.bottom-42))
            pygame.display.flip()
            clock.tick(30)

    def choose_disk1():
        p = browser("Choose Dalek Attack Disk.1", "open", None)
        if not p:
            return
        try:
            size = p.stat().st_size
            if size != DISK1_EXPECTED_SIZE:
                raise ValueError(
                    f"Disk image must be {DISK1_EXPECTED_SIZE} bytes, got {size}"
                )
            # Validate the five known character streams before accepting it.
            data = p.read_bytes()
            for i, off in enumerate(ORIGINAL_CHARACTER_ICE_OFFSETS, 1):
                if data[off:off + 4] not in (b"Ice!", b"ICE!"):
                    raise ValueError(f"missing CHAR{i} Ice! stream at ${off:06X}")
            state["disk1"] = p
            state["browser_dir"] = p.parent
            add_status(f"Loaded Disk.1: {p.name} ({size} bytes)")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def extract_disk_originals():
        if not state["disk1"]:
            add_status("ERROR: choose Disk.1 first.")
            return
        d = browser("Choose folder for extracted original characters", "dir")
        if not d:
            return
        try:
            out = d / "dalek_original_characters"
            results = extract_originals_from_disk1(state["disk1"], out, editable=True)
            state["workdir"] = out
            # Load CHAR1 immediately so the extraction result is visible.
            state["bank"], state["portrait"] = results[0]
            state["sheet"] = out / "CHAR1.png"
            state["portrait_edit"] = out / "CHAR1_portrait.png"
            add_status(f"Extracted 5 raw character banks + 5 portraits to {out}")
            add_status("Also exported all five as editable PNG + ILBM. CHAR1 loaded for preview.")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def choose_disk2():
        p = browser("Choose Dalek Attack Disk.2", "open", None)
        if not p:
            return
        try:
            size = p.stat().st_size
            if size != DISK2_EXPECTED_SIZE:
                raise ValueError(
                    f"Disk image must be {DISK2_EXPECTED_SIZE} bytes, got {size}"
                )
            data = p.read_bytes()
            if data[SPRITES1_ICE_OFFSET:SPRITES1_ICE_OFFSET + 4] not in (b"Ice!", b"ICE!"):
                raise ValueError(
                    f"missing SPRITES1 Ice! stream at ${SPRITES1_ICE_OFFSET:06X}"
                )
            state["disk2"] = p
            state["browser_dir"] = p.parent
            add_status(f"Loaded Disk.2: {p.name} ({size} bytes)")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def extract_hoverbouts_ui():
        if not state["disk2"]:
            add_status("ERROR: choose Disk.2 first.")
            return
        d = browser("Choose folder for Level 1 hoverbout frames", "dir")
        if not d:
            return
        try:
            out = d / "dalek_hoverbouts"
            results = extract_hoverbouts_from_disk2(state["disk2"], out, editable=True)
            state["workdir"] = out
            state["hoverbout"] = results[-1]
            state["hoverbout_edit"] = out / "CHAR6_hoverbout_template.png"
            add_status(f"Extracted 5 original riders + empty CHAR6 template to {out}")
            add_status("CHAR6 hoverbout template loaded for preview.")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def choose_hoverbout():
        p = browser("Choose raw hoverbout frame ($0380)", "open", {".bin"})
        if not p:
            return
        try:
            load_exact(p, HOVERBOUT_BYTES, "hoverbout frame")
            state["hoverbout"] = p
            state["hoverbout_edit"] = None
            add_status(
                f"Loaded hoverbout: {p.name} "
                f"({HOVERBOUT_BYTES} bytes / $0380) - preview updated"
            )
        except Exception as e:
            add_status(f"ERROR: {e}")

    def choose_hoverbout_edit():
        p = browser("Choose edited hoverbout frame", "open", {".png", ".iff", ".ilbm"})
        if not p:
            return
        try:
            if p.suffix.lower() == ".png":
                with Image.open(p) as im:
                    image_to_indices(
                        im, HOVERBOUT_W, HOVERBOUT_H,
                        EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield"
                    )
            else:
                read_ilbm_indices(p, HOVERBOUT_W, HOVERBOUT_H)
            state["hoverbout_edit"] = p
            add_status(
                f"Loaded edited hoverbout: {p.name} - "
                f"{crop_note(p, HOVERBOUT_W, HOVERBOUT_H)}"
            )
        except Exception as e:
            add_status(f"ERROR: edited hoverbout rejected: {e}")

    def choose_bank():
        p = browser("Choose raw character bank ($7080)", "open", {".bin"})
        if not p:
            return
        try:
            load_exact(p, BANK_BYTES, "character bank")
            state["bank"] = p
            state["sheet"] = None
            add_status(f"Loaded character bank: {p.name} ({BANK_BYTES} bytes / $7080) - preview updated")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def choose_portrait():
        p = browser("Choose raw portrait ($0200)", "open", {".bin"})
        if not p:
            return
        try:
            load_exact(p, PORTRAIT_BYTES, "portrait")
            state["portrait"] = p
            state["portrait_edit"] = None
            add_status(f"Loaded portrait: {p.name} ({PORTRAIT_BYTES} bytes / $0200) - preview updated")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def choose_sheet():
        p = browser("Choose edited character sheet", "open", {".png", ".iff", ".ilbm"})
        if not p:
            return
        try:
            if p.suffix.lower() == ".png":
                with Image.open(p) as im:
                    image_to_indices(im, SHEET_W, SHEET_H, EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield")
            else:
                read_ilbm_indices(p, SHEET_W, SHEET_H)
            state["sheet"] = p
            add_status(f"Loaded edited sheet: {p.name} - {crop_note(p, SHEET_W, SHEET_H)}")
        except Exception as e:
            add_status(f"ERROR: edited sheet rejected: {e}")

    def choose_portrait_edit():
        p = browser("Choose edited portrait", "open", {".png", ".iff", ".ilbm"})
        if not p:
            return
        try:
            if p.suffix.lower() == ".png":
                with Image.open(p) as im:
                    image_to_indices(im, PORTRAIT_W, PORTRAIT_H, EDITOR_RGB_PORTRAIT, GAME_RGB_PORTRAIT, "portrait/menu")
            else:
                read_ilbm_indices(p, PORTRAIT_W, PORTRAIT_H)
            state["portrait_edit"] = p
            add_status(f"Loaded edited portrait: {p.name} - {crop_note(p, PORTRAIT_W, PORTRAIT_H)}")
        except Exception as e:
            add_status(f"ERROR: edited portrait rejected: {e}")

    def choose_workdir():
        p = browser("Choose work/output folder", "dir")
        if p:
            state["workdir"] = p
            add_status(f"Work folder: {p}")

    def export_character():
        if not state["bank"]:
            add_status("ERROR: choose a raw character bank first.")
            return
        try:
            wd = state["workdir"]
            wd.mkdir(parents=True, exist_ok=True)
            base = wd / state["bank"].stem
            export_bank(state["bank"], base, "both")
            state["sheet"] = base.with_suffix(".png")
            add_status(f"Exported {base.name}.png + {base.name}.iff to {wd}")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def export_portrait_ui():
        if not state["portrait"]:
            add_status("ERROR: choose a raw portrait first.")
            return
        try:
            wd = state["workdir"]
            wd.mkdir(parents=True, exist_ok=True)
            base = wd / state["portrait"].stem
            export_portrait(state["portrait"], base, "both")
            state["portrait_edit"] = base.with_suffix(".png")
            add_status(f"Exported {base.name}.png + {base.name}.iff to {wd}")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def export_hoverbout_ui():
        if not state["hoverbout"]:
            add_status("ERROR: choose a raw hoverbout frame first.")
            return
        try:
            wd = state["workdir"]
            wd.mkdir(parents=True, exist_ok=True)
            base = wd / state["hoverbout"].stem
            export_hoverbout(state["hoverbout"], base, "both")
            state["hoverbout_edit"] = base.with_suffix(".png")
            add_status(f"Exported {base.name}.png + {base.name}.iff to {wd}")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def export_both():
        if not state["bank"] or not state["portrait"]:
            add_status("ERROR: choose both a raw character bank and raw portrait first.")
            return
        d = browser("Choose folder for complete editable character set", "dir")
        if not d:
            return
        try:
            export_set(state["bank"], state["portrait"], d, "both")
            state["workdir"] = d
            state["sheet"] = d / "character.png"
            state["portrait_edit"] = d / "portrait.png"
            add_status(f"Exported complete editable set to {d}")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def build_character():
        if not state["sheet"]:
            add_status("ERROR: choose an edited character PNG/ILBM first.")
            return
        suggested = (state["bank"].stem + "_NEW.bin") if state["bank"] else "CHAR_NEW.bin"
        out = browser("Save reconstructed $7080 character bank", "save", {".bin"}, suggested)
        if not out:
            return
        if out.suffix.lower() != ".bin":
            out = out.with_suffix(".bin")
        try:
            import_bank(state["sheet"], out)
            add_status(f"Built {out.name}: {out.stat().st_size} bytes / $7080")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def build_portrait():
        if not state["portrait_edit"]:
            add_status("ERROR: choose an edited portrait PNG/ILBM first.")
            return
        suggested = (state["portrait"].stem + "_NEW.bin") if state["portrait"] else "CHAR_portrait_NEW.bin"
        out = browser("Save reconstructed $0200 portrait", "save", {".bin"}, suggested)
        if not out:
            return
        if out.suffix.lower() != ".bin":
            out = out.with_suffix(".bin")
        try:
            import_portrait(state["portrait_edit"], out)
            add_status(f"Built {out.name}: {out.stat().st_size} bytes / $0200")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def build_hoverbout():
        if not state["hoverbout_edit"]:
            add_status("ERROR: choose an edited hoverbout PNG/ILBM first.")
            return
        suggested = (
            state["hoverbout"].stem.replace("_template", "") + "_NEW.bin"
            if state["hoverbout"] else "CHAR6_hoverbout.bin"
        )
        out = browser("Save reconstructed $0380 hoverbout frame", "save", {".bin"}, suggested)
        if not out:
            return
        if out.suffix.lower() != ".bin":
            out = out.with_suffix(".bin")
        try:
            import_hoverbout(state["hoverbout_edit"], out)
            add_status(f"Built {out.name}: {out.stat().st_size} bytes / $0380")
        except Exception as e:
            add_status(f"ERROR: {e}")

    def verify_character_ui():
        if not state["bank"]:
            add_status("ERROR: choose a raw character bank first.")
            return
        try:
            original = load_exact(state["bank"], BANK_BYTES, "character bank")
            wd = state["workdir"] / "verify_character"
            wd.mkdir(parents=True, exist_ok=True)
            results = []
            for fmt, ext in (("png", ".png"), ("ilbm", ".iff")):
                base = wd / f"character_{fmt}"
                export_bank(state["bank"], base, fmt)
                rebuilt = wd / f"roundtrip_{fmt}.bin"
                import_bank(base.with_suffix(ext), rebuilt)
                results.append((fmt, rebuilt.read_bytes() == original))
            add_status("Character round-trip: " + ", ".join(f"{f.upper()} {'OK' if ok else 'FAIL'}" for f, ok in results))
        except Exception as e:
            add_status(f"ERROR: {e}")

    def verify_portrait_ui():
        if not state["portrait"]:
            add_status("ERROR: choose a raw portrait first.")
            return
        try:
            original = load_exact(state["portrait"], PORTRAIT_BYTES, "portrait")
            wd = state["workdir"] / "verify_portrait"
            wd.mkdir(parents=True, exist_ok=True)
            results = []
            for fmt, ext in (("png", ".png"), ("ilbm", ".iff")):
                base = wd / f"portrait_{fmt}"
                export_portrait(state["portrait"], base, fmt)
                rebuilt = wd / f"roundtrip_{fmt}.bin"
                import_portrait(base.with_suffix(ext), rebuilt)
                results.append((fmt, rebuilt.read_bytes() == original))
            add_status("Portrait round-trip: " + ", ".join(f"{f.upper()} {'OK' if ok else 'FAIL'}" for f, ok in results))
        except Exception as e:
            add_status(f"ERROR: {e}")

    def verify_hoverbout_ui():
        if not state["hoverbout"]:
            add_status("ERROR: choose a raw hoverbout frame first.")
            return
        try:
            original = load_exact(state["hoverbout"], HOVERBOUT_BYTES, "hoverbout frame")
            wd = state["workdir"] / "verify_hoverbout"
            wd.mkdir(parents=True, exist_ok=True)
            results = []
            for fmt, ext in (("png", ".png"), ("ilbm", ".iff")):
                base = wd / f"hoverbout_{fmt}"
                export_hoverbout(state["hoverbout"], base, fmt)
                rebuilt = wd / f"roundtrip_{fmt}.bin"
                import_hoverbout(base.with_suffix(ext), rebuilt)
                results.append((fmt, rebuilt.read_bytes() == original))
            add_status(
                "Hoverbout round-trip: " +
                ", ".join(f"{f.upper()} {'OK' if ok else 'FAIL'}" for f, ok in results)
            )
        except Exception as e:
            add_status(f"ERROR: {e}")

    def load_preview_indices(path, kind):
        try:
            if not path:
                return None
            if kind == "character":
                if path.suffix.lower() == ".bin":
                    return bank_to_sheet_indices(load_exact(path, BANK_BYTES, "character bank"))
                if path.suffix.lower() == ".png":
                    with Image.open(path) as im:
                        return image_to_indices(
                            im, SHEET_W, SHEET_H,
                            EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield"
                        )
                return read_ilbm_indices(path, SHEET_W, SHEET_H)
            if kind == "portrait":
                if path.suffix.lower() == ".bin":
                    return decode_planar(
                        load_exact(path, PORTRAIT_BYTES, "portrait"),
                        PORTRAIT_W, PORTRAIT_H
                    )
                if path.suffix.lower() == ".png":
                    with Image.open(path) as im:
                        return image_to_indices(
                            im, PORTRAIT_W, PORTRAIT_H,
                            EDITOR_RGB_PORTRAIT, GAME_RGB_PORTRAIT, "portrait/menu"
                        )
                return read_ilbm_indices(path, PORTRAIT_W, PORTRAIT_H)
            if kind == "hoverbout":
                if path.suffix.lower() == ".bin":
                    return decode_planar(
                        load_exact(path, HOVERBOUT_BYTES, "hoverbout frame"),
                        HOVERBOUT_W, HOVERBOUT_H
                    )
                if path.suffix.lower() == ".png":
                    with Image.open(path) as im:
                        return image_to_indices(
                            im, HOVERBOUT_W, HOVERBOUT_H,
                            EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield"
                        )
                return read_ilbm_indices(path, HOVERBOUT_W, HOVERBOUT_H)
        except Exception:
            return None

    def surface_from_indices(indices, w, h, scale, editor_rgb):
        if indices is None:
            return None
        rgb = bytearray()
        for i in indices:
            rgb.extend(editor_rgb[i])
        surf = pygame.image.frombuffer(bytes(rgb), (w, h), "RGB").copy()
        return pygame.transform.scale(surf, (w * scale, h * scale))

    def accept_drop(path):
        p = Path(path)
        try:
            if p.is_dir():
                state["workdir"] = p
                state["browser_dir"] = p
                add_status(f"Dropped folder -> work folder: {p}")
                return
            ext = p.suffix.lower()
            if p.stat().st_size == DISK1_EXPECTED_SIZE:
                data = p.read_bytes()
                if all(data[o:o+4] in (b"Ice!", b"ICE!") for o in ORIGINAL_CHARACTER_ICE_OFFSETS):
                    state["disk1"] = p
                    state["browser_dir"] = p.parent
                    add_status(f"Dropped Disk.1: {p.name}")
                    return
            if ext == ".bin":
                size = p.stat().st_size
                if size == BANK_BYTES:
                    state["bank"] = p
                    state["sheet"] = None
                    add_status(f"Dropped character bank: {p.name} - preview updated")
                elif size == PORTRAIT_BYTES:
                    state["portrait"] = p
                    state["portrait_edit"] = None
                    add_status(f"Dropped portrait bank: {p.name} - preview updated")
                elif size == HOVERBOUT_BYTES:
                    state["hoverbout"] = p
                    state["hoverbout_edit"] = None
                    add_status(f"Dropped hoverbout frame: {p.name} - preview updated")
                else:
                    add_status(
                        f"ERROR: .bin is {size} bytes; expected $7080, $0200 or $0380"
                    )
            elif ext in (".png", ".iff", ".ilbm"):
                try:
                    w, h, _ = graphic_dimensions(p)
                    # Filename hint resolves oversized DPaint hoverbout canvases,
                    # which would otherwise also be large enough for a char sheet.
                    if "hover" in p.stem.lower() and w >= HOVERBOUT_W and h >= HOVERBOUT_H:
                        if ext == ".png":
                            with Image.open(p) as im:
                                image_to_indices(
                                    im, HOVERBOUT_W, HOVERBOUT_H,
                                    EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield"
                                )
                        else:
                            read_ilbm_indices(p, HOVERBOUT_W, HOVERBOUT_H)
                        state["hoverbout_edit"] = p
                        add_status(
                            f"Dropped edited hoverbout: {p.name} - "
                            f"{crop_note(p, HOVERBOUT_W, HOVERBOUT_H)}"
                        )
                    # A canvas large enough for 288x200 is otherwise treated as
                    # a character sheet. This catches standard DPaint 320x256.
                    elif w >= SHEET_W and h >= SHEET_H:
                        if ext == ".png":
                            with Image.open(p) as im:
                                image_to_indices(im, SHEET_W, SHEET_H, EDITOR_RGB_PLAYFIELD, GAME_RGB_PLAYFIELD, "playfield")
                        else:
                            read_ilbm_indices(p, SHEET_W, SHEET_H)
                        state["sheet"] = p
                        add_status(f"Dropped edited sheet: {p.name} - {crop_note(p, SHEET_W, SHEET_H)}")
                    elif w >= PORTRAIT_W and h >= PORTRAIT_H:
                        if ext == ".png":
                            with Image.open(p) as im:
                                image_to_indices(im, PORTRAIT_W, PORTRAIT_H, EDITOR_RGB_PORTRAIT, GAME_RGB_PORTRAIT, "portrait/menu")
                        else:
                            read_ilbm_indices(p, PORTRAIT_W, PORTRAIT_H)
                        state["portrait_edit"] = p
                        add_status(f"Dropped edited portrait: {p.name} - {crop_note(p, PORTRAIT_W, PORTRAIT_H)}")
                    else:
                        add_status(f"ERROR: graphic is {w}x{h}; too small for character, portrait or hoverbout")
                except Exception as e:
                    add_status(f"ERROR: dropped graphic rejected: {e}")
            else:
                add_status(f"Ignored dropped file type: {p.name}")
        except Exception as e:
            add_status(f"ERROR: {e}")

    buttons = [
        Button(24, 92, 190, 34, "Choose Disk.1", choose_disk1),
        Button(224, 92, 190, 34, "Extract 5 originals", extract_disk_originals),
        Button(424, 92, 190, 34, "Choose character .bin", choose_bank),
        Button(624, 92, 190, 34, "Choose portrait .bin", choose_portrait),
        Button(824, 92, 190, 34, "Choose edited sheet", choose_sheet),
        Button(1024, 92, 190, 34, "Choose edited portrait", choose_portrait_edit),

        Button(24, 138, 190, 34, "Choose Disk.2", choose_disk2),
        Button(224, 138, 190, 34, "Extract hoverbouts", extract_hoverbouts_ui),
        Button(424, 138, 190, 34, "Choose hoverbout .bin", choose_hoverbout),
        Button(624, 138, 190, 34, "Choose edited hover", choose_hoverbout_edit),
        Button(824, 138, 190, 34, "Work folder", choose_workdir),
        Button(1024, 138, 190, 34, "Export char+portrait", export_both),

        Button(24, 184, 190, 34, "Export character", export_character),
        Button(224, 184, 190, 34, "Export portrait", export_portrait_ui),
        Button(424, 184, 190, 34, "Export hoverbout", export_hoverbout_ui),
        Button(624, 184, 190, 34, "Build character .bin", build_character),
        Button(824, 184, 190, 34, "Build portrait .bin", build_portrait),
        Button(1024, 184, 190, 34, "Build hoverbout .bin", build_hoverbout),

        Button(24, 230, 190, 34, "Verify character", verify_character_ui),
        Button(224, 230, 190, 34, "Verify portrait", verify_portrait_ui),
        Button(424, 230, 190, 34, "Verify hoverbout", verify_hoverbout_ui),
    ]

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                running = False
            elif event.type == getattr(pygame, "DROPFILE", -999):
                accept_drop(event.file)
            for b in buttons:
                b.handle(event)

        screen.fill((28, 31, 38))
        screen.blit(title_font.render("Dalek Attack - Character / Portrait / Hoverbout Tool", True, (244, 244, 248)), (24, 20))
        screen.blit(small.render("Pure Pygame UI - no Tkinter. Drag/drop is supported.", True, (180, 186, 198)), (25, 58))
        notice_colour = (255, 125, 125) if state.get("notice_error") else (158, 225, 170)
        draw_text_clipped(screen, state.get("notice", ""), (420, 59), 710, notice_colour, tiny)

        for b in buttons:
            b.draw(screen)

        y = 278
        entries = [
            ("Disk.1", state["disk1"]),
            ("Disk.2", state["disk2"]),
            ("Raw character", state["bank"]),
            ("Raw portrait", state["portrait"]),
            ("Raw hoverbout", state["hoverbout"]),
            ("Edited sheet", state["sheet"]),
            ("Edited portrait", state["portrait_edit"]),
            ("Edited hoverbout", state["hoverbout_edit"]),
            ("Work folder", state["workdir"]),
        ]
        for label, path in entries:
            screen.blit(tiny.render(f"{label}: {shortpath(path)}", True, (205, 208, 216)), (24, y))
            y += 20

        char_source = state["sheet"] or state["bank"]
        char_indices = load_preview_indices(char_source, "character")
        char_surf = surface_from_indices(char_indices, SHEET_W, SHEET_H, 2, EDITOR_RGB_PLAYFIELD)
        char_box = pygame.Rect(24, 440, SHEET_W * 2, SHEET_H * 2)
        pygame.draw.rect(screen, (12, 12, 15), char_box)
        if char_surf:
            screen.blit(char_surf, char_box.topleft)
            for col in range(1, SHEET_COLS):
                x = char_box.x + col * FRAME_W * 2
                pygame.draw.line(screen, (85, 85, 92), (x, char_box.y), (x, char_box.bottom), 1)
            for row in range(1, SHEET_ROWS):
                yy = char_box.y + row * FRAME_H * 2
                pygame.draw.line(screen, (85, 85, 92), (char_box.x, yy), (char_box.right, yy), 1)
        pygame.draw.rect(screen, (155, 160, 172), char_box, 1)
        screen.blit(small.render("Character sheet preview - 9 x 5 frames", True, (232, 232, 236)), (24, 414))

        portrait_source = state["portrait_edit"] or state["portrait"]
        portrait_indices = load_preview_indices(portrait_source, "portrait")
        portrait_surf = surface_from_indices(portrait_indices, PORTRAIT_W, PORTRAIT_H, 6, EDITOR_RGB_PORTRAIT)
        pbox = pygame.Rect(626, 440, PORTRAIT_W * 6, PORTRAIT_H * 6)
        pygame.draw.rect(screen, (12, 12, 15), pbox)
        if portrait_surf:
            screen.blit(portrait_surf, pbox.topleft)
        pygame.draw.rect(screen, (155, 160, 172), pbox, 1)
        screen.blit(small.render("Portrait preview - 32 x 32", True, (232, 232, 236)), (626, 414))

        hover_source = state["hoverbout_edit"] or state["hoverbout"]
        hover_indices = load_preview_indices(hover_source, "hoverbout")
        hover_surf = surface_from_indices(
            hover_indices, HOVERBOUT_W, HOVERBOUT_H, 4, EDITOR_RGB_PLAYFIELD
        )
        hbox = pygame.Rect(844, 440, HOVERBOUT_W * 4, HOVERBOUT_H * 4)
        pygame.draw.rect(screen, (12, 12, 15), hbox)
        if hover_surf:
            screen.blit(hover_surf, hbox.topleft)
        pygame.draw.rect(screen, (155, 160, 172), hbox, 1)
        screen.blit(
            small.render("Hoverbout - 32 x 56", True, (232, 232, 236)),
            (844, 414)
        )

        info_x = 990
        info_y = 414
        info = [
            "CHARACTER RAW", "45 frames", "32 x 40 each",
            "9 x 5 sheet = 288 x 200", "Oversize import: crop top-left", "4 planes / 16 indexed colours",
            "$7080 = 28,800 bytes", "", "PORTRAIT RAW",
            "1 frame / 32 x 32", "4 planes / 16 indexed colours",
            "$0200 = 512 bytes", "Menu/HUD palette @ $11E92", "",
            "HOVERBOUT RAW", "1 frame / 32 x 56", "4 planes / playfield palette",
            "$0380 = 896 bytes", "", "INDEX 0",
            "Editor: $F0F / #FF00FF", "Game raw: palette index 0",
            "Do not reorder palette.",
        ]
        for line in info:
            col = (240, 240, 244) if line.isupper() and line else (195, 199, 208)
            screen.blit(tiny.render(line, True, col), (info_x, info_y))
            info_y += 19

        stat = pygame.Rect(626, 690, 668, 160)
        pygame.draw.rect(screen, (20, 22, 28), stat, border_radius=5)
        pygame.draw.rect(screen, (90, 96, 108), stat, 1, border_radius=5)
        screen.blit(small.render("Status", True, (236, 236, 240)), (638, 700))
        yy = 726
        for line in state["status"][-7:]:
            words = line.split()
            current = ""
            rows = []
            for word in words:
                test = (current + " " + word).strip()
                if tiny.size(test)[0] > 640 and current:
                    rows.append(current)
                    current = word
                else:
                    current = test
            if current:
                rows.append(current)
            for row in rows[:2]:
                screen.blit(tiny.render(row, True, (207, 211, 220)), (638, yy))
                yy += 18
                if yy > stat.bottom - 18:
                    break
            if yy > stat.bottom - 18:
                break

        screen.blit(tiny.render("ESC quits. Drag files/folders onto the window, or use the built-in Pygame browser.", True, (158, 164, 176)), (24, 875))
        pygame.display.flip()
        clock.tick(30)

    pygame.quit()

def main():
    # With no command at all, launch the UI: this makes double-click / simple
    # terminal use much friendlier while preserving the complete CLI.
    if len(sys.argv) == 1:
        launch_ui()
        return

    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sp = ap.add_subparsers(dest="cmd", required=True)

    sp.add_parser("ui", help="launch the Pygame user interface")

    p = sp.add_parser("disk-extract", help="extract all 5 original character banks + portraits from Disk.1")
    p.add_argument("disk1", type=Path)
    p.add_argument("outdir", type=Path)
    p.add_argument("--raw-only", action="store_true", help="write only .bin files; skip PNG/ILBM exports")

    p = sp.add_parser("export", help="export one $7080 character bank as one 9x5 sprite sheet")
    p.add_argument("bank", type=Path)
    p.add_argument("outbase", type=Path)
    p.add_argument("--format", choices=["png", "ilbm", "both"], default="both")

    p = sp.add_parser("import", help="import one edited 9x5 sprite sheet back to a $7080 bank")
    p.add_argument("input", type=Path)
    p.add_argument("out", type=Path)

    p = sp.add_parser("verify", help="prove PNG and ILBM round-trip against one original bank")
    p.add_argument("bank", type=Path)
    p.add_argument("workdir", type=Path)

    p = sp.add_parser("portrait-export", help="export one raw $0200 portrait as PNG/ILBM")
    p.add_argument("portrait", type=Path)
    p.add_argument("outbase", type=Path)
    p.add_argument("--format", choices=["png", "ilbm", "both"], default="both")

    p = sp.add_parser("portrait-import", help="import one edited 32x32 portrait back to $0200 raw")
    p.add_argument("input", type=Path)
    p.add_argument("out", type=Path)

    p = sp.add_parser("hoverbout-extract", help="extract Level 1 hoverbout composites from Disk.2")
    p.add_argument("disk2", type=Path)
    p.add_argument("outdir", type=Path)
    p.add_argument("--raw-only", action="store_true")

    p = sp.add_parser("hoverbout-export", help="export one raw $0380 hoverbout frame")
    p.add_argument("hoverbout", type=Path)
    p.add_argument("outbase", type=Path)
    p.add_argument("--format", choices=["png", "ilbm", "both"], default="both")

    p = sp.add_parser("hoverbout-import", help="import one edited 32x56 hoverbout frame")
    p.add_argument("input", type=Path)
    p.add_argument("out", type=Path)

    p = sp.add_parser("hoverbout-verify", help="verify hoverbout PNG/ILBM round-trip")
    p.add_argument("hoverbout", type=Path)
    p.add_argument("workdir", type=Path)

    p = sp.add_parser("set-export", help="export one character bank + its 32x32 portrait")
    p.add_argument("bank", type=Path)
    p.add_argument("portrait", type=Path)
    p.add_argument("outdir", type=Path)
    p.add_argument("--format", choices=["png", "ilbm", "both"], default="both")

    p = sp.add_parser("set-import", help="rebuild one character bank + portrait")
    p.add_argument("indir", type=Path)
    p.add_argument("bankout", type=Path)
    p.add_argument("portraitout", type=Path)
    p.add_argument("--format", choices=["auto", "png", "ilbm"], default="auto")

    p = sp.add_parser("set-verify", help="verify both bank and portrait round-trip")
    p.add_argument("bank", type=Path)
    p.add_argument("portrait", type=Path)
    p.add_argument("workdir", type=Path)

    a = ap.parse_args()
    try:
        if a.cmd == "ui":
            launch_ui()
        elif a.cmd == "disk-extract":
            extract_originals_from_disk1(a.disk1, a.outdir, editable=not a.raw_only)
            print(f"Extracted 5 characters + portraits to {a.outdir}")
        elif a.cmd == "export":
            export_bank(a.bank, a.outbase, a.format)
        elif a.cmd == "import":
            import_bank(a.input, a.out)
        elif a.cmd == "verify":
            verify_bank(a.bank, a.workdir)
        elif a.cmd == "portrait-export":
            export_portrait(a.portrait, a.outbase, a.format)
        elif a.cmd == "portrait-import":
            import_portrait(a.input, a.out)
        elif a.cmd == "hoverbout-extract":
            extract_hoverbouts_from_disk2(a.disk2, a.outdir, editable=not a.raw_only)
            print(f"Extracted Level 1 hoverbout frames to {a.outdir}")
        elif a.cmd == "hoverbout-export":
            export_hoverbout(a.hoverbout, a.outbase, a.format)
        elif a.cmd == "hoverbout-import":
            import_hoverbout(a.input, a.out)
        elif a.cmd == "hoverbout-verify":
            verify_hoverbout(a.hoverbout, a.workdir)
            print("Hoverbout PNG/ILBM round-trip OK")
        elif a.cmd == "set-export":
            export_set(a.bank, a.portrait, a.outdir, a.format)
        elif a.cmd == "set-import":
            import_set(a.indir, a.bankout, a.portraitout, a.format)
        elif a.cmd == "set-verify":
            verify_set(a.bank, a.portrait, a.workdir)
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        raise SystemExit(2)


if __name__ == "__main__":
    main()
