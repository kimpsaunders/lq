LQ=lq

SRCS=devino.c lq.c
OBJS=$(patsubst %.c,%.o,$(SRCS))
MANS=$(LQ).1.gz

all: $(LQ) $(MANS)

$(LQ): $(OBJS)
	$(CC) -o $@ $^

install: $(LQ) $(MANS)
	install -D $(LQ) $(DESTDIR)$(prefix)/usr/bin/$(LQ)
	install -D $(LQ).1.gz $(DESTDIR)$(prefix)/usr/share/man/man1/$(LQ).1.gz

uninstall:
	-rm -f $(DESTDIR)$(prefix)/usr/bin/$^

clean:
	rm -f $(LQ) $(OBJS)

%.gz: %
	gzip -k9 $^
