TARGETS = cfspack cfsunpack

.PHONY: all
all: $(TARGETS)

cfspack: cfspack.c
cfsunpack: cfsunpack.c
$(TARGETS):
	$(CC) -o $@ $^
