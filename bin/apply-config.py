#!/usr/bin/env python3
"""config.json (اللي الموقع بيولّده) -> توكنز الهوية في tokens/digitalflow.css

من غير الخطوة دي، الألوان اللي المستخدم اختارها على الموقع مش بتوصل للمشاهد
أصلاً — بتفضل ألوان الكيت الافتراضية.
"""
import json, os, re, sys

# مفاتيح config.json -> متغيّرات CSS
MAP = {
    "primary": "--df-primary",
    "accent":  "--df-accent",
    "ink":     "--df-ink",
    "bg":      "--df-bg",
    "surface": "--df-surface",
    "border":  "--df-border",
}

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    cpath = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "config.json")
    if not os.path.exists(cpath):
        raise SystemExit("مفيش config.json في %s\n"
                         "ده الملف اللي الموقع بينزّله مع البرومبت." % cpath)

    cfg = json.load(open(cpath, encoding="utf-8"))
    brand = cfg.get("brand", {})
    colors = brand.get("colors", {})

    tpath = os.path.join(root, "tokens", "digitalflow.css")
    css = open(tpath, encoding="utf-8").read()

    changed = []
    for key, var in MAP.items():
        val = colors.get(key)
        if not val:
            continue
        if not HEX.match(val):
            print("  تخطّيت %s — مش لون hex صالح: %r" % (key, val))
            continue
        pat = re.compile(r"(%s:\s*)(#[0-9a-fA-F]{6})" % re.escape(var))
        m = pat.search(css)
        if not m:
            print("  تخطّيت %s — مالقيتش %s في الملف" % (key, var))
            continue
        if m.group(2).lower() != val.lower():
            css = pat.sub(lambda mm: mm.group(1) + val, css, count=1)
            changed.append("%s  %s -> %s" % (var, m.group(2), val))

    font = (brand.get("font") or {}).get("family")
    if font:
        pat = re.compile(r'(--df-font:\s*)("[^"]*"|\'[^\']*\')')
        m = pat.search(css)
        if m and font not in m.group(2):
            css = pat.sub(lambda mm: mm.group(1) + '"%s"' % font, css, count=1)
            changed.append('--df-font -> "%s"' % font)

    if not changed:
        print("مفيش حاجة اتغيّرت — التوكنز مطابقة للـconfig أصلاً.")
        return

    open(tpath, "w", encoding="utf-8").write(css)
    print("اتغيّر في tokens/digitalflow.css:")
    for c in changed:
        print("  " + c)
    print("\nكل المشاهد بتقرا من التوكنز دي، فالتغيير بيسري على اللي اترندر بعد كده.")

if __name__ == "__main__":
    main()
