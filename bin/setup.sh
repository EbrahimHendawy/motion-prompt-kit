#!/bin/bash
# Check every tool the kit needs and say exactly what to run for anything missing.
# Nothing here installs silently — you should know what lands on your machine.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OK=1
say() { printf "  %-14s %s\n" "$1" "$2"; }

echo "بفحص الأدوات المطلوبة…"
echo

if command -v ffmpeg >/dev/null; then say "ffmpeg" "موجود ✓"; else
  say "ffmpeg" "ناقص ✗   ->  brew install ffmpeg"; OK=0; fi

if command -v node >/dev/null; then say "node" "$(node -v) ✓"; else
  say "node" "ناقص ✗   ->  brew install node"; OK=0; fi

if command -v whisper-cli >/dev/null; then say "whisper-cli" "موجود ✓"; else
  say "whisper-cli" "ناقص ✗   ->  brew install whisper-cpp"; OK=0; fi

CH=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
         "/Applications/Chromium.app/Contents/MacOS/Chromium" \
         "/usr/bin/google-chrome" "/usr/bin/chromium"; do
  [ -f "$c" ] && CH="$c" && break
done
if [ -n "$CH" ]; then say "Chrome" "موجود ✓"; else
  say "Chrome" "ناقص ✗   ->  نزّل Google Chrome، أو  export CHROME_PATH=..."; OK=0; fi

MODEL="${WHISPER_MODEL:-$HOME/.cache/whisper/ggml-large-v3.bin}"
if [ -f "$MODEL" ]; then say "whisper model" "موجود ✓"; else
  say "whisper model" "ناقص ✗"
  echo "                 mkdir -p ~/.cache/whisper && curl -L -o \"$MODEL\" \\"
  echo "                   https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
  echo "                 (حوالي ٣ چيجا — مرة واحدة بس)"
  OK=0; fi

if [ -d "$DIR/node_modules/puppeteer-core" ]; then say "puppeteer" "موجود ✓"; else
  say "puppeteer" "بنزّله دلوقتي…"
  (cd "$DIR" && npm install --silent) && say "puppeteer" "اتنزّل ✓" || { say "puppeteer" "فشل ✗"; OK=0; }
fi

echo
if [ "$OK" = "1" ]; then
  echo "كله تمام. ابدأ بـ:  bin/1-probe.sh /path/to/video.mov"
else
  echo "نزّل الناقص فوق وشغّل الأمر ده تاني."
fi
