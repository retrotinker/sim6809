; SIMARGS: --load 0x2000 --data 0x8000
; sim6809 --os9: renaming a file as RBF's rename does it, by writing a new
; name over its entry in the directory, opened for update (DIR. + UPDAT.):
; the host file is renamed; and what isn't a rename is refused: onto a
; name that's there (E$CEF), a changed LSN or the ".." entry (E$Write), a
; directory opened to read (E$BMode), and DIR. + WRITE. (E$BMode).
	PRAGMA	6809
	MOD	EOM,NAME,$11,$81,START,SIZE
PATH	RMB	1
NENT	RMB	1
ENT	RMB	32
	RMB	160		; (the stack: the data stays in a page)
SIZE	EQU	.
NAME	FCS	/OS9REN/
	FCB	1
START	LEAX	FNEW,PCR	; (what a failed run left goes)
	OS9	$87
	LEAX	FOLD,PCR
	OS9	$87
	LEAX	FOTHER,PCR
	OS9	$87
	LEAX	DNAME,PCR
	LDA	#$81
	OS9	$84
	BCS	NOLEFT
	STA	PATH,U
	LDB	#$1C		; (D off, to delete it)
	LDX	#$3F
	OS9	$8E
	LDA	PATH,U
	OS9	$8F
	LEAX	DNAME,PCR
	OS9	$87
NOLEFT	LEAX	DNAME,PCR	; the directory, with "old" and "other"
	LDB	#$3F
	OS9	$85
	LBCS	FAIL
	LEAX	FOLD,PCR
	LBSR	MAKE
	LEAX	FOTHER,PCR
	LBSR	MAKE
	LEAX	DNAME,PCR	; DIR. + WRITE.: E$BMode
	LDA	#$82
	OS9	$84
	LBCC	FAIL
	CMPB	#$CB
	LBNE	FAIL
	LEAX	DNAME,PCR	; opened to read, a write is E$BMode
	LDA	#$81
	OS9	$84
	LBCS	FAIL
	STA	PATH,U
	LEAX	ENT,U
	LDY	#32
	OS9	$89
	LBCS	FAIL
	CLR	NENT,U
	LBSR	WRENT
	LBCC	FAIL
	CMPB	#$CB
	LBNE	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	DNAME,PCR	; DIR. + UPDAT.
	LDA	#$83
	OS9	$84
	LBCS	FAIL
	STA	PATH,U
	CLR	NENT,U		; "old"'s entry
FIND	LEAX	ENT,U
	LDY	#32
	LDA	PATH,U
	OS9	$89
	LBCS	FAIL
	LDD	ENT,U
	CMPD	#$6F6C		; "ol"
	BNE	NEXT
	LDA	ENT+2,U
	CMPA	#$E4		; "d", bit 7 set
	BEQ	FOUND
NEXT	INC	NENT,U
	BRA	FIND
FOUND	LDD	#$6E65		; "new" over it
	STD	ENT,U
	LDA	#$F7
	STA	ENT+2,U
	LBSR	WRENT
	LBCS	FAIL
	LEAX	FNEW,PCR	; "new" is there, "old" isn't
	LDA	#1
	OS9	$84
	LBCS	FAIL
	OS9	$8F
	LEAX	FOLD,PCR
	LDA	#1
	OS9	$84
	LBCC	FAIL
	CMPB	#$D8
	LBNE	FAIL
	LDD	#$6F74		; "other" over "new": it's there, E$CEF
	STD	ENT,U
	LDD	#$6865
	STD	ENT+2,U
	LDA	#$F2
	STA	ENT+4,U
	LBSR	WRENT
	LBCC	FAIL
	CMPB	#$DA
	LBNE	FAIL
	LDD	#$6E65		; "new" again, but another LSN: E$Write
	STD	ENT,U
	LDD	#$F700
	STD	ENT+2,U
	CLR	ENT+4,U
	INC	ENT+31,U
	LBSR	WRENT
	LBCC	FAIL
	CMPB	#$F5
	LBNE	FAIL
	CLR	NENT,U		; and the ".." entry: E$Write
	LBSR	WRENT
	LBCC	FAIL
	CMPB	#$F5
	LBNE	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	FNEW,PCR	; still "new" and "other"
	OS9	$87
	LBCS	FAIL
	LEAX	FOTHER,PCR
	OS9	$87
	LBCS	FAIL
	LEAX	DNAME,PCR	; and the directory goes
	LDA	#$81
	OS9	$84
	LBCS	FAIL
	STA	PATH,U
	LDB	#$1C
	LDX	#$3F
	OS9	$8E
	LBCS	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	DNAME,PCR
	OS9	$87
	LBCS	FAIL
	LEAX	MSG,PCR
	LDY	#3
	LDA	#1
	OS9	$8C
	LDB	#42
	OS9	$06
FAIL	LDB	#99
	OS9	$06

; MAKE: create the file named at X, empty
MAKE	LDA	#2
	OS9	$83
	BCS	MFAIL
	OS9	$8F
	RTS
MFAIL	LEAS	2,S
	LBRA	FAIL

; WRENT: write ENT over entry NENT of PATH (I$Seek to NENT * 32, with U
; the position's low word, then I$Write); CC and B as the calls leave them
WRENT	LDB	NENT,U
	LDA	#32
	MUL
	PSHS	D
	LDA	PATH,U
	PSHS	U
	LDU	2,S
	LDX	#0
	OS9	$88
	PULS	U
	LEAS	2,S
	BCS	WRX
	LEAX	ENT,U
	LDY	#32
	LDA	PATH,U
	OS9	$8A
WRX	RTS
DNAME	FCC	"build/tests/os9ren.tmp"
	FCB	13
FOLD	FCC	"build/tests/os9ren.tmp/old"
	FCB	13
FNEW	FCC	"build/tests/os9ren.tmp/new"
	FCB	13
FOTHER	FCC	"build/tests/os9ren.tmp/other"
	FCB	13
MSG	FCC	"OK"
	FCB	13
	EMOD
EOM	EQU	*
	END
