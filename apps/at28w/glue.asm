; at28w - Write to AT28 EEPROM
;
; Write data from the active block device into an eeprom device geared as
; regular memory. Implements write polling to know when the next byte can be
; written and verifies that data is written properly.
;
; Optionally receives a word argument that specifies the number or bytes to
; write. If unspecified, will write until max bytes (0x2000) is reached or EOF
; is reached on the block device.

; *** Requirements ***
; blkGetC
; parseArgs
;
; *** Includes ***

#include "user.h"
#include "err.h"
.org	USER_CODE
.equ	AT28W_RAMSTART	USER_RAMSTART

jp	at28wMain

#include "at28w/main.asm"
