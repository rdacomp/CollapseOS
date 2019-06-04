; *** Errors ***
; We start error at 0x10 to avoid overlapping with shell errors
; Unknown instruction or directive
.equ	ERR_UNKNOWN		0x11

; Bad argument: Doesn't match any constant argspec or, if an expression,
; contains references to undefined symbols.
.equ	ERR_BAD_ARG		0x12

; Code is badly formatted (comma without a following arg, unclosed quote, etc.)
.equ	ERR_BAD_FMT		0x13

; Value specified doesn't fit in its destination byte or word
.equ	ERR_OVFL		0x14

.equ	ERR_FILENOTFOUND	0x15

; Duplicate symbol
.equ	ERR_DUPSYM		0x16

; Out of memory
.equ	ERR_OOM			0x17

; *** Other ***
.equ	ZASM_DEBUG_PORT		42
