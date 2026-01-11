SCENARIOS=$(shell ls *.bash)
DIRECTORIES=$(patsubst %.bash,%,$(SCENARIOS))
DOTDOT=$(dir $(PWD))
MD=README.md

all: $(DIRECTORIES) $(MD)

%.md: %.m4
	m4 $< > $@
	cp $@ ..

%: %.bash
	rm -rf $@.tmp
	mkdir $@.tmp
	cd $@.tmp && PATH=$$PATH:$(DOTDOT) ../$^
	ls $@.tmp/$@-*.sh && PATH=$$PATH:$(DOTDOT) ./interpreter $@.tmp/$@-*.sh || true
	mv $@.tmp $@
