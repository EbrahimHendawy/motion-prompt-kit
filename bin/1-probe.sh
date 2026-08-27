#!/bin/bash
# Step 1 — read the footage and write project.json.
#
# Two things here are worth more than they look:
#  * every field is queried on its own. `-show_entries stream=w,h,rate` returns the
#    fields in the stream's own order, not the order you asked for, so reading them
#    positionally silently swaps values on some files.
#  * the black bars are measured, not detected. ffmpeg's cropdetect misses them at its
#    default threshold, and delivering at the container size instead of the picture size
#    is the most expensive mistake in this whole pipeline.
set -e
V="$1"
if [ -z "$V" ] || [ ! -f "$V" ]; then
  echo "الاستخدام: bin/1-probe.sh /path/to/video.mov"; exit 1
fi
DIR="$(cd "$(dirname "$0")/.." && pwd)"

get() { ffprobe -v error -select_streams v:0 -show_entries "stream=$1" \
        -of default=nw=1:nk=1 "$V" | head -1; }

W=$(get width); H=$(get height); RATE=$(get r_frame_rate)
NB=$(get nb_frames); DURSEC=$(get duration)
TC=$(ffprobe -v error -select_streams v:0 -show_entries stream_tags=timecode \
     -of default=nw=1:nk=1 "$V" | head -1)
[ -z "$TC" ] && TC=$(ffprobe -v error -show_entries format_tags=timecode \
                     -of default=nw=1:nk=1 "$V" | head -1)
[ -z "$DURSEC" ] || [ "$DURSEC" = "N/A" ] && \
  DURSEC=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$V" | head -1)

echo "الفيديو  : ${W}x${H}   ${RATE} fps   ${NB} فريم   ${DURSEC}s"
echo "تايم كود : ${TC:-مفيش}"
echo
echo "بقيس الشرايط السودا عند ٣ نقط…"

BARS=""
for T in $(python3 -c "d=float('$DURSEC');print(int(d*0.15),int(d*0.5),int(d*0.85))"); do
  ffmpeg -nostdin -y -v error -ss "$T" -i "$V" -frames:v 1 -vf "scale=8:$H,format=gray" \
    -f rawvideo "/tmp/kitrows.raw"
  LINE=$(python3 -c "
d=open('/tmp/kitrows.raw','rb').read(); H=$H
rows=[sum(d[i*8:(i+1)*8])/8 for i in range(H)]
nz=[i for i,v in enumerate(rows) if v>12]
print('%d %d'%(nz[0], H-1-nz[-1]) if nz else '0 0')")
  echo "  عند ${T}s → فوق ${LINE% *}  تحت ${LINE#* }"
  BARS="$BARS$LINE"$'\n'
done
rm -f /tmp/kitrows.raw

BARS="$BARS" python3 - "$V" "$W" "$H" "$RATE" "$NB" "$DURSEC" "$TC" "$DIR" <<'PY'
import json, os, sys
v, W, H, rate, nb, dursec, tc, DIR = sys.argv[1:9]
W, H = int(W), int(H)
bars = [l.split() for l in os.environ["BARS"].strip().split("\n") if l.strip()]
# take the SMALLEST bar seen — a bar that shrinks at any point in the film is not a bar
top = min(int(b[0]) for b in bars)
bot = min(int(b[1]) for b in bars)
if top < 4 and bot < 4:
    top = bot = 0
pic_h = H - top - bot

num, den = (int(x) for x in rate.split("/"))
sys.path.insert(0, os.path.join(DIR, "bin"))
from lib import rate_key
key = rate_key(num, den)
fps_r = num / den

frames = int(nb) if nb.isdigit() else round(float(dursec) * fps_r)

tc_frames = 0
if tc:
    h, m, s, f = (int(x) for x in tc.replace(";", ":").split(":"))
    tc_frames = ((h * 60 + m) * 60 + s) * round(fps_r) + f

cfg = {
  "video": os.path.abspath(v),
  "frame":   [W, H],
  "picture": [W, pic_h],
  "letterbox": {"top": top, "bottom": bot},
  "fps": key, "fps_exact": [num, den],
  "total_frames": frames, "duration": float(dursec),
  "timecode": tc or None, "timecode_frames": tc_frames,
  # the canvas always matches the PICTURE's aspect, so a letterboxed source still
  # renders overlays at exactly the delivered size
  "canvas": [1920, round(1920 * pic_h / W / 2) * 2],
  "scale": round(W / 1920, 6),
}
json.dump(cfg, open(os.path.join(DIR, "project.json"), "w"), ensure_ascii=False, indent=2)
print()
if top or bot:
    print("!! فيه شرايط: فوق %d تحت %d" % (top, bot))
    print("   التسليم هيكون على مقاس الصورة %dx%d — مش مقاس الإطار %dx%d" % (W, pic_h, W, H))
    print("   وفي Resolve: Image Scaling > Mismatched Resolution > Center crop with no resizing")
else:
    print("مفيش شرايط — الإطار كله صورة.")
cw, ch = cfg["canvas"]
print("الكانفاس %dx%d والـ scale = %s   (يعني المشهد بيترندر %dx%d)"
      % (cw, ch, cfg["scale"], cw * cfg["scale"], ch * cfg["scale"]))
print("التايم كود بيبدأ عند فريم %d" % tc_frames)
print("\n-> project.json")
PY
