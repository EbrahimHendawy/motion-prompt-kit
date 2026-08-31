#!/bin/bash
# Does every fading cutaway actually reach zero alpha on its last frame?
#
# This catches the one bug that looks fine in every still and ruins the edit: a scene
# whose background never fades leaves an opaque card sitting over the speaker for the
# rest of the shot. Stills won't show it — only the alpha channel will.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# مصفوفة مش سلسلة: المسار اللي فيه مسافة كان بينقسم لأجزاء والسكربت
# يدوّر على ملفات مش موجودة. ده بيحصل لأي حد مجلده فيه مسافة في اسمه.
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  for f in "$DIR"/out/*.mov; do [ -e "$f" ] && FILES+=("$f"); done
fi
[ ${#FILES[@]} -eq 0 ] && { echo "مفيش ماسترز في out/ — شغّل bin/5-render.sh الأول"; exit 1; }
echo "بقيس قناة الألفا عند آخر فريم في كل ماستر…"
echo
for f in "${FILES[@]}"; do
  [ -f "$f" ] || f="$DIR/out/$f.mov"
  NAME=$(basename "$f" .mov)
  N=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$f" | head -1)
  MAX=$(ffmpeg -nostdin -v error -i "$f" -vf "select=eq(n\,$((N-1))),alphaextract,scale=64:36" \
        -fps_mode passthrough -f rawvideo -pix_fmt gray - 2>/dev/null | \
        python3 -c "import sys;d=sys.stdin.buffer.read();print(max(d) if d else -1)")
  if [ "$MAX" = "0" ]; then
    printf "  %-26s صفر — بيسيب الشاشة نضيفة ✓\n" "$NAME"
  else
    printf "  %-26s %-4s ← لسه فيه حاجة ظاهرة في آخر فريم\n" "$NAME" "$MAX"
  fi
done
echo
echo "المشهد اللي بيعمل فيد أوت لازم يطلع صفر."
echo "المشهد اللي ماسك لآخر الفيديو (زي كارت النهاية) طبيعي يطلع 255."
