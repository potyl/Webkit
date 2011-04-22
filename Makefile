WEBKIT=$(shell pkg-config --cflags --libs webkit-1.0)

.PHONY: all
all: transparent download-cb


.PHONY: run
run: transparent
	./$< file://$(PWD)/sample.html


transparent: transparent.c
	$(CC) $(WEBKIT) -o $@ $<


download-cb: download-cb.c
	$(CC) $(WEBKIT) -o $@ $<


.PHONY: clean
clean:
	rm -f transparent
	rm -f download-cb
