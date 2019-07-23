; It's fine to declare the same constant twice. Only the first value is
; kept
.equ	FOO	42
.equ	FOO	22
ld	a, FOO
