#!/usr/bin/env bash
# Assembles every isa/rv32ui/*.S test from riscv-tests into a flat
# little-endian hex image (compliance/build/<name>.hex) ready for
# $readmemh, relocated to run from address 0.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$HERE")"
RISCV_TESTS="${RISCV_TESTS:-$REPO_ROOT/riscv-tests}"
ISA_DIR="$RISCV_TESTS/isa/rv32ui"
BUILD_DIR="$HERE/build"

# MacPorts installs riscv32-none-elf-* under /opt/local/bin, which isn't on
# PATH by default.
export PATH="/opt/local/bin:$PATH"

GCC=riscv32-none-elf-gcc
OBJCOPY=riscv32-none-elf-objcopy

if ! command -v "$GCC" >/dev/null 2>&1; then
    echo "error: $GCC not found (expected MacPorts riscv32-none-elf toolchain)" >&2
    exit 1
fi

if [ ! -d "$ISA_DIR" ]; then
    echo "error: $ISA_DIR not found." >&2
    echo "clone riscv-tests with submodules next to this repo first:" >&2
    echo "  git clone --recurse-submodules https://github.com/riscv-software-src/riscv-tests.git \"$RISCV_TESTS\"" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

# Base ISA + Zicsr/Zifencei only: the boilerplate in riscv_test.h uses CSR
# ops (csrw/csrr/mret) and fence.i, but this core doesn't implement M/A/F/D
# and we don't want the assembler accepting instructions it can't run.
declare -a CFLAGS=(
    -march=rv32i_zicsr_zifencei
    -mabi=ilp32
    -static
    -mcmodel=medany
    -fvisibility=hidden
    -nostdlib
    -nostartfiles
    -I"$RISCV_TESTS/env/p"
    -I"$RISCV_TESTS/isa/macros/scalar"
    -T"$HERE/link.ld"
    -Wl,--no-relax
)

shopt -s nullglob
tests=("$ISA_DIR"/*.S)
if [ ${#tests[@]} -eq 0 ]; then
    echo "error: no .S sources found in $ISA_DIR" >&2
    exit 1
fi

count=0
for src in "${tests[@]}"; do
    name="$(basename "$src" .S)"
    elf="$BUILD_DIR/$name.elf"
    bin="$BUILD_DIR/$name.bin"
    hex="$BUILD_DIR/$name.hex"

    "$GCC" "${CFLAGS[@]}" -o "$elf" "$src"
    "$OBJCOPY" -O binary "$elf" "$bin"
    python3 "$HERE/bin2hex.py" "$bin" "$hex"
    count=$((count + 1))
done

echo "built $count/${#tests[@]} tests -> $BUILD_DIR"
