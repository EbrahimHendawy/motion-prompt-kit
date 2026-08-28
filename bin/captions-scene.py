#!/usr/bin/env python3
"""captions.srt -> مشهد HTML بيمشي على عقد window.SCENE زي أي مشهد تاني.

الكابشن بيقعد تحت خالص بحيث مايغطّيش وش المتكلم — نفس قاعدة الكروت في الكيت.
"""
import json, os, re, sys

def secs(t):
    h, m, rest = t.split(":")
    s, ms = rest.split(",")
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000

def parse(path):
    blocks = re.split(r"\n\s*\n", open(path, encoding="utf-8").read().strip())
    cues = []
    for b in blocks:
        lines = [l for l in b.strip().split("\n") if l.strip()]
        if len(lines) < 2:
            continue
        m = re.search(r"(\S+)\s*-->\s*(\S+)", lines[1] if "-->" in lines[1] else lines[0])
        if not m:
            continue
        text = " ".join(lines[2:] if "-->" in lines[1] else lines[1:])
        cues.append({"a": secs(m.group(1)), "b": secs(m.group(2)), "t": text})
    return cues

def main():
    srt, out = sys.argv[1], sys.argv[2]
    root = os.path.dirname(os.path.dirname(os.path.abspath(out)))
    cfg = json.load(open(os.path.join(root, "project.json")))
    cues = parse(srt)
    if not cues:
        raise SystemExit("مفيش كابشنز في %s" % srt)

    w, h = cfg["canvas"]
    dur = cfg["duration"]
    html = """<!doctype html>
<meta charset="utf-8">
<title>captions</title>
<link rel="stylesheet" href="../fonts/fonts.css">
<link rel="stylesheet" href="../tokens/digitalflow.css">
<style>
  html,body { margin:0; background:transparent; }
  body { width:%(w)dpx; height:%(h)dpx; position:relative;
         font-family:'IBM Plex Sans Arabic',sans-serif; }
  /* تحت خالص — الوش بيفضل فاضي */
  #cap { position:absolute; left:8%%; right:8%%; bottom:5%%;
         display:flex; justify-content:center; }
  #cap span {
    display:inline-block; max-width:100%%;
    font-size:%(fs)dpx; font-weight:600; line-height:1.55; text-align:center;
    color:#fff; background:rgba(11,42,46,.78);
    padding:%(pv)dpx %(ph)dpx; border-radius:%(br)dpx;
    text-shadow:0 2px 6px rgba(0,0,0,.45);
  }
</style>
<div id="cap"><span></span></div>
<script>
const CUES = %(cues)s;
const box = document.querySelector('#cap');
const el  = box.querySelector('span');
window.SCENE = {
  duration: %(dur)s, width: %(w)d, height: %(h)d,
  seek(t) {
    const c = CUES.find(c => t >= c.a && t < c.b);
    if (!c) { box.style.opacity = 0; return; }
    if (el.textContent !== c.t) el.textContent = c.t;
    // ظهور سريع جداً — الكابشن لازم يلحق الكلام مش يتأخر عنه
    const p = Math.min(1, (t - c.a) / 0.12);
    box.style.opacity = p;
  }
};
</script>
""" % {
        "w": w, "h": h, "dur": dur,
        "fs": round(h * 0.038), "pv": round(h * 0.012),
        "ph": round(h * 0.022), "br": round(h * 0.011),
        "cues": json.dumps(cues, ensure_ascii=False),
    }
    open(out, "w", encoding="utf-8").write(html)
    print("   %d كابشن -> %s" % (len(cues), os.path.relpath(out, root)))

if __name__ == "__main__":
    main()
