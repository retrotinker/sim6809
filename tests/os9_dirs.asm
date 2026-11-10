; SIMARGS: --load 0x2000 --data 0x8000
; sim6809 --os9: F$Mem (ask, grow, use the new memory, too much, shrink),
; and directories: I$MakDir, a file in it, I$ChgDir into it, the
; directory read (I$Open with DIR.) as RBF's 32-byte entries, whose names
; are printed, I$ChgDir back; the root (where sim6809 starts: its ".."
; and "." have the same LSN) and its name (I$GetStt SS.DevNm: H0); the
; directory's ".." the LSN of its parent's "."; then I$Delete of the
; file, and of the directory, refused (E$FNA) until its D attribute is
; turned off (I$GetStt SS.FD shows it, I$SetStt SS.Attr turns it off; it
; can't be opened as a directory then), as RBF has it.
	PRAGMA	6809
	MOD	EOM,NAME,$11,$81,START,SIZE
PATH	RMB	1
SAVEU	RMB	2
ENT	RMB	32
ENT2	RMB	32
SAVE3	RMB	3
	RMB	160		; (the stack: the data stays in a page)
SIZE	EQU	.
NAME	FCS	/OS9DIRS/
	FCB	1
START	STU	SAVEU,U
	LEAX	FILE,PCR	; (what a failed run left goes: the file, and
	OS9	$87		; the directory, its D attribute off first)
	LEAX	DNAME,PCR
	LDA	#$81
	OS9	$84
	BCS	NOLEFT
	STA	PATH,U
	LDB	#$1C
	LDX	#$3F
	OS9	$8E
	LDA	PATH,U
	OS9	$8F
	LEAX	DNAME,PCR
	OS9	$87
NOLEFT
	LDD	#0		; F$Mem 0: the size, 1 page (D), its end (Y)
	OS9	$07
	LBCS	FAIL
	CMPD	#$100
	LBNE	FAIL
	CMPY	#$8100
	LBNE	FAIL
	LDD	#$1001		; grow to $1001: whole pages, $1100
	OS9	$07
	LBCS	FAIL
	CMPD	#$1100
	LBNE	FAIL
	CMPY	#$9100
	LBNE	FAIL
	LDA	#$5A		; the new memory can be written
	STA	$90FF
	LDD	#$7000		; up to $F000 is free; $FF00 is the I/O
	OS9	$07
	LBCS	FAIL
	LDD	#$7F01		; past it: E$MemFul
	OS9	$07
	LBCC	FAIL
	CMPB	#$CF
	LBNE	FAIL
	LDD	#$200		; shrink
	OS9	$07
	LBCS	FAIL
	CMPY	#$8200
	LBNE	FAIL
	LEAX	DNAME,PCR	; I$MakDir; again is E$CEF
	LDB	#$3F
	OS9	$85
	LBCS	FAIL
	LEAX	DNAME,PCR
	LDB	#$3F
	OS9	$85
	LBCC	FAIL
	CMPB	#$DA
	LBNE	FAIL
	LEAX	FILE,PCR	; a file in it
	LDA	#2
	OS9	$83
	LBCS	FAIL
	OS9	$8F
	LEAX	DNAME,PCR	; I$Open of a directory without DIR.: E$FNA
	LDA	#1
	OS9	$84
	LBCC	FAIL
	CMPB	#$D6
	LBNE	FAIL
	LEAX	DNAME,PCR	; I$ChgDir into it
	LDA	#3
	OS9	$86
	LBCS	FAIL
	LEAX	DOT,PCR		; ".", read as a directory
	LDA	#$81
	OS9	$84
	LBCS	FAIL
	STA	PATH,U
ENTRY	LEAX	ENT,U		; each entry: its name, printed
	LDY	#32
	LDA	PATH,U
	OS9	$89
	BCS	EOF
	CMPY	#32
	LBNE	FAIL
	LEAX	ENT,U
NAMEC	LDA	,X
	ANDA	#$7F
	PSHS	X
	STA	ENT+31,U	; (its LSN is no longer needed)
	LEAX	ENT+31,U
	LDY	#1
	LDA	#1
	OS9	$8A
	PULS	X
	TST	,X+
	BPL	NAMEC
	LEAX	CRMSG,PCR
	LDY	#1
	LDA	#1
	OS9	$8A
	BRA	ENTRY
EOF	CMPB	#$D3
	LBNE	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	UP,PCR		; I$ChgDir back to where it started
	LDA	#3
	OS9	$86
	LBCS	FAIL
	LEAX	DOT,PCR		; the root: ".." and "." the same LSN
	LBSR	OPEN2
	LBSR	SAME
	LBNE	FAIL
	LDA	PATH,U		; and its device: H0
	LDB	#$0E
	LEAX	ENT,U
	OS9	$8D
	LBCS	FAIL
	LDD	ENT,U
	CMPD	#$48B0
	LBNE	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	PARENT,PCR	; the directory's ".." is its parent's "."
	LBSR	OPEN2
	LDD	ENT2+29,U
	STD	SAVE3,U
	LDA	ENT2+31,U
	STA	SAVE3+2,U
	LDA	PATH,U
	OS9	$8F
	LEAX	DNAME,PCR
	LBSR	OPEN2
	LDD	ENT+29,U
	CMPD	SAVE3,U
	LBNE	FAIL
	LDA	ENT+31,U
	CMPA	SAVE3+2,U
	LBNE	FAIL
	LDA	PATH,U		; I$GetStt SS.FD: D is on
	LDB	#$0F
	LEAX	ENT,U
	LDY	#1
	OS9	$8D
	LBCS	FAIL
	TST	ENT,U
	LBPL	FAIL
	LDA	PATH,U
	OS9	$8F
	LEAX	FILE,PCR	; I$Delete the file
	OS9	$87
	LBCS	FAIL
	LEAX	DNAME,PCR	; and the directory: E$FNA, as a directory
	OS9	$87
	LBCC	FAIL
	CMPB	#$D6
	LBNE	FAIL
	LEAX	DNAME,PCR	; D off (I$SetStt SS.Attr, X)
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
	LEAX	DNAME,PCR	; not a directory now: E$FNA
	LDA	#$81
	OS9	$84
	LBCC	FAIL
	CMPB	#$D6
	LBNE	FAIL
	LEAX	DNAME,PCR	; and it can be deleted
	OS9	$87
	LBCS	FAIL
	LEAX	DNAME,PCR	; gone: I$ChgDir fails
	LDA	#3
	OS9	$86
	LBCC	FAIL
	LEAX	MSG,PCR
	LDY	#3
	LDA	#1
	OS9	$8C
	LDB	#42
	OS9	$06
FAIL	LDB	#99
	OS9	$06

; OPEN2: open the directory named at X (path in PATH), and read its
; first two entries ("..", ".") into ENT and ENT2
OPEN2	LDA	#$81
	OS9	$84
	BCS	O2FAIL
	STA	PATH,U
	LEAX	ENT,U
	LDY	#32
	OS9	$89
	BCS	O2FAIL
	LEAX	ENT2,U
	LDY	#32
	LDA	PATH,U
	OS9	$89
	BCS	O2FAIL
	RTS
O2FAIL	LEAS	2,S
	LBRA	FAIL

; SAME: Z set if ENT's and ENT2's LSNs are the same
SAME	LDD	ENT+29,U
	CMPD	ENT2+29,U
	BNE	SAMEX
	LDA	ENT+31,U
	CMPA	ENT2+31,U
SAMEX	RTS
DNAME	FCC	"build/tests/os9dirs.tmp"
	FCB	13
FILE	FCC	"build/tests/os9dirs.tmp/afile"
	FCB	13
DOT	FCC	"."
	FCB	13
PARENT	FCC	"build/tests"
	FCB	13
UP	FCC	"../../.."
	FCB	13
CRMSG	FCB	13
MSG	FCC	"OK"
	FCB	13
	EMOD
EOM	EQU	*
	END
