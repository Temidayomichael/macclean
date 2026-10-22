// Renders the README previews. Usage: node docs/previews/render.js docs
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1040, height: 700 }, deviceScaleFactor: 2 });
  const jobs = [
    ['apps', 'light'], ['installers', 'light'], ['clean', 'light'],
    ['apps', 'dark'],
  ];
  for (const [name, scheme] of jobs) {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto('file://' + path.join(__dirname, name + '.html'));
    await page.waitForTimeout(300);
    const out = `screenshot-${name}${scheme === 'dark' ? '-dark' : ''}.png`;
    await page.screenshot({ path: path.join(process.argv[2], out) });
    console.log('rendered', out);
  }
  await browser.close();
})();
