; *** Errors ***
; Unknown instruction or directive
.equ	ERR_UNKNOWN		0x01

; Bad argument: Doesn't match any constant argspec or, if an expression,
; contains references to undefined symbols.
.equ	ERR_BAD_ARG		0x02

; Code is badly formatted (comma without a following arg, unclosed quote, etc.)
.equ	ERR_BAD_FMT		0x03

; Value specified doesn't fit in its destination byte or word
.equ	ERR_OVFL		0x04

.equ	ERR_FILENOTFOUND	0x05

; Duplicate symbol
.equ	ERR_DUPSYM		0x06

; Out of memory
.equ	ERR_OOM			0x07

; *** Other ***
.equ	ZASM_DEBUG_PORT		42
