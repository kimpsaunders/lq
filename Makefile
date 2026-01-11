SRCS=devino.c lq.c
OBJS=$(patsubst %.c,%.o,$(SRCS))

LQ=lq
CFLAGS=-Wall -pedantic -g

$(LQ): $(OBJS)
	$(CC) -o $@ $^

install: $(LQ)
	install -D $< $(DESTDIR)$(prefix)/bin/hello

uninstall:
	-rm -f $(DESTDIR)$(prefix)/bin/hello

clean:
	rm -f $(LQ) $(OBJS)
