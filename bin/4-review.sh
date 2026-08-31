#!/bin/bash
# Step 4 — one frame per scene, composited on the real footage frame at the same moment.
#
# Two traps live in this file:
#
#  * The scale step is not optional, and it is the RENDER size that matters, not the
#    canvas size. check.js writes at canvas x scale (a 1920x1080 canvas at scale 2 gives
#    a 3840x2160 shot). Scale the FOOTAGE to that same size before the overlay. Scaling
#    it to the bare canvas instead makes every card render at double size, sitting over
#    the speaker's face — which looks like a layout mistake, not a scaling one.
#
#  * ffmpeg reads stdin. Inside a `while read` loop it will swallow the next lines of
#    input, and you get scenes silently skipped or names mangled ("02-x" arriving as
#    "2-x"). Every ffmpeg call in a loop needs -nostdin.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
V=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['video'])")
# check.js يرندر بمقاس الكانفاس × الـscale، فالفيديو لازم يتظبط على المقاس ده هو كمان
# مش على الكانفاس لوحده — وإلا الكارت بيطلع بضعف حجمه ومقصوص من فوق الوش.
read CW CH TOP < <(python3 -c "
import json;c=json.load(open('$DIR/project.json'))
s=c.get('scale',1)
print(int(c['canvas'][0]*s), int(c['canvas'][1]*s), c['letterbox']['top'])")
mkdir -p "$DIR/review"

if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
  SCENES="$1|$2|$3"        # scene | seconds into the scene | seconds into the video
else
  # no arguments: read every clip out of timeline.json and shoot it near its end
  SCENES=$(python3 -c "
import json
d=json.load(open('$DIR/timeline.json'))
for c in d['clips']:
    print('%s|%.2f|%.2f' % (c['scene'], c['dur']*0.88, c['sec']+c['dur']*0.88))
")
fi

# a letterboxed source has to be cropped to its picture before the overlay lines up
CROP=""
[ "$TOP" != "0" ] && CROP="crop=iw:ih-2*$TOP:0:$TOP,"

echo "$SCENES" | while IFS='|' read -r NAME ST VT; do
  [ -z "$NAME" ] && continue
  node "$DIR/bin/check.js" "$DIR/scenes/$NAME.html" "/tmp/kitshot.png" "$ST" >/dev/null
  ffmpeg -nostdin -y -v error -ss "$VT" -i "$V" -i /tmp/kitshot.png \
    -filter_complex "[0:v]${CROP}scale=${CW}:${CH}[a];[a][1:v]overlay=0:0,scale=1200:-2" \
    -frames:v 1 "$DIR/review/$NAME.png"
  printf "  %-24s @%ss\n" "$NAME" "$VT"
done
rm -f /tmp/kitshot.png
echo
echo "-> review/   افتحهم وبُصّ. الرندر بعد كده، مش قبله."
