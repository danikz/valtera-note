import { chromium } from 'playwright';

async function testConsole() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  page.on('console', msg => console.log('BROWSER LOG:', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('BROWSER ERROR:', err));
  await page.goto('http://localhost:1420', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  await browser.close();
}

testConsole();
