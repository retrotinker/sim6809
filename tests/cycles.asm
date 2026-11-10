; SIMARGS: --swi
; Cycle counts that depend on what happens at run time, which lwasm can't
; list (the len_ops test checks every other instruction against lwasm):
; taken and untaken branches, RTI with E clear and set, the interrupt
; responses (IRQ and NMI 19 cycles, FIRQ 10, 7 out of CWAI), SWI/SWI2/SWI3,
; CWAI and SYNC, and the timer counting cycles (IO +11).  Measured with the
; cycle counter at IO +12..+15: MARK saves its low 16 bits (the count at
; MARK's LDA, latched by reading +12) and ELAPSED gives D = the cycles from
; MARK's LDA to ELAPSED's: 17 for MARK itself (LDA ext 5, LDD ext 6, STD
; ext 6) plus the code between.  Expected values from the MC6809 datasheet.
	INCLUDE	harness.inc

INTSET	EQU	$FF06
INTCLR	EQU	$FF07
TIMHI	EQU	$FF08
TIMLO	EQU	$FF09
TIMLINE	EQU	$FF0A
TIMMODE	EQU	$FF0B
CYCLES	EQU	$FF0C

CD	MACRO
	JSR	CHKD
	FDB	\1
	ENDM
MARK	MACRO
	LDA	>CYCLES		; latch the counter
	LDD	>CYCLES+2
	STD	>T0
	ENDM
ELAPSED	MACRO
	LDA	>CYCLES
	LDD	>CYCLES+2
	SUBD	>T0
	ENDM

MAIN	LDX	#N_BRANCH
	JSR	TBEGIN
	MARK			; nothing in between
	ELAPSED
	CD	17
	MARK
	ANDCC	#$FB		; 3: Z clear
	BEQ	B1		; 3, not taken
B1	ELAPSED
	CD	23
	MARK
	ORCC	#$04		; 3: Z set
	BEQ	B2		; 3, taken
B2	ELAPSED
	CD	23
	MARK
	ANDCC	#$FB		; 3
	LBEQ	B3		; 5, not taken
B3	ELAPSED
	CD	25
	MARK
	ORCC	#$04		; 3
	LBEQ	B4		; 6, taken
B4	ELAPSED
	CD	26
	MARK
	LBRN	B5		; 5
B5	ELAPSED
	CD	22
	MARK
	LBRA	B6		; 5
B6	ELAPSED
	CD	22
	JSR	TEND

	LDX	#N_RTI
	JSR	TBEGIN
	LDX	#R1		; a frame with E clear: PC, CC
	PSHS	X
	CLRA
	PSHS	A
	MARK
	RTI			; 6
R1	ELAPSED
	CD	23
	LDX	#R2		; a frame with E set: everything
	PSHS	X
	PSHS	U,Y,X,DP,B,A
	LDA	#$80
	PSHS	A
	MARK
	RTI			; 15
R2	ELAPSED
	CD	32
	JSR	TEND

	LDX	#N_INT
	JSR	TBEGIN
	ANDCC	#$AF
	MARK
	LDA	#1		; 2
	STA	INTSET		; 5, then the IRQ: 19, handler 29
	ELAPSED
	CD	17+2+5+19+29
	MARK
	LDA	#2		; 2
	STA	INTSET		; 5, then the FIRQ: 10, handler 13
	ELAPSED
	CD	17+2+5+10+13
	MARK
	LDA	#4		; 2
	STA	INTSET		; 5, then the NMI: 19, handler 15
	ELAPSED
	CD	17+2+5+19+15
	MARK
	SWI			; 19, handler 15
	ELAPSED
	CD	17+19+15
	MARK
	SWI2			; 20, handler 15
	ELAPSED
	CD	17+20+15
	MARK
	SWI3			; 20, handler 15
	ELAPSED
	CD	17+20+15
	JSR	TEND

	LDX	#N_CWAI
	JSR	TBEGIN
	ORCC	#$50		; an IRQ waiting, masked
	LDA	#1
	STA	INTSET
	MARK
	CWAI	#$EF		; 20, then the IRQ at once: 7, handler 29
	ELAPSED
	CD	17+20+7+29
	JSR	TEND

	LDX	#N_TIMER
	JSR	TBEGIN
	CLR	TIMHI		; the period's high byte
	LDA	#1
	STA	TIMMODE		; the period counts cycles
	ORCC	#$50
	MARK			; t=17
	LDA	#100		; 19
	STA	TIMLO		; 24: the period starts after this instruction
	CWAI	#$EF		; 44, then one cycle per step waiting until 124,
	ELAPSED			; the IRQ from CWAI 131, its handler 160
	CD	160
	ORCC	#$50		; masked: SYNC just ends when the line rises
	MARK			; t=17
	LDA	#100		; 19
	STA	TIMLO		; 24
	SYNC			; 28, then waiting until the timer fires at 124
	ELAPSED
	CD	124
	CLR	TIMLO		; stop it
	LDA	#1
	STA	INTCLR
	LDA	INTSET
	JSR	CHKA
	FCB	0
	JSR	TEND
	JMP	DONE

; IRQ: release the line, stop the timer (2 + 5 + 7), RTI (15): 29
IRQH	LDA	#1
	STA	INTCLR
	CLR	TIMLO
	RTI
; FIRQ: release the line (2 + 5), RTI with E clear (6): 13
FIRQH	LDA	#2
	STA	INTCLR
	RTI
; NMI, SWI, SWI2, SWI3: RTI (15)
NMIH	RTI

T0	FDB	0
N_BRANCH	FCN	"BRANCHES"
N_RTI	FCN	"RTI"
N_INT	FCN	"INTERRUPTS"
N_CWAI	FCN	"CWAI"
N_TIMER	FCN	"CYCLE TIMER"

	ORG	$FFF2
	FDB	NMIH		; SWI3
	FDB	NMIH		; SWI2
	FDB	FIRQH
	FDB	IRQH
	FDB	NMIH		; SWI
	FDB	NMIH		; NMI
	END	H_START
