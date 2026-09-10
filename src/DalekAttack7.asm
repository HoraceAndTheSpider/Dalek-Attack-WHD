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
; Roster position is deliberately independent of the original game character
; ID. Re-order the four-byte entries in CharacterRoster to change selection
; order without changing any selector code.
;
; Current test roster contains:
;   original CHAR1..CHAR5
;   external CHAR6..CHAR8
;
; The architecture allows up to 30 custom $8000 FastRAM slots.

ROSTER_COUNT                    EQU     8
ROSTER_ENTRY_SIZE               EQU     4

ROSTER_TYPE                     EQU     0
ROSTER_ASSET                    EQU     1
ROSTER_BEHAVIOUR                EQU     2
ROSTER_FLAGS                    EQU     3

ROSTER_ORIGINAL                 EQU     0
ROSTER_CUSTOM                   EQU     1

MAX_CUSTOM_SLOTS                EQU     30

CHARACTER_BANK_SIZE             EQU     $7080
PORTRAIT_SIZE                   EQU     $0200
HOVERBOUT_SIZE                  EQU     $0380

; One custom character gets a simple $8000 slot:
;   +$0000  $7080 animation bank
;   +$7080  $0200 portrait
;   +$7280  $0380 Hoverbout
;   +$7600  $0A00 currently spare for later per-character assets
CUSTOM_SLOT_SIZE                EQU     $8000
CUSTOM_ANIM_OFFSET              EQU     $0000
CUSTOM_PORTRAIT_OFFSET          EQU     $7080
CUSTOM_HOVERBOUT_OFFSET         EQU     $7280
CUSTOM_USED_SIZE                EQU     $7600

; 30 * $8000 = $F0000, leaving the final $10000 of a 1MB ExpMem block
; for shared/cached metadata. The five original portraits are copied here
; before any portrait cache can overwrite an original portrait slot.
EXPMEMSIZE                      EQU     $100000
ORIGINAL_PORTRAITS_FAST_OFFSET  EQU     $0F0000

CHIPMEMSIZE                     EQU     $100000

ORIGINAL_CHAR_TABLE             EQU     $e528
ORIGINAL_RUNTIME_CHAR_TABLE     EQU     $e588
ORIGINAL_PORTRAIT_BASE          EQU     $1797a

; Two existing original runtime banks are used only as P1/P2 preview caches
; while CUSTOM2 is active. They are refilled from the selected roster source.
P1_PREVIEW_CACHE_PTR_SLOT       EQU     ORIGINAL_RUNTIME_CHAR_TABLE+(3*4)
P2_PREVIEW_CACHE_PTR_SLOT       EQU     ORIGINAL_RUNTIME_CHAR_TABLE+(4*4)

; Two original portrait slots become temporary ChipRAM source caches.
; All five original portraits have already been preserved in ExpMem.
P1_PORTRAIT_CACHE               EQU     $17f7a
P2_PORTRAIT_CACHE               EQU     $1817a
P1_PORTRAIT_DEST                EQU     $1837a
P2_PORTRAIT_DEST                EQU     $1857a

; Original asset map. The animation value is the ADDRESS OF the game's live
; resource-pointer slot, not the resource itself. This lets the game populate
; the pointer normally and lets our roster resolve it later.
;
; entry:
;   +0.l address of live animation-source pointer
;   +4.l original portrait address
;   +8.b original Hoverbout frame (0..4)
;   +9.b original behaviour/global ID
;   +A.w reserved
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
			dc.b	"1.7 (Roster Alpha)"
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
		; Roster-aware source selectors. The game still performs its normal
		; CPU copy into ChipRAM and Ice check/depack after these hooks.
		PL_P	$281e,SelectP1Character
		PL_P	$2862,SelectP2Character

		; Roster size for P1 random/default and manual cycling.
		PL_W	$ebde,ROSTER_COUNT
		PL_W	$eec6,ROSTER_COUNT

		; P2 originally BCHG-toggles between two values.
		PL_PS	$ef98,CycleP2Character

		; Portrait routines now use roster pointer lookup + ChipRAM caches.
		PL_P	$2518,SelectP1Portrait
		PL_P	$2532,SelectP2Portrait

		; Selection-screen/main-menu character rendering needs ChipRAM.
		; Each player therefore gets a dedicated cache backed by two of the
		; game's existing original runtime character buffers.
		PL_P	$f0b2,SelectP1RuntimeGraphics
		PL_P	$f0fa,SelectP2RuntimeGraphics

		; Global/non-graphics character ID comes from the roster entry,
		; not from roster position.
		PL_P	$1fb8,SetP1CharacterID
		PL_P	$1ff2,SetP2CharacterID

		; Hoverbout note:
		; CHAR6-8 Hoverbout data is loaded into FastRAM and represented in
		; RosterHoverboutSources. No render hook is installed in this test:
		; the two previous copy-in-place Hoverbout hooks were not reliable.
		; The next step is to patch the exact frame-pointer consumer so it
		; indexes RosterHoverboutSources.

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
; Scalable roster / FastRAM implementation
; ---------------------------------------------------------------------------

; Load the three current external characters into fixed $8000 ExpMem slots.
; This deliberately happens only when CUSTOM2 is active.
;
; WHDLoad itself attempts optional ws_ExpMem allocation before the Slave runs.
; Because the request is negative, failure leaves _expmem = 0 instead of
; preventing the original 1MB game from starting.
LoadExtraCharacterAssets
		movem.l	d0-d7/a0-a6,-(sp)

		; Preserve all five original portraits in FastRAM before two of the
		; original portrait slots become P1/P2 temporary ChipRAM caches.
		movea.l	#ORIGINAL_PORTRAIT_BASE,a0
		movea.l	(_expmem,pc),a1
		adda.l	#ORIGINAL_PORTRAITS_FAST_OFFSET,a1
		move.w	#$027f,d0		;$0A00 / 4 - 1
.copyOriginalPortraits
		move.l	(a0)+,(a1)+
		dbf	d0,.copyOriginalPortraits

		; ---------------- CHAR6 / custom slot 0 ----------------
		movea.l	(_expmem,pc),a1
		lea	Char6Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		lea	BadChar6Message(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#CUSTOM_PORTRAIT_OFFSET,a1
		lea	Char6PortraitFilename(pc),a0
		move.l	#PORTRAIT_SIZE,d0
		lea	BadChar6PortraitMessage(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#CUSTOM_HOVERBOUT_OFFSET,a1
		lea	Char6HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		lea	BadChar6HoverboutMessage(pc),a3
		bsr	LoadCheckedFile

		; ---------------- CHAR7 / custom slot 1 ----------------
		movea.l	(_expmem,pc),a1
		adda.l	#CUSTOM_SLOT_SIZE,a1
		lea	Char7Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		lea	BadChar7Message(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#CUSTOM_SLOT_SIZE+CUSTOM_PORTRAIT_OFFSET,a1
		lea	Char7PortraitFilename(pc),a0
		move.l	#PORTRAIT_SIZE,d0
		lea	BadChar7PortraitMessage(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#CUSTOM_SLOT_SIZE+CUSTOM_HOVERBOUT_OFFSET,a1
		lea	Char7HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		lea	BadChar7HoverboutMessage(pc),a3
		bsr	LoadCheckedFile

		; ---------------- CHAR8 / custom slot 2 ----------------
		movea.l	(_expmem,pc),a1
		adda.l	#(2*CUSTOM_SLOT_SIZE),a1
		lea	Char8Filename(pc),a0
		move.l	#CHARACTER_BANK_SIZE,d0
		lea	BadChar8Message(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#(2*CUSTOM_SLOT_SIZE)+CUSTOM_PORTRAIT_OFFSET,a1
		lea	Char8PortraitFilename(pc),a0
		move.l	#PORTRAIT_SIZE,d0
		lea	BadChar8PortraitMessage(pc),a3
		bsr	LoadCheckedFile

		movea.l	(_expmem,pc),a1
		adda.l	#(2*CUSTOM_SLOT_SIZE)+CUSTOM_HOVERBOUT_OFFSET,a1
		lea	Char8HoverboutFilename(pc),a0
		move.l	#HOVERBOUT_SIZE,d0
		lea	BadChar8HoverboutMessage(pc),a3
		bsr	LoadCheckedFile

		; Force the resolved address list and preview caches to initialise
		; from the live game tables when first needed.
		clr.b	_rosterReady
		move.b	#$ff,_p1PreviewRoster
		move.b	#$ff,_p2PreviewRoster

		movem.l	(sp)+,d0-d7/a0-a6
		rts

; A0 = filename
; A1 = destination
; D0 = exact expected size
; A3 = error-message pointer
LoadCheckedFile
		movem.l	d1/a0-a1/a3,-(sp)
		move.l	d0,d1
		move.l	(_resload,pc),a2
		jsr	(resload_GetFileSize,a2)
		cmp.l	d1,d0
		beq.b	.sizeOK

		movem.l	(sp)+,d1/a0-a1/a3
		movea.l	a3,a0
		bra	AbortAssetError

.sizeOK	movem.l	(sp)+,d1/a0-a1/a3
		move.l	(_resload,pc),a2
		jsr	(resload_LoadFile,a2)
		rts

AbortAssetError
		move.l	a0,-(sp)
		pea	TDREASON_FAILMSG
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

; ---------------------------------------------------------------------------
; Build the resolved roster address lists.
; ---------------------------------------------------------------------------
;
; CharacterRoster itself is the author-editable ordering.
;
; Original entries resolve through OriginalAssetMap:
;   animation -> dereference the game's live pointer at $E528/$E52C/...
;   portrait  -> preserved FastRAM copy of the original portrait
;   Hoverbout -> original frame number for now
;
; Custom entries resolve to their $8000 ExpMem slot:
;   animation -> +$0000
;   portrait  -> +$7080
;   Hoverbout -> +$7280
;
; RosterHoverboutSources therefore already contains FastRAM pointers for
; custom entries. Original entries contain their original frame number in the
; low longword until the later Hoverbout renderer work resolves them against
; the current level descriptor.
EnsureRosterTables
		tst.b	_rosterReady(pc)
		bne.b	.done
		bsr	BuildRosterTables
.done		rts

BuildRosterTables
		movem.l	d0-d7/a0-a6,-(sp)

		; The game's live original resource table is populated later than
		; PatchGame. Do not mark the roster ready until it is actually live.
		movea.l	#ORIGINAL_CHAR_TABLE,a6
		tst.l	(a6)
		beq	.notReady

		lea	CharacterRoster(pc),a0
		lea	RosterAnimSources(pc),a1
		lea	RosterPortraitSources(pc),a2
		lea	RosterHoverboutSources(pc),a3
		lea	RosterBehaviourIds(pc),a4
		moveq	#ROSTER_COUNT-1,d7

.loop		move.b	ROSTER_BEHAVIOUR(a0),(a4)+
		tst.b	ROSTER_TYPE(a0)
		bne.b	.custom

		; ----- original character -----
		moveq	#0,d0
		move.b	ROSTER_ASSET(a0),d0
		move.w	d0,d1
		mulu.w	#ORIGINAL_MAP_ENTRY_SIZE,d1
		lea	OriginalAssetMap(pc),a5
		lea	(a5,d1.w),a5

		; +0.l is the address of the game's live source-pointer slot.
		movea.l	ORIGINAL_MAP_ANIM_SLOT(a5),a6
		move.l	(a6),(a1)+

		; Portrait source = our FastRAM preservation copy.
		movea.l	(_expmem,pc),a6
		adda.l	#ORIGINAL_PORTRAITS_FAST_OFFSET,a6
		lsl.w	#8,d0
		lsl.w	#1,d0			;original id * $200
		adda.w	d0,a6
		move.l	a6,(a2)+

		; For now retain original Hoverbout frame number as a roster ref.
		moveq	#0,d0
		move.b	ORIGINAL_MAP_HOVER_FRAME(a5),d0
		move.l	d0,(a3)+
		bra.b	.next

.custom
		; ----- external FastRAM character -----
		moveq	#0,d0
		move.b	ROSTER_ASSET(a0),d0	;custom slot number
		lsl.l	#8,d0
		lsl.l	#7,d0			;slot * $8000
		movea.l	(_expmem,pc),a6
		adda.l	d0,a6

		move.l	a6,(a1)+		;animation +$0000

		movea.l	a6,a5
		adda.l	#CUSTOM_PORTRAIT_OFFSET,a5
		move.l	a5,(a2)+

		movea.l	a6,a5
		adda.l	#CUSTOM_HOVERBOUT_OFFSET,a5
		move.l	a5,(a3)+

.next		adda.w	#ROSTER_ENTRY_SIZE,a0
		dbf	d7,.loop

		move.b	#1,_rosterReady

.notReady	movem.l	(sp)+,d0-d7/a0-a6
		rts

; ---------------------------------------------------------------------------
; Main player animation source lookup
; ---------------------------------------------------------------------------

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
; Selection/menu animation ChipRAM caches
; ---------------------------------------------------------------------------
;
; F0B2/F0FA eventually feed the Amiga blitter, so a FastRAM bank cannot be
; returned directly. Two existing original runtime banks become temporary
; P1/P2 caches while CUSTOM2 is active.
;
; LoadRosterToChipCache deliberately uses the game's own $F31A copy routine
; followed by the normal Ice detector/depacker at $D74C. This supports both:
;   original Ice source -> copied and depacked into the cache
;   custom raw source   -> copied; $D74C sees no Ice! and returns
LoadRosterToChipCache
		move.l	a1,-(sp)		;preserve cache destination
		bsr	GetRosterAnimSource	;A0 = roster source
		movea.l	(sp),a1
		jsr	$f31a
		movea.l	(sp),a0
		movea.l	(sp)+,a1
		jsr	$d74c
		rts

SelectP1RuntimeGraphics
		movem.l	d0-d2/a1-a2,-(sp)
		moveq	#0,d0
		move.b	$156(a5),d0
		cmp.b	_p1PreviewRoster(pc),d0
		beq.b	.ready
		move.b	d0,_p1PreviewRoster

		movea.l	#P1_PREVIEW_CACHE_PTR_SLOT,a1
		movea.l	(a1),a1
		bsr	LoadRosterToChipCache

.ready		movea.l	#P1_PREVIEW_CACHE_PTR_SLOT,a1
		movea.l	(a1),a0
		movem.l	(sp)+,d0-d2/a1-a2
		jmp	$f0d0

SelectP2RuntimeGraphics
		movem.l	d0-d2/a1-a2,-(sp)
		moveq	#0,d0
		move.b	$157(a5),d0
		cmp.b	_p2PreviewRoster(pc),d0
		beq.b	.ready
		move.b	d0,_p2PreviewRoster

		movea.l	#P2_PREVIEW_CACHE_PTR_SLOT,a1
		movea.l	(a1),a1
		bsr	LoadRosterToChipCache

.ready		movea.l	#P2_PREVIEW_CACHE_PTR_SLOT,a1
		movea.l	(a1),a0
		movem.l	(sp)+,d0-d2/a1-a2
		jmp	$f10a

; ---------------------------------------------------------------------------
; Portrait roster lookup + ChipRAM caches
; ---------------------------------------------------------------------------

GetRosterPortraitSource
		bsr	EnsureRosterTables
		lsl.w	#2,d0
		lea	RosterPortraitSources(pc),a0
		movea.l	(a0,d0.w),a0
		rts

CopyRosterPortraitToCache
		move.l	a1,-(sp)
		bsr	GetRosterPortraitSource
		movea.l	(sp)+,a1
		move.w	#$007f,d1		;$200 / 4 - 1
.copy		move.l	(a0)+,(a1)+
		dbf	d1,.copy
		rts

SelectP1Portrait
		movem.l	d0-d1/a0-a1,-(sp)
		moveq	#0,d0
		move.b	$156(a5),d0
		movea.l	#P1_PORTRAIT_CACHE,a1
		bsr	CopyRosterPortraitToCache
		movem.l	(sp)+,d0-d1/a0-a1

		movea.l	#P1_PORTRAIT_CACHE,a4
		movea.l	#P1_PORTRAIT_DEST,a2
		jmp	$2548

SelectP2Portrait
		movem.l	d0-d1/a0-a1,-(sp)
		moveq	#0,d0
		move.b	$157(a5),d0
		movea.l	#P2_PORTRAIT_CACHE,a1
		bsr	CopyRosterPortraitToCache
		movem.l	(sp)+,d0-d1/a0-a1

		movea.l	#P2_PORTRAIT_CACHE,a4
		movea.l	#P2_PORTRAIT_DEST,a2
		jmp	$2548

; ---------------------------------------------------------------------------
; Behaviour/global character IDs
; ---------------------------------------------------------------------------
;
; This is the key separation between roster order and original game identity.
; The byte in ROSTER_BEHAVIOUR may be 0..4 regardless of where the character
; appears in the roster.
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

		; Preserve the original routine's D0 result: selector value.
		moveq	#0,d0
		move.b	$157(a5),d0

		clr.w	$2a(a0)
		move.w	d0,d1
		lea	RosterBehaviourIds(pc),a1
		move.b	(a1,d1.w),$2b(a0)

		movem.l	(sp)+,d1/a1
		jmp	$2000


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
RosterPortraitSources	ds.l	ROSTER_COUNT
RosterHoverboutSources	ds.l	ROSTER_COUNT
RosterBehaviourIds	ds.b	ROSTER_COUNT

_rosterReady		dc.b	0
_p1PreviewRoster	dc.b	$ff
_p2PreviewRoster	dc.b	$ff
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
BadChar6Message
		dc.b	"chars/CHAR6.bin missing or wrong size - expected $7080 bytes",0
BadChar6PortraitMessage
		dc.b	"chars/CHAR6_portrait.bin missing or wrong size - expected $0200 bytes",0
BadChar6HoverboutMessage
		dc.b	"chars/CHAR6_hoverbout.bin missing or wrong size - expected $0380 bytes",0

Char7Filename
		dc.b	"chars/CHAR7.bin",0
Char7PortraitFilename
		dc.b	"chars/CHAR7_portrait.bin",0
Char7HoverboutFilename
		dc.b	"chars/CHAR7_hoverbout.bin",0
BadChar7Message
		dc.b	"chars/CHAR7.bin missing or wrong size - expected $7080 bytes",0
BadChar7PortraitMessage
		dc.b	"chars/CHAR7_portrait.bin missing or wrong size - expected $0200 bytes",0
BadChar7HoverboutMessage
		dc.b	"chars/CHAR7_hoverbout.bin missing or wrong size - expected $0380 bytes",0

Char8Filename
		dc.b	"chars/CHAR8.bin",0
Char8PortraitFilename
		dc.b	"chars/CHAR8_portrait.bin",0
Char8HoverboutFilename
		dc.b	"chars/CHAR8_hoverbout.bin",0
BadChar8Message
		dc.b	"chars/CHAR8.bin missing or wrong size - expected $7080 bytes",0
BadChar8PortraitMessage
		dc.b	"chars/CHAR8_portrait.bin missing or wrong size - expected $0200 bytes",0
BadChar8HoverboutMessage
		dc.b	"chars/CHAR8_hoverbout.bin missing or wrong size - expected $0380 bytes",0

		even
hiscore		dc.b	"DalekAttack.High",0