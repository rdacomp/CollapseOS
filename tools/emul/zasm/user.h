.equ    USER_CODE       0x4800
.equ    USER_RAMSTART   0x6000
.equ    FS_HANDLE_SIZE  8

; *** JUMP TABLE ***
.equ    strncmp        0x03
.equ    addDE          0x06
.equ    addHL          0x09
.equ    upcase         0x0c
.equ    unsetZ         0x0f
.equ    intoDE         0x12
.equ    intoHL         0x15
.equ    writeHLinDE    0x18
.equ    findchar       0x1b
.equ    parseHex       0x1e
.equ    parseHexPair   0x21
.equ    blkSel         0x24
.equ    fsFindFN       0x27
.equ    fsOpen         0x2a
.equ    fsGetC         0x2d
.equ    fsSeek         0x30
.equ    fsTell         0x33
.equ    cpHLDE         0x36
.equ    parseArgs      0x39
