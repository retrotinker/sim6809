# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

sim6809 is a headless Motorola MC6809 simulator in C11, with OS-9 and FLEX program environments and board devices, plus `srec2flex` (S-records → FLEX `.CMD`). It was split out of [plm09](https://github.com/retrotinker/plm09) (the PL/M-80 → 6809 compiler) at plm09 0.4.6, with its history; plm09's test suites run their compiled programs in it, so keep its behavior compatible (options, MMIO, exit statuses, OS-9/FLEX emulation) or change plm09 in step.

**Status:** version 1.0.0 (`VERSION` in the Makefile, `Version` in `sim6809.spec`; bump both and add a `%changelog` entry together). GitHub: retrotinker/sim6809 (this repo replaced the content of an unrelated 2016 fork of Jerome Thoen's sim6809; a backup bundle of that is in `~/claude/backup/`).

Requirements: gcc, make; for the tests lwasm (lwtools), python3 and groff.

## Commands

- `make` builds `build/sim6809` and `build/srec2flex` with `-std=c11 -Wall -Wextra -Werror` (`WERROR ?= -Werror`; `CFLAGS`/`LDFLAGS` default to `-O2 -g`/empty so rpmbuild's flags can replace them). `--version` prints `SIM6809_VERSION`.
- `make test` (= `make check`) runs `make sim-test` and `make man-test` through `tests/run_tests.sh sim|man`. On a mismatch it prints a diff and leaves every intermediate in `build/tests/`.
- `make install` copies both programs to `$(DESTDIR)$(BINDIR)` and `docs/man/*.1` to `$(DESTDIR)$(MANDIR)/man1`. Test it with `DESTDIR=/tmp/...`.
- `make rpm` / `make srpm` build `sim6809.spec` from `git archive v$(VERSION)` (HEAD until the version is tagged) into `build/rpm`; `%check` runs `make test`. Check with `rpmlint` and `mock -r fedora-44-x86_64`.
- GitHub Actions CI (`.github/workflows/ci.yml`) runs `make test` with gcc and clang in a `fedora:44` container on every PR and push to master; failing runs upload `build/tests/`. A second job, `plm09 tests`, checks out retrotinker/plm09's master and runs its `make test` with the sim6809 and srec2flex just built, so a change that breaks plm09 fails here, on its own PR (plm09's CI also builds this repo's master).
- `make docs` rebuilds `docs/sim6809.pdf` from `docs/sim6809.md` with pandoc + xelatex (`docs/tex/footnotehyper.sty` stands in for a missing package).

**Test file conventions:**
- **sim:** `tests/X.asm` + `X.out`. The expected output is stdout followed by a last line `rc=N`. An optional first line `; SIMARGS: -n 1000` passes extra options. `os9_*.asm` are assembled with `lwasm -f os9` and run with `--os9`; `flex_*.asm` are converted by `srec2flex` and run with `--flex`. `gen_len_ops.py` generates every opcode × addressing mode; the runner checks each traced (address, bytes) pair between `LEN_BEGIN` and `LEN_END` against the lwasm listing.
- **man:** `docs/man/{sim6809,srec2flex}.1` must format with no output from `groff -man -ww -z`, and every option `--help` lists must appear in the page as a whole word, written with `\-`.

Most tests `INCLUDE harness.inc`: `TBEGIN`/`TEND` print `OK name`; `JSR CHKA` + `FCB expected`, `JSR CHKD` + `FDB expected`; table-driven `RUN8`/`RUN16`. Expected values are worked out by hand from the datasheet, so when a test fails, check the expected value as well as the simulator. LD/ST set N, Z and V, while TFR, LEAS/LEAU and PSH/PUL (except PULS CC) leave CC alone.

## Documentation rule

Every changed or added feature updates, in the same commit: `docs/sim6809.md` (and `make docs` for the PDF), `docs/man/sim6809.1` / `srec2flex.1` when options, exit statuses or usage change, and `README.md` when anything users see changes. Quote real output from actual runs. Keep this file's status current.

## Architecture

| File | Contents |
|---|---|
| `src/cpu6809.c`, `cpu6809.h` | the CPU core: full MC6809 instruction set, IRQ/FIRQ/NMI (`cpu_interrupt()`, called by `main.c` before each step), CWAI/SYNC, MMIO; no cycle counts |
| `src/os9.c`, `flex.c` | the `--os9` (system calls through `swi2_hook`) and `--flex` (DOS entry points through `pc_hook`, FLEX memory write-protected, FMS on host files) environments |
| `src/disasm.c` | table-driven disassembler, used only by `-t` |
| `src/srec.c` | S1/S9 and Intel HEX loader |
| `src/main.c` | the driver: options, devices (ACIA, FT245), run loop, trace |
| `tools/srec2flex.c` | S-records → FLEX binary |

Instruction lengths are decoded separately in `cpu6809.c` and `disasm.c`; the `len_ops` test keeps both in agreement with lwasm.

MMIO at $FF00 by default (`--io`; `IO_*` in `cpu6809.h`):

| Address | Access | Meaning |
|---|---|---|
| +0 | write | put a character |
| +1 | read | get a character (0 at EOF) |
| +2 | write | exit with that status |
| +4/+5 | write | print the 16-bit value in decimal and a newline; the write to +5 triggers it |
| +6 | write/read | assert interrupt lines (1 IRQ, 2 FIRQ, 4 NMI) / read the asserted lines |
| +7 | write | release lines (IRQ and FIRQ are level-triggered) |
| +8/+9 | write | timer period in instructions; the write to +9 starts it, 0 stops it |
| +10 | write | lines the timer asserts (default IRQ) |

Exit status: the byte written to the exit port; 124 instruction limit; 125 illegal opcode, SWI without `--swi`, unsupported OS-9 call/FLEX entry, or memory protection violation; 2 usage or load error.

## lwasm pitfalls

- lwasm defaults to 6309 mode: always pass `-9` (and `PRAGMA 6809`).
- The listing needs `--list=FILE`.
- Anything in column 1 is a label, so indent mnemonics with a tab.
