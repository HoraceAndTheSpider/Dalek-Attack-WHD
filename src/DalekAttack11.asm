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
; Character expansion - 2MB ChipRAM, 8-character test
; ---------------------------------------------------------------------------
CHARACTER_COUNT                 EQU     8
CHARACTER_TABLE_SLOTS           EQU     8
CHARACTER_BANK_SIZE             EQU     $7080
PORTRAIT_SIZE                   EQU     $0200
HOVERBOUT_SIZE                  EQU     $0380

ORIGINAL_CHAR_TABLE             EQU     $e528
ORIGINAL_RUNTIME_CHAR_TABLE     EQU     $e588
ORIGINAL_PORTRAIT_BASE          EQU     $1797a

; Full expansion slave requires 2MB ChipRAM.
CHIPMEMSIZE                     EQU     $200000

; Permanent expansion assets in the second megabyte.
CHAR6_CHIP                      EQU     $100000
CHAR7_CHIP                      EQU     CHAR6_CHIP+CHARACTER_BANK_SIZE
CHAR8_CHIP                      EQU     CHAR7_CHIP+CHARACTER_BANK_SIZE

; Eight contiguous portraits in selection order.
PORTRAIT_BASE_ALL               EQU     $116000

; Custom Hoverbout source frames. Loaded safely into ChipRAM now, but not
; connected to descriptor 21 until graphics + masks + index path are patched
; together.
HOVERBOUT6_CHIP                 EQU     $118000
HOVERBOUT7_CHIP                 EQU     HOVERBOUT6_CHIP+HOVERBOUT_SIZE
HOVERBOUT8_CHIP                 EQU     HOVERBOUT7_CHIP+HOVERBOUT_SIZE

CHAR6_BEHAVIOUR_ID              EQU     0
CHAR7_BEHAVIOUR_ID              EQU     0
CHAR8_BEHAVIOUR_ID              EQU     0


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
			dc.b	"1.9 (2MB Chip Roster Alpha)"
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
		PL_P	$281e,SelectP1Character
		PL_P	$2862,SelectP2Character
		PL_W	$ebde,CHARACTER_COUNT
		PL_W	$eec6,CHARACTER_COUNT
		PL_PS	$ef98,CycleP2Character

		; Same proven portrait-base patch as the working CHAR6 build.
		PL_L	$251a,PORTRAIT_BASE_ALL
		PL_L	$2534,PORTRAIT_BASE_ALL

		PL_P	$f0b2,SelectP1RuntimeGraphics
		PL_P	$f0fa,SelectP2RuntimeGraphics

		PL_PS	$1fb8,SetP1CharacterID
		PL_PS	$1ff2,SetP2CharacterIDBase

		; No $26B2 Hoverbout hook in this baseline test.
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
; 2MB ChipRAM expansion routines
; ---------------------------------------------------------------------------
LoadCharacter6Assets
		movem.l	d0-d7/a0-a6,-(sp)

		lea	Char6Filename(pc),a0
		movea.l	#CHAR6_CHIP,a1
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char7Filename(pc),a0
		movea.l	#CHAR7_CHIP,a1
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char8Filename(pc),a0
		movea.l	#CHAR8_CHIP,a1
		move.l	#CHARACTER_BANK_SIZE,d0
		bsr	LoadCharacterAsset

		; Original five portraits -> contiguous second-meg block.
		movea.l	#ORIGINAL_PORTRAIT_BASE,a0
		movea.l	#PORTRAIT_BASE_ALL,a1
		move.w	#$027f,d0
.copyPortraits	move.l	(a0)+,(a1)+
		dbf	d0,.copyPortraits

		lea	Char6PortraitFilename(pc),a0
		movea.l	#PORTRAIT_BASE_ALL+(5*PORTRAIT_SIZE),a1
		move.l	#PORTRAIT_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char7PortraitFilename(pc),a0
		movea.l	#PORTRAIT_BASE_ALL+(6*PORTRAIT_SIZE),a1
		move.l	#PORTRAIT_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char8PortraitFilename(pc),a0
		movea.l	#PORTRAIT_BASE_ALL+(7*PORTRAIT_SIZE),a1
		move.l	#PORTRAIT_SIZE,d0
		bsr	LoadCharacterAsset

		; Load custom Hoverbout source frames into permanent ChipRAM.
		lea	Char6HoverboutFilename(pc),a0
		movea.l	#HOVERBOUT6_CHIP,a1
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char7HoverboutFilename(pc),a0
		movea.l	#HOVERBOUT7_CHIP,a1
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		lea	Char8HoverboutFilename(pc),a0
		movea.l	#HOVERBOUT8_CHIP,a1
		move.l	#HOVERBOUT_SIZE,d0
		bsr	LoadCharacterAsset

		; Custom source/runtime entries stay permanently in second-meg ChipRAM.
		lea	CharacterTable(pc),a0
		move.l	#CHAR6_CHIP,$14(a0)
		move.l	#CHAR7_CHIP,$18(a0)
		move.l	#CHAR8_CHIP,$1c(a0)
		lea	RuntimeCharacterTable(pc),a0
		move.l	#CHAR6_CHIP,$14(a0)
		move.l	#CHAR7_CHIP,$18(a0)
		move.l	#CHAR8_CHIP,$1c(a0)

		move.l	(_resload,pc),a2
		jsr	(resload_FlushCache,a2)
		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Shared loader. WHDLF_NoError lets WHDLoad report missing/unreadable files.
; Only successful loads return; then enforce the expected exact length.
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

; P1 global behaviour ID: originals unchanged, custom entries inherit a valid
; original behaviour ID from the compact table.
SetP1CharacterID
		movem.l	d0/a1,-(sp)
		moveq	#0,d0
		move.b	$156(a5),d0
		cmpi.b	#5,d0
		blo.b	.store
		subi.w	#5,d0
		lea	CustomBehaviourIds(pc),a1
		move.b	(a1,d0.w),d0
.store		move.b	d0,$2b(a0)
		movem.l	(sp)+,d0/a1
		rts

; P2 original continuation reloads selection and adds it to $2B(A0).
; For custom entries set the base so base+selection becomes the inherited ID.
SetP2CharacterIDBase
		movem.l	d0-d1/a1,-(sp)
		move.w	#0,$2a(a0)
		moveq	#0,d0
		move.b	$157(a5),d0
		cmpi.b	#5,d0
		blo.b	.done
		move.w	d0,d1
		subi.w	#5,d1
		lea	CustomBehaviourIds(pc),a1
		moveq	#0,d1
		move.b	$157(a5),d1
		subi.w	#5,d1
		move.b	(a1,d1.w),d1
		sub.b	d0,d1
		move.b	d1,$2b(a0)
.done		movem.l	(sp)+,d0-d1/a1
		rts

RefreshCharacterTables
		movem.l	d0/a0-a1,-(sp)
		movea.l	#ORIGINAL_CHAR_TABLE,a0
		lea	CharacterTable(pc),a1
		moveq	#4,d0
.copySource	move.l	(a0)+,(a1)+
		dbf	d0,.copySource
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

; Identical mechanism to the working six-character build; bound is now 8.
CycleP2Character
		addq.b	#1,$157(a5)
		cmpi.b	#CHARACTER_COUNT,$157(a5)
		bne.b	.done
		clr.b	$157(a5)
.done		rts

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

CustomBehaviourIds
		dc.b	CHAR6_BEHAVIOUR_ID,CHAR7_BEHAVIOUR_ID,CHAR8_BEHAVIOUR_ID
		even

Char6Filename		dc.b	"chars/CHAR6.bin",0
Char6PortraitFilename	dc.b	"chars/CHAR6_portrait.bin",0
Char6HoverboutFilename	dc.b	"chars/CHAR6_hoverbout.bin",0
Char7Filename		dc.b	"chars/CHAR7.bin",0
Char7PortraitFilename	dc.b	"chars/CHAR7_portrait.bin",0
Char7HoverboutFilename	dc.b	"chars/CHAR7_hoverbout.bin",0
Char8Filename		dc.b	"chars/CHAR8.bin",0
Char8PortraitFilename	dc.b	"chars/CHAR8_portrait.bin",0
Char8HoverboutFilename	dc.b	"chars/CHAR8_hoverbout.bin",0
BadCharacterAssetMessage dc.b	"Extra character asset has wrong size",0
		even

hiscore		dc.b	"DalekAttack.High",0