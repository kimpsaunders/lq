SRCS=devino.c lq.c
OBJS=$(patsubst %.c,%.o,$(SRCS))

LQ=lq
CFLAGS=-Wall -pedantic -g

lq: $(OBJS)
	$(CC) -o $@ $^

clean:
	rm -f $(LQ) $(OBJS)
