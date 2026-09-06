;*---------------------------------------------------------------------------
;  :Program.   	  DalekAttackHD.asm
;  :Contents.  	  Slave for "Dalek Attack" from
;  :Authors.	  Bored Seal & Hungry Horace
;  :History.   	  2009-08-04 - V1.2
;		  2026-09-05 - V1.3
;	
;		This updated patch has no purpose other than to add 
;		additional characters to the game 
;

		INCDIR	Includes:
		INCLUDE	whdload.i
		INCLUDE	whdmacros.i

; ---------------------------------------------------------------------------
; Character expansion test 1
; ---------------------------------------------------------------------------
CHARACTER_COUNT		EQU	5
CHARACTER_TABLE_SLOTS	EQU	6
ORIGINAL_CHAR_TABLE	EQU	$e528
ORIGINAL_RUNTIME_CHAR_TABLE EQU	$e588
PORTRAIT_BASE_ALL	EQU	$1797a


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
		dc.l	$100000			;ws_BaseMemSize
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
		dc.b    0


		IFD BARFLY
		DOSCMD	"WDate  >T:date"
		ENDC

DECL_VERSION:MACRO
			dc.b	"1.3 (Alpha)"
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

NoTrainer	lea	_gamepatch,a0
		suba.l	a1,a1
		move.l	_resload,a2
		jsr	resload_Patch(a2)
		movem.l	(sp)+,a0-a2/d0-d2

		bsr	LoadHi
		jmp	$800

_gamepatch	PL_START
		PL_P	$112f2,LoadRNCTracks	;disk loader emulators
		PL_P	$dc00,InsertDisk1
		PL_P	$dc5e,InsertDisk2
		PL_PS	$106a4,SaveHi_Sub	;save highscore routine
		PL_R	$fc3a			;remove manual protection
		PL_L	$11274,$24094e71	;skip memory test => use 1MB ChipRAM

		PL_PS	$5738,AccessFault1	;test a4 for minus value to avoid access fault
		PL_PS	$a07c,AccessFault2	;correct 24bit access fault
		PL_PS	$a0d4,AccessFault2
		PL_W	$1036,$4e71		;correct 24bit access fault
		PL_PS	$1038,AccessFault3

; Character expansion test 1: all five originals available to both players.
		PL_P	$281e,SelectP1Character
		PL_P	$2862,SelectP2Character
		PL_W	$ebde,CHARACTER_COUNT	; P1 initial random divisor
		PL_W	$eec6,CHARACTER_COUNT	; P1 manual wrap limit
		PL_PS	$ef98,CycleP2Character	; replace 0/1 BCHG toggle
		PL_L	$2534,PORTRAIT_BASE_ALL	; P2 portraits use common 5-entry block

		; A second pair of routines selects the already-decompressed
		; ChipRAM graphics used for drawing the players.  The originals
		; hard-code P1 as 0 / 1 / anything-else and P2 as 0 / anything-else,
		; which otherwise makes five P1 choices appear as 1,2,3,3,3.
		PL_P	$f0b2,SelectP1RuntimeGraphics
		PL_P	$f0fa,SelectP2RuntimeGraphics

		; P2 normally forms the global character ID as 3 + $157(a5),
		; because its original choices are character IDs 3 and 4. With both
		; players now selecting the common global IDs 0..4, make that base 0.
		PL_W	$1ff4,$0000

		PL_END

; ---------------------------------------------------------------------------
; Character expansion test routines
; ---------------------------------------------------------------------------

; The game's table at $e528 is actually a 23-entry RESIDENT resource table.
; Its first five entries are the character banks. Copy only those five live
; pointers into our dedicated slave-owned character table. Slot 5 remains
; reserved for the external $7080 test character used in test 2.
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
_custom1	dc.l    0,0
		dc.l	TAG_DONE,TAG_DONE
		even
CharacterTable	ds.l	CHARACTER_TABLE_SLOTS
RuntimeCharacterTable	ds.l	CHARACTER_TABLE_SLOTS
		; [0..4] = original live pointers copied from $e528-$e538
		; [5]    = reserved for external WHDLoad-loaded test character

hiscore		dc.b	"DalekAttack.High",0