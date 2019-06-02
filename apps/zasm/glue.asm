; zasm
;
; Reads input from specified blkdev ID, assemble the binary in two passes and
; spit the result in another specified blkdev ID.
;
; We don't buffer the whole source in memory, so we need our input blkdev to
; support Seek so we can read the file a second time. So, for input, we need
; GetC and Seek.
;
; For output, we only need PutC. Output doesn't start until the second pass.
;
; The goal of the second pass is to assign values to all symbols so that we
; can have forward references (instructions referencing a label that happens
; later).
;
; Labels and constants are both treated the same way, that is, they can be
; forward-referenced in instructions. ".equ" directives, however, are evaluated
; during the first pass so forward references are not allowed.
;
; *** Requirements ***
; blockdev
; strncmp
; addDE
; addHL
; upcase
; unsetZ
; intoDE
; intoHL
; writeHLinDE
; findchar
; parseHex
; parseHexPair
; blkSel
; fsFindFN
; fsOpen
; fsGetC
; fsSeek
; fsTell
; cpHLDE
; parseArgs
; FS_HANDLE_SIZE

; *** Variables ***

#include "user.h"
#include "err.h"
.org	USER_CODE

jp	zasmMain

#include "zasm/const.asm"
#include "zasm/util.asm"
.equ	IO_RAMSTART	USER_RAMSTART
#include "zasm/io.asm"
.equ	TOK_RAMSTART	IO_RAMEND
#include "zasm/tok.asm"
#include "zasm/parse.asm"
#include "zasm/expr.asm"
#include "zasm/instr.asm"
.equ	DIREC_RAMSTART	TOK_RAMEND
#include "zasm/directive.asm"
.equ	SYM_RAMSTART	DIREC_RAMEND
#include "zasm/symbol.asm"
.equ	ZASM_RAMSTART	SYM_RAMEND
#include "zasm/main.asm"

