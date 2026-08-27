// Shared config + Chrome discovery for every node tool in the kit.
// Nothing is hard-coded: fps, frame size and canvas scale all come from project.json,
// which `1-probe.sh` writes by actually measuring the footage.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');

function config() {
  const p = path.join(ROOT, 'project.json');
  if (!fs.existsSync(p)) {
    console.error('project.json مش موجود — شغّل bin/1-probe.sh على الفيديو الأول');
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

// Chrome ships in a different place on every machine, so look rather than assume.
function chrome() {
  const env = process.env.CHROME_PATH;
  if (env && fs.existsSync(env)) return env;
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  ];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  console.error('مش لاقي Chrome. حدّد المسار بنفسك:  export CHROME_PATH="/path/to/chrome"');
  process.exit(1);
}

const LAUNCH = {
  headless: 'new',
  args: ['--force-color-profile=srgb', '--disable-lcd-text', '--hide-scrollbars',
         '--allow-file-access-from-files', '--font-render-hinting=none'],
};

module.exports = { ROOT, config, chrome, LAUNCH };
