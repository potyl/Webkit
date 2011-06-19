WEBKIT=$(shell pkg-config --cflags --libs webkit-1.0)

CFLAGS=-std=c99

.PHONY: all


.PHONY: run
run: transparent
	./$< file://$(PWD)/sample.html


transparent: transparent.c
	$(CC) $(CFLAGS) $(WEBKIT) -o $@ $<



download-cb: download-cb.c
	$(CC) $(CFLAGS) $(WEBKIT) -o $@ $<


.PHONY: clean
clean:
	rm -f transparent
	rm -f download-cb
