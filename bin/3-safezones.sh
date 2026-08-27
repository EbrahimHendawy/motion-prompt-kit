#!/bin/bash
# Step 3 — where is the speaker actually sitting in the frame?
# Writes a frame with a coordinate grid burned in. Read the face box off it once and
# every card position for the whole video follows from those four numbers.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
V=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['video'])")
read CW CH < <(python3 -c "import json;c=json.load(open('$DIR/project.json'))['canvas'];print(c[0],c[1])")
T="${1:-}"
[ -z "$T" ] && T=$(python3 -c "import json;print(round(json.load(open('$DIR/project.json'))['duration']*0.4,2))")

CELL_W=$((CW / 12)); CELL_H=$((CH / 9))
ffmpeg -nostdin -y -v error -ss "$T" -i "$V" \
  -vf "scale=${CW}:${CH},drawgrid=w=${CELL_W}:h=${CELL_H}:t=2:c=red@0.65" \
  -frames:v 1 "$DIR/safezones.png"
echo "-> safezones.png   (عند ${T}s)"
echo
echo "الشبكة كل خانة ${CELL_W}×${CELL_H} على كانفاس ${CW}×${CH}."
echo "افتح الصورة وسجّل ٤ أرقام:"
echo "  • الوش: من x كام لـ x كام"
echo "  • الدقن: عند y كام   ← أهم رقم، أي كارت تحتاني لازم يبدأ تحتيه بـ100 بكسل على الأقل"
echo "  • المايك والإيدين: من y كام"
echo "وبعدين حطّهم في README تحت 'المناطق الآمنة' عشان تفضل قدامك."
