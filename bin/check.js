#!/usr/bin/env node
// One frame of a scene, at a time you choose. This is the tool you live in while
// designing — it takes about a second, where a full render takes minutes.
const puppeteer = require('puppeteer-core');
const path = require('path');
const { config, chrome, LAUNCH } = require('./lib');

(async () => {
  const [scene, out, tStr] = process.argv.slice(2);
  if (!scene || !out) {
    console.error('الاستخدام: node bin/check.js scenes/01-x.html out.png <الثانية>');
    process.exit(1);
  }
  const cfg = config();
  const t = parseFloat(tStr || '3');
  const browser = await puppeteer.launch({ executablePath: chrome(), ...LAUNCH });
  const page = await browser.newPage();
  page.on('pageerror', e => console.error('PAGE ERROR:', path.basename(scene), e.message));
  await page.goto('file://' + path.resolve(scene), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const m = await page.evaluate(() => ({
    w: SCENE.width, h: SCENE.height, s: SCENE.scale || null }));
  // the scene says how big it is in canvas units; the project says how much to scale it
  await page.setViewport({ width: m.w, height: m.h, deviceScaleFactor: m.s || cfg.scale });
  await page.evaluate(tt => window.SCENE.seek(tt), t);
  await page.screenshot({ path: out, omitBackground: true });   // omitBackground keeps alpha
  await Promise.race([browser.close(), new Promise(r => setTimeout(r, 5000))]);
  process.exit(0);
})();
