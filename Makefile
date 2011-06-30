WEBKIT=$(shell pkg-config --cflags --libs webkitgtk-3.0)

CFLAGS=-std=c99

.PHONY: all
all: transparent download-cb screenshot dom

.PHONY: run
run: transparent
	./$< file://$(PWD)/sample.html


transparent: transparent.c
	$(CC) $(CFLAGS) $(WEBKIT) -o $@ $<


download-cb: download-cb.c
	$(CC) $(CFLAGS) $(WEBKIT) -o $@ $<


screenshot: screenshot.c
	$(CC) $(CFLAGS) `pkg-config --cflags --libs webkitgtk-3.0 cairo-pdf` -o $@ $<


dom: dom.c
	$(CC) $(CFLAGS) `pkg-config --cflags --libs webkitgtk-3.0` -o $@ $<


.PHONY: clean
clean:
	rm -f transparent
	rm -f download-cb
	rm -f screenshot
	rm -f dom
