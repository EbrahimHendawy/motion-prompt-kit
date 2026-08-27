// Shared timing helpers. Motion is fade + short slide on ease-out only —
// the DigitalFlow system rules out bounce and flashy motion.
window.DF = (() => {
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const easeOut = p => 1 - Math.pow(1 - p, 3);
  // eased 0..1 ramp starting at `start`, lasting `dur`
  const win = (t, start, dur) => easeOut(clamp((t - start) / dur));
  // fade a node in with a small upward slide
  const rise = (el, t, start, dur = 0.7, dist = 28) => {
    const p = win(t, start, dur);
    el.style.opacity = p;
    el.style.transform = `translateY(${(1 - p) * dist}px)`;
    return p;
  };
  // slide in from the right (RTL entry direction)
  const slideIn = (el, t, start, dur = 0.7, dist = 60) => {
    const p = win(t, start, dur);
    el.style.opacity = p;
    el.style.transform = `translateX(${(1 - p) * dist}px)`;
    return p;
  };
  // the two drifting background glows, 7s / 9s cycles
  const drift = (a, b, t) => {
    if (a) a.style.transform = `translate(${Math.sin(t / 7 * 2 * Math.PI) * 34}px, ${Math.cos(t / 7 * 2 * Math.PI) * 22}px)`;
    if (b) b.style.transform = `translate(${Math.cos(t / 9 * 2 * Math.PI) * 28}px, ${Math.sin(t / 9 * 2 * Math.PI) * 30}px)`;
  };
  return { clamp, easeOut, win, rise, slideIn, drift };
})();
