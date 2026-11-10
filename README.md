# sim6809

`sim6809` is a headless simulator for the Motorola MC6809 8-bit
microprocessor. It loads a program in Motorola S-record, Intel HEX or FLEX
binary format, runs it with no display, and reports the result through
standard output and its exit status. That makes it a good fit for automated
tests, scripts and continuous integration.

It was written to run the test programs of
[plm09](https://github.com/retrotinker/plm09), a PL/M-80 compiler for the
6809, but nothing in it depends on the compiler.

Features:

- the complete documented MC6809 instruction set, IRQ/FIRQ/NMI, `CWAI` and
  `SYNC`
- a 16-byte memory-mapped I/O block (character I/O, decimal output, exit
  status, interrupt lines and a timer)
- an optional per-instruction trace with disassembly and registers, and an
  instruction limit
- an OS-9 mode that runs a program module with the basic I/O system calls
  on the terminal and host files, and memory protection
- a FLEX mode that runs a `.CMD` file with FLEX's DOS entry points and File
  Management System on host files
- board devices: an MC6850 ACIA, an FT245RL USB FIFO, working `SWI`, ROM
  regions and reset-vector start, enough to run small boards' monitor ROMs
- `srec2flex`, which converts S-records to a FLEX binary (`.CMD`) file

## Building

`sim6809` is plain C11 with no dependencies beyond the C library:

```
make                  # build/sim6809 and build/srec2flex
make test             # self-tests; needs lwasm (lwtools), python3 and groff
make install          # PREFIX=/usr/local, BINDIR, MANDIR, DESTDIR
make rpm              # Fedora RPM and SRPM in build/rpm
make docs             # docs/sim6809.pdf from docs/sim6809.md (pandoc, xelatex)
```

Fedora RPMs are attached to each
[release](https://github.com/retrotinker/sim6809/releases).

## Usage

```
sim6809 [options] program.s19
lwasm -9 -f srec -o hello.s19 hello.asm && sim6809 hello.s19; echo $?
lwasm -9 -f os9 -o prog prog.asm && sim6809 --os9 --param "file.txt" prog
srec2flex prog.s19 PROG.CMD && sim6809 --flex PROG.CMD
```

The exit status is the byte the program wrote to the exit port, 124 if the
instruction limit was reached, 125 on an illegal opcode, and 2 on a usage or
load error.

The full manual is [docs/sim6809.md](docs/sim6809.md) (also as
[PDF](docs/sim6809.pdf)), and the man pages are `sim6809(1)` and
`srec2flex(1)`.

## License

MIT; see [LICENSE](LICENSE).
