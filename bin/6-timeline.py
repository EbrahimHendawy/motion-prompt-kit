#!/usr/bin/env python3
"""Step 6 — check the rendered masters, then write the timeline as FCPXML.

Two jobs in one file because the second must never run on unchecked input:

  reconcile  timeline.json durations are written by hand; render.js lays down
             round(duration * fps) frames, which can differ by one. One frame of drift
             pushes the last clip past the end of the footage. So the plan is corrected
             from the masters rather than trusted.

  fcpxml     the import file. Two things here cause bug reports that point nowhere:

             1. If the footage carries a timecode track starting at 01:00:00:00, the NLE
                treats the media as beginning at frame 86400. An asset declared start="0s"
                asks for a range the file does not have and imports as MEDIA OFFLINE.
             2. A connected clip's offset is measured in its PARENT's local time, whose
                origin is the parent's start — not the start of the timeline. Forget to add
                the timecode and every overlay stacks at the head of the timeline, shoving
                the footage to the end.
"""
import json, os, subprocess, sys
from urllib.parse import quote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import ROOT, config, dur, FRAME_DURATION

MIN_GAP = 6      # frames of clearance required between consecutive clips


def probe(path, tries=3):
    """ffprobe occasionally returns a short line, so read until it looks complete."""
    out = ""
    for _ in range(tries):
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
             "stream=width,height,pix_fmt,nb_frames", "-of", "csv=p=0", path],
            capture_output=True, text=True).stdout.strip()
        parts = out.split(",")
        if len(parts) == 4 and parts[3].isdigit():
            return int(parts[0]), int(parts[1]), parts[2], int(parts[3])
    raise SystemExit("مش قادر أقرا %s (آخر قراءة: %r)" % (path, out))


def reconcile(cfg, plan):
    W = cfg["canvas"][0] * cfg["scale"]
    H = cfg["canvas"][1] * cfg["scale"]
    W, H = round(W), round(H)
    fixed, bad = [], []

    for c in plan["clips"]:
        p = os.path.join(ROOT, "out", c["scene"] + ".mov")
        if not os.path.exists(p):
            raise SystemExit("مفيش ماستر للمشهد %s — شغّل bin/5-render.sh" % c["scene"])
        w, h, fmt, n = probe(p)
        if (w, h) != (W, H):
            bad.append("%s مقاسه %dx%d والمفروض %dx%d" % (c["scene"], w, h, W, H))
        if not fmt.startswith("yuva"):
            bad.append("%s مالوش قناة ألفا (%s) — هيطلع مربع أسود فوق الفيديو"
                       % (c["scene"], fmt))
        if n != c["frames"]:
            fixed.append((c["scene"], c["frames"], n))
            c["frames"] = n
    if bad:
        raise SystemExit("\n".join("!! " + b for b in bad))

    # Only snap the final clip to the last frame of the footage when you actually meant
    # it to run to the cut (an end card, say). Doing it by default silently teleports the
    # last clip to the end of the timeline, which is a very confusing thing to debug.
    last = plan["clips"][-1]
    if plan.get("flush_last"):
        last["frame"] = cfg["total_frames"] - last["frames"]
    over = last["frame"] + last["frames"] - cfg["total_frames"]
    if over > 0:
        raise SystemExit("!! آخر كليب بيعدّي نهاية الفيديو بـ%d فريم" % over)

    for scene, was, now in fixed:
        print("صحّحت %-24s %d -> %d فريم" % (scene, was, now))
    if not fixed:
        print("كل الـ%d ماستر مطابقين للخطة" % len(plan["clips"]))

    cl = plan["clips"]
    tight = [(a["scene"], b["scene"], b["frame"] - (a["frame"] + a["frames"]))
             for a, b in zip(cl, cl[1:])
             if b["frame"] - (a["frame"] + a["frames"]) < MIN_GAP]
    if tight:
        raise SystemExit("!! كليبات قريبة من بعض أقل من %d فريمات: %r" % (MIN_GAP, tight))
    print("مفيش تصادمات | آخر فريم %d من %d"
          % (last["frame"] + last["frames"] - 1, cfg["total_frames"] - 1))
    return plan


def fcpxml(cfg, plan):
    key = cfg["fps"]
    n, d = FRAME_DURATION[key]
    FD = "%d/%ds" % (n, d)
    W, H = round(cfg["canvas"][0] * cfg["scale"]), round(cfg["canvas"][1] * cfg["scale"])
    SRC_W, SRC_H = cfg["frame"]
    TC = cfg["timecode_frames"]
    TOTAL = cfg["total_frames"]
    footage = cfg["video"]
    stem = os.path.splitext(os.path.basename(footage))[0]

    def url(p):
        return "file://" + quote(os.path.abspath(p))

    res = ['  <format id="r1" name="FFVideoFormat%dx%dp%s" frameDuration="%s" '
           'width="%d" height="%d" colorSpace="1-1-1 (Rec. 709)"/>'
           % (W, H, key.replace(".", ""), FD, W, H)]

    # When the source is letterboxed the delivered frame is smaller than the source frame.
    # Declaring the real source size keeps the file honest; the NLE crops to the timeline.
    src_fmt = "r1"
    if (SRC_W, SRC_H) != (W, H):
        src_fmt = "r2"
        res.append('  <format id="r2" name="FFVideoFormat%dx%dp%s" frameDuration="%s" '
                   'width="%d" height="%d" colorSpace="1-1-1 (Rec. 709)"/>'
                   % (SRC_W, SRC_H, key.replace(".", ""), FD, SRC_W, SRC_H))

    res.append('  <asset id="a0" name="%s" start="%s" duration="%s" hasVideo="1" '
               'hasAudio="1" audioSources="1" audioChannels="2" audioRate="48000" format="%s">\n'
               '    <media-rep kind="original-media" src="%s"/>\n  </asset>'
               % (stem, dur(TC, key), dur(TOTAL, key), src_fmt, url(footage)))

    clips = []
    for i, c in enumerate(plan["clips"], 1):
        p = os.path.join(ROOT, "out", c["scene"] + ".mov")
        res.append('  <asset id="a%d" name="%s" start="0s" duration="%s" hasVideo="1" format="r1">\n'
                   '    <media-rep kind="original-media" src="%s"/>\n  </asset>'
                   % (i, c["scene"], dur(c["frames"], key), url(p)))
        clips.append('        <asset-clip ref="a%d" lane="1" offset="%s" name="%s" '
                     'start="0s" duration="%s" format="r1"/>'
                     % (i, dur(TC + c["frame"], key), c["scene"], dur(c["frames"], key)))

    xml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.9">
 <resources>
%s
 </resources>
 <library>
  <event name="%s">
   <project name="%s">
    <sequence format="r1" duration="%s" tcStart="0s" tcFormat="NDF"
              audioLayout="stereo" audioRate="48k">
     <spine>
      <asset-clip ref="a0" offset="0s" name="%s" start="%s"
                  duration="%s" format="%s" audioRole="dialogue">
%s
      </asset-clip>
     </spine>
    </sequence>
   </project>
  </event>
 </library>
</fcpxml>
''' % ("\n".join(res), stem, stem + " — with animation", dur(TOTAL, key),
       stem, dur(TC, key), dur(TOTAL, key), src_fmt, "\n".join(clips))

    out = os.path.join(ROOT, stem + "-with-animation.fcpxml")
    open(out, "w", encoding="utf-8").write(xml)
    return out


def main():
    cfg = config()
    p = os.path.join(ROOT, "timeline.json")
    if not os.path.exists(p):
        raise SystemExit("timeline.json مش موجود — شوف نموذج في templates/timeline.example.json")
    plan = json.load(open(p, encoding="utf-8"))

    plan = reconcile(cfg, plan)
    json.dump(plan, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    out = fcpxml(cfg, plan)
    print("\n->", out)
    for c in plan["clips"]:
        print("  V2  فريم %6d  %5d فريم  %s" % (c["frame"], c["frames"], c["scene"]))
    print("\nقبل الاستيراد في Resolve — Project Settings > Master Settings:")
    print("  Timeline Resolution = %d x %d" % (round(cfg["canvas"][0]*cfg["scale"]),
                                               round(cfg["canvas"][1]*cfg["scale"])))
    print("  Timeline Frame Rate = %s" % cfg["fps"])
    if cfg["letterbox"]["top"] or cfg["letterbox"]["bottom"]:
        print("  Image Scaling > Mismatched Resolution > Center crop with no resizing")
    print("وبعدين: File > Import > Timeline…")


if __name__ == "__main__":
    main()
