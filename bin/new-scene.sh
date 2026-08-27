#!/bin/bash
# Copy a template into scenes/ and fix its relative links in one go.
# (Templates live one folder deeper than the scenes do, so a plain cp leaves the
#  stylesheet paths pointing at nothing and you get an unstyled white box.)
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
T="$1"; NAME="$2"
if [ -z "$T" ] || [ -z "$NAME" ]; then
  echo "الاستخدام: bin/new-scene.sh <اسم القالب> <اسم المشهد>"
  echo "مثال:      bin/new-scene.sh 01-lower-third 03-my-scene"
  echo; echo "القوالب الموجودة:"; ls "$DIR/templates"/*.html | xargs -n1 basename | sed 's/\.html$//' | sed 's/^/  /'
  exit 1
fi
SRC="$DIR/templates/$T.html"
[ -f "$SRC" ] || { echo "مفيش قالب اسمه $T"; exit 1; }
OUT="$DIR/scenes/$NAME.html"
[ -f "$OUT" ] && { echo "$NAME.html موجود بالفعل — اختار اسم تاني"; exit 1; }
sed -e 's|\.\./scenes/base\.css|base.css|' \
    -e 's|\.\./scenes/anim\.js|anim.js|' \
    "$SRC" > "$OUT"
echo "-> scenes/$NAME.html   (من قالب $T)"
echo "افتحه، غيّر النص، وحطّ توقيت كل عنصر من words.txt"
