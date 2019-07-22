ZASM = ../../../tools/zasm.sh
KERNEL = ../../../kernel
APPS = ../../../apps

.PHONY: all clean
all: os.sms

ed.bin: $(APPS)/ed/glue.asm
	echo ".equ USER_CODE ED_CODE" | cat user-tmpl.h - > user.h
	$(ZASM) $(KERNEL) $(APPS) user.h < $< > $@

zasm.bin: $(APPS)/zasm/glue.asm
	echo ".equ USER_CODE ZASM_CODE" | cat user-tmpl.h - > user.h
	$(ZASM) $(KERNEL) $(APPS) user.h < $< > $@

os.sms: glue.asm ed.bin zasm.bin
	$(ZASM) $(KERNEL) ed.bin zasm.bin < $< > $@

clean:
	rm -f os.sms ed.bin zasm.bin
