VERSION := 1.3.0

# CFLAGS and LDFLAGS may be replaced (rpmbuild sets its own); the language
# and warning flags are always used, and WERROR= turns off -Werror
CC      ?= gcc
CFLAGS  ?= -O2 -g
WERROR  ?= -Werror
ALL_CFLAGS = -std=c11 -Wall -Wextra $(WERROR) $(CPPFLAGS) $(CFLAGS) -DSIM6809_VERSION='"$(VERSION)"'
BUILD   := build

SIM_SRCS := $(wildcard src/*.c)
SIM_OBJS := $(SIM_SRCS:src/%.c=$(BUILD)/src/%.o)

SIM := $(BUILD)/sim6809
S2F := $(BUILD)/srec2flex

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
MANPAGES := docs/man/sim6809.1 docs/man/srec2flex.1

.PHONY: all install rpm srpm docs test check sim-test man-test clean

all: $(SIM) $(S2F)

$(SIM): $(SIM_OBJS)
	$(CC) $(ALL_CFLAGS) $(LDFLAGS) -o $@ $^

$(S2F): tools/srec2flex.c | $(BUILD)/src
	$(CC) $(ALL_CFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD)/src/%.o: src/%.c | $(BUILD)/src
	$(CC) $(ALL_CFLAGS) -MMD -MP -c -o $@ $<

$(BUILD)/src:
	mkdir -p $@

-include $(SIM_OBJS:.o=.d)

# the programs that print VERSION (--version) are rebuilt when it changes
$(BUILD)/src/main.o $(S2F): Makefile

# install sim6809 and srec2flex in BINDIR (default $(PREFIX)/bin, PREFIX
# default /usr/local) and their man pages in MANDIR/man1 (default
# $(PREFIX)/share/man); DESTDIR prefixes them all for staged installs
install: all
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -m 755 $(SIM) $(S2F) $(DESTDIR)$(BINDIR)
	install -m 644 $(MANPAGES) $(DESTDIR)$(MANDIR)/man1

# Fedora RPMs, in build/rpm.  The tarball is the release tag v$(VERSION),
# the same files as the GitHub archive the spec's Source0 names, or HEAD
# while VERSION isn't tagged yet; the spec itself comes from the work tree.
RPMTOP := $(abspath $(BUILD)/rpm)
TARBALL := $(RPMTOP)/SOURCES/sim6809-$(VERSION).tar.gz
RPMTREE = $(shell git rev-parse -q --verify refs/tags/v$(VERSION) >/dev/null && echo v$(VERSION) || echo HEAD)

$(TARBALL): .FORCE
	mkdir -p $(RPMTOP)/SOURCES
	@echo "sim6809-$(VERSION).tar.gz from $(RPMTREE)"
	git archive --format=tar.gz --prefix=sim6809-$(VERSION)/ -o $@ $(RPMTREE)

rpm: $(TARBALL)
	rm -rf $(RPMTOP)/RPMS $(RPMTOP)/SRPMS
	rpmbuild -ba --define "_topdir $(RPMTOP)" sim6809.spec

srpm: $(TARBALL)
	rpmbuild -bs --define "_topdir $(RPMTOP)" sim6809.spec

.FORCE:

test check: sim-test man-test

sim-test man-test: all
	tests/run_tests.sh $(@:-test=)

# PDF manual.  docs/tex supplies a stand-in for footnotehyper.sty, which
# pandoc's LaTeX template needs but this TeX installation lacks.
docs: docs/sim6809.pdf

docs/%.pdf: docs/%.md docs/tex/footnotehyper.sty
	cd docs && TEXINPUTS=./tex//: pandoc $*.md -o $*.pdf --pdf-engine=xelatex

clean:
	rm -rf $(BUILD)
