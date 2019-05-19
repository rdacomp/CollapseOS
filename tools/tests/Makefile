EMULDIR = ../emul

.PHONY: run
run:
	make -C $(EMULDIR) zasm runbin
	cd unit && ./runtests.sh
	cd zasm && ./runtests.sh
