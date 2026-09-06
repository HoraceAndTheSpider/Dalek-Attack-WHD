; Dalek Attack – character expansion patch skeleton
; -------------------------------------------------
; Integration fragment, NOT a complete replacement DalekAttack.asm.
; Addresses are runtime addresses in the main game image (loaded at $000000).
; Intended for merging into the official Bored Seal WHDLoad source.
;
; This skeleton demonstrates the safest patch split found during reverse engineering:
; selector counts -> gameplay source selection -> ChipRAM menu caches -> portraits.
;
; Exact asset-count constants and loader placement are intentionally compile-time values
; until the first proof build has been tested in-game.

P1_COUNT        EQU 4           ; original 3 + one test custom character
P2_COUNT        EQU 3           ; original 2 + one test custom character
CHAR_BANK_SIZE  EQU $7080       ; 45 * 32x40x4bpp
PORTRAIT_SIZE   EQU $0200       ; 32x32x4bpp

; Existing game locations
P1_SEL          EQU $0156       ; offset from A5
P2_SEL          EQU $0157
WORK_BANK       EQU $000055F8   ; original game ChipRAM staging bank

P1_SRC0_SLOT    EQU $0000E528   ; contains pointer to original compressed source
P1_SRC1_SLOT    EQU $0000E52C
P1_SRC2_SLOT    EQU $0000E530
P2_SRC0_SLOT    EQU $0000E534
P2_SRC1_SLOT    EQU $0000E538

; Raw/decompressed menu preview banks in ChipRAM
P1_RAW0_PTRVAR  EQU $0000E58C   ; selector 0 (preserve original mapping)
P1_RAW1_PTRVAR  EQU $0000E588   ; selector 1
P1_RAW2_PTRVAR  EQU $0000E590   ; selector 2; proposed custom-cache slot
P2_RAW0_PTRVAR  EQU $0000E594   ; selector 0
P2_RAW1_PTRVAR  EQU $0000E598   ; selector 1; proposed custom-cache slot

P1_RAW2_ADDR    EQU $0003C2D0   ; value installed in P1_RAW2_PTRVAR
P2_RAW1_ADDR    EQU $0004A3D0   ; value installed in P2_RAW1_PTRVAR

P1_PORTRAIT0    EQU $0001797A
P1_PORTRAIT1    EQU $00017B7A
P1_PORTRAIT2    EQU $00017D7A   ; proposed P1 portrait cache slot
P2_PORTRAIT0    EQU $00017F7A
P2_PORTRAIT1    EQU $0001817A   ; proposed P2 portrait cache slot

; ---------------------------------------------------------------------------
; Patch-list concept
; ---------------------------------------------------------------------------
; P1 simple fixed count:
;       PL_W    $EEC6,P1_COUNT
;
; Or, to keep limit logic in slave code instead:
;       PL_PS   $EEC4,.p1_limit_compare
;
; P2 replaces six-byte BCHG #0,$157(A5):
;       PL_PS   $EF98,.cycle_p2
;
; Replace P1/P2 gameplay selector fronts (six bytes each) with JMP hooks:
;       PL_P    $281E,.select_p1_game_bank
;       PL_P    $2862,.select_p2_game_bank
;
; Selection-screen full sprite preview fronts:
;       PL_P    $F0B2,.select_p1_preview
;       PL_P    $F0FA,.select_p2_preview
;
; Portrait source selection needs a separate hook because original code performs
; base + selector*$200. A larger selector must not reach the following tables.
; The most robust final patch is to replace the P1/P2 branch source setup with a
; custom routine that returns A4 pointing to a ChipRAM portrait source.
;
; Addresses $2518 (P1) and $2532 (P2) begin LEA base,A4, each six bytes, so PL_PS
; can replace the LEA only IF the hook returns an A4 base suitable for the original
; selector*$200 calculation. For arbitrary selectors, prefer patching a larger
; section or make the hook supply a synthetic base only after ensuring the resulting
; source remains in ChipRAM.

.p1_limit_compare
        cmpi.b  #P1_COUNT,P1_SEL(a5)     ; leave CCR exactly as original CMPI
        rts

.cycle_p2
        addq.b  #1,P2_SEL(a5)
        cmpi.b  #P2_COUNT,P2_SEL(a5)
        bne.b   .p2_ok
        clr.b   P2_SEL(a5)
.p2_ok
        rts

; ---------------------------------------------------------------------------
; Gameplay bank source selection
; ---------------------------------------------------------------------------
; Original common code at $2842/$2876 performs CPU copy via $F31A to WORK_BANK,
; followed by $D74C. Raw custom data is valid because $D74C returns immediately
; when WORK_BANK does not begin with 'Ice!'.

.select_p1_game_bank
        moveq   #0,d0
        move.b  P1_SEL(a5),d0
        cmpi.w  #3,d0
        bhs.b   .p1_custom
        add.w   d0,d0
        add.w   d0,d0
        lea     .p1_orig_slots(pc),a0
        move.l  (a0,d0.w),a0             ; A0 = address of game's pointer slot
        move.l  (a0),a0                  ; A0 = original compressed source
        jmp     $2842
.p1_custom
        subi.w  #3,d0
        add.w   d0,d0
        add.w   d0,d0
        lea     ExtraP1BankPtrs(pc),a0
        move.l  (a0,d0.w),a0             ; raw $7080 source in ExpMem
        jmp     $2842
.p1_orig_slots
        dc.l    P1_SRC0_SLOT,P1_SRC1_SLOT,P1_SRC2_SLOT

.select_p2_game_bank
        moveq   #0,d0
        move.b  P2_SEL(a5),d0
        cmpi.w  #2,d0
        bhs.b   .p2_custom
        add.w   d0,d0
        add.w   d0,d0
        lea     .p2_orig_slots(pc),a0
        move.l  (a0,d0.w),a0
        move.l  (a0),a0
        jmp     $2876
.p2_custom
        subi.w  #2,d0
        add.w   d0,d0
        add.w   d0,d0
        lea     ExtraP2BankPtrs(pc),a0
        move.l  (a0,d0.w),a0
        jmp     $2876
.p2_orig_slots
        dc.l    P2_SRC0_SLOT,P2_SRC1_SLOT

; ---------------------------------------------------------------------------
; Preview hooks – IMPORTANT: renderer source must be ChipRAM.
; ---------------------------------------------------------------------------
; For first proof build, do NOT point A0 directly at Fast/ExpMem.
; Extra source data should be CPU-copied into P1_RAW2_ADDR / P2_RAW1_ADDR first.
; Back up the original content of these two slots into ExpMem before first overwrite,
; and restore when selecting original P1 choice2 / P2 choice1.
;
; The helper Copy7080_CPU is deliberately left as an integration helper because the
; official slave may already contain a suitable copy loop/convention.

.select_p1_preview
        moveq   #0,d0
        move.b  P1_SEL(a5),d0
        cmpi.w  #2,d0
        beq.b   .p1_restore_original2
        bhi.b   .p1_load_custom
        tst.w   d0
        beq.b   .p1_prev0
        move.l  P1_RAW1_PTRVAR,a0
        jmp     $F0D0
.p1_prev0
        move.l  P1_RAW0_PTRVAR,a0
        jmp     $F0D0
.p1_restore_original2
        ; if cache currently custom, restore saved original $7080 to P1_RAW2_ADDR
        ; ... cache-state check + CPU copy ...
        move.l  P1_RAW2_PTRVAR,a0
        jmp     $F0D0
.p1_load_custom
        ; D0 = selector >=3. Convert to custom index, locate ExpMem source,
        ; CPU-copy CHAR_BANK_SIZE bytes to P1_RAW2_ADDR if selection changed.
        ; A0 must finally be P1_RAW2_ADDR (or value from P1_RAW2_PTRVAR).
        ; ...
        move.l  P1_RAW2_PTRVAR,a0
        jmp     $F0D0

.select_p2_preview
        moveq   #0,d0
        move.b  P2_SEL(a5),d0
        tst.w   d0
        beq.b   .p2_prev0
        cmpi.w  #1,d0
        beq.b   .p2_restore_original1
        ; selector >=2 -> copy custom bank to P2_RAW1_ADDR if selection changed
        ; ...
        move.l  P2_RAW1_PTRVAR,a0
        jmp     $F10A
.p2_prev0
        move.l  P2_RAW0_PTRVAR,a0
        jmp     $F10A
.p2_restore_original1
        ; restore original bank if cache currently custom
        ; ...
        move.l  P2_RAW1_PTRVAR,a0
        jmp     $F10A

; ---------------------------------------------------------------------------
; ExpMem asset pointers – filled by slave startup loader
; ---------------------------------------------------------------------------
; For P1_COUNT=4 / P2_COUNT=3 there is one extra of each.
; Increase tables with counts.
ExtraP1BankPtrs
        dc.l    0
ExtraP1PortraitPtrs
        dc.l    0
ExtraP2BankPtrs
        dc.l    0
ExtraP2PortraitPtrs
        dc.l    0

; Suggested filenames (relative paths; no colon):
P1Extra0Name    dc.b "data/P1_03.bin",0
P1Extra0PortraitName dc.b "data/P1_03_portrait.bin",0
P2Extra0Name    dc.b "data/P2_02.bin",0
P2Extra0PortraitName dc.b "data/P2_02_portrait.bin",0
        even

; Startup loading concept:
;   lea P1Extra0Name(pc),a0
;   move.l <allocated expmem address>,a1
;   move.l (_resload,pc),a2
;   jsr (resload_LoadFile,a2)
;   cmp.l #CHAR_BANK_SIZE,d0
;   bne Unsupported/Abort
;   move.l a1,ExtraP1BankPtrs
; ...same for portrait and P2 assets...
;
; resload_LoadFile destroys D0-D1/A0-A1. Preserve anything the enclosing slave
; routine needs around these calls.
