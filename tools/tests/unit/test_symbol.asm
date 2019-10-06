.equ	RAMSTART	0x4000
.equ	ZASM_REG_MAXCNT		0xff
.equ	ZASM_LREG_MAXCNT	0x40
.equ	ZASM_REG_BUFSZ		0x1000
.equ	ZASM_LREG_BUFSZ		0x200

jp	test

.inc "core.asm"
.inc "lib/util.asm"
.inc "zasm/util.asm"
.inc "zasm/const.asm"
.equ	SYM_RAMSTART	RAMSTART
.inc "zasm/symbol.asm"

testNum:	.db 1

sFOO:		.db "FOO", 0
sFOOBAR:	.db "FOOBAR", 0
sOther:		.db "Other", 0

test:
	ld	sp, 0xffff

	; Check that we compare whole strings (a prefix will not match a longer
	; string).
	call	symInit
	ld	hl, sFOOBAR
	ld	de, 42
	call	symRegisterGlobal
	jp	nz, fail
	ld	hl, sFOO
	ld	de, 43
	call	symRegisterGlobal
	jp	nz, fail

	ld	hl, sFOO
	call	symFindVal		; don't match FOOBAR
	jp	nz, fail
	ld	a, d
	or	a
	jp	nz, fail
	ld	a, e
	cp	43
	jp	nz, fail
	call	nexttest

	ld	hl, sOther
	call	symFindVal
	jp	z, fail
	call	nexttest

	; success
	xor	a
	halt

nexttest:
	ld	hl, testNum
	inc	(hl)
	ret

fail:
	ld	a, (testNum)
	halt




