#!/usr/bin/env python3
"""Flatten a raw little-endian binary into one 32-bit hex word per line,
suitable for Verilog $readmemh.
"""
import struct
import sys


def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <in.bin> <out.hex>", file=sys.stderr)
        return 1

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        data = f.read()

    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)

    with open(dst, "w") as out:
        for i in range(0, len(data), 4):
            word = struct.unpack_from("<I", data, i)[0]
            out.write(f"{word:08x}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
