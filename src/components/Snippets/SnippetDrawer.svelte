<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    X, 
    Database, 
    FileText, 
    Copy, 
    PlusCircle, 
    Check, 
    Search, 
    Sparkles 
  } from 'lucide-svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let searchQuery = $state('');
  let activeCategory = $state<'all' | 'sql' | 'markdown' | 'json'>('all');
  let copiedId = $state<string | null>(null);

  const builtInSnippets = [
    {
      id: 'sql-select',
      title: 'SELECT with Filter & Pagination',
      lang: 'sql',
      category: 'sql',
      desc: 'Standard query template with WHERE, ORDER BY, and LIMIT',
      code: `-- Query with filter and pagination\nSELECT \n  id,\n  name,\n  status,\n  created_at\nFROM items\nWHERE status = 'active'\nORDER BY created_at DESC\nLIMIT 50 OFFSET 0;`
    },
    {
      id: 'sql-create-table',
      title: 'CREATE TABLE (SQLite Standard)',
      lang: 'sql',
      category: 'sql',
      desc: 'Table definition with auto-increment, unique index, and timestamp',
      code: `CREATE TABLE IF NOT EXISTS documents (\n  id INTEGER PRIMARY KEY AUTOINCREMENT,\n  title TEXT NOT NULL,\n  content TEXT,\n  is_pinned INTEGER DEFAULT 0,\n  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,\n  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP\n);\n\nCREATE INDEX IF NOT EXISTS idx_documents_created ON documents(created_at DESC);`
    },
    {
      id: 'sql-aggregate',
      title: 'GROUP BY & Aggregations',
      lang: 'sql',
      category: 'sql',
      desc: 'Aggregation query with COUNT, SUM, AVG, and HAVING filter',
      code: `SELECT \n  category,\n  COUNT(*) AS total_items,\n  SUM(amount) AS total_amount,\n  AVG(amount) AS average_amount\nFROM transactions\nGROUP BY category\nHAVING COUNT(*) > 1\nORDER BY total_amount DESC;`
    },
    {
      id: 'sql-table-info',
      title: 'Inspect Table Schema (PRAGMA)',
      lang: 'sql',
      category: 'sql',
      desc: 'Quick schema metadata lookup in SQLite',
      code: `PRAGMA table_info(users);\nPRAGMA index_list(users);`
    },
    {
      id: 'md-meeting',
      title: 'Meeting Notes Template',
      lang: 'md',
      category: 'markdown',
      desc: 'Clean agenda, attendees, notes, and action items',
      code: `# 📅 Meeting Notes: [Topic]\n\n- **Date:** ${new Date().toLocaleDateString()}\n- **Attendees:** @Name1, @Name2\n- **Goal:** [Objective]\n\n---\n\n## 📝 Discussion Points\n1. Point 1\n2. Point 2\n\n## ✅ Action Items\n- [ ] Task 1 (@assignee)\n- [ ] Task 2 (@assignee)`
    },
    {
      id: 'md-gfm-table',
      title: 'GFM Table & Task List',
      lang: 'md',
      category: 'markdown',
      desc: 'GitHub Flavored Markdown table and interactive checklist',
      code: `| Feature | Status | Priority | ETA |\n| :--- | :---: | :---: | :--- |\n| SQLite Storage | ✅ Done | High | Today |\n| Markdown Preview | ✅ Done | High | Today |\n| Cloud Sync | 🚀 Beta | Medium | Tomorrow |\n\n### Task List\n- [x] Create project architecture\n- [x] Implement CodeMirror 6 engine\n- [ ] Deploy to production`
    },
    {
      id: 'json-api-template',
      title: 'Standard JSON API Response',
      lang: 'json',
      category: 'json',
      desc: 'Clean JSON response structure with metadata and pagination',
      code: `{\n  "status": "success",\n  "code": 200,\n  "data": [\n    {\n      "id": "item_1",\n      "title": "Sample Item",\n      "active": true\n    }\n  ],\n  "pagination": {\n    "page": 1,\n    "limit": 20,\n    "total": 1\n  }\n}`
    }
  ];

  let filteredSnippets = $derived(
    builtInSnippets.filter(s => {
      const matchCat = activeCategory === 'all' || s.category === activeCategory;
      const matchQuery = s.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                         s.desc.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         s.code.toLowerCase().includes(searchQuery.toLowerCase());
      return matchCat && matchQuery;
    })
  );

  function handleInsert(code: string) {
    const tab = editorStore.activeTab;
    if (tab) {
      const current = tab.content;
      tab.content = current ? `${current}\n\n${code}` : code;
      editorStore.updateContent(tab.content);
    }
    onClose();
  }

  async function handleCopy(id: string, code: string) {
    try {
      await navigator.clipboard.writeText(code);
      copiedId = id;
      setTimeout(() => { copiedId = null; }, 1500);
    } catch (e) {
      console.warn('Copy failed:', e);
    }
  }
</script>

{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-end bg-black/60 backdrop-blur-xs select-none animate-in fade-in duration-150">
    <div class="bg-slate-900 border-l border-slate-800 shadow-2xl h-full w-full max-w-md flex flex-col text-slate-200">
      
      <!-- Drawer Header -->
      <div class="h-12 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-4 flex-shrink-0">
        <div class="flex items-center space-x-2 text-sm font-semibold text-slate-100">
          <Sparkles class="w-4 h-4 text-amber-400" />
          <span>Snippets & Templates</span>
        </div>
        <button 
          onclick={onClose}
          class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-colors"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Search & Filters -->
      <div class="p-3 bg-slate-950/40 border-b border-slate-800 space-y-2 flex-shrink-0">
        <div class="relative">
          <Search class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
          <input 
            type="text" 
            bind:value={searchQuery} 
            placeholder="Search templates (e.g. SELECT, meeting, table)..."
            class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div class="flex space-x-1 text-xs">
          <button 
            onclick={() => (activeCategory = 'all')}
            class="px-2.5 py-1 rounded transition-colors {activeCategory === 'all' ? 'bg-blue-600 text-white font-medium' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}"
          >
            All
          </button>
          <button 
            onclick={() => (activeCategory = 'sql')}
            class="px-2.5 py-1 rounded transition-colors {activeCategory === 'sql' ? 'bg-blue-600 text-white font-medium' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}"
          >
            SQL
          </button>
          <button 
            onclick={() => (activeCategory = 'markdown')}
            class="px-2.5 py-1 rounded transition-colors {activeCategory === 'markdown' ? 'bg-blue-600 text-white font-medium' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}"
          >
            Markdown
          </button>
          <button 
            onclick={() => (activeCategory = 'json')}
            class="px-2.5 py-1 rounded transition-colors {activeCategory === 'json' ? 'bg-blue-600 text-white font-medium' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}"
          >
            JSON
          </button>
        </div>
      </div>

      <!-- Snippets List -->
      <div class="flex-1 overflow-y-auto p-3 space-y-3">
        {#each filteredSnippets as snippet (snippet.id)}
          <div class="bg-slate-950/70 border border-slate-800 rounded-lg p-3 hover:border-slate-700 transition-all space-y-2 group">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                {#if snippet.lang === 'sql'}
                  <Database class="w-3.5 h-3.5 text-blue-400" />
                {:else}
                  <FileText class="w-3.5 h-3.5 text-amber-400" />
                {/if}
                <span class="text-xs font-semibold text-slate-200">{snippet.title}</span>
              </div>
              
              <div class="flex items-center space-x-1">
                <button 
                  onclick={() => handleCopy(snippet.id, snippet.code)}
                  class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors"
                  title="Copy to Clipboard"
                >
                  {#if copiedId === snippet.id}
                    <Check class="w-3.5 h-3.5 text-emerald-400" />
                  {:else}
                    <Copy class="w-3.5 h-3.5" />
                  {/if}
                </button>

                <button 
                  onclick={() => handleInsert(snippet.code)}
                  class="flex items-center space-x-1 px-2 py-0.5 rounded bg-blue-600/20 hover:bg-blue-600 text-blue-400 hover:text-white transition-colors text-[11px] font-medium"
                  title="Insert into Editor"
                >
                  <PlusCircle class="w-3 h-3" />
                  <span>Insert</span>
                </button>
              </div>
            </div>

            <p class="text-[11px] text-slate-400 leading-snug">{snippet.desc}</p>

            <pre class="bg-slate-900/90 border border-slate-800/80 rounded p-2 text-[11px] font-mono text-slate-300 overflow-x-auto max-h-28 scrollbar-none select-text"><code>{snippet.code}</code></pre>
          </div>
        {:else}
          <div class="h-40 flex items-center justify-center text-slate-500 text-xs italic">
            No snippets found matching "{searchQuery}"
          </div>
        {/each}
      </div>

    </div>
  </div>
{/if}
