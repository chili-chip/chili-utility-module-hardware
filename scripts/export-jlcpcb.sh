#!/usr/bin/env bash
# Export JLCPCB fabrication + assembly files: gerber/drill zip, BOM and CPL.
# Usage: scripts/export-jlcpcb.sh [VERSION] [OUTPUT_DIR]
set -euo pipefail

NAME=chili-utility-module
PREFIX=chili-utility-module
VERSION=${1:-$(git describe --tags --always --dirty 2>/dev/null || echo dev)}
OUT=${2:-production}
PCB=$NAME.kicad_pcb
SCH=$NAME.kicad_sch

cd "$(dirname "$0")/.."
rm -rf "$OUT"
mkdir -p "$OUT/gerbers"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Gerbers (Protel extensions) + Excellon drill in mm.
kicad-cli pcb export gerbers --subtract-soldermask \
  --layers F.Cu,B.Cu,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts \
  -o "$OUT/gerbers/" "$PCB"
kicad-cli pcb export drill --format excellon --excellon-units mm \
  --generate-map --map-format gerberx2 -o "$OUT/gerbers/" "$PCB"
(cd "$OUT/gerbers" && zip -q "../$PREFIX-$VERSION-gerbers.zip" ./*)
rm -rf "$OUT/gerbers"

# BOM in JLCPCB column format, grouped by value/footprint/LCSC part.
kicad-cli sch export bom \
  --fields 'Value,Reference,${FOOTPRINT_NAME},LCSC' \
  --labels 'Comment,Designator,Footprint,LCSC Part #' \
  --group-by 'Value,${FOOTPRINT_NAME},LCSC' \
  --ref-delimiter ',' --ref-range-delimiter '' \
  --exclude-dnp -o "$OUT/$PREFIX-$VERSION-bom.csv" "$SCH"

# CPL: KiCad position file converted to JLCPCB column names.
kicad-cli pcb export pos --format csv --units mm --side front --exclude-dnp \
  -o "$TMP/pos.csv" "$PCB"
python3 - "$TMP/pos.csv" "$OUT/$PREFIX-$VERSION-cpl.csv" <<'EOF'
import csv, sys
with open(sys.argv[1]) as src, open(sys.argv[2], "w", newline="") as dst:
    w = csv.writer(dst)
    w.writerow(["Designator", "Mid X", "Mid Y", "Layer", "Rotation"])
    for r in csv.DictReader(src):
        w.writerow([r["Ref"], f'{float(r["PosX"]):.4f}mm', f'{float(r["PosY"]):.4f}mm',
                    "Top" if r["Side"] == "top" else "Bottom", f'{float(r["Rot"]) % 360:g}'])
EOF

# Keep only BOM lines JLCPCB places: parts left out of the CPL (hand-soldered parts;
# none since v2, where the motor became SMD) are dropped.
python3 - "$OUT/$PREFIX-$VERSION-bom.csv" "$OUT/$PREFIX-$VERSION-cpl.csv" <<'EOF'
import csv, sys
bom_path, cpl_path = sys.argv[1], sys.argv[2]
placed = {r["Designator"] for r in csv.DictReader(open(cpl_path))}
rows = list(csv.reader(open(bom_path)))
head, body = rows[0], rows[1:]
di = head.index("Designator")
kept, dropped = [], []
for r in body:
    refs = [x.strip() for x in r[di].split(",")]
    keep = [x for x in refs if x in placed]
    dropped += [x for x in refs if x not in placed]
    if keep:
        r[di] = ",".join(keep)
        kept.append(r)
with open(bom_path, "w", newline="") as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(head)
    w.writerows(kept)
if dropped:
    print("hand-soldered, not in the JLCPCB BOM:", ", ".join(dropped))
EOF

ls -1 "$OUT"
