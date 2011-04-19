.PHONY: run
run: transparent
	./$< file://$(PWD)/sample.html

transparent: transparent.c
	$(CC) `pkg-config --cflags --libs webkit-1.0` -o $@ $<


.PHONY: clean
clean:
	rm -f transparent
