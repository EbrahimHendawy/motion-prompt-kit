#!/usr/bin/env node
// Print the on-screen box of any element, in canvas coordinates.
// Use it instead of squinting: "is this card clear of his chin" is a number, not a feeling.
const puppeteer = require('puppeteer-core');
const path = require('path');
const { config, chrome, LAUNCH } = require('./lib');

(async () => {
  const [scene, tStr, sel] = process.argv.slice(2);
  if (!scene) {
    console.error('الاستخدام: node bin/measure.js scenes/01-x.html <الثانية> [css selector]');
    process.exit(1);
  }
  const cfg = config();
  const browser = await puppeteer.launch({ executablePath: chrome(), ...LAUNCH });
  const page = await browser.newPage();
  await page.setViewport({ width: cfg.canvas[0], height: cfg.canvas[1], deviceScaleFactor: 1 });
  await page.goto('file://' + path.resolve(scene), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(t => window.SCENE.seek(t), parseFloat(tStr || '3'));
  const rows = await page.evaluate(s => {
    const els = s ? [...document.querySelectorAll(s)]
                  : [...document.body.children].filter(e => e.tagName !== 'SCRIPT');
    return els.map(e => {
      const b = e.getBoundingClientRect();
      return { tag: e.className || e.tagName.toLowerCase(),
               l: Math.round(b.left),  t: Math.round(b.top),
               r: Math.round(b.right), b: Math.round(b.bottom),
               w: Math.round(b.width), h: Math.round(b.height) };
    });
  }, sel || null);
  for (const r of rows) {
    if (!r.w && !r.h) continue;
    console.log(`${String(r.tag).slice(0,26).padEnd(28)} x ${r.l}–${r.r}   y ${r.t}–${r.b}   (${r.w}×${r.h})`);
  }
  await Promise.race([browser.close(), new Promise(r => setTimeout(r, 5000))]);
  process.exit(0);
})();
