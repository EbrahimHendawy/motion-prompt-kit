/* رَنتايم تصميمات Claude Design داخل الكيت.
 *
 * صفحة التصميم بتشغّل الحركة بأنيميشن CSS: العنصر بياخد data-a="rise" و--d
 * للتأخير، والمتصفح بيلعبها بنفسه. ده ممتاز للمعاينة وبايظ للرندر — الكيت
 * بيصوّر فريم فريم وبينادي seek(t)، فالأنيميشن اللي بيلعب لوحده بيدي فريمات
 * مختلفة كل مرة.
 *
 * الملف ده بيقرا نفس الوسوم (data-a، --d، data-k، data-count-to) وبيحسب
 * الستايل من t مباشرة. يعني نفس الماركب بالحرف بيشتغل في الاتنين:
 * في صفحة التصميم بأنيميشن CSS، وهنا بحساب صريح — ونفس الشكل يطلع.
 */
window.DC = (() => {

  // ── منحنيات التسهيل ──────────────────────────────────────────────
  // نفس اللي في التصميم: --ease و --ease-out
  const bezier = (x1, y1, x2, y2) => {
    const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
    const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
    const fx = t => ((ax * t + bx) * t + cx) * t;
    const dfx = t => (3 * ax * t + 2 * bx) * t + cx;
    return x => {
      if (x <= 0) return 0;
      if (x >= 1) return 1;
      let t = x;
      for (let i = 0; i < 8; i++) {          // نيوتن، وبعدين تنصيف لو مااستقرّش
        const e = fx(t) - x;
        if (Math.abs(e) < 1e-6) break;
        const d = dfx(t);
        if (Math.abs(d) < 1e-6) break;
        t -= e / d;
      }
      t = Math.min(1, Math.max(0, t));
      return ((ay * t + by) * t + cy) * t;
    };
  };
  const EASE     = bezier(.22, .9, .28, 1);
  const EASE_OUT = bezier(.16, 1, .3, 1);
  const EASE_IO  = bezier(.42, 0, .58, 1);
  const LINEAR   = x => x;

  const clamp01 = v => v < 0 ? 0 : v > 1 ? 1 : v;
  /* تدرّج بين نقاط keyframe.
   * مهم: CSS بيطبّق منحنى التسهيل **بين كل نقطتين متتاليتين على حدة**، مش
   * على المدة كلها مرة واحدة. حركة زي pop عندها تلات نقاط (0 / 60% / 100%)،
   * فلو مرّرنا التقدّم الخام بيطلع العنصر باهت في وقت المفروض يكون ظاهر فيه.  */
  const track = (p, stops, ease) => {
    const e = ease || (x => x);
    for (let i = 1; i < stops.length; i++) {
      if (p <= stops[i][0]) {
        const [a, av] = stops[i - 1], [b, bv] = stops[i];
        const k = b === a ? 1 : e((p - a) / (b - a));
        return av + (bv - av) * k;
      }
    }
    return stops[stops.length - 1][1];
  };

  // ── الحركات لمرة واحدة: مدة + دالة بتحطّ الستايل ──────────────────
  const ONCE = {
    rise:  { dur: .72, ease: EASE, apply(el, p) {
      el.style.opacity = p; el.style.transform = `translateY(${(1 - p) * 34}px)`; } },
    right: { dur: .74, ease: EASE, apply(el, p) {
      el.style.opacity = p; el.style.transform = `translateX(${(1 - p) * 90}px)`; } },
    left:  { dur: .74, ease: EASE, apply(el, p) {
      el.style.opacity = p; el.style.transform = `translateX(${(1 - p) * -90}px)`; } },
    fade:  { dur: .60, ease: LINEAR, apply(el, p) { el.style.opacity = p; } },
    pop:   { dur: .58, ease: EASE_OUT, raw: true, apply(el, p) {
      el.style.opacity = track(p, [[0, 0], [.6, 1], [1, 1]], EASE_OUT);
      el.style.transform = `scale(${track(p, [[0, .7], [.6, 1.06], [1, 1]], EASE_OUT)})`; } },
    mask:  { dur: .80, ease: EASE_OUT, apply(el, p) {
      el.style.opacity = 1; el.style.clipPath = `inset(0 0 0 ${(1 - p) * 100}%)`; } },
    scale: { dur: .78, ease: EASE, apply(el, p) {
      el.style.opacity = p; el.style.transform = `scale(${.9 + .1 * p})`; } },
    unfold:{ dur: .70, ease: EASE, apply(el, p) {
      el.style.opacity = p; el.style.maxHeight = (p * 400) + 'px'; el.style.overflow = 'hidden'; } },
    barx:  { dur: .70, ease: EASE_OUT, apply(el, p) {
      el.style.opacity = 1; el.style.transform = `scaleX(${p})`; } },
    bary:  { dur: .70, ease: EASE_OUT, apply(el, p) {
      el.style.opacity = 1; el.style.transform = `scaleY(${p})`; } },
    stamp: { dur: .50, ease: EASE_OUT, raw: true, apply(el, p) {
      el.style.opacity = track(p, [[0, 0], [.6, 1], [1, 1]], EASE_OUT);
      el.style.transform = `scale(${track(p, [[0, 2.2], [.6, .96], [1, 1]], EASE_OUT)}) rotate(-10deg)`; } },
    // مدتها من --l، والشفافية بتطلع وتنزل
    hold:  { dur: null, ease: LINEAR, raw: true, varDur: '--l', defDur: 2,
      apply(el, p) { el.style.opacity = track(p, [[0, 0], [.08, 1], [.92, 1], [1, 0]]); } },
    // الرسم على SVG: محتاج طول المسار
    draw:  { dur: null, ease: EASE_OUT, varDur: '--dur', defDur: 1,
      apply(el, p) {
        // لو العنصر عليه pathLength الطول بيبقى معياري (التصميم بيحطّها 1)،
        // ساعتها dasharray لازم تبقى نفس الرقم مش الطول الهندسي الحقيقي.
        const L = el.__len !== undefined ? el.__len : (el.__len =
          el.hasAttribute('pathLength') ? parseFloat(el.getAttribute('pathLength'))
          : (el.getTotalLength ? el.getTotalLength() : 1));
        el.style.opacity = 1;
        el.style.strokeDasharray = L;
        el.style.strokeDashoffset = L * (1 - p);
      } },
  };

  // ── الحركات المستمرة (بتلفّ طول المشهد) ───────────────────────────
  const AMB = {
    pulse: (el, t) => {   // 2.2s، ease-out
      const p = (t % 2.2) / 2.2;
      const k = p < .7 ? EASE_OUT(p / .7) : 1;
      el.style.boxShadow = `0 0 0 ${34 * k}px rgba(116,216,93,${.55 * (1 - k)})`;
    },
    ken: (el, t) => {     // 9s، بيقف عند الآخر
      el.style.transform = `scale(${1.02 + .10 * clamp01(t / 9)})`;
    },
    scroll: (el, t) => {  // 6s بعد تأخير 1.2s، بيقف عند الآخر
      const p = EASE_IO(clamp01((t - 1.2) / 6));
      el.style.transform = `translateY(${-37 * p}%)`;
    },
    glow: (el, t) => {    // 3s، ease-in-out، واللون نفسه بيتدرّج بين الاتنين
      const p = (t % 3) / 3;
      const k = p < .5 ? EASE_IO(p / .5) : 1 - EASE_IO((p - .5) / .5);
      const mix = (a, b) => Math.round(a + (b - a) * k);
      el.style.boxShadow = `0 0 ${30 + 40 * k}px rgba(${mix(34,116)},${mix(179,216)},${mix(152,93)},${(.25 + .30 * k).toFixed(3)})`;
    },
    float: (el, t) => {   // 7s
      const p = (t % 7) / 7;
      el.style.transform = `translate(${track(p, [[0, 0], [.5, 60], [1, 0]])}px,${track(p, [[0, 0], [.5, -50], [1, 0]])}px)`;
    },
  };

  const num = (el, name, def) => {
    const v = getComputedStyle(el).getPropertyValue(name).trim();
    if (!v) return def;
    return parseFloat(v) * (v.endsWith('ms') ? .001 : 1);
  };

  /* جهّز المشهد. بيرجّع دالة seek(t) تديها للكيت.
   * root: العنصر اللي جواه العناصر المتحركة (الافتراضي document).      */
  function scene(root) {
    root = root || document;
    const once = [...root.querySelectorAll('[data-a]')].map(el => {
      const kind = el.getAttribute('data-a');
      const spec = ONCE[kind];
      if (!spec) { console.warn('DC: حركة مش معروفة', kind); return null; }
      const delay = num(el, '--d', 0);
      const dur = spec.dur !== null ? spec.dur : num(el, spec.varDur, spec.defDur);
      return { el, spec, delay, dur };
    }).filter(Boolean);

    const amb = [...root.querySelectorAll('[data-k]')].map(el => {
      const fn = AMB[el.getAttribute('data-k')];
      if (!fn) { console.warn('DC: حركة مستمرة مش معروفة', el.getAttribute('data-k')); return null; }
      return { el, fn, delay: num(el, '--d', 0) };
    }).filter(Boolean);

    const counters = [...root.querySelectorAll('[data-count-to]')].map(el => ({
      el,
      to: parseFloat(el.dataset.countTo),
      delay: (+el.dataset.countDelay || 400) / 1000,
      dur: (+el.dataset.countDur || 1100) / 1000,
      ar: el.dataset.countAr === '1',
    }));
    const AR = '٠١٢٣٤٥٦٧٨٩';
    const toAr = n => String(n).replace(/[0-9]/g, d => AR[+d]);

    return function seek(t) {
      for (const { el, spec, delay, dur } of once) {
        const p = clamp01((t - delay) / dur);
        spec.apply(el, spec.raw ? p : spec.ease(p));
      }
      for (const { el, fn, delay } of amb) fn(el, Math.max(0, t - delay));
      for (const c of counters) {
        const p = clamp01((t - c.delay) / c.dur);
        const v = Math.round(c.to * (1 - Math.pow(1 - p, 3)));
        c.el.textContent = c.ar ? toAr(v) : String(v);
      }
    };
  }

  return { scene, bezier, EASE, EASE_OUT, EASE_IO };
})();
