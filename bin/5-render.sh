#!/bin/bash
# Step 5 — every scene to a ProRes 4444 master with alpha, plus a small preview.
# ProRes 4444 is the common master format that actually carries an alpha channel into
# an NLE; h.264 and ProRes 422 will silently throw it away and give you a black box.
set -e
export PATH="/opt/homebrew/bin:$PATH"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DIR/out"; mkdir -p "$OUT"
JOBS=${JOBS:-4}
FPS=$(python3 -c "
import json;c=json.load(open('$DIR/project.json'));print('%d/%d'%tuple(c['fps_exact']))")

one() {
  local f="$1" name tmp
  name=$(basename "$f" .html)
  tmp="${TMPDIR:-/tmp}/kit-$name"
  rm -rf "$tmp"; mkdir -p "$tmp"
  node "$DIR/bin/render.js" "$f" "$tmp" > "$tmp/.log" 2>&1 || { echo "!! فشل $name"; cat "$tmp/.log"; return 1; }
  ffmpeg -nostdin -y -v error -framerate "$FPS" -i "$tmp/%05d.png" \
    -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le "$OUT/$name.mov"
  ffmpeg -nostdin -y -v error -framerate "$FPS" -i "$tmp/%05d.png" \
    -vf "scale=1024:-2" -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart \
    "$OUT/$name.preview.mp4"
  echo "خلص $name ($(ls "$tmp"/*.png | wc -l | tr -d ' ') فريم)"
  rm -rf "$tmp"
}
export -f one; export DIR OUT FPS

if [ $# -gt 0 ]; then
  printf '%s\n' "$@" | sed "s|^|$DIR/scenes/|; s|$|.html|" | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {}
else
  # timeline.json هو مصدر الحقيقة. الجلوب على الأرقام كان بيسيب أي مشهد اسمه
  # مابيبدأش برقم من غير رندر ومن غير رسالة — الرندر بيخلص "بنجاح" وout/ فاضية.
  if [ -f "$DIR/timeline.json" ]; then
    python3 -c "
import json,sys,os
d=json.load(open('$DIR/timeline.json'))
miss=[c['scene'] for c in d['clips'] if not os.path.exists('$DIR/scenes/%s.html'%c['scene'])]
if miss:
    sys.stderr.write('!! مشاهد في timeline.json ملهاش ملفات: %s\n' % '، '.join(miss)); sys.exit(1)
print('\n'.join('$DIR/scenes/%s.html'%c['scene'] for c in d['clips']))
" | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {}
  else
    N=$(ls "$DIR"/scenes/[0-9]*.html 2>/dev/null | wc -l | tr -d ' ')
    [ "$N" = "0" ] && { echo "مفيش مشاهد في scenes/ ولا timeline.json — مفيش حاجة تترندر"; exit 1; }
    ls "$DIR"/scenes/[0-9]*.html | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {}
  fi
fi
echo; ls -lh "$OUT"/*.mov | awk '{print $5, $9}'
echo
echo "استنى الأمر ده يخلص فعلاً — متعدّش الملفات."
echo "ffmpeg بينشئ ملف الخرج من أول ثانية في الترميز، فالعدّ بيعدّي والملف لسه بيتكتب."
