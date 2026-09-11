import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distDir = path.resolve(__dirname, '../dist');
const outDir = path.resolve(__dirname, '../docs/screenshots');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Complete, harmonious, high-contrast light theme CSS injection
const lightThemeCss = `
  /* Global Background & Text */
  html, body, #app, main {
    background-color: #f8fafc !important;
    color: #0f172a !important;
  }

  /* Aside / Sidebar Light Styling */
  aside, aside * {
    border-color: #e2e8f0 !important;
  }
  aside {
    background-color: #f8fafc !important;
    color: #1e293b !important;
  }
  aside .bg-slate-950\\/60,
  aside .bg-slate-950\\/30,
  aside .bg-slate-950 {
    background-color: #f1f5f9 !important;
  }
  aside .text-slate-200,
  aside .text-slate-300,
  aside .text-slate-400 {
    color: #334155 !important;
  }
  aside .text-slate-500 {
    color: #64748b !important;
  }
  aside input {
    background-color: #ffffff !important;
    border-color: #cbd5e1 !important;
    color: #0f172a !important;
  }

  /* Structural Containers */
  .bg-slate-950,
  .bg-slate-950\\/90,
  .bg-slate-950\\/80,
  .bg-slate-950\\/70,
  .bg-slate-950\\/60,
  .bg-slate-950\\/50,
  .bg-slate-950\\/40,
  .bg-slate-950\\/30 {
    background-color: #ffffff !important;
  }

  .bg-slate-900,
  .bg-slate-900\\/95,
  .bg-slate-900\\/90,
  .bg-slate-900\\/80,
  .bg-slate-900\\/70,
  .bg-slate-900\\/60,
  .bg-slate-900\\/50,
  .bg-slate-900\\/40 {
    background-color: #f8fafc !important;
  }

  .bg-slate-800,
  .bg-slate-800\\/80,
  .bg-slate-800\\/60,
  .bg-slate-800\\/40 {
    background-color: #f1f5f9 !important;
  }

  /* Borders */
  .border-slate-800,
  .border-slate-800\\/80,
  .border-slate-800\\/60,
  .border-slate-800\\/40,
  .border-slate-700,
  .border-slate-700\\/80,
  .border-slate-900 {
    border-color: #e2e8f0 !important;
  }

  /* Typography */
  .text-slate-100,
  .text-slate-200 {
    color: #0f172a !important;
  }

  .text-slate-300 {
    color: #334155 !important;
  }

  .text-slate-400 {
    color: #475569 !important;
  }

  .text-slate-500 {
    color: #64748b !important;
  }

  /* CodeMirror 6 Light Palette */
  .cm-editor {
    background-color: #ffffff !important;
    color: #0f172a !important;
  }

  .cm-scroller {
    background-color: #ffffff !important;
  }

  .cm-gutters {
    background-color: #f8fafc !important;
    color: #94a3b8 !important;
    border-right: 1px solid #e2e8f0 !important;
  }

  .cm-activeLineGutter {
    background-color: #e2e8f0 !important;
    color: #0f172a !important;
  }

  .cm-activeLine {
    background-color: #f8fafc !important;
  }

  .cm-cursor {
    border-left: 2px solid #0284c7 !important;
  }

  .cm-line {
    color: #1e293b !important;
  }
  
  /* Markdown Live Preview Pane - Rich Contrast */
  .markdown-body {
    background-color: #ffffff !important;
    color: #1e293b !important;
  }

  .markdown-body h1,
  .markdown-body h2,
  .markdown-body h3,
  .markdown-body h4,
  .markdown-body h5 {
    color: #0f172a !important;
    border-bottom-color: #e2e8f0 !important;
  }

  .markdown-body p,
  .markdown-body li {
    color: #334155 !important;
  }

  .markdown-body strong {
    color: #0f172a !important;
  }

  .markdown-body code {
    background-color: #f1f5f9 !important;
    color: #0369a1 !important;
    border: 1px solid #e2e8f0 !important;
    font-weight: 600 !important;
  }

  .markdown-body pre {
    background-color: #f8fafc !important;
    border: 1px solid #e2e8f0 !important;
    color: #0f172a !important;
  }

  .markdown-body pre code {
    color: #0f172a !important;
  }

  .markdown-body blockquote {
    border-left-color: #cbd5e1 !important;
    color: #475569 !important;
  }

  /* JSON Tree Node & Tools Overrides */
  .bg-slate-900\\/80, .bg-slate-900\\/90 {
    background-color: #ffffff !important;
  }

  /* Inputs, Textareas, and Pre elements inside tools */
  input[type="text"], input[type="search"], textarea, select {
    background-color: #ffffff !important;
    border-color: #cbd5e1 !important;
    color: #0f172a !important;
  }

  input::placeholder, textarea::placeholder {
    color: #94a3b8 !important;
  }

  /* Scrollbars */
  ::-webkit-scrollbar-track {
    background: #f1f5f9 !important;
  }
  ::-webkit-scrollbar-thumb {
    background: #cbd5e1 !important;
  }
  ::-webkit-scrollbar-thumb:hover {
    background: #94a3b8 !important;
  }
`;

// Start lightweight static server
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
    res.writeHead(200, { 'Content-Type': 'text/html' });
    fs.createReadStream(path.join(distDir, 'index.html')).pipe(res);
  }
});

const PORT = 5301;

server.listen(PORT, async () => {
  console.log(`Static server running on http://localhost:${PORT} ...`);
  try {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      viewport: { width: 1366, height: 820 },
      deviceScaleFactor: 2
    });

    const page = await context.newPage();
    console.log('Navigating to app...');
    await page.goto(`http://localhost:${PORT}`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    // Apply Light Theme CSS
    console.log('Injecting professional Light Theme CSS...');
    await page.addStyleTag({ content: lightThemeCss });

    // Populate editor store with rich demo content
    console.log('Populating workspace tabs and sample data...');
    await page.evaluate(() => {
      // @ts-ignore
      const store = window.editorStore;
      if (!store) return;

      store.folders = ['Personal', 'Work', 'Projects', 'Database'];
      store.tabs = [];

      // Tab 1: Markdown note with emojis and checklist
      store.tabs.push({
        id: 'tab-md-1',
        title: 'Project Roadmap.md',
        content: `# 🚀 Valtera Note — Modern Light Workspace

**Valtera Note** is an ultra-fast, local-first smart notepad engineered with **Tauri v2 & Rust** for power users and developers.

---

### ✨ Key Capabilities (v0.1.7)
- ⚡ **Ultra Lightweight**: Consumes under **40MB of RAM** with sub-250ms cold startup.
- 🛠️ **Developer Tools Suite**: JSON Formatter, Favicon Generator, MySQL Password, URL & UUID.
- 🗄️ **SQL Query Runner**: Interactive SQLite scratchpad execution with virtualized data grid.
- 🎨 **Inline Emoji Picker**: Autocomplete with \`:rocket:\`, \`:star:\`, \`:check:\`, \`:db:\`.
- ☁️ **Supabase Cloud Sync**: Local-first offline resilience with background cloud sync.

### 📋 Feature Checklist
- [x] CodeMirror 6 virtualized buffer & syntax engine
- [x] Multi-tab manager with non-destructive close all tabs (\`Ctrl+Shift+W\`)
- [x] Built-in in-app auto-updater with cryptographic signatures
- [x] Dedicated Developer Tools Workspace (\`Ctrl+Shift+J\`)

\`\`\`rust
fn main() {
    println!("Hello from Valtera Note Light Engine!");
}
\`\`\`
`,
        file_extension: 'md',
        folder: 'Projects',
        is_pinned: true,
        split_mode: 'split-horizontal',
        cursor_line: 12,
        cursor_col: 10,
        is_dirty: false,
        is_open: true
      });

      // Tab 2: SQL Query
      store.tabs.push({
        id: 'tab-sql-2',
        title: 'Analytics Query.sql',
        content: `-- ============================================================
-- Valtera Note SQL Scratchpad (Light Mode)
-- Fast local query execution & formatting
-- ============================================================

SELECT 
    u.id AS user_id,
    u.name,
    u.email,
    u.plan_type,
    COUNT(o.id) AS total_orders,
    ROUND(SUM(o.amount), 2) AS total_revenue,
    MAX(o.created_at) AS last_purchase_at
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.status = 'active'
  AND u.created_at >= DATE('now', '-30 days')
GROUP BY u.id, u.name, u.email, u.plan_type
HAVING total_orders > 0
ORDER BY total_revenue DESC
LIMIT 25;
`,
        file_extension: 'sql',
        folder: 'Database',
        is_pinned: false,
        split_mode: 'split-horizontal',
        cursor_line: 10,
        cursor_col: 4,
        is_dirty: false,
        is_open: true
      });

      // Tab 3: JSON Data
      store.tabs.push({
        id: 'tab-json-3',
        title: 'Configuration.json',
        content: JSON.stringify({
          "app": "Valtera Note",
          "version": "0.1.7",
          "developer": "PT Valtera Teknologi Digital",
          "engine": {
            "runtime": "Tauri v2",
            "backend": "Rust 1.75+",
            "frontend": "Svelte 5",
            "memoryFootprint": "38.2 MB"
          },
          "developerTools": [
            "JSON Formatter & Tree Inspector",
            "Favicon & Web Icon Package Generator",
            "MySQL Password Hash Generator",
            "Base64 Encoder & Decoder",
            "URL Encoder & Query Inspector",
            "Bulk UUID Generator (v4)"
          ],
          "activeWorkspaces": 4
        }, null, 2),
        file_extension: 'json',
        folder: 'Work',
        is_pinned: false,
        split_mode: 'split-horizontal',
        cursor_line: 5,
        cursor_col: 12,
        is_dirty: false,
        is_open: true
      });

      store.activeTabIndex = 0;
    });

    await page.waitForTimeout(1000);
    await page.addStyleTag({ content: lightThemeCss });

    // 1. Capture Hero / Markdown Split View in Light Mode
    console.log('Capturing preview-hero-light.png ...');
    await page.screenshot({ path: path.join(outDir, 'preview-hero-light.png') });

    // 2. Switch to SQL Tab and run query
    console.log('Switching to SQL Tab...');
    await page.evaluate(() => {
      // @ts-ignore
      window.editorStore.selectTab(1);
    });
    await page.waitForTimeout(800);
    await page.addStyleTag({ content: lightThemeCss });

    // Click "Run Query" button if present
    const runBtn = await page.$('button:has-text("Run Query")');
    if (runBtn) {
      await runBtn.click();
      await page.waitForTimeout(800);
      await page.addStyleTag({ content: lightThemeCss });
    }

    console.log('Capturing preview-sql-light.png ...');
    await page.screenshot({ path: path.join(outDir, 'preview-sql-light.png') });

    // 3. Trigger Tools Workspace
    console.log('Switching to Developer Tools Workspace...');
    await page.keyboard.press('Control+Shift+J');
    await page.waitForTimeout(1200);

    // Re-inject Light Theme CSS into Tools Workspace
    await page.addStyleTag({ content: lightThemeCss });
    await page.waitForTimeout(600);

    console.log('Capturing preview-tools-light.png ...');
    await page.screenshot({ path: path.join(outDir, 'preview-tools-light.png') });

    // 4. Switch to Favicon Generator in Tools
    console.log('Switching to Favicon Tool...');
    await page.keyboard.press('Control+Shift+F');
    await page.waitForTimeout(1000);
    await page.addStyleTag({ content: lightThemeCss });
    await page.waitForTimeout(600);

    console.log('Capturing preview-favicon-light.png ...');
    await page.screenshot({ path: path.join(outDir, 'preview-favicon-light.png') });

    // 5. Capture the new Showcase / Documentation Page (docs/index.html)
    console.log('Navigating to docs/index.html showcase page...');
    const docsPath = 'file:///' + path.resolve(__dirname, '../docs/index.html').replace(/\\\\/g, '/');
    await page.goto(docsPath, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    console.log('Capturing preview-showcase-light.png ...');
    await page.screenshot({ path: path.join(outDir, 'preview-showcase-light.png') });

    await browser.close();
    console.log('All high-resolution Light Mode screenshots successfully generated!');
  } catch (err) {
    console.error('Error during screenshot capture:', err);
  } finally {
    server.close();
    process.exit(0);
  }
});
