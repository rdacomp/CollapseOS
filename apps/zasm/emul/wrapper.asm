; setup the stack
ld	hl, 0xffff
ld	sp, hl
; zasm input
ld	hl, 0x9000
; zasm output
ld	de, 0xc000
call	zasm
; signal the emulator we're done
; BC contains the number of written bytes
ld	a, b
out	(c), a
halt
zasm:
; beginning of the code
