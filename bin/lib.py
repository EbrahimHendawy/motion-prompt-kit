"""Shared config + frame-rate maths for the python tools."""
import json, os, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def config():
    p = os.path.join(ROOT, "project.json")
    if not os.path.exists(p):
        raise SystemExit("project.json مش موجود — شغّل bin/1-probe.sh على الفيديو الأول")
    return json.load(open(p, encoding="utf-8"))

# FCPXML wants time as an exact rational, and the NTSC rates are not whole numbers.
# Getting this wrong is why a timeline drifts a frame every few seconds.
FRAME_DURATION = {
    "23.976": (1001, 24000), "24": (1, 24), "25": (1, 25),
    "29.97":  (1001, 30000), "30": (1, 30), "50": (1, 50),
    "59.94":  (1001, 60000), "60": (1, 60),
}

def rate_key(fps_num, fps_den):
    """Turn ffprobe's r_frame_rate (e.g. 24000/1001) into a key of the table above."""
    r = fps_num / fps_den
    for k in FRAME_DURATION:
        if abs(float(k) - r) < 0.01:
            return k
    raise SystemExit("فريم ريت غير مدعوم: %.4f — ضيفه في FRAME_DURATION" % r)

def dur(frames, key):
    n, d = FRAME_DURATION[key]
    return "%d/%ds" % (frames * n, d)

def probe(path, entries, stream="v:0"):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", stream,
         "-show_entries", entries, "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True).stdout.strip().splitlines()
    return out
