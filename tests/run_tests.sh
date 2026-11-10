#!/usr/bin/env bash
# sim6809 test runner.
#   run_tests.sh sim    the simulator's self-tests (tests/*.asm)
#   run_tests.sh man    the man pages in docs/man
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=$ROOT/build
SIM=$BUILD/sim6809
OUT=$BUILD/tests

pass=0
fail=0
mkdir -p "$OUT"

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL $1: $2"; }

# assemble ASM -> S19; listing alongside
assemble() {
    lwasm -9 -f srec --list="${2%.s19}.lst" -o "$2" "$1" 2>"$2.err"
}

# compare actual file $2 with expected $3; name $1
check_diff() {
    if diff -u "$3" "$2" >"$2.diff" 2>&1; then
        return 0
    fi
    bad "$1" "output differs (see $2.diff)"
    head -20 "$2.diff"
    return 1
}

# (address, bytes) of each instruction from LEN_BEGIN up to LEN_END, from an
# lwasm listing ($1 = listing) or a sim6809 -t trace ($1 = trace)
len_pairs() {
    awk -v b="$2" -v e="$3" '$1 ~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ &&
        $2 ~ /^[0-9A-F]+$/ && $1 >= b && $1 < e { print $1, $2 }' "$1"
}

# sim test: assemble, run, compare stdout+rc with .out.  Optional first-line
# "; SIMARGS: ..." passes extra simulator options.  os9_*.asm files are OS-9
# modules: assembled with -f os9 and run with --os9.  Files whose listing has
# LEN_BEGIN/LEN_END also get the trace-vs-listing instruction length check.
sim_one() {    # $1 = asm, $2 = expected .out
    local name s19 lst args b e
    name=sim/$(basename "$1" .asm)
    s19=$OUT/$(basename "$1" .asm).s19
    lst=${s19%.s19}.lst
    args=$(sed -n '1s/^; SIMARGS: *//p' "$1")
    case $(basename "$1") in
    os9_*)      # OS-9 module tests: assembled with -f os9, run with --os9
        if ! lwasm -9 -f os9 --list="$lst" -o "$s19" "$1" 2>"$s19.err"; then
            bad "$name" "lwasm failed"; cat "$s19.err"; return
        fi
        args="--os9 $args" ;;
    flex_*)     # FLEX tests: S-records converted to a .CMD file, run with --flex
        if ! assemble "$1" "$s19" || ! "$BUILD/srec2flex" "$s19" "${s19%.s19}.cmd" 2>>"$s19.err"; then
            bad "$name" "lwasm or srec2flex failed"; cat "$s19.err"; return
        fi
        s19=${s19%.s19}.cmd
        args="--flex $args" ;;
    *)
        if ! assemble "$1" "$s19"; then bad "$name" "lwasm failed"; cat "$s19.err"; return; fi ;;
    esac
    b=$(awk '/LEN_BEGIN/ { print $1; exit }' "$lst")
    e=$(awk '/LEN_END/ { print $1; exit }' "$lst")
    [ -n "$b" ] && args="$args -t"
    # shellcheck disable=SC2086
    "$SIM" $args "$s19" </dev/null >"$s19.stdout" 2>"$s19.stderr"
    echo "rc=$?" >>"$s19.stdout"
    check_diff "$name" "$s19.stdout" "$2" || return
    if [ -n "$b" ]; then
        len_pairs "$lst" "$b" "$e" >"$s19.want"
        len_pairs "$s19.stderr" "$b" "$e" >"$s19.got"
        if [ ! -s "$s19.want" ]; then bad "$name" "no instructions in listing range"; return; fi
        check_diff "$name (lengths)" "$s19.got" "$s19.want" || return
        echo "  $name: $(wc -l <"$s19.want") instructions match the lwasm listing"
    fi
    ok
}

suite_sim() {
    local f
    for f in "$ROOT"/tests/*.asm; do
        [ -e "$f" ] || continue
        sim_one "$f" "${f%.asm}.out"
    done
    if python3 "$ROOT/tests/gen_len_ops.py" >"$OUT/len_ops.asm"; then
        sim_one "$OUT/len_ops.asm" "$ROOT/tests/len_ops.out"
    else
        bad sim/len_ops "generator failed"
    fi
}

# The man pages in docs/man: each must format without groff warnings, and
# must mention every option its program's --help lists.
suite_man() {
    local p warn missing
    for p in sim6809 srec2flex; do
        if [ ! -e "$ROOT/docs/man/$p.1" ]; then bad "man/$p" "no docs/man/$p.1"; continue; fi
        warn=$(groff -man -ww -z "$ROOT/docs/man/$p.1" 2>&1)
        [ -n "$warn" ] && { bad "man/$p" "groff warnings"; echo "$warn"; continue; }
        # each option, written \- in roff, as a whole word
        missing=$("$BUILD/$p" --help 2>&1 | python3 -I -c '
import re, sys
page = open(sys.argv[1]).read()
for o in re.findall(r"^ +(-[-a-z0-9]+)", sys.stdin.read(), re.M):
    roff = re.escape(o.replace("-", "\\-"))
    if not re.search(r"(^|[^-A-Za-z0-9\\])" + roff + r"($|[^-A-Za-z0-9\\])", page, re.M):
        print(o, end=" ")
' "$ROOT/docs/man/$p.1")
        [ -n "$missing" ] && { bad "man/$p" "options missing from the page:$missing"; continue; }
        ok
    done
}

case ${1:-} in
    sim)   suite_sim ;;
    man)   suite_man ;;
    *)     sed -n '2,4s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
esac

echo "${1}: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
