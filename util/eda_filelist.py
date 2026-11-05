#!/usr/bin/env python3
import os
import sys

import yaml

with open(sys.argv[1]) as f:
    files = yaml.safe_load(f)["files"]

sv_files = [f for f in files if f.get("file_type") == "systemVerilogSource"]

include_dirs = []
for f in sv_files:
    if f.get("is_include_file"):
        include_dir = f.get("include_path") or os.path.dirname(f["name"])
        if include_dir not in include_dirs:
            include_dirs.append(include_dir)

for include_dir in include_dirs:
    print(f"-I{include_dir}")

for f in sv_files:
    if f.get("is_include_file"):
        continue
    if os.path.basename(f["name"]) == "prim_generic_clock_gating.sv":
        print(sys.argv[2])
    else:
        print(f["name"])
