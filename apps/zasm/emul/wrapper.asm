; setup the stack
ld	hl, 0xffff
ld	sp, hl
; zasm input
ld	hl, 0x9000
; zasm output
ld	hl, 0xc000
call	zasm
; signal the emulator we're done
out	(0), a
halt
zasm:
; beginning of the code
