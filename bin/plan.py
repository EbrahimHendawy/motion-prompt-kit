#!/usr/bin/env python3
"""Turn a list of (scene, in, out) seconds into timeline.json — frames, gaps and all.

Write your scenes' in/out points in seconds while you are reading words.txt; let this
convert to frames. Doing that arithmetic by hand is where off-by-one clip collisions
come from.

    bin/plan.py 01-promise 0 16.10  02-no-code 16.60 30.05  ...
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import ROOT, config

MIN_GAP = 6

def main():
    a = sys.argv[1:]
    if not a or len(a) % 3:
        raise SystemExit(__doc__)
    cfg = config()
    fps = cfg["fps_exact"][0] / cfg["fps_exact"][1]

    clips = []
    for i in range(0, len(a), 3):
        name, s, e = a[i], float(a[i+1]), float(a[i+2])
        if e <= s:
            raise SystemExit("%s: وقت الخروج لازم يكون بعد الدخول" % name)
        clips.append({"scene": name, "sec": round(s, 3), "dur": round(e - s, 3),
                      "frame": round(s * fps), "frames": round((e - s) * fps)})

    clips.sort(key=lambda c: c["frame"])
    print("%-24s %9s %9s %8s %8s %7s" % ("المشهد", "يدخل", "يخرج", "فريم", "فريمات", "فجوة"))
    bad = False
    for i, c in enumerate(clips):
        gap = "-" if i == 0 else c["frame"] - (clips[i-1]["frame"] + clips[i-1]["frames"])
        flag = ""
        if gap != "-" and gap < MIN_GAP:
            flag = "  << تصادم"; bad = True
        print("%-24s %9.2f %9.2f %8d %8d %7s%s"
              % (c["scene"], c["sec"], c["sec"]+c["dur"], c["frame"], c["frames"], gap, flag))

    last = clips[-1]
    over = last["frame"] + last["frames"] - cfg["total_frames"]
    if over > 0:
        print("\n!! آخر كليب بيعدّي نهاية الفيديو بـ%d فريم" % over); bad = True

    cov = sum(c["dur"] for c in clips) / cfg["duration"] * 100
    print("\nالتغطية %.1f٪ من زمن الفيديو" % cov)
    if bad:
        raise SystemExit("\nصلّح اللي فوق الأول — مكتبتش timeline.json")

    plan = {"clips": clips}
    json.dump(plan, open(os.path.join(ROOT, "timeline.json"), "w"),
              ensure_ascii=False, indent=2)
    print("-> timeline.json")

if __name__ == "__main__":
    main()
