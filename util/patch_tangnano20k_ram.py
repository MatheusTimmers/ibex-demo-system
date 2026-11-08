#!/usr/bin/env python3
import json
import re
import sys

CELL = re.compile(r"u_ibex_demo_system\.u_ram\.u_ram\.gen_generic\.u_impl_generic\.mem\.(\d+)\.(\d+)$")
BITS_PER_COLUMN = 2
ENTRIES_PER_RAM_LINE = 128
RAM_LINES = 64
WORD_BITS = 32


def read_vmem(path):
    with open(path) as file:
        text = re.sub(r"/\*.*?\*/", " ", file.read(), flags=re.S)
    words = {}
    address = 0
    for token in text.split():
        if token.startswith("@"):
            address = int(token[1:], 16)
            continue
        words[address] = int(token, 16)
        address += 1
    return words


def ram_line(words, column, line):
    bits = 0
    first_address = line * ENTRIES_PER_RAM_LINE
    for entry in range(ENTRIES_PER_RAM_LINE):
        word = words.get(first_address + entry, 0)
        value = (word >> (column * BITS_PER_COLUMN)) & ((1 << BITS_PER_COLUMN) - 1)
        bits |= value << (entry * BITS_PER_COLUMN)
    return format(bits, f"0{ENTRIES_PER_RAM_LINE * BITS_PER_COLUMN}b")


def ram_cells(design):
    modules = design["modules"]
    top = modules.get("top_tangnano20k") or next(iter(modules.values()))
    found = []
    for name, cell in top["cells"].items():
        match = CELL.search(name)
        if match:
            found.append((int(match.group(2)), cell))
    if len(found) != WORD_BITS:
        sys.exit(f"esperava {WORD_BITS} blocos de RAM e achei {len(found)}")
    return found


def main():
    with open(sys.argv[1]) as file:
        design = json.load(file)
    words = read_vmem(sys.argv[2])

    for index, cell in ram_cells(design):
        column = index % (WORD_BITS // BITS_PER_COLUMN)
        for line in range(RAM_LINES):
            cell["parameters"][f"INIT_RAM_{line:02X}"] = ram_line(words, column, line)

    if len(sys.argv) > 3:
        with open(sys.argv[3], "w") as file:
            json.dump(design, file)


if __name__ == "__main__":
    main()
