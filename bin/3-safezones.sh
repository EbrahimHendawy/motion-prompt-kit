#!/bin/bash
# Step 3 — where can you actually put things?
#
# Two outputs, and the second one is the one that matters:
#
#   safezones.png  a single frame with a coordinate grid burned in. Good for reading the
#                  face box off once.
#
#   motion map     a per-pixel variance map computed over ~50 frames spanning the WHOLE
#                  video. One frame lies: the speaker's hands may be down at 0:40 and up
#                  across the lower third for the other two minutes. Only the map over
#                  time tells you where a card can sit for the entire clip.
#
# On a talking-head shot the map routinely rules out the bottom band entirely — which is
# exactly where the default lower-third wants to go.
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

RAW="${TMPDIR:-/tmp}/kit-motion.raw"
DUR=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['duration'])")
STEP=$(python3 -c "print(max(1, round($DUR/50, 3)))")
ffmpeg -nostdin -v error -i "$V" \
  -vf "fps=1/${STEP},scale=192:108,format=gray" -f rawvideo -pix_fmt gray "$RAW" -y

python3 - "$RAW" "$CW" "$CH" <<'PY'
import os, sys
raw_path, CW, CH = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
W, H = 192, 108
raw = open(raw_path, 'rb').read()
N = len(raw) // (W * H)
if N < 4:
    raise SystemExit("مش قادر أقرا فريمات كفاية للخريطة")
frames = [raw[i*W*H:(i+1)*W*H] for i in range(N)]

var = [0.0] * (W * H)
for p in range(W * H):
    vals = [frames[f][p] for f in range(N)]
    m = sum(vals) / N
    var[p] = sum((v - m) ** 2 for v in vals) / N
mx = max(var) or 1.0

print("خريطة الحركة على %d فريم من الفيديو كله" % N)
print("(· ثابت تماماً   ░ حركة خفيفة   ▓ حركة   █ حركة كتير)")
print()
rows = []
for gy in range(9):
    line = ""
    for gx in range(12):
        tot = cnt = 0
        for y in range(gy*H//9, (gy+1)*H//9):
            for x in range(gx*W//12, (gx+1)*W//12):
                tot += var[y*W+x]; cnt += 1
        a = tot / cnt / mx
        line += "█" if a > .15 else ("▓" if a > .06 else ("░" if a > .02 else "·"))
    rows.append(line)
    print("   %s   y %4d–%-4d" % (line, gy*CH//9, (gy+1)*CH//9))
print("   " + "".join("^" for _ in range(12)))
print("   x: كل خانة %d بكسل، من 0 لـ %d" % (CW//12, CW))
print()

# كل المستطيلات الثابتة، وبعدين أكبر أربعة مختلفين فعلاً عن بعض
def quiet(gx, gy): return rows[gy][gx] in "\u00b7\u2591"

cands = []
for gy0 in range(9):
    for gy1 in range(gy0, 9):
        run = []
        for gx in range(13):
            ok = gx < 12 and all(quiet(gx, y) for y in range(gy0, gy1 + 1))
            if ok:
                run.append(gx)
            else:
                if len(run) >= 2 and (gy1 - gy0) >= 1:
                    cands.append((len(run) * (gy1 - gy0 + 1), run[0], run[-1] + 1, gy0, gy1 + 1))
                run = []
cands.sort(reverse=True)

def overlap(a, b):
    _, ax0, ax1, ay0, ay1 = a; _, bx0, bx1, by0, by1 = b
    ix = max(0, min(ax1, bx1) - max(ax0, bx0))
    iy = max(0, min(ay1, by1) - max(ay0, by0))
    inter = ix * iy
    return inter / min((ax1-ax0)*(ay1-ay0), (bx1-bx0)*(by1-by0)) if inter else 0

picked = []
for c in cands:
    if all(overlap(c, p) < 0.55 for p in picked):
        picked.append(c)
    if len(picked) == 4: break

print("المناطق الثابتة اللي تقدر تحط فيها:")
if picked:
    for _, gx0, gx1, gy0, gy1 in picked:
        x0, x1 = gx0*CW//12, gx1*CW//12
        y0, y1 = gy0*CH//9,  gy1*CH//9
        print("   x %4d\u2013%-5d y %4d\u2013%-5d   (%d\u00d7%d)" % (x0, x1, y0, y1, x1-x0, y1-y0))
else:
    print("   مفيش منطقة كبيرة ثابتة \u2014 المتكلم بيتحرك في الكادر كله.")
    print("   استخدم كت أواي (شاشة كاملة) بدل الكروت.")
print()
print("القاعدة: أي كارت لازم يقع جوه منطقة كلها · أو ░ — مش ▓ ولا █.")
PY
rm -f "$RAW"
