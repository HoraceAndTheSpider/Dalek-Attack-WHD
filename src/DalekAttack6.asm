;*---------------------------------------------------------------------------
;  :Program.   	  DalekAttackHD.asm
;  :Contents.  	  Slave for "Dalek Attack" from
;  :Authors.	  Bored Seal & Hungry Horace
;  :History.   	  2009-08-04 - V1.2
;		  2026-09-05 - V1.3
;		  2026-09-06 - 6-character external bank + Hoverbout fix
;	
;		This updated patch has no purpose other than to add 
;		additional characters to the game 
;

		INCDIR	Includes:
		INCLUDE	whdload.i
		INCLUDE	whdmacros.i

; ---------------------------------------------------------------------------
; Character expansion - six characters available to both players
; ---------------------------------------------------------------------------
CHARACTER_COUNT		EQU	6
CHARACTER_TABLE_SLOTS	EQU	6

CHARACTER_BANK_SIZE	EQU	$7080
PORTRAIT_SIZE		EQU	$0200

ORIGINAL_CHAR_TABLE	EQU	$e528
ORIGINAL_RUNTIME_CHAR_TABLE EQU	$e588
ORIGINAL_PORTRAIT_BASE	EQU	$1797a

; The original game is still told it has 1MB ChipRAM. WHDLoad reserves
; an additional $10000 bytes above that for the sixth character and portraits.
CHIPMEMSIZE		EQU	$110000
CHAR6_CHIP		EQU	$100000

; Six contiguous $200-byte portraits:
;   $107080-$107A7F = copies of original CHAR1..CHAR5 portraits
;   $107A80-$107C7F = externally-loaded CHAR6 portrait
PORTRAIT_BASE_ALL	EQU	$107080
PORTRAIT6_CHIP		EQU	PORTRAIT_BASE_ALL+(5*PORTRAIT_SIZE)

; Level 1 hoverbout rider graphics are SPRITES1 descriptor 21:
; 32x56, 6 frames, $380 bytes per frame. Frame 5 is the empty hoverbout.
HOVERBOUT_SIZE		EQU	$0380
HOVERBOUT6_CHIP	EQU	$107c80
LEVEL1_HOVERBOUT6_OFFSET EQU	$b680

; Selection 5 is new to the game. For non-graphics metadata, alias CHAR6
; to one of the original valid character IDs 0..4.
CHAR6_BEHAVIOUR_ID	EQU	0


		IFD BARFLY
		OUTPUT	DalekAttack.slave
		BOPT	O+				;enable optimizing
		BOPT	OG+				;enable optimizing
		BOPT	ODd-				;disable mul optimizing
		BOPT	ODe-				;disable mul optimizing
		BOPT	w4-				;disable 64k warnings
		BOPT	wo-				;disable optimizer warnings
		SUPER
		ENDC

_base		SLAVE_HEADER			;ws_Security + ws_ID
		dc.w	17			;ws_Version
		dc.w	WHDLF_NoError|WHDLF_EmulTrap|WHDLF_ClearMem|WHDLF_NoDivZero
		dc.l	CHIPMEMSIZE		;ws_BaseMemSize
		dc.l	0			;ws_ExecInstall
		dc.w	_Start-_base		;ws_GameLoader
		dc.w	0			;ws_CurrentDir
		dc.w	0			;ws_DontCache
_keydebug	dc.b	0			;ws_keydebug
_keyexit	dc.b	$50			;ws_keyexit = F1
_expmem		IFD	USE_FASTMEM	
		dc.l	EXPMEMSIZE		;ws_ExpMem
		ELSE
		dc.l	0
		ENDC

		dc.w	_name-_base		;ws_name
		dc.w	_copy-_base		;ws_copy
		dc.w	_info-_base		;ws_info

		dc.w	0			; ws_kickname
		dc.l	0			; ws_kicksize
		dc.w	0			; ws_kickcrc
		dc.w	_config-_base		

_config:	dc.b    "C1:X:Player 1 Infinite Lives:0;"	; ws_config;	
		dc.b    "C2:X:Extra Characters:0;"
		dc.b    0


		IFD BARFLY
		DOSCMD	"WDate  >T:date"
		ENDC

DECL_VERSION:MACRO
			dc.b	"1.6 (Alpha)"
		IFD BARFLY
			dc.b	" "
			INCBIN	"T:date"
		ENDC
		ENDM

_name		dc.b	"Dalek Attack",0
_copy		dc.b	"1992 Alternative",0
_info		dc.b	"installed & fixed by Bored Seal",10
		dc.b	"Additions by Hungry Horace",10,10
		dc.b	"Version "
		DECL_VERSION
		dc.b	0
_dir		dc.b	"data",0

		even

; version xx.slave works

		dc.b	"$","VER: slave "
		DECL_VERSION
		dc.b	$A,$D,0
		even

;==========================

_Start		lea	(_resload,pc),a1
		move.l	a0,(a1)
		move.l	a0,a2
                lea     (_tags,pc),a0
                jsr     (resload_Control,a2)

		moveq	#8,d1
		move.l	#$b8,d2
		lea	$800,a0
		bsr	LoadRNCTracks

		move.w	#$4ef9,$3142
		pea	LoadRNCTracks
		move.l	(sp)+,$3144

		move.l	#$24094e71,$41b6	;force $100000 memory

		move.l	#$2b90,$78		;fix autovector event

		pea	PatchMenu
		move.l	(sp)+,$ca2

		jmp	(a0)

PatchMenu	move.w	#$4ef9,$78162
		pea	LoadRNCTracks
		move.l	(sp)+,$78164

		move.w	#$4ef9,$7fa
		pea	PatchGame
		move.l	(sp)+,$7fc
		move.w	#$7fa,$78040

		jmp	$78000

PatchGame	movem.l	a0-a2/d0-d2,-(sp)
		lea	_custom1,a0
		tst.l	(a0)
		beq	NoTrainer

		move.w	#$6004,$6194		;unlimited lives
;		move.w	#$6002,$e61a		;unlimited continues

;$96384 = number of hostages to rescue
;$91cf4 = grenades

NoTrainer	lea	_gamepatch(pc),a0
		lea	_custom2(pc),a1
		tst.l	(a1)
		beq.b	.ApplyPatches

		; CUSTOM2 enables all extra-character loading and patches.
		bsr	LoadCharacter6Assets
		lea	_character_patch(pc),a0

.ApplyPatches	suba.l	a1,a1
		move.l	_resload(pc),a2
		jsr	resload_Patch(a2)
		movem.l	(sp)+,a0-a2/d0-d2

		bsr	LoadHi
		jmp	$800

_character_patch	PL_START
		; Optional extra-character patch list (CUSTOM2).
		PL_P	$281e,SelectP1Character
		PL_P	$2862,SelectP2Character
		PL_W	$ebde,CHARACTER_COUNT
		PL_W	$eec6,CHARACTER_COUNT
		PL_PS	$ef98,CycleP2Character

		PL_L	$251a,PORTRAIT_BASE_ALL
		PL_L	$2534,PORTRAIT_BASE_ALL

		PL_P	$f0b2,SelectP1RuntimeGraphics
		PL_P	$f0fa,SelectP2RuntimeGraphics

		PL_PS	$1fb8,SetP1CharacterID
		PL_PS	$1ff2,SetP2CharacterIDBase

		; Level 1 Hoverbout:
		; $26B2 is the original BSR.W $5562 followed by RTS at $26B6.
		; PL_P replaces both with a JMP to our wrapper. The wrapper inserts
		; CHAR6 into the raw SPRITES1 bank, then JMPs to the original $5562
		; descriptor/mask builder; its RTS returns directly to the caller.
		PL_P	$26b2,BuildLevelSprites

		PL_NEXT	_gamepatch

_gamepatch	PL_START
		PL_P	$112f2,LoadRNCTracks
		PL_P	$dc00,InsertDisk1
		PL_P	$dc5e,InsertDisk2
		PL_PS	$106a4,SaveHi_Sub
		PL_R	$fc3a
		PL_L	$11274,$24094e71

		PL_PS	$5738,AccessFault1
		PL_PS	$a07c,AccessFault2
		PL_PS	$a0d4,AccessFault2
		PL_W	$1036,$4e71
		PL_PS	$1038,AccessFault3
		PL_END

; ---------------------------------------------------------------------------
; Character expansion test routines
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; External CHAR6 asset loading
; ---------------------------------------------------------------------------
; Expected files relative to the existing data/ current directory:
;   chars/CHAR6.bin             exactly $7080 bytes
;   chars/CHAR6_portrait.bin    exactly $0200 bytes
;   chars/CHAR6_hoverbout.bin  exactly $0380 bytes
;
; This corresponds to data/chars/... in the installed game drawer.
; PatchGame runs after the main game image is resident, so the original
; portrait data at $1797a is available to copy here.
LoadCharacter6Assets
		movem.l	d0-d7/a0-a6,-(sp)
		move.l	(_resload,pc),a2

		; Validate both files before writing to the reserved memory.
		lea	Char6Filename(pc),a0
		jsr	(resload_GetFileSize,a2)
		cmp.l	#CHARACTER_BANK_SIZE,d0
		bne	.badCharacter

		lea	Char6PortraitFilename(pc),a0
		jsr	(resload_GetFileSize,a2)
		cmp.l	#PORTRAIT_SIZE,d0
		bne	.badPortrait

		lea	Char6HoverboutFilename(pc),a0
		jsr	(resload_GetFileSize,a2)
		cmp.l	#HOVERBOUT_SIZE,d0
		bne	.badHoverbout

		; Copy the five original portraits into the six-entry ChipRAM block.
		movea.l	#ORIGINAL_PORTRAIT_BASE,a0
		movea.l	#PORTRAIT_BASE_ALL,a1
		move.w	#$027f,d0		; $0a00 bytes / 4 - 1
.copyPortraits	move.l	(a0)+,(a1)+
		dbf	d0,.copyPortraits

		; CHAR6.bin is already raw/decompressed game-format data.
		lea	Char6Filename(pc),a0
		movea.l	#CHAR6_CHIP,a1
		jsr	(resload_LoadFile,a2)

		; Sixth portrait goes immediately after the five copied originals.
		lea	Char6PortraitFilename(pc),a0
		movea.l	#PORTRAIT6_CHIP,a1
		jsr	(resload_LoadFile,a2)

		; One complete 32x56 character+hoverbout frame for Level 1.
		lea	Char6HoverboutFilename(pc),a0
		movea.l	#HOVERBOUT6_CHIP,a1
		jsr	(resload_LoadFile,a2)

		; Permanent external entry 5 in both slave-owned character tables.
		lea	CharacterTable(pc),a0
		move.l	#CHAR6_CHIP,$14(a0)
		lea	RuntimeCharacterTable(pc),a0
		move.l	#CHAR6_CHIP,$14(a0)

		movem.l	(sp)+,d0-d7/a0-a6
		rts

.badCharacter	lea	BadChar6Message(pc),a0
		bra	AbortAssetError

.badPortrait	lea	BadPortrait6Message(pc),a0
		bra	AbortAssetError

.badHoverbout	lea	BadHoverbout6Message(pc),a0
		bra	AbortAssetError

AbortAssetError
		move.l	a0,-(sp)
		pea	TDREASON_FAILMSG
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

; ---------------------------------------------------------------------------
; Level 1 sixth Hoverbout frame
; ---------------------------------------------------------------------------
; Level 1's descriptor list is:
;   0C,0F,06,0B,03,0A,02,04,11,13,15,...
;
; Summing the raw byte sizes of descriptors before ID $15 gives $A500.
; Descriptor $15 (decimal 21) is:
;   32 x 56
;   6 frames
;   $0380 bytes per frame
;
; Therefore its sixth frame begins at:
;   $A500 + (5 * $0380) = $B680
;
; $26B2 in the original game is:
;   BSR.W   $5562
;   RTS
;
; _character_patch replaces those six bytes with a JMP here. At this point:
;   - SPRITES1 has already been Ice-depacked;
;   - $55F8 still points at the START of the raw sprite bank;
;   - $5562 has not yet advanced $55F8 or built descriptor pointers/masks.
;
; This is therefore the most direct point to replace the empty sixth
; Hoverbout frame before the game consumes it.
BuildLevelSprites
		; For non-Level-1 banks, behave exactly like the original code.
		tst.w	$8a(a5)
		bne.b	.build

		; Preserve the original call-state. $5562 expects A0 to still contain
		; the selected descriptor-list pointer.
		movem.l	d0-d1/a0-a2,-(sp)

		movea.l	#HOVERBOUT6_CHIP,a0
		movea.l	$55f8,a1
		adda.l	#LEVEL1_HOVERBOUT6_OFFSET,a1
		move.w	#(HOVERBOUT_SIZE/4)-1,d0
.copy		move.l	(a0)+,(a1)+
		dbf	d0,.copy

		; The colour data will later be read by Amiga DMA/blitter paths.
		; Ensure the CPU copy is committed before $5562 builds the mask.
		move.l	(_resload,pc),a2
		jsr	(resload_FlushCache,a2)

		movem.l	(sp)+,d0-d1/a0-a2

.build		jmp	$5562

; ---------------------------------------------------------------------------
; Safe original-game character ID mapping
; ---------------------------------------------------------------------------
; P1 originally copies $156(a5) directly to the global character-ID byte.
; Keep 0..4 unchanged; alias selection 5 to a valid original ID.
SetP1CharacterID
		move.l	d0,-(sp)
		moveq	#0,d0
		move.b	$156(a5),d0
		cmpi.b	#5,d0
		bne.b	.store
		moveq	#CHAR6_BEHAVIOUR_ID,d0
.store		move.b	d0,$2b(a0)
		move.l	(sp)+,d0
		rts

; P2's next original instructions are:
;   move.b $157(a5),d0
;   add.b  d0,$2b(a0)
; Replace the preceding base assignment so 0..4 resolve normally and
; selection 5 resolves to CHAR6_BEHAVIOUR_ID rather than invalid ID 5.
SetP2CharacterIDBase
		move.w	#0,$2a(a0)
		cmpi.b	#5,$157(a5)
		bne.b	.done
		moveq	#CHAR6_BEHAVIOUR_ID,d0
		subq.b	#5,d0
		move.b	d0,$2b(a0)
.done		rts

; ---------------------------------------------------------------------------
; Slave-owned character pointer tables
; ---------------------------------------------------------------------------
; $e528 is a 23-entry RESIDENT resource table. Its first five entries are
; the original characters. Refresh only those five; slot 5 remains CHAR6.
RefreshCharacterTables
		movem.l	d0/a0-a1,-(sp)

		; First five RESIDENT resource pointers: compressed/source banks.
		movea.l	#ORIGINAL_CHAR_TABLE,a0
		lea	CharacterTable(pc),a1
		moveq	#4,d0
.copySource	move.l	(a0)+,(a1)+
		dbf	d0,.copySource

		; Five contiguous pointers to the decompressed 32x40x45 banks
		; in ChipRAM: $e588,$e58c,$e590,$e594,$e598.
		movea.l	#ORIGINAL_RUNTIME_CHAR_TABLE,a0
		lea	RuntimeCharacterTable(pc),a1
		moveq	#4,d0
.copyRuntime	move.l	(a0)+,(a1)+
		dbf	d0,.copyRuntime

		movem.l	(sp)+,d0/a0-a1
		rts

SelectP1Character
		movem.l	d0/a1,-(sp)
		bsr	RefreshCharacterTables
		moveq	#0,d0
		move.b	$156(a5),d0
		lsl.w	#2,d0
		lea	CharacterTable(pc),a1
		movea.l	(a1,d0.w),a0
		movem.l	(sp)+,d0/a1
		jmp	$2842

SelectP2Character
		movem.l	d0/a1,-(sp)
		bsr	RefreshCharacterTables
		moveq	#0,d0
		move.b	$157(a5),d0
		lsl.w	#2,d0
		lea	CharacterTable(pc),a1
		movea.l	(a1,d0.w),a0
		movem.l	(sp)+,d0/a1
		jmp	$2876

CycleP2Character
		addq.b	#1,$157(a5)
		cmpi.b	#CHARACTER_COUNT,$157(a5)
		bne.b	.done
		clr.b	$157(a5)
.done		rts

; Select the already-decompressed player graphics.  These two hooks replace
; the original hard-coded 3-way/2-way selectors at $f0b2 and $f0fa.
; A0 is the value the original routines produce; execution then resumes at
; the common code immediately after their old selection branches.
SelectP1RuntimeGraphics
		movem.l	d0/a1,-(sp)
		bsr	RefreshCharacterTables
		moveq	#0,d0
		move.b	$156(a5),d0
		lsl.w	#2,d0
		lea	RuntimeCharacterTable(pc),a1
		movea.l	(a1,d0.w),a0
		movem.l	(sp)+,d0/a1
		jmp	$f0d0

SelectP2RuntimeGraphics
		movem.l	d0/a1,-(sp)
		bsr	RefreshCharacterTables
		moveq	#0,d0
		move.b	$157(a5),d0
		lsl.w	#2,d0
		lea	RuntimeCharacterTable(pc),a1
		movea.l	(a1,d0.w),a0
		movem.l	(sp)+,d0/a1
		jmp	$f10a

AccessFault1	add.w	d4,d4
		move.l	d0,-(sp)
		move.l	a4,d0
		tst.l	d0
		bmi	error
		move.l	(sp)+,d0
		move.b	(a4,d4.w),d5
		rts

error		moveq	#0,d0
		lea	8(sp),sp
		rts

AccessFault2	move.l	d0,-(sp)
		move.l	a1,d0
		and.l	#$000fffff,d0
		move.l	d0,a1
		move.l	(sp)+,d0
		btst	#6,(a1)
		bne	error2
		rts

error2		sf	(a0)
		rts

AccessFault3	move.l	d0,-(sp)
		movea.l	$10(a5),a1
		adda.l	8(a0),a1
		move.l	a1,d0
		and.l	#$000fffff,d0
		move.l	d0,a1
		move.l	(sp)+,d0
		rts

InsertDisk1	move.l	a6,-(sp)
		lea	disknum,a6
		move.w	#1,(a6)
		move.l	(sp)+,a6
		rts

InsertDisk2	move.l	a6,-(sp)
		lea	disknum,a6
		move.w	#2,(a6)
		move.l	(sp)+,a6
		rts

LoadRNCTracks	movem.l a0-a2/d0-d3,-(sp)
		mulu.w	#$200,d1
		mulu.w	#$200,d2
		move.l	d1,d0
		move.l	d2,d1
		lea	disknum,a2
		move.w	(a2),d2
		move.l	(_resload,pc),a2
		jsr	(resload_DiskLoad,a2)
		movem.l (sp)+,a0-a2/d0-d3
		clr.l	d0
		rts

SaveHi_Sub	cmpi.w	#$14,$10c(a5)
		beq	SaveHi
		jmp	$10644

LoadHi		movem.l	d0-d7/a0-a6,-(sp)
		bsr	Params
                jsr     (resload_GetFileSize,a2)
                tst.l   d0
                beq     NoHisc
		bsr	Params
		jsr	(resload_LoadFile,a2)
NoHisc		movem.l	(sp)+,d0-d7/a0-a6
		rts

Params		lea	hiscore,a0
		lea	$10916,a1
		move.l	(_resload,pc),a2
		rts

SaveHi		movem.l	d0-d7/a0-a6,-(sp)
		bsr	Params
		move.l	#$1ee,d0
		jsr	(resload_SaveFile,a2)
		movem.l	(sp)+,d0-d7/a0-a6
		rts

_resload	dc.l	0
disknum		dc.w	1
_tags		dc.l	WHDLTAG_CUSTOM1_GET
_custom1	dc.l	0
		dc.l	WHDLTAG_CUSTOM2_GET
_custom2	dc.l	0
		dc.l	TAG_DONE,0
		even
CharacterTable	ds.l	CHARACTER_TABLE_SLOTS
RuntimeCharacterTable	ds.l	CHARACTER_TABLE_SLOTS
		; [0..4] = original live pointers copied from the game
		; [5]    = external CHAR6 at CHAR6_CHIP

		even
Char6Filename		dc.b	"chars/CHAR6.bin",0
Char6PortraitFilename	dc.b	"chars/CHAR6_portrait.bin",0
Char6HoverboutFilename dc.b	"chars/CHAR6_hoverbout.bin",0
BadChar6Message		dc.b	"chars/CHAR6.bin missing or wrong size - expected $7080 bytes",0
BadPortrait6Message	dc.b	"chars/CHAR6_portrait.bin missing or wrong size - expected $0200 bytes",0
BadHoverbout6Message	dc.b	"chars/CHAR6_hoverbout.bin missing or wrong size - expected $0380 bytes",0
		even
hiscore		dc.b	"DalekAttack.High",0