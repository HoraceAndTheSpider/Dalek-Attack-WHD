;*---------------------------------------------------------------------------
;  :Program.   	  DalekAttackHD.asm
;  :Contents.  	  Slave for "Dalek Attack" from
;  :Authors.	  Bored Seal & Hungry Horace
;  :History.   	  2009-08-04 - V1.2
;		  2026-09-05 - V1.3
;		  2026-09-07 - scalable roster / optional FastRAM test (CHAR6-8)
;	
;		This updated patch has no purpose other than to add 
;		additional characters to the game 
;

		INCDIR	Includes:
		INCLUDE	whdload.i
		INCLUDE	whdmacros.i

; ---------------------------------------------------------------------------
; Scalable character roster - 8 entries for current test
; ---------------------------------------------------------------------------
;
; Roster position is independent of original game character ID.
; CUSTOM2 keeps BaseMem at the original 1MB and uses optional ExpMem.
;
ROSTER_COUNT                    EQU     8
ROSTER_ENTRY_SIZE               EQU     4
ROSTER_TYPE                     EQU     0
ROSTER_ASSET                    EQU     1
ROSTER_BEHAVIOUR                EQU     2
ROSTER_FLAGS                    EQU     3
ROSTER_ORIGINAL                 EQU     0
ROSTER_CUSTOM                   EQU     1

CHARACTER_BANK_SIZE             EQU     $7080
PORTRAIT_SIZE                   EQU     $0200
HOVERBOUT_SIZE                  EQU     $0380

EXPMEMSIZE                      EQU     $100000
CHIPMEMSIZE                     EQU     $100000

; Custom animation banks are kept separately in FastRAM.
; Reserve a simple $7080 stride for the three current test characters.
CUSTOM_ANIM_BASE                EQU     $000000
CUSTOM_ANIM_STRIDE              EQU     CHARACTER_BANK_SIZE
CHAR6_ANIM_OFF                  EQU     CUSTOM_ANIM_BASE+(0*CUSTOM_ANIM_STRIDE)
CHAR7_ANIM_OFF                  EQU     CUSTOM_ANIM_BASE+(1*CUSTOM_ANIM_STRIDE)
CHAR8_ANIM_OFF                  EQU     CUSTOM_ANIM_BASE+(2*CUSTOM_ANIM_STRIDE)

; Contiguous roster-order portraits:
;   PORTRAIT_BASE + roster*$200
PORTRAIT_ROSTER_OFF             EQU     $020000
PORTRAIT_ROSTER_SIZE            EQU     ROSTER_COUNT*PORTRAIT_SIZE

; Contiguous Hoverbout set:
;   frame 0              = original empty/dismount frame
;   frame roster+1       = that roster character
; Thus normal character index gets +1; dismount code uses frame 0.
HOVERBOUT_ROSTER_OFF            EQU     $021000
HOVERBOUT_FRAME_COUNT           EQU     ROSTER_COUNT+1
HOVERBOUT_ROSTER_SIZE           EQU     HOVERBOUT_FRAME_COUNT*HOVERBOUT_SIZE

; Temporary storage for custom portrait/Hoverbout files while constructing
; the contiguous roster blocks. These are FastRAM, not game-owned buffers.
CUSTOM_SMALL_ASSET_OFF          EQU     $030000
CUSTOM_SMALL_STRIDE             EQU     $0800
CHAR6_HOVER_TMP                EQU     CUSTOM_SMALL_ASSET_OFF
CHAR7_HOVER_TMP                EQU     CUSTOM_SMALL_ASSET_OFF+$0800
CHAR8_HOVER_TMP                EQU     CUSTOM_SMALL_ASSET_OFF+$1000

ORIGINAL_CHAR_TABLE             EQU     $e528
ORIGINAL_RUNTIME_CHAR_TABLE     EQU     $e588
ORIGINAL_PORTRAIT_BASE          EQU     $1797a

; Level 1 descriptor 21 original graphics:
; six $380 frames at decompressed SPRITES1 offset $A500.
; Frame 5 is the empty/dismount Hoverbout.
ORIGINAL_HOVER_DESC_ID          EQU     $15
ORIGINAL_HOVER_GFX_OFFSET       EQU     $a500
ORIGINAL_HOVER_EMPTY_FRAME      EQU     5

; Original asset map:
; +0.l address of live animation source-pointer slot
; +4.l original portrait address
; +8.b original Hoverbout character frame 0..4
; +9.b original behaviour/global ID
; +A.w reserved
ORIGINAL_MAP_ENTRY_SIZE         EQU     12
ORIGINAL_MAP_ANIM_SLOT          EQU     0
ORIGINAL_MAP_PORTRAIT           EQU     4
ORIGINAL_MAP_HOVER_FRAME        EQU     8
ORIGINAL_MAP_BEHAVIOUR          EQU     9


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
		dc.l	CHIPMEMSIZE		;ws_BaseMemSize - original 1MB ChipRAM
		dc.l	0			;ws_ExecInstall
		dc.w	_Start-_base		;ws_GameLoader
		dc.w	0			;ws_CurrentDir
		dc.w	0			;ws_DontCache
_keydebug	dc.b	0			;ws_keydebug
_keyexit	dc.b	$50			;ws_keyexit = F1
_expmem		dc.l	-EXPMEMSIZE		;ws_ExpMem - optional 1MB ExpMem/FastRAM

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
			dc.b	"1.8 (Roster Alpha)"
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

		; CUSTOM2 enables the roster/FastRAM path.
		; ws_ExpMem is optional, so low-memory users can still run the
		; original game with CUSTOM2 disabled.
		move.l	(_expmem,pc),d0
		bne.b	.HaveExpMem
		lea	NoExpMemMessage(pc),a0
		bra	AbortAssetError

.HaveExpMem	bsr	LoadExtraCharacterAssets
		lea	_character_patch(pc),a0

.ApplyPatches	suba.l	a1,a1
		move.l	_resload(pc),a2
		jsr	resload_Patch(a2)
		movem.l	(sp)+,a0-a2/d0-d2

		bsr	LoadHi
		jmp	$800

_character_patch	PL_START
		; Main character source selectors use roster pointer table.
		PL_P	$281e,SelectP1Character
		PL_P	$2862,SelectP2Character

		PL_W	$ebde,ROSTER_COUNT
		PL_W	$eec6,ROSTER_COUNT
		PL_PS	$ef98,CycleP2Character

		; Portrait renderer: restore the previously proven implementation.
		; Only change the two base operands. The original code continues to
		; calculate base + selection*$200.
		; $251A/$2534 portrait base operands are written at runtime by
		; InstallRosterBaseAddresses because ExpMem base is allocated dynamically.

		; Behaviour/global ID remains roster-defined.
		PL_P	$1fb8,SetP1CharacterID
		PL_P	$1ff2,SetP2CharacterID

		; Hoverbout: let $5562 build descriptor 21 normally, then redirect
		; descriptor +8 to our contiguous FastRAM roster set. This hook
		; replaces the BSR.W $5562 / RTS sequence at $26B2.
		PL_P	$26b2,BuildLevelSpritesRoster

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
; Scalable roster / FastRAM implementation - conservative test
; ---------------------------------------------------------------------------

LoadExtraCharacterAssets
		movem.l	d0-d7/a0-a6,-(sp)

		; Load only the large custom animation banks here.
		movea.l	(_expmem,pc),a1
		adda.l	#CHAR6_ANIM_OFF,a1
		lea	Char6Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		movea.l	(_expmem,pc),a1
		adda.l	#CHAR7_ANIM_OFF,a1
		lea	Char7Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		movea.l	(_expmem,pc),a1
		adda.l	#CHAR8_ANIM_OFF,a1
		lea	Char8Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		; Load custom Hoverbout frames once into FastRAM source storage.
		movea.l	(_expmem,pc),a1
		adda.l	#CHAR6_HOVER_TMP,a1
		lea	Char6HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		movea.l	(_expmem,pc),a1
		adda.l	#CHAR7_HOVER_TMP,a1
		lea	Char7HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		movea.l	(_expmem,pc),a1
		adda.l	#CHAR8_HOVER_TMP,a1
		lea	Char8HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		; Build the contiguous portrait roster in FastRAM. Originals are
		; CPU-copied from their existing raw game portraits; custom files
		; load directly into their final roster positions.
		bsr	BuildPortraitRoster

		; Install the new portrait base directly into the original code.
		; This is exactly the old working base-address mechanism, but the
		; address itself is dynamic because WHDLoad chooses ExpMem.
		bsr	InstallRosterBaseAddresses

		; Character animation pointer table can only be finalised after the
		; game's live $E528 source table has been populated, so mark pending.
		lea	_rosterReady(pc),a0
		clr.b	(a0)

		movem.l	(sp)+,d0-d7/a0-a6
		rts

; A0 filename, A1 destination, D0 exact expected size.
; WHDLF_NoError lets WHDLoad report missing/unreadable files itself.
LoadCharacterAsset
		move.l	d0,-(sp)
		move.l	(_resload,pc),a2
		jsr	(resload_LoadFile,a2)
		cmp.l	(sp)+,d0
		bne.b	.badSize
		rts
.badSize
		lea	BadCharacterAssetMessage(pc),a0
		move.l	a0,-(sp)
		pea	TDREASON_FAILMSG
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

AbortAssetError
		move.l	a0,-(sp)
		pea	TDREASON_FAILMSG
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

; ---------------------------------------------------------------------------
; Contiguous portrait roster
; ---------------------------------------------------------------------------
BuildPortraitRoster
		lea	CharacterRoster(pc),a4
		movea.l	(_expmem,pc),a6
		adda.l	#PORTRAIT_ROSTER_OFF,a6
		moveq	#ROSTER_COUNT-1,d7
.loop
		tst.b	ROSTER_TYPE(a4)
		bne.b	.custom

		; Original portrait: source from OriginalAssetMap, copy $200.
		moveq	#0,d0
		move.b	ROSTER_ASSET(a4),d0
		mulu.w	#ORIGINAL_MAP_ENTRY_SIZE,d0
		lea	OriginalAssetMap(pc),a0
		movea.l	ORIGINAL_MAP_PORTRAIT(a0,d0.w),a0
		movea.l	a6,a1
		move.w	#$7f,d1
.copyOriginal
		move.l	(a0)+,(a1)+
		dbf	d1,.copyOriginal
		bra.b	.next

.custom
		; Custom portrait loads straight into its final roster slot.
		moveq	#0,d0
		move.b	ROSTER_ASSET(a4),d0
		cmpi.b	#0,d0
		beq.b	.c6
		cmpi.b	#1,d0
		beq.b	.c7
		lea	Char8PortraitFilename(pc),a0
		bra.b	.load
.c6		lea	Char6PortraitFilename(pc),a0
		bra.b	.load
.c7		lea	Char7PortraitFilename(pc),a0
.load		movea.l	a6,a1
		move.l	#PORTRAIT_SIZE,d0
		bsr	LoadCharacterAsset
.next
		adda.l	#PORTRAIT_SIZE,a6
		adda.w	#ROSTER_ENTRY_SIZE,a4
		dbf	d7,.loop
		rts

InstallRosterBaseAddresses
		move.l	(_expmem,pc),d0
		addi.l	#PORTRAIT_ROSTER_OFF,d0
		move.l	d0,$251a
		move.l	d0,$2534
		move.l	(_resload,pc),a2
		jsr	(resload_FlushCache,a2)
		rts

; ---------------------------------------------------------------------------
; Main animation roster pointer table
; ---------------------------------------------------------------------------
EnsureRosterTables
		lea	_rosterReady(pc),a0
		tst.b	(a0)
		bne.b	.done
		bsr	BuildRosterTables
.done		rts

BuildRosterTables
		movem.l	d0-d7/a0-a6,-(sp)
		movea.l	#ORIGINAL_CHAR_TABLE,a6
		tst.l	(a6)
		beq.b	.notReady

		lea	CharacterRoster(pc),a0
		lea	RosterAnimSources(pc),a1
		lea	RosterBehaviourIds(pc),a2
		moveq	#ROSTER_COUNT-1,d7
.loop
		move.b	ROSTER_BEHAVIOUR(a0),(a2)+
		tst.b	ROSTER_TYPE(a0)
		bne.b	.custom

		moveq	#0,d0
		move.b	ROSTER_ASSET(a0),d0
		mulu.w	#ORIGINAL_MAP_ENTRY_SIZE,d0
		lea	OriginalAssetMap(pc),a3
		movea.l	ORIGINAL_MAP_ANIM_SLOT(a3,d0.w),a3
		move.l	(a3),(a1)+
		bra.b	.next

.custom
		moveq	#0,d0
		move.b	ROSTER_ASSET(a0),d0
		mulu.w	#CHARACTER_BANK_SIZE,d0
		movea.l	(_expmem,pc),a3
		adda.l	d0,a3
		move.l	a3,(a1)+
.next
		adda.w	#ROSTER_ENTRY_SIZE,a0
		dbf	d7,.loop
		lea	_rosterReady(pc),a0
		move.b	#1,(a0)
.notReady
		movem.l	(sp)+,d0-d7/a0-a6
		rts

GetRosterAnimSource
		bsr	EnsureRosterTables
		lsl.w	#2,d0
		lea	RosterAnimSources(pc),a0
		movea.l	(a0,d0.w),a0
		rts

SelectP1Character
		movem.l	d0-d1/a1,-(sp)
		moveq	#0,d0
		move.b	$156(a5),d0
		bsr	GetRosterAnimSource
		movem.l	(sp)+,d0-d1/a1
		jmp	$2842

SelectP2Character
		movem.l	d0-d1/a1,-(sp)
		moveq	#0,d0
		move.b	$157(a5),d0
		bsr	GetRosterAnimSource
		movem.l	(sp)+,d0-d1/a1
		jmp	$2876

CycleP2Character
		addq.b	#1,$157(a5)
		cmpi.b	#ROSTER_COUNT,$157(a5)
		bne.b	.done
		clr.b	$157(a5)
.done		rts

; ---------------------------------------------------------------------------
; Behaviour/global character IDs
; ---------------------------------------------------------------------------
SetP1CharacterID
		movem.l	d0-d1/a1,-(sp)
		bsr	EnsureRosterTables
		moveq	#0,d1
		move.b	$156(a5),d1
		lea	RosterBehaviourIds(pc),a1
		move.b	(a1,d1.w),$2b(a0)
		movem.l	(sp)+,d0-d1/a1
		jmp	$1fbe

SetP2CharacterID
		movem.l	d1/a1,-(sp)
		bsr	EnsureRosterTables
		moveq	#0,d0
		move.b	$157(a5),d0
		clr.w	$2a(a0)
		move.w	d0,d1
		lea	RosterBehaviourIds(pc),a1
		move.b	(a1,d1.w),$2b(a0)
		movem.l	(sp)+,d1/a1
		jmp	$2000

; ---------------------------------------------------------------------------
; Hoverbout contiguous roster
; ---------------------------------------------------------------------------
;
; $26B2 originally:
;   BSR.W $5562
;   RTS
;
; We preserve that operation first. For Level 1, $5562 has then populated
; descriptor 21 (+8 graphics pointer). We construct:
;
;   new frame 0 = original frame 5 (empty/dismount)
;   new frame 1 = roster character 0
;   ...
;   new frame 8 = roster character 7
;
; and redirect descriptor 21 graphics pointer to the new contiguous FastRAM
; block. No original level sprite data is overwritten.
;
; IMPORTANT: if the eventual renderer proves to blit directly from this
; descriptor pointer, FastRAM is not DMA-visible and this block will need a
; ChipRAM presentation buffer. This test deliberately establishes whether the
; descriptor consumer is CPU-side or blitter-side without corrupting game data.
BuildLevelSpritesRoster
		jsr	$5562

		cmpi.b	#0,$8a(a5)
		bne	.done

		movem.l	d0-d7/a0-a6,-(sp)

		; Descriptor 21 address = master table $1EDA6 + 21*22 = $1EF74.
		; +8 contains the graphics base set by $5562.
		movea.l	$1ef7c,a4		;original 6-frame graphics base
		movea.l	(_expmem,pc),a6
		adda.l	#HOVERBOUT_ROSTER_OFF,a6

		; New frame 0 = old frame 5 (empty/dismount).
		movea.l	a4,a0
		adda.l	#(5*HOVERBOUT_SIZE),a0
		movea.l	a6,a1
		bsr	CopyHoverFrame

		; Build roster frames 1..8.
		lea	CharacterRoster(pc),a3
		moveq	#ROSTER_COUNT-1,d7
		movea.l	a6,a5
		adda.l	#HOVERBOUT_SIZE,a5
.rosterLoop
		tst.b	ROSTER_TYPE(a3)
		bne.b	.custom

		; Original character frame 0..4 from old descriptor block.
		moveq	#0,d0
		move.b	ROSTER_ASSET(a3),d0
		mulu.w	#ORIGINAL_MAP_ENTRY_SIZE,d0
		lea	OriginalAssetMap(pc),a2
		moveq	#0,d1
		move.b	ORIGINAL_MAP_HOVER_FRAME(a2,d0.w),d1
		mulu.w	#HOVERBOUT_SIZE,d1
		movea.l	a4,a0
		adda.l	d1,a0
		movea.l	a5,a1
		bsr	CopyHoverFrame
		bra.b	.next

.custom
		; Custom Hoverbout source was loaded once at startup.
		moveq	#0,d0
		move.b	ROSTER_ASSET(a3),d0
		mulu.w	#$0800,d0
		movea.l	(_expmem,pc),a0
		adda.l	#CHAR6_HOVER_TMP,a0
		adda.l	d0,a0
		movea.l	a5,a1
		bsr	CopyHoverFrame

.next		adda.l	#HOVERBOUT_SIZE,a5
		adda.w	#ROSTER_ENTRY_SIZE,a3
		dbf	d7,.rosterLoop

		; Redirect descriptor graphics pointer to contiguous roster block.
		move.l	a6,$1ef7c

		; TODO/TEST: descriptor +12 mask pointer is left exactly as built by
		; $5562. This test is specifically about pointer/index architecture.
		; If masks are frame-indexed here, the next correction is to build the
		; equally contiguous mask block rather than overwrite source data.

		movem.l	(sp)+,d0-d7/a0-a6
.done		rts

CopyHoverFrame
		move.w	#(HOVERBOUT_SIZE/4)-1,d0
.copy		move.l	(a0)+,(a1)+
		dbf	d0,.copy
		rts


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

; ---------------------------------------------------------------------------
; Original asset map
; ---------------------------------------------------------------------------
; anim slot address, portrait address, Hoverbout frame, behaviour ID, reserved
OriginalAssetMap
		dc.l	$0000e528,$0001797a
		dc.b	0,0
		dc.w	0

		dc.l	$0000e52c,$00017b7a
		dc.b	1,1
		dc.w	0

		dc.l	$0000e530,$00017d7a
		dc.b	2,2
		dc.w	0

		dc.l	$0000e534,$00017f7a
		dc.b	3,3
		dc.w	0

		dc.l	$0000e538,$0001817a
		dc.b	4,4
		dc.w	0

; ---------------------------------------------------------------------------
; Author-editable roster
; ---------------------------------------------------------------------------
; Format:
;   dc.b type, asset, behaviour, flags
;
; ORIGINAL:
;   asset = OriginalAssetMap index 0..4
;
; CUSTOM:
;   asset = $8000 ExpMem slot number
;   slot 0 = files named CHAR6_*
;   slot 1 = files named CHAR7_*
;   slot 2 = files named CHAR8_*
;
; Re-order THESE LINES to re-order the in-game roster. Nothing in the
; selector code assumes that originals occupy roster positions 0..4.
;
; Current conservative ordering retained for first test:
CharacterRoster
		dc.b	ROSTER_ORIGINAL,0,0,0	; roster 0: original CHAR1
		dc.b	ROSTER_ORIGINAL,1,1,0	; roster 1: original CHAR2
		dc.b	ROSTER_ORIGINAL,2,2,0	; roster 2: original CHAR3
		dc.b	ROSTER_ORIGINAL,3,3,0	; roster 3: original CHAR4
		dc.b	ROSTER_ORIGINAL,4,4,0	; roster 4: original CHAR5
		dc.b	ROSTER_CUSTOM,0,0,0	; roster 5: CHAR6, behaviour inherited from ID0
		dc.b	ROSTER_CUSTOM,1,0,0	; roster 6: CHAR7, behaviour inherited from ID0
		dc.b	ROSTER_CUSTOM,2,0,0	; roster 7: CHAR8, behaviour inherited from ID0

; Resolved address lists. These are filled from CharacterRoster once the
; game's live original source table is available.
		even
RosterAnimSources	ds.l	ROSTER_COUNT
RosterBehaviourIds	ds.b	ROSTER_COUNT

_rosterReady		dc.b	0
		even

; ---------------------------------------------------------------------------
; External files
; ---------------------------------------------------------------------------
NoExpMemMessage
		dc.b	"Extra Characters requires optional 1MB ExpMem/FastRAM",0

Char6Filename
		dc.b	"chars/CHAR6.bin",0
Char6PortraitFilename
		dc.b	"chars/CHAR6_portrait.bin",0
Char6HoverboutFilename
		dc.b	"chars/CHAR6_hoverbout.bin",0

Char7Filename
		dc.b	"chars/CHAR7.bin",0
Char7PortraitFilename
		dc.b	"chars/CHAR7_portrait.bin",0
Char7HoverboutFilename
		dc.b	"chars/CHAR7_hoverbout.bin",0

Char8Filename
		dc.b	"chars/CHAR8.bin",0
Char8PortraitFilename
		dc.b	"chars/CHAR8_portrait.bin",0
Char8HoverboutFilename
		dc.b	"chars/CHAR8_hoverbout.bin",0
BadCharacterAssetMessage
		dc.b	"Extra character asset has wrong size",0

		even
hiscore		dc.b	"DalekAttack.High",0