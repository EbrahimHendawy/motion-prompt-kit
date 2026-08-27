#!/bin/bash
# Step 2 — a transcript with a timestamp on every single word.
# `--max-len 1` is what makes it one word per line. Without it you get sentence
# timings, which are useless: you cannot land an element on the word that names it.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
V=$(python3 -c "import json;print(json.load(open('$DIR/project.json'))['video'])")
MODEL="${WHISPER_MODEL:-$HOME/.cache/whisper/ggml-large-v3.bin}"
LANG="${LANG_CODE:-ar}"

[ -f "$MODEL" ] || { echo "مش لاقي موديل whisper في: $MODEL"; echo "نزّله بـ bin/setup.sh"; exit 1; }

echo "بستخرج الصوت…"
ffmpeg -nostdin -y -v error -i "$V" -map 0:a:0 -ac 1 -ar 16000 -c:a pcm_s16le "$DIR/audio.wav"

echo "بشغّل whisper (بياخد وقت على قد طول الفيديو)…"
whisper-cli -m "$MODEL" -f "$DIR/audio.wav" -l "$LANG" -oj -of "$DIR/transcript" \
  --max-len 1 -ml 1 -sow > "$DIR/whisper.log" 2>&1

python3 - "$DIR" <<'PY'
import json, sys
DIR = sys.argv[1]
d = json.load(open(DIR + "/transcript.json"))
ws = [s for s in d["transcription"] if s["text"].strip() and not s["text"].strip().startswith("[")]
with open(DIR + "/words.txt", "w") as f:
    for i, s in enumerate(ws):
        f.write("%4d %8.2f %8.2f  %s\n"
                % (i, s["offsets"]["from"]/1000, s["offsets"]["to"]/1000, s["text"].strip()))
print("%d كلمة — آخر كلمة عند %.2fs" % (len(ws), ws[-1]["offsets"]["to"]/1000))
print("-> transcript.json  و  words.txt")
print("\nwords.txt هو اللي هتاخد منه توقيت كل عنصر. دوّر فيه بـ:")
print("   grep 'الكلمة' words.txt")
PY
