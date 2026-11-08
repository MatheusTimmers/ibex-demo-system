#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    echo "uso: $0 <imagem.vmem>" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VMEM="$(realpath "$1")"
OSS="${OSS_CAD_SUITE:-$HOME/.local/opt/oss-cad-suite}"
CORE_DIR="$ROOT/build/lowrisc_ibex_demo_system_0/synth_tangnano20k-verilator"
OUT="$ROOT/build/tangnano20k"
TOP=top_tangnano20k

mkdir -p "$OUT"
cd "$ROOT"

source "$ROOT/.venv/bin/activate"
fusesoc --cores-root=. run --target=synth_tangnano20k --tool=verilator --setup lowrisc:ibex:demo_system \
    > "$OUT/fusesoc.log" 2>&1

python3 "$ROOT/util/eda_filelist.py" "$CORE_DIR"/*.eda.yml \
    "$ROOT/rtl/fpga/prim_generic_clock_gating_passthrough.sv" > "$OUT/sv2v.args"

cd "$CORE_DIR"
xargs -a "$OUT/sv2v.args" sv2v --define=SYNTHESIS --define=YOSYS \
    --define=PRIM_DEFAULT_IMPL=prim_pkg::ImplGeneric > "$OUT/$TOP.v"
cd "$OUT"

sed -i -e '/reg show_mem_paths;/d' \
    -e '/\$value\$plusargs/d' \
    -e '/if (show_mem_paths)/,+1d' \
    -e '/\$display("Initializing memory/d' "$TOP.v"

"$OSS/bin/yosys" -l yosys.log -q -p "
    read_verilog -defer $TOP.v;
    chparam -set SRAMInitFile \"$VMEM\" $TOP;
    synth_gowin -top $TOP -family gw2a -json $TOP.json;
    tee -o stat.txt stat
"

"$OSS/bin/nextpnr-himbaechel" -l nextpnr.log \
    --json "$TOP.json" --write "$TOP.pnr.json" \
    --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C \
    --vopt cst="$ROOT/data/pins_tangnano20k.cst" --freq 27

"$OSS/bin/gowin_pack" -d GW2A-18C --mspi_as_gpio -o "$TOP.fs" "$TOP.pnr.json"

echo "$OUT/$TOP.fs"
