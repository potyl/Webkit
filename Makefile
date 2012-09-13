WEBKIT=$(shell pkg-config --cflags --libs webkitgtk-3.0)

CFLAGS=-std=c99

.PHONY: all
all: transparent download-cb screenshot dom-walker js

.PHONY: run
run: transparent
	./$< file://$(PWD)/sample.html


transparent: transparent.c
	$(CC) $(CFLAGS) -o $@ $< $(WEBKIT)


download-cb: download-cb.c
	$(CC) $(CFLAGS) -o $@ $< $(WEBKIT)


dom-walker: dom-walker.c
	$(CC) $(CFLAGS) -o $@ $< $(WEBKIT)


js: js.c
	$(CC) $(CFLAGS) -o $@ $< $(WEBKIT)


screenshot: screenshot.c
	$(CC) $(CFLAGS) -o $@ $< `pkg-config --cflags --libs webkitgtk-3.0 cairo-pdf libsoup-2.4`


.PHONY: clean
clean:
	rm -f transparent
	rm -f download-cb
	rm -f screenshot
	rm -f dom-walker
	rm -f js

