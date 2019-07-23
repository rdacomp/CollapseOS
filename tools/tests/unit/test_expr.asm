.equ	RAMSTART	0x4000
.equ	ZASM_REG_MAXCNT		0xff
.equ	ZASM_LREG_MAXCNT	0x40
.equ	ZASM_REG_BUFSZ		0x1000
.equ	ZASM_LREG_BUFSZ		0x200

jp	test

#include "core.asm"
#include "parse.asm"
#include "lib/util.asm"
#include "zasm/util.asm"
#include "zasm/const.asm"
#include "lib/parse.asm"
#include "zasm/parse.asm"
.equ	SYM_RAMSTART	RAMSTART
#include "zasm/symbol.asm"
#include "zasm/expr.asm"

; Pretend that we aren't in first pass
zasmIsFirstPass:
	jp	unsetZ

zasmGetPC:
	ret

testNum:	.db 1

s1:		.db "2+2", 0
s2:		.db "0x4001+0x22", 0
s3:		.db "FOO+BAR", 0
s4:		.db "BAR*3", 0
s5:		.db "FOO-3", 0
s6:		.db "FOO+BAR*4", 0

sFOO:		.db "FOO", 0
sBAR:		.db "BAR", 0

test:
	ld	hl, 0xffff
	ld	sp, hl

	ld	hl, s1
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	or	a
	jp	nz, fail
	ld	a, l
	cp	4
	jp	nz, fail
	call	nexttest

	ld	hl, s2
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	cp	0x40
	jp	nz, fail
	ld	a, l
	cp	0x23
	jp	nz, fail
	call	nexttest

	; before the next test, let's set up FOO and BAR symbols
	call	symInit
	ld	hl, sFOO
	ld	de, 0x4000
	call	symRegisterGlobal
	jp	nz, fail
	ld	hl, sBAR
	ld	de, 0x20
	call	symRegisterGlobal
	jp	nz, fail

	ld	hl, s3
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	cp	0x40
	jp	nz, fail
	ld	a, l
	cp	0x20
	jp	nz, fail
	call	nexttest

	ld	hl, s4
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	or	a
	jp	nz, fail
	ld	a, l
	cp	0x60
	jp	nz, fail
	call	nexttest

	ld	hl, s5
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	cp	0x3f
	jp	nz, fail
	ld	a, l
	cp	0xfd
	jp	nz, fail
	call	nexttest

	ld	hl, s6
	call	parseExpr
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	cp	0x40
	jp	nz, fail
	ld	a, l
	cp	0x80
	jp	nz, fail
	call	nexttest

	; success
	xor	a
	halt

nexttest:
	ld	a, (testNum)
	inc	a
	ld	(testNum), a
	ret

fail:
	ld	a, (testNum)
	halt
