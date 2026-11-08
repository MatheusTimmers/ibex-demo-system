#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    echo "uso: $0 <imagem.vmem>" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VMEM="$(realpath "$1")"
GOWIN="${GOWIN_HOME:-$HOME/.local/opt/gowin}"
CORE_DIR="$ROOT/build/lowrisc_ibex_demo_system_0/synth_tangnano20k-verilator"
OUT="$ROOT/build/tangnano20k_gowin"
TOP=top_tangnano20k

rm -rf "$OUT"
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
    -e '/\$display("Initializing memory/d' \
    -e '/reg unused_scramble_inputs = /d' \
    -e "s|parameter SRAMInitFile = \"\";|parameter SRAMInitFile = \"$VMEM\";|" "$TOP.v"

python3 "$ROOT/util/gowin_ram_byte_lanes.py" "$TOP.v" "$VMEM"

cat > clock.sdc <<SDC
create_clock -name IO_CLK -period 37.037 [get_ports {IO_CLK}]
SDC

cat > build.tcl <<TCL
set_device -device_version C GW2AR-LV18QN88C8/I7
add_file $OUT/$TOP.v
add_file $ROOT/data/pins_tangnano20k.cst
add_file $OUT/clock.sdc
set_option -output_base_name $TOP
set_option -top_module $TOP
set_option -verilog_std v2001
set_option -use_mspi_as_gpio 1
run all
TCL

LD_PRELOAD=/lib64/libfreetype.so.6 QT_QPA_PLATFORM=minimal "$GOWIN/IDE/bin/gw_sh" build.tcl 2>&1 | tee gowin.log

test -f "$OUT/impl/pnr/$TOP.fs"
echo "$OUT/impl/pnr/$TOP.fs"
