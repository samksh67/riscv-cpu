#!/usr/bin/env bash
# Builds every rv32ui test and runs each against the core, printing a
# pass/fail summary.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$HERE")"
BUILD_DIR="$HERE/build"
SIM="$BUILD_DIR/tb_compliance.vvp"

export PATH="/opt/local/bin:$PATH"

"$HERE/build.sh" || exit 1

if ! command -v iverilog >/dev/null 2>&1; then
    echo "error: iverilog not found" >&2
    exit 1
fi

iverilog -g2012 -o "$SIM" \
    "$HERE/tb_compliance.v" \
    "$REPO_ROOT/cpu.v" \
    "$REPO_ROOT/decoder.v" \
    "$REPO_ROOT/control.v" \
    "$REPO_ROOT/regfile.v" \
    "$REPO_ROOT/alu.v" \
    "$REPO_ROOT/dmem.v"

pass=0
fail=0
declare -a failed=()

shopt -s nullglob
hexes=("$BUILD_DIR"/*.hex)

for hex in "${hexes[@]}"; do
    name="$(basename "$hex" .hex)"
    out="$(vvp "$SIM" +testfile="$hex" 2>&1)"

    if echo "$out" | grep -q "^PASS"; then
        pass=$((pass + 1))
        echo "PASS  $name"
    else
        fail=$((fail + 1))
        failed+=("$name")
        detail="$(echo "$out" | grep -E "^(FAIL|TIMEOUT)")"
        echo "FAIL  $name  ($detail)"
    fi
done

total=$((pass + fail))
echo
echo "==============================="
echo "$pass/$total passed"
if [ ${#failed[@]} -gt 0 ]; then
    echo "Failures:"
    for n in "${failed[@]}"; do
        echo "  - $n"
    done
fi

[ "$fail" -eq 0 ]
