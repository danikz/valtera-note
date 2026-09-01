import { chromium } from 'playwright';

import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distDir = path.resolve(__dirname, '../dist');

const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/') reqPath = '/index.html';
  const filePath = path.join(distDir, reqPath);
  
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    let contentType = 'text/html';
    if (filePath.endsWith('.js')) contentType = 'application/javascript';
    if (filePath.endsWith('.css')) contentType = 'text/css';
    if (filePath.endsWith('.png')) contentType = 'image/png';
    if (filePath.endsWith('.svg')) contentType = 'image/svg+xml';
    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  } else {
    // SPA fallback
    res.writeHead(200, { 'Content-Type': 'text/html' });
    fs.createReadStream(path.join(distDir, 'index.html')).pipe(res);
  }
});

server.listen(5188, async () => {
  console.log('Testing production dist build on http://localhost:5188 ...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1100, height: 720 } });
  page.on('console', msg => console.log('BROWSER LOG:', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('BROWSER ERROR:', err));
  await page.goto('http://localhost:5188', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  const text = await page.innerText('body');
  console.log('--- PRODUCTION DIST BODY TEXT START ---');
  console.log(text);
  console.log('--- PRODUCTION DIST BODY TEXT END ---');
  await page.screenshot({ path: './scripts/debug-dist-startup.png' });
  await browser.close();
  server.close();
  process.exit(0);
});
