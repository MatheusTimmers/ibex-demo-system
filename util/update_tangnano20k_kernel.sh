#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    echo "uso: $0 <imagem.vmem>" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VMEM="$(realpath "$1")"
OSS="${OSS_CAD_SUITE:-$HOME/.local/opt/oss-cad-suite}"
OUT="$ROOT/build/tangnano20k"
TOP=top_tangnano20k

if [[ ! -f "$OUT/$TOP.pnr.json" ]]; then
    echo "$OUT/$TOP.pnr.json nao existe: rode util/synth_tangnano20k.sh antes" >&2
    exit 1
fi

python3 "$ROOT/util/patch_tangnano20k_ram.py" "$OUT/$TOP.pnr.json" "$VMEM" "$OUT/$TOP.patched.pnr.json"
"$OSS/bin/gowin_pack" -d GW2A-18C --mspi_as_gpio -o "$OUT/$TOP.fs" "$OUT/$TOP.patched.pnr.json" 2>/dev/null

echo "$OUT/$TOP.fs"
