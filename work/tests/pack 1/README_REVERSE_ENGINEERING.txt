Dalek Attack (Amiga) – initial graphics reverse engineering
============================================================
Source images: Disk.1 and Disk.2 supplied by the user.

KEY RESULT – PLAYABLE CHARACTERS
--------------------------------
The five playable character banks are NOT WHO1:SPRITES1..5. Those are level/location sprite banks.
The five player banks live in Disk 1's WHO0:RESIDENT resource.

Runtime selection code (main game binary maps Disk.1 +$17800 -> runtime $000000):
  Player 1 selector byte: $0156(A5)
    0 -> pointer slot $E528
    1 -> pointer slot $E52C
    2/other -> pointer slot $E530
  Player 2 selector byte: $0157(A5)
    0 -> pointer slot $E534
    1/other -> pointer slot $E538

The five pointer slots are generated from the first five entries of the RESIDENT resource index.
Each selected source is copied to the working buffer and then Ice-depacked by the game's routine at runtime $D74C.

The player sprite descriptors are entries 0 and 1 in the descriptor table at runtime $1EDA6.
Both are:
  width       32 pixels
  height      40 pixels
  frames      45
  bitplanes   4
  bytes/frame 640 ($280)
  bank size   28,800 ($7080)

Full contiguous Ice blocks used for extraction from Disk.1:
  bank 1: $090E5C  packed 15859  unpacked 28800
  bank 2: $094C50  packed 15475  unpacked 28800
  bank 3: $0988C4  packed 13875  unpacked 28800
  bank 4: $09BEF8  packed 12944  unpacked 28800
  bank 5: $09F188  packed 15493  unpacked 28800

Selection/order and artwork indicate:
  bank 1 = P1 choice 0, Patrick Troughton / Second Doctor
  bank 2 = P1 choice 1, Tom Baker / Fourth Doctor
  bank 3 = P1 choice 2, Sylvester McCoy / Seventh Doctor
  bank 4 = P2 choice 0, Ace
  bank 5 = P2 choice 1, UNIT soldier

PIXEL STORAGE
-------------
The decompressed data is 4-bitplane planar graphics. For each scanline the data is:
  plane 0 bytes, plane 1 bytes, plane 2 bytes, plane 3 bytes
For a 32-pixel player frame that is 4 bytes per plane, 16 bytes per scanline, 40 lines = 640 bytes.
This is closely related to the ST-style planar organisation, but the game's own Amiga code confirms its exact row/plane traversal and also creates a 1-bit collision/transparency mask by ORing the four planes.

The supplied PNGs currently use a deliberately high-contrast DIAGNOSTIC palette. Pixel index 0 is background/transparent and the original 0..15 pixel indices are preserved. The actual gameplay palette table has not yet been tied to these indexes, so do not treat the displayed colours as original game colours.

LEVEL SPRITE BANKS
------------------
Disk 2 alternates five level tile BLOCK banks and five level SPRITES banks.
The level index is runtime $008A(A5); it is also used by the game's LOADING LONDON/PARIS/NEW YORK/TOKYO/SKARO code.

SPRITES banks (decompressed with the exact descriptor lists in the executable):
  SPRITES1 $013000 ->  90352 bytes
  SPRITES2 $031800 ->  79360 bytes
  SPRITES3 $04E200 ->  88304 bytes
  SPRITES4 $06CC00 ->  92680 bytes
  SPRITES5 $08C400 ->  75680 bytes

The descriptor table is runtime $1EDA6, 22 bytes per descriptor. The first fields are:
  +0 word width in pixels
  +2 word height in pixels
  +4 word frame count
  +6 word bytes per bitplane per frame
The game's level-specific byte lists at runtime $1F882/$1F8A0/$1F8B1/$1F8C7/$1F8DF identify which descriptor records occur in each SPRITES bank. Summing descriptor_size = frame_count * plane_bytes * 4 exactly equals each decompressed bank size, confirming the structure.

LEVEL TILE/BLOCK BANKS
----------------------
  BLOCK001 $005600 -> 138304 bytes
  BLOCK002 $022800 -> 138304 bytes
  BLOCK003 $040400 -> 138304 bytes
  BLOCK004 $05E000 -> 138304 bytes
  BLOCK005 $07C200 -> 138304 bytes

Each has a 64-byte prefix followed by exactly 1080 16x16, 4-bitplane tiles (128 bytes/tile). The generated atlases show the geometry is correct; BLOCK001 visibly contains London architecture/signage including THE TIMES / DALEKS LONDON and PUB FOOD tiles.

PACK-ICE
--------
The resources use Pack-Ice 'Ice!' compression. Dalek Attack embeds the older 32-bit backward bit-reader depacker; its length/distance tables are present in Disk.1 and match the decoder supplied here. Generic byte-buffer Ice decoders may fail on these streams.

NEXT PATCHING TARGET
--------------------
For adding player characters, the best patch point is now much narrower than the original disk-level problem:
  - keep descriptors 0/1 as the fixed 32x40x45 runtime format;
  - provide additional 28800-byte character banks in the same planar frame format;
  - extend/intercept the P1/P2 selector logic around runtime $2820/$2864; and
  - redirect the source pointer chosen from $E528..$E538 to additional data.
This avoids changing the rest of the animation/drawing code. A WHDLoad slave can potentially provide the new banks outside the original disk resource layout.
