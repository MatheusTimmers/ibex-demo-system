#!/usr/bin/env python3
import re
import sys
from pathlib import Path

LANES = 4
LANE_BITS = 8


def split_vmem(vmem, directory):
    words = {}
    address = 0
    text = re.sub(r"/\*.*?\*/", " ", vmem.read_text(), flags=re.S)
    for token in text.split():
        if token.startswith("@"):
            address = int(token[1:], 16)
            continue
        words[address] = int(token, 16)
        address += 1

    files = []
    for lane in range(LANES):
        path = directory / f"ram_lane{lane}.mem"
        lines = [
            f"@{address:x} {(word >> (lane * LANE_BITS)) & 0xFF:02x}"
            for address, word in sorted(words.items())
        ]
        path.write_text("\n".join(lines) + "\n")
        files.append(path)
    return files


def lane_block(lane, init_file):
    low = lane * LANE_BITS
    slice_ = f"[{low + LANE_BITS - 1}:{low}]"
    return f"""	reg [7:0] lane{lane} [0:Depth - 1];
	initial $readmemh("{init_file}", lane{lane});
	always @(posedge clk_a_i)
		if (a_req_i) begin
			if (a_write_i && a_wmask[{lane}])
				lane{lane}[a_addr_i] <= a_wdata_i{slice_};
			else
				a_rdata_o{slice_} <= lane{lane}[a_addr_i];
		end
	always @(posedge clk_b_i)
		if (b_req_i)
			b_rdata_o{slice_} <= lane{lane}[b_addr_i];
"""


verilog = Path(sys.argv[1])
vmem = Path(sys.argv[2])
source = verilog.read_text()

module = source.index("module prim_generic_ram_2p (")
memory = source.index("\treg [Width - 1:0] mem [0:Depth - 1];\n", module)
first_always = source.index("\talways @(posedge clk_a_i)\n", memory)
end = source.index("endmodule", first_always)

declaration_end = memory + len("\treg [Width - 1:0] mem [0:Depth - 1];\n")
files = split_vmem(vmem, verilog.parent.resolve())
lanes = "".join(lane_block(lane, path) for lane, path in enumerate(files))

source = source[:memory] + source[declaration_end:first_always] + lanes + source[end:]
verilog.write_text(source)
