TARGET = os.bin
ZASM = ../../tools/zasm.sh

.PHONY: all
all: $(TARGET)
$(TARGET): glue.asm
	$(ZASM) < $< > $@
