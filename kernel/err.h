; Error codes used throughout the kernel

; The command that was type isn't known to the shell
.equ	SHELL_ERR_UNKNOWN_CMD	0x01

; Arguments for the command weren't properly formatted
.equ	SHELL_ERR_BAD_ARGS	0x02

; IO routines (GetC, PutC) returned an error in a load/save command
.equ	SHELL_ERR_IO_ERROR	0x05

