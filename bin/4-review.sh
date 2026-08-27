#!/bin/bash
# Step 4 — one frame per scene, composited on the real footage frame at the same moment.
#
# Two traps live in this file:
#
#  * The scale step is not optional. check.js writes at canvas size (say 1920x1080) while
#    the footage is 4K, so overlaying straight puts every card at half size in the corner.
#    Scale the FOOTAGE down to the canvas first, then overlay.
#
#  * ffmpeg reads stdin. Inside a `while read` loop it will swallow the next lines of
#    input, and you get scenes silently skipped or names mangled ("02-x" arriving as
#    "2-x"). Every ffmpeg call in a loop needs -nostdin.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
V=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['video'])")
read CW CH TOP < <(python3 -c "
import json;c=json.load(open('$DIR/project.json'))
print(c['canvas'][0], c['canvas'][1], c['letterbox']['top'])")
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
