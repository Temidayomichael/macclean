const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1040, height: 700 }, deviceScaleFactor: 2 });
  for (const name of ['apps', 'clean']) {
    await page.goto('file://' + path.join(__dirname, name + '.html'));
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(process.argv[2], `screenshot-${name}.png`), omitBackground: false });
    console.log('rendered', name);
  }
  await browser.close();
})();
