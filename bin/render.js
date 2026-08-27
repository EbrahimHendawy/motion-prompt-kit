#!/usr/bin/env node
// Scene -> PNG sequence with alpha, one screenshot per frame.
// Time is driven by SCENE.seek(t), never by CSS animation playback: the browser is
// never asked to "play" anything, so the output is frame-exact and re-rendering the
// same scene gives you the same pixels every time.
const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');
const { config, chrome, LAUNCH } = require('./lib');

(async () => {
  const [scene, outDir] = process.argv.slice(2);
  if (!scene || !outDir) {
    console.error('الاستخدام: node bin/render.js scenes/01-x.html <مجلد الخرج>');
    process.exit(1);
  }
  const cfg = config();
  const FPS = cfg.fps_exact[0] / cfg.fps_exact[1];
  fs.mkdirSync(outDir, { recursive: true });

  // Four Chrome instances each holding a 4K page will starve each other on a busy
  // machine, and the default 180s protocol timeout then fires mid-screenshot: the run
  // dies with "Target closed" or "detached Frame" after most frames are already on disk.
  const browser = await puppeteer.launch({
    executablePath: chrome(), protocolTimeout: 600000, ...LAUNCH });
  const page = await browser.newPage();
  page.on('pageerror', e => console.error('PAGE ERROR:', e.message));
  await page.goto('file://' + path.resolve(scene), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);

  const meta = await page.evaluate(() => ({
    duration: window.SCENE.duration,
    width: window.SCENE.width,
    height: window.SCENE.height,
    scale: window.SCENE.scale || null,
  }));
  const scale = meta.scale || cfg.scale;
  await page.setViewport({ width: meta.width, height: meta.height, deviceScaleFactor: scale });

  const total = Math.round(meta.duration * FPS);
  console.log(`${path.basename(scene)}: ${meta.width*scale}x${meta.height*scale}  ${meta.duration}s  ${total} frames`);

  for (let f = 0; f < total; f++) {
    await page.evaluate(t => window.SCENE.seek(t), f / FPS);
    await page.screenshot({
      path: path.join(outDir, String(f).padStart(5, '0') + '.png'),
      omitBackground: true,
      captureBeyondViewport: false,
    });
    if (f % 24 === 0) process.stdout.write(`\r  ${f}/${total}`);
  }
  console.log(`\r  ${total}/${total} done`);
  // browser.close() sometimes never resolves after the last screenshot, which strands the
  // process with every frame already written and stalls the encode waiting behind it.
  await Promise.race([browser.close(), new Promise(r => setTimeout(r, 5000))]);
  process.exit(0);
})();
