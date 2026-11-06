#!/usr/bin/env bash
# Regenerate the README board renders in docs/images/.
set -euo pipefail

cd "$(dirname "$0")/.."
PCB=chili-utility-module.kicad_pcb
OUT=docs/images
mkdir -p "$OUT"

kicad-cli pcb render --side top --zoom 0.9 -w 960 -h 900 -o "$OUT/top.png" "$PCB"
kicad-cli pcb render --side bottom --zoom 0.9 -w 960 -h 900 -o "$OUT/bottom.png" "$PCB"
kicad-cli pcb render --quality high --side top --rotate "-45,0,30" --zoom 0.7 \
  -w 1300 -h 1150 -o "$OUT/iso.png" "$PCB"
