import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const outDir = path.resolve(__dirname, '../docs/screenshots');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

async function capture() {
  console.log('Launching browser for screenshot captures...');
  const browser = await chromium.launch({
    headless: true
  });

  const context = await browser.newContext({
    viewport: { width: 1366, height: 820 },
    deviceScaleFactor: 2
  });

  const page = await context.newPage();

  console.log('Navigating to http://localhost:1420 ...');
  await page.goto('http://localhost:1420', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);

  // Setup rich workspace in editorStore
  console.log('Populating tabs and workspace...');
  await page.evaluate(() => {
    // @ts-ignore
    const store = window.editorStore;
    if (!store) return;

    store.folders = ['Personal', 'Work', 'Projects', 'Database'];
    store.tabs = [];

    // Tab 1: Markdown Note with Split View
    store.tabs.push({
      id: 'tab-md-1',
      title: 'Project Roadmap.md',
      content: `# 🚀 Valtera Note — Modern Workspace

**Valtera Note** is an ultra-fast, local-first smart notepad engineered with **Tauri v2 & Rust** for power users and developers.

---

### ✨ Key Capabilities
- ⚡ **Ultra Lightweight**: Consumes under **40MB of RAM** with sub-250ms cold startup.
- 🗄️ **SQL Query Runner**: Interactive SQLite scratchpad execution with virtualized data grid.
- 🌳 **Collapsible JSON Tree**: Interactive tree viewer with direct node path copying.
- ☁️ **Supabase Cloud Sync**: Local-first offline resilience with background cloud sync.

### 📋 Feature Checklist
- [x] CodeMirror 6 virtualized buffer & syntax engine
- [x] Multi-tab manager with non-destructive close protection
- [x] Built-in in-app auto-updater with cryptographic signatures
- [ ] AI prompt scratchpad integration

\`\`\`rust
fn main() {
    println!("Hello from Valtera Note Engine!");
}
\`\`\`
`,
      file_extension: 'md',
      folder: 'Projects',
      is_pinned: true,
      split_mode: 'split-horizontal',
      cursor_line: 14,
      cursor_col: 18,
      is_dirty: false,
      is_open: true
    });

    // Tab 2: SQL Query
    store.tabs.push({
      id: 'tab-sql-2',
      title: 'Analytics Query.sql',
      content: `-- ============================================================
-- Valtera Note SQL Scratchpad
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
      cursor_line: 12,
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
        "version": "0.1.0",
        "developer": "PT Valtera Teknologi Digital",
        "engine": {
          "runtime": "Tauri v2",
          "backend": "Rust 1.75+",
          "frontend": "Svelte 5",
          "memoryFootprint": "38.2 MB"
        },
        "features": {
          "localFirst": true,
          "cloudSync": "Supabase PostgreSQL",
          "autoUpdater": "Enabled (Mandatory)",
          "splitModes": ["editor-only", "split-horizontal", "preview-only"]
        },
        "supportedFormats": ["txt", "md", "sql", "json", "csv", "rs", "ts"],
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

  // 1. Capture Hero / Markdown Split View
  console.log('Capturing preview-hero.png ...');
  await page.screenshot({ path: path.join(outDir, 'preview-hero.png') });

  // 2. Switch to SQL Tab
  console.log('Capturing preview-sql.png ...');
  await page.evaluate(() => {
    // @ts-ignore
    window.editorStore.selectTab(1);
  });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(outDir, 'preview-sql.png') });

  // 3. Switch to JSON Tab
  console.log('Capturing preview-json.png ...');
  await page.evaluate(() => {
    // @ts-ignore
    window.editorStore.selectTab(2);
  });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(outDir, 'preview-json.png') });

  await browser.close();
  console.log('All screenshots captured successfully into docs/screenshots/!');
}

capture().catch(err => {
  console.error('Error capturing screenshots:', err);
  process.exit(1);
});
