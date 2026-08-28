#!/bin/bash
# Step 7 (optional) — burn the captions into the picture.
#
# Not ffmpeg's `subtitles` filter: that needs libass, which plenty of ffmpeg builds
# ship without, and its Arabic shaping depends on the build too. The kit already has
# a renderer that does Arabic correctly (headless Chrome), so captions go through the
# same path as every other scene: HTML -> PNG with alpha -> overlay.
set -e
export PATH="/opt/homebrew/bin:$PATH"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
V=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['video'])")
SRT="$DIR/captions.srt"
OUT="${1:-$DIR/out/captioned.mp4}"

[ -f "$SRT" ] || { echo "مفيش captions.srt — شغّل bin/2-transcribe.sh الأول"; exit 1; }
mkdir -p "$DIR/out"

echo "١/٣  ببني مشهد الكابشنز…"
python3 "$DIR/bin/captions-scene.py" "$SRT" "$DIR/scenes/captions.html"

echo "٢/٣  برندره بألفا…"
TMP="${TMPDIR:-/tmp}/kit-captions"; rm -rf "$TMP"; mkdir -p "$TMP"
node "$DIR/bin/render.js" "$DIR/scenes/captions.html" "$TMP"

FPS=$(python3 -c "import json;c=json.load(open('$DIR/project.json'));print('%d/%d'%tuple(c['fps_exact']))")
ffmpeg -nostdin -y -v error -framerate "$FPS" -i "$TMP/%05d.png" \
  -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le "$DIR/out/captions.mov"
rm -rf "$TMP"

echo "٣/٣  ببصمها على الفيديو…"
ffmpeg -nostdin -y -v error -stats -i "$V" -i "$DIR/out/captions.mov" \
  -filter_complex "[1:v]scale=rw:rh[c];[0:v][c]overlay=0:0:format=auto" \
  -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a copy "$OUT"

echo
echo "-> $OUT"
echo "الكابشنز محروقة في الصورة دلوقتي — مفيش طريقة تقفلها بعد كده غير إنك ترندر تاني."
echo "الماستر بألفا محفوظ في out/captions.mov لو حبيت تركّبه في المونتاج بدل الحرق."
