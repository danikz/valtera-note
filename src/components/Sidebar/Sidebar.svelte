<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    Search, 
    Plus, 
    X, 
    FileText, 
    Database, 
    FileCode, 
    Edit3, 
    Cloud, 
    PanelLeftClose, 
    Layers, 
    Folder,
    FolderOpen,
    FolderPlus,
    ChevronDown,
    ChevronRight,
    List,
    StickyNote,
    Edit2,
    Trash2,
    FolderInput,
    MoreHorizontal,
    Check,
    AlertTriangle
  } from 'lucide-svelte';

  let { isOpen, onToggle }: { isOpen: boolean; onToggle: () => void } = $props();

  let searchQuery = $state('');
  let filterMode = $state<'all' | 'cloud' | 'dirty'>('all');
  let viewMode = $state<'tree' | 'flat'>('tree');
  let collapsedGroups = $state<Record<string, boolean>>({});
  
  // Tab title renaming
  let editingTabIndex = $state<number | null>(null);
  let editingTitle = $state('');

  // Folder management states
  let showNewFolderModal = $state(false);
  let newFolderName = $state('');
  let editingFolderOldName = $state<string | null>(null);
  let editingFolderNewName = $state('');
  
  // Note move menu state
  let noteMovingIndex = $state<number | null>(null);

  function getFileIcon(ext: string) {
    switch (ext.toLowerCase()) {
      case 'sql': return Database;
      case 'md': case 'markdown': return Edit3;
      case 'json': case 'csv': case 'rs': case 'ts': case 'js': return FileCode;
      default: return FileText;
    }
  }

  interface NoteItem {
    tab: typeof editorStore.tabs[0];
    originalIndex: number;
  }

  interface FolderSection {
    id: string;
    name: string;
    isCustomFolder: boolean;
    category: 'custom' | 'cloud' | 'disk' | 'unfiled';
    pathSnippet?: string;
    items: NoteItem[];
  }

  let filteredTabs = $derived(
    editorStore.tabs.map((tab, originalIndex) => ({ tab, originalIndex })).filter(({ tab }) => {
      const matchSearch = tab.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          tab.content.toLowerCase().includes(searchQuery.toLowerCase());
      if (!matchSearch) return false;

      if (filterMode === 'cloud') return Boolean(tab.supabase_id);
      if (filterMode === 'dirty') return tab.is_dirty;
      return true;
    })
  );

  let folderSections = $derived.by(() => {
    const sections: FolderSection[] = [];
    const assignedIndices = new Set<number>();

    // 1. Custom User Folders (always list all created folders so user can see their structure)
    editorStore.folders.forEach((folderName) => {
      const items: NoteItem[] = [];
      filteredTabs.forEach((item) => {
        if (item.tab.folder === folderName) {
          items.push(item);
          assignedIndices.add(item.originalIndex);
        }
      });

      sections.push({
        id: `custom_folder_${folderName}`,
        name: folderName,
        isCustomFolder: true,
        category: 'custom',
        pathSnippet: `Folder: ${folderName}`,
        items
      });
    });

    // 2. Local Disk Folders (for files opened from disk without a custom folder)
    const diskFoldersMap = new Map<string, FolderSection>();
    filteredTabs.forEach((item) => {
      if (assignedIndices.has(item.originalIndex)) return;
      if (item.tab.file_path) {
        const normalized = item.tab.file_path.replace(/\\/g, '/');
        const lastSlash = normalized.lastIndexOf('/');
        const dirPath = lastSlash > 0 ? item.tab.file_path.substring(0, lastSlash) : 'Local Files';
        const folderName = dirPath.split(/[\\/]/).pop() || 'Local Folder';
        const secId = `disk_folder_${dirPath}`;

        if (!diskFoldersMap.has(secId)) {
          diskFoldersMap.set(secId, {
            id: secId,
            name: folderName,
            isCustomFolder: false,
            category: 'disk',
            pathSnippet: dirPath,
            items: []
          });
        }
        diskFoldersMap.get(secId)!.items.push(item);
        assignedIndices.add(item.originalIndex);
      }
    });
    diskFoldersMap.forEach(sec => sections.push(sec));

    // 3. Supabase Cloud Notes (synced notes without a custom folder)
    const cloudItems: NoteItem[] = [];
    filteredTabs.forEach((item) => {
      if (assignedIndices.has(item.originalIndex)) return;
      if (item.tab.supabase_id) {
        cloudItems.push(item);
        assignedIndices.add(item.originalIndex);
      }
    });

    if (cloudItems.length > 0) {
      sections.push({
        id: 'section_cloud_unfiled',
        name: 'Supabase Cloud',
        isCustomFolder: false,
        category: 'cloud',
        pathSnippet: editorStore.supabaseConfig.url ? editorStore.supabaseConfig.url.replace(/^https?:\/\//, '').split('/')[0] : 'Cloud Database',
        items: cloudItems
      });
    }

    // 4. Unfiled Quick Notes / Scratchpads
    const unfiledItems: NoteItem[] = [];
    filteredTabs.forEach((item) => {
      if (!assignedIndices.has(item.originalIndex)) {
        unfiledItems.push(item);
      }
    });

    if (unfiledItems.length > 0 || sections.length === 0) {
      sections.push({
        id: 'section_unfiled',
        name: 'Unfiled Notes',
        isCustomFolder: false,
        category: 'unfiled',
        pathSnippet: 'Root / Scratchpad',
        items: unfiledItems
      });
    }

    return sections;
  });

  function toggleGroupCollapse(groupId: string) {
    collapsedGroups[groupId] = !collapsedGroups[groupId];
  }

  function handleSelect(index: number) {
    editorStore.selectTab(index);
    noteMovingIndex = null;
  }

  function handleClose(e: MouseEvent, index: number) {
    e.stopPropagation();
    editorStore.closeTab(index);
  }

  function handleNewNoteInFolder(e: MouseEvent, folderName?: string) {
    e.stopPropagation();
    if (folderName) {
      collapsedGroups[`custom_folder_${folderName}`] = false;
    } else {
      collapsedGroups['section_unfiled'] = false;
    }
    editorStore.addTab(undefined, 'md', '', folderName);
  }

  // Folder creation
  function submitCreateFolder() {
    const trimmed = newFolderName.trim();
    if (trimmed) {
      editorStore.createFolder(trimmed, true);
      collapsedGroups[`custom_folder_${trimmed}`] = false;
      newFolderName = '';
      showNewFolderModal = false;
    }
  }

  // Folder renaming
  function startRenameFolder(e: MouseEvent, folderName: string) {
    e.stopPropagation();
    editingFolderOldName = folderName;
    editingFolderNewName = folderName;
  }

  function saveRenameFolder() {
    if (editingFolderOldName && editingFolderNewName.trim()) {
      editorStore.renameFolder(editingFolderOldName, editingFolderNewName.trim());
    }
    editingFolderOldName = null;
    editingFolderNewName = '';
  }

  // Deletion modals state
  let folderToDelete = $state<string | null>(null);
  let noteToDelete = $state<{ index: number; title: string; isCloud: boolean } | null>(null);
  let showClearAllModal = $state(false);

  function promptDeleteFolder(e: MouseEvent, folderName: string) {
    e.stopPropagation();
    folderToDelete = folderName;
  }

  async function executeDeleteFolder(deleteNotes: boolean) {
    if (folderToDelete) {
      const target = folderToDelete;
      folderToDelete = null;
      await editorStore.deleteFolder(target, deleteNotes);
    }
  }

  function promptDeleteNote(e: MouseEvent, index: number, title: string, isCloud: boolean) {
    e.stopPropagation();
    noteToDelete = { index, title, isCloud };
  }

  async function executeDeleteNote() {
    if (noteToDelete) {
      const idx = noteToDelete.index;
      noteToDelete = null;
      await editorStore.deleteTab(idx, true);
    }
  }

  async function executeClearAllData() {
    showClearAllModal = false;
    await editorStore.clearAllData();
  }

  // Tab renaming
  function startRenamingTab(e: MouseEvent, index: number, currentTitle: string) {
    e.stopPropagation();
    editingTabIndex = index;
    editingTitle = currentTitle;
  }

  function saveRenameTab(index: number) {
    if (editingTitle.trim()) {
      editorStore.renameTab(index, editingTitle.trim());
    }
    editingTabIndex = null;
  }

  function handleTabRenameKey(e: KeyboardEvent, index: number) {
    if (e.key === 'Enter') {
      saveRenameTab(index);
    } else if (e.key === 'Escape') {
      editingTabIndex = null;
    }
  }

  // Move tab to folder
  function handleMoveNoteToFolder(tabIndex: number, folderName?: string) {
    editorStore.setNoteFolder(tabIndex, folderName);
    noteMovingIndex = null;
  }
</script>

{#if isOpen}
  <aside class="w-64 h-full bg-slate-900/95 border-r border-slate-800 flex flex-col select-none flex-shrink-0 z-20 animate-in slide-in-from-left-2 duration-150 text-slate-300 relative">
    
    <!-- Sidebar Header -->
    <div class="h-9 px-3 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
      <div class="flex items-center space-x-1.5 text-xs font-semibold text-slate-200">
        <Layers class="w-3.5 h-3.5 text-blue-400" />
        <span>Explorer</span>
        <span class="px-1.5 py-0.2 rounded-full bg-slate-800 text-[10px] text-slate-400 font-mono">
          {editorStore.tabs.length}
        </span>
      </div>

      <!-- Action Toolbar -->
      <div class="flex items-center space-x-1">
        <!-- New Folder Button -->
        <button 
          onclick={() => (showNewFolderModal = true)}
          class="p-1 rounded hover:bg-slate-800 text-amber-400/90 hover:text-amber-300 transition-colors"
          title="Create New Folder"
        >
          <FolderPlus class="w-3.5 h-3.5" />
        </button>

        <!-- New Note Button -->
        <button 
          onclick={() => editorStore.addTab()}
          class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-white transition-colors"
          title="New Note (Ctrl+N)"
        >
          <Plus class="w-3.5 h-3.5" />
        </button>

        <!-- Toggle Tree vs Flat View -->
        <button 
          onclick={() => (viewMode = viewMode === 'tree' ? 'flat' : 'tree')}
          class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors"
          title={viewMode === 'tree' ? 'Switch to Flat List' : 'Group by Folders'}
        >
          {#if viewMode === 'tree'}
            <Folder class="w-3.5 h-3.5 text-blue-400" />
          {:else}
            <List class="w-3.5 h-3.5 text-slate-400" />
          {/if}
        </button>

        <!-- Close Sidebar -->
        <button 
          onclick={onToggle}
          class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-white transition-colors"
          title="Collapse Sidebar (Ctrl+B)"
        >
          <PanelLeftClose class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Search & Filter Bar -->
    <div class="p-2 space-y-1.5 border-b border-slate-800 bg-slate-950/30">
      <!-- Search Input -->
      <div class="relative">
        <Search class="w-3 h-3 absolute left-2.5 top-2 text-slate-500" />
        <input 
          type="text" 
          bind:value={searchQuery}
          placeholder="Filter notes..."
          class="w-full bg-slate-950 border border-slate-800 rounded px-2 pl-7 py-1 text-[11px] text-slate-200 placeholder-slate-600 focus:outline-none focus:border-blue-500"
        />
        {#if searchQuery}
          <button 
            onclick={() => (searchQuery = '')}
            class="absolute right-2 top-1.5 text-slate-500 hover:text-slate-300"
          >
            <X class="w-3 h-3" />
          </button>
        {/if}
      </div>

      <!-- Filter Pills -->
      <div class="flex items-center space-x-1 text-[10px]">
        <button 
          onclick={() => (filterMode = 'all')}
          class="px-2 py-0.5 rounded transition-colors {filterMode === 'all' ? 'bg-blue-600/30 text-blue-300 font-medium' : 'text-slate-500 hover:text-slate-300'}"
        >
          All ({editorStore.tabs.length})
        </button>
        <button 
          onclick={() => (filterMode = 'cloud')}
          class="px-2 py-0.5 rounded transition-colors {filterMode === 'cloud' ? 'bg-emerald-600/30 text-emerald-300 font-medium' : 'text-slate-500 hover:text-slate-300'}"
        >
          Cloud ({editorStore.tabs.filter(t => Boolean(t.supabase_id)).length})
        </button>
        <button 
          onclick={() => (filterMode = 'dirty')}
          class="px-2 py-0.5 rounded transition-colors {filterMode === 'dirty' ? 'bg-amber-600/30 text-amber-300 font-medium' : 'text-slate-500 hover:text-slate-300'}"
        >
          Unsaved ({editorStore.tabs.filter(t => t.is_dirty).length})
        </button>
      </div>
    </div>

    <!-- Notes Explorer Tree / List -->
    <div class="flex-1 overflow-y-auto p-1.5 space-y-1.5 scrollbar-thin">
      {#if viewMode === 'tree'}
        <!-- FOLDER STRUCTURE VIEW -->
        {#each folderSections as section (section.id)}
          {@const isCollapsed = Boolean(collapsedGroups[section.id])}
          {@const isEditingFolder = editingFolderOldName === section.name}
          
          <div class="space-y-0.5">
            <!-- Folder Header -->
            <div 
              class="w-full flex items-center justify-between px-2 py-1 rounded text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800/60 transition-colors group cursor-pointer"
              title={section.pathSnippet}
            >
              <div 
                role="button"
                tabindex="0"
                onclick={() => toggleGroupCollapse(section.id)}
                onkeydown={(e) => { if (e.key === 'Enter') toggleGroupCollapse(section.id); }}
                class="flex items-center space-x-1.5 truncate flex-1 min-w-0"
              >
                {#if isCollapsed}
                  <ChevronRight class="w-3 h-3 text-slate-500 flex-shrink-0" />
                {:else}
                  <ChevronDown class="w-3 h-3 text-slate-400 flex-shrink-0" />
                {/if}

                {#if section.category === 'cloud'}
                  <Cloud class="w-3.5 h-3.5 text-emerald-400 flex-shrink-0" />
                {:else if section.isCustomFolder || section.category === 'disk'}
                  {#if isCollapsed}
                    <Folder class="w-3.5 h-3.5 text-amber-400/90 flex-shrink-0" />
                  {:else}
                    <FolderOpen class="w-3.5 h-3.5 text-amber-400 flex-shrink-0" />
                  {/if}
                {:else}
                  <StickyNote class="w-3.5 h-3.5 text-blue-400 flex-shrink-0" />
                {/if}

                {#if isEditingFolder}
                  <input 
                    type="text" 
                    bind:value={editingFolderNewName}
                    onkeydown={(e) => { if (e.key === 'Enter') saveRenameFolder(); if (e.key === 'Escape') editingFolderOldName = null; }}
                    onblur={saveRenameFolder}
                    class="w-full bg-slate-950 border border-blue-500 rounded px-1 text-[11px] text-white focus:outline-none"
                    onclick={(e) => e.stopPropagation()}
                  />
                {:else}
                  <span class="font-semibold text-[11px] truncate {section.category === 'cloud' ? 'text-emerald-300' : 'text-slate-200'}">
                    {section.name}
                  </span>
                {/if}
              </div>

              <!-- Folder Actions (Hover) -->
              <div class="flex items-center space-x-1 flex-shrink-0">
                <!-- Add Note into this folder -->
                {#if section.isCustomFolder}
                  <button 
                    onclick={(e) => handleNewNoteInFolder(e, section.name)}
                    class="p-0.5 rounded hover:bg-slate-700 text-slate-400 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity"
                    title="Add note in this folder"
                  >
                    <Plus class="w-3 h-3" />
                  </button>

                  <!-- Rename Folder -->
                  <button 
                    onclick={(e) => startRenameFolder(e, section.name)}
                    class="p-0.5 rounded hover:bg-slate-700 text-slate-400 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity"
                    title="Rename folder"
                  >
                    <Edit2 class="w-2.5 h-2.5" />
                  </button>

                  <!-- Delete Folder -->
                  <button 
                    onclick={(e) => promptDeleteFolder(e, section.name)}
                    class="p-0.5 rounded hover:bg-red-900/60 text-slate-400 hover:text-red-300 opacity-0 group-hover:opacity-100 transition-opacity"
                    title="Hapus folder..."
                  >
                    <Trash2 class="w-2.5 h-2.5" />
                  </button>
                {:else if section.category === 'unfiled'}
                  <button 
                    onclick={(e) => handleNewNoteInFolder(e, undefined)}
                    class="p-0.5 rounded hover:bg-slate-700 text-slate-400 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity"
                    title="Add unfiled note"
                  >
                    <Plus class="w-3 h-3" />
                  </button>
                {/if}

                <span class="text-[10px] text-slate-500 font-mono px-1 rounded bg-slate-950/60">
                  {section.items.length}
                </span>
              </div>
            </div>

            <!-- Folder Notes List -->
            {#if !isCollapsed}
              <div class="pl-2.5 space-y-0.5 border-l border-slate-800/60 ml-2.5">
                {#if section.items.length === 0}
                  <button 
                    type="button"
                    onclick={(e) => handleNewNoteInFolder(e, section.isCustomFolder ? section.name : undefined)}
                    class="w-full text-left py-1 px-2 text-[10.5px] text-slate-500 hover:text-blue-400 italic hover:bg-slate-800/30 rounded transition-colors"
                  >
                    + Kosong, klik untuk tambah catatan
                  </button>
                {:else}
                  {#each section.items as { tab, originalIndex } (tab.title + '_' + originalIndex)}
                    {@const IconComponent = getFileIcon(tab.file_extension)}
                    {@const isActive = originalIndex === editorStore.activeTabIndex}
                    {@const isEditingTab = editingTabIndex === originalIndex}

                    <div 
                      role="button"
                      tabindex="0"
                      onclick={() => handleSelect(originalIndex)}
                      onkeydown={(e) => { if (e.key === 'Enter') handleSelect(originalIndex); }}
                      class="group w-full flex items-center justify-between px-2 py-1.5 rounded-md text-xs cursor-pointer transition-all border
                      {isActive 
                        ? 'bg-blue-600/20 text-blue-200 border-blue-500/40 font-medium' 
                        : 'text-slate-300 border-transparent hover:bg-slate-800/60 hover:text-white'}"
                    >
                      <div class="flex items-center space-x-1.5 truncate flex-1 min-w-0 pr-1">
                        <IconComponent class="w-3.5 h-3.5 flex-shrink-0 {isActive ? 'text-blue-400' : 'text-slate-500'}" />
                        
                        {#if isEditingTab}
                          <input 
                            type="text" 
                            bind:value={editingTitle}
                            onkeydown={(e) => handleTabRenameKey(e, originalIndex)}
                            onblur={() => saveRenameTab(originalIndex)}
                            class="w-full bg-slate-950 border border-blue-500 rounded px-1.5 py-0.5 text-xs text-white focus:outline-none"
                            onclick={(e) => e.stopPropagation()}
                          />
                        {:else}
                          <div class="flex flex-col truncate" ondblclick={(e) => startRenamingTab(e, originalIndex, tab.title)}>
                            <span class="truncate leading-tight text-[11.5px]">{tab.title}</span>
                            {#if tab.file_path && section.category !== 'disk'}
                              <span class="text-[9px] text-slate-500 truncate font-mono">{tab.file_path}</span>
                            {/if}
                          </div>
                        {/if}
                      </div>

                      <div class="flex items-center space-x-1 flex-shrink-0">
                        <!-- Cloud Synced Badge -->
                        {#if tab.supabase_id}
                          <span title="Synced to Supabase">
                            <Cloud class="w-3 h-3 text-emerald-400" />
                          </span>
                        {/if}

                        <!-- Dirty Indicator (Unsaved) -->
                        {#if tab.is_dirty}
                          <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" title="Unsaved changes"></span>
                        {/if}

                        <!-- Move to Folder Menu Trigger -->
                        <button 
                          onclick={(e) => {
                            e.stopPropagation();
                            noteMovingIndex = noteMovingIndex === originalIndex ? null : originalIndex;
                          }}
                          class="p-0.5 rounded hover:bg-slate-700/80 text-slate-500 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                          title="Pindahkan ke folder lain..."
                        >
                          <FolderInput class="w-2.5 h-2.5" />
                        </button>

                        <!-- Rename Note Button -->
                        <button 
                          onclick={(e) => startRenamingTab(e, originalIndex, tab.title)}
                          class="p-0.5 rounded hover:bg-slate-700/80 text-slate-500 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                          title="Rename note"
                        >
                          <Edit2 class="w-2.5 h-2.5" />
                        </button>

                        <!-- Delete Note Button (Permanent) -->
                        <button 
                          onclick={(e) => promptDeleteNote(e, originalIndex, tab.title, Boolean(tab.supabase_id))}
                          class="p-0.5 rounded hover:bg-red-900/60 text-slate-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
                          title="Hapus Catatan Permanen"
                        >
                          <Trash2 class="w-2.5 h-2.5" />
                        </button>

                        <!-- Close Tab Button (if tab is open) -->
                        {#if tab.is_open !== false}
                          <button 
                            onclick={(e) => handleClose(e, originalIndex)}
                            class="p-0.5 rounded hover:bg-slate-700/80 text-slate-500 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                            title="Tutup Tab"
                          >
                            <X class="w-3 h-3" />
                          </button>
                        {/if}
                      </div>
                    </div>

                    <!-- Inline Move Folder Dropdown Menu -->
                    {#if noteMovingIndex === originalIndex}
                      <div 
                        class="bg-slate-950 border border-slate-700 rounded-lg p-1.5 my-1 shadow-2xl space-y-1 z-30"
                        onclick={(e) => e.stopPropagation()}
                        role="region"
                        aria-label="Move note to folder"
                      >
                        <div class="text-[10px] font-semibold text-slate-400 px-1.5 py-0.5 flex justify-between items-center border-b border-slate-800">
                          <span>Pindahkan Catatan Ke:</span>
                          <button onclick={() => (noteMovingIndex = null)} class="text-slate-500 hover:text-white">
                            <X class="w-2.5 h-2.5" />
                          </button>
                        </div>
                        
                        <div class="max-h-36 overflow-y-auto space-y-0.5">
                          <!-- Unfiled Option -->
                          <button 
                            onclick={() => handleMoveNoteToFolder(originalIndex, undefined)}
                            class="w-full text-left px-2 py-1 rounded text-[11px] flex items-center justify-between hover:bg-slate-800 {tab.folder === undefined ? 'text-blue-400 font-semibold' : 'text-slate-300'}"
                          >
                            <span class="flex items-center space-x-1.5">
                              <StickyNote class="w-3 h-3 text-slate-400" />
                              <span>(Tanpa Folder / Unfiled)</span>
                            </span>
                            {#if tab.folder === undefined}
                              <Check class="w-3 h-3 text-blue-400" />
                            {/if}
                          </button>

                          <!-- User Folders List -->
                          {#each editorStore.folders as f}
                            <button 
                              onclick={() => handleMoveNoteToFolder(originalIndex, f)}
                              class="w-full text-left px-2 py-1 rounded text-[11px] flex items-center justify-between hover:bg-slate-800 {tab.folder === f ? 'text-amber-400 font-semibold' : 'text-slate-300'}"
                            >
                              <span class="flex items-center space-x-1.5 truncate">
                                <Folder class="w-3 h-3 text-amber-400" />
                                <span class="truncate">{f}</span>
                              </span>
                              {#if tab.folder === f}
                                <Check class="w-3 h-3 text-amber-400" />
                              {/if}
                            </button>
                          {/each}
                        </div>

                        <button 
                          onclick={() => { showNewFolderModal = true; noteMovingIndex = null; }}
                          class="w-full text-left px-2 py-1 rounded text-[10.5px] text-blue-400 hover:bg-blue-600/20 flex items-center space-x-1 border-t border-slate-800/80 pt-1"
                        >
                          <FolderPlus class="w-3 h-3" />
                          <span>+ Buat Folder Baru...</span>
                        </button>
                      </div>
                    {/if}
                  {/each}
                {/if}
              </div>
            {/if}
          </div>
        {:else}
          <div class="p-4 text-center text-slate-500 text-xs italic">
            Belum ada catatan
          </div>
        {/each}

      {:else}
        <!-- Flat View: Semua Catatan dalam List -->
        {#each filteredTabs as { tab, originalIndex } (tab.title + '_' + originalIndex)}
          {@const IconComponent = getFileIcon(tab.file_extension)}
          {@const isActive = originalIndex === editorStore.activeTabIndex}
          {@const isEditingTab = editingTabIndex === originalIndex}

          <div 
            role="button"
            tabindex="0"
            onclick={() => handleSelect(originalIndex)}
            onkeydown={(e) => { if (e.key === 'Enter') handleSelect(originalIndex); }}
            class="group w-full flex items-center justify-between px-2.5 py-1.5 rounded-md text-xs cursor-pointer transition-all border mb-0.5
            {isActive 
              ? 'bg-blue-600/20 text-blue-200 border-blue-500/40 font-medium' 
              : 'text-slate-300 border-transparent hover:bg-slate-800/60 hover:text-white'}"
          >
            <div class="flex items-center space-x-2 truncate flex-1 min-w-0 pr-1">
              <IconComponent class="w-3.5 h-3.5 flex-shrink-0 {isActive ? 'text-blue-400' : 'text-slate-500'}" />
              
              {#if isEditingTab}
                <input 
                  type="text" 
                  bind:value={editingTitle}
                  onkeydown={(e) => handleTabRenameKey(e, originalIndex)}
                  onblur={() => saveRenameTab(originalIndex)}
                  class="w-full bg-slate-950 border border-blue-500 rounded px-1.5 py-0.5 text-xs text-white focus:outline-none"
                  onclick={(e) => e.stopPropagation()}
                />
              {:else}
                <div class="flex flex-col truncate" ondblclick={(e) => startRenamingTab(e, originalIndex, tab.title)}>
                  <div class="flex items-center space-x-1.5 truncate">
                    <span class="truncate leading-tight text-[11.5px]">{tab.title}</span>
                    {#if tab.folder}
                      <span class="px-1 py-0.2 rounded bg-amber-500/10 border border-amber-500/30 text-amber-400 text-[9px] font-mono">
                        {tab.folder}
                      </span>
                    {/if}
                  </div>
                  {#if tab.file_path}
                    <span class="text-[9px] text-slate-500 truncate font-mono">{tab.file_path}</span>
                  {/if}
                </div>
              {/if}
            </div>

            <div class="flex items-center space-x-1 flex-shrink-0">
              {#if tab.supabase_id}
                <span title="Synced to Supabase">
                  <Cloud class="w-3 h-3 text-emerald-400" />
                </span>
              {/if}

              {#if tab.is_dirty}
                <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" title="Unsaved changes"></span>
              {/if}

              <button 
                onclick={(e) => startRenamingTab(e, originalIndex, tab.title)}
                class="p-0.5 rounded hover:bg-slate-700/80 text-slate-500 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                title="Rename note"
              >
                <Edit2 class="w-2.5 h-2.5" />
              </button>

              <button 
                onclick={(e) => promptDeleteNote(e, originalIndex, tab.title, Boolean(tab.supabase_id))}
                class="p-0.5 rounded hover:bg-red-900/60 text-slate-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
                title="Hapus Catatan Permanen"
              >
                <Trash2 class="w-2.5 h-2.5" />
              </button>

              {#if tab.is_open !== false}
                <button 
                  onclick={(e) => handleClose(e, originalIndex)}
                  class="p-0.5 rounded hover:bg-slate-700/80 text-slate-500 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Tutup Tab"
                >
                  <X class="w-3 h-3" />
                </button>
              {/if}
            </div>
          </div>
        {:else}
          <div class="p-4 text-center text-slate-500 text-xs italic">
            Belum ada catatan
          </div>
        {/each}
      {/if}
    </div>

    <!-- Sidebar Footer -->
    <div class="h-9 border-t border-slate-800 px-3 flex items-center justify-between text-[11px] text-slate-400 bg-slate-950/40">
      <button 
        onclick={() => (showNewFolderModal = true)}
        class="flex items-center space-x-1 text-amber-400 hover:text-amber-300 font-medium transition-colors"
        title="Buat folder baru"
      >
        <FolderPlus class="w-3.5 h-3.5" />
        <span>+ Folder</span>
      </button>

      <button 
        onclick={() => (showClearAllModal = true)}
        class="flex items-center space-x-1 text-slate-500 hover:text-red-400 font-medium transition-colors"
        title="Bersihkan semua catatan & struktur folder"
      >
        <Trash2 class="w-3.5 h-3.5" />
        <span>Reset Data</span>
      </button>

      <button 
        onclick={() => editorStore.addTab()}
        class="flex items-center space-x-1 text-blue-400 hover:text-blue-300 font-medium transition-colors"
        title="Buat catatan baru"
      >
        <Plus class="w-3.5 h-3.5" />
        <span>+ Note</span>
      </button>
    </div>

    <!-- Modal Buat Folder Baru -->
    {#if showNewFolderModal}
      <div 
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        onclick={() => (showNewFolderModal = false)}
        role="dialog"
        tabindex="-1"
      >
        <div 
          class="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden text-slate-200"
          onclick={(e) => e.stopPropagation()}
          role="document"
        >
          <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
            <div class="flex items-center space-x-2 text-sm font-semibold text-white">
              <FolderPlus class="w-4 h-4 text-amber-400" />
              <span>Buat Struktur Folder Baru</span>
            </div>
            <button 
              onclick={() => (showNewFolderModal = false)}
              class="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X class="w-4 h-4" />
            </button>
          </div>

          <form onsubmit={(e) => { e.preventDefault(); submitCreateFolder(); }} class="p-4 space-y-4">
            <div>
              <label for="folder-name-input" class="block text-xs font-medium text-slate-300 mb-1.5">
                Nama Folder:
              </label>
              <input 
                id="folder-name-input"
                type="text" 
                bind:value={newFolderName}
                placeholder="misal: Catatan Kerja, SQL Query, Kuliah/Tugas..."
                class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-amber-500"
              />
            </div>

            <!-- Rekomendasi Folder Populer -->
            <div class="space-y-1.5">
              <span class="text-[11px] text-slate-400">Rekomendasi Template:</span>
              <div class="flex flex-wrap gap-1.5">
                {#each ['Kerja', 'Proyek', 'SQL Queries', 'Personal', 'Kuliah', 'Drafts'] as suggestion}
                  <button 
                    type="button"
                    onclick={() => (newFolderName = suggestion)}
                    class="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 border border-slate-700 text-[11px] text-slate-300 hover:text-white transition-colors"
                  >
                    📁 {suggestion}
                  </button>
                {/each}
              </div>
            </div>

            <div class="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
              <button 
                type="button"
                onclick={() => (showNewFolderModal = false)}
                class="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors"
              >
                Batal
              </button>
              <button 
                type="submit"
                disabled={!newFolderName.trim()}
                class="px-4 py-1.5 rounded-lg text-xs font-semibold bg-amber-500 hover:bg-amber-400 text-slate-950 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-md shadow-amber-500/20"
              >
                Buat Folder
              </button>
            </div>
          </form>
        </div>
      </div>
    {/if}

    <!-- Modal Konfirmasi Hapus Folder -->
    {#if folderToDelete}
      <div 
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        onclick={() => (folderToDelete = null)}
        role="dialog"
        tabindex="-1"
      >
        <div 
          class="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden text-slate-200"
          onclick={(e) => e.stopPropagation()}
          role="document"
        >
          <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
            <div class="flex items-center space-x-2 text-sm font-semibold text-red-400">
              <Trash2 class="w-4 h-4" />
              <span>Hapus Folder "{folderToDelete}"</span>
            </div>
            <button 
              onclick={() => (folderToDelete = null)}
              class="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X class="w-4 h-4" />
            </button>
          </div>

          <div class="p-4 space-y-3">
            <p class="text-xs text-slate-300">
              Pilih tindakan untuk menghapus folder <strong class="text-white font-semibold">"{folderToDelete}"</strong>:
            </p>

            <div class="space-y-2 pt-1">
              <button 
                onclick={() => executeDeleteFolder(false)}
                class="w-full text-left p-2.5 rounded-lg border border-slate-700 hover:border-slate-600 bg-slate-800/60 hover:bg-slate-800 text-xs transition-all group"
              >
                <div class="font-semibold text-slate-200 group-hover:text-blue-300">📁 Hapus Folder Saja</div>
                <div class="text-[11px] text-slate-400 mt-0.5">Catatan di dalamnya akan dipindahkan ke <em>Unfiled Notes</em> (catatan tidak terhapus).</div>
              </button>

              <button 
                onclick={() => executeDeleteFolder(true)}
                class="w-full text-left p-2.5 rounded-lg border border-red-900/60 hover:border-red-700 bg-red-950/30 hover:bg-red-950/50 text-xs transition-all group"
              >
                <div class="font-semibold text-red-400 group-hover:text-red-300">🗑️ Hapus Folder & Seluruh Catatannya</div>
                <div class="text-[11px] text-red-300/70 mt-0.5">Menghapus folder beserta seluruh catatan di dalamnya secara permanen dari lokal dan Cloud Supabase.</div>
              </button>
            </div>

            <div class="flex justify-end pt-2">
              <button 
                type="button"
                onclick={() => (folderToDelete = null)}
                class="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors"
              >
                Batal
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}

    <!-- Modal Konfirmasi Hapus Catatan Permanen -->
    {#if noteToDelete}
      <div 
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        onclick={() => (noteToDelete = null)}
        role="dialog"
        tabindex="-1"
      >
        <div 
          class="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden text-slate-200"
          onclick={(e) => e.stopPropagation()}
          role="document"
        >
          <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
            <div class="flex items-center space-x-2 text-sm font-semibold text-red-400">
              <Trash2 class="w-4 h-4" />
              <span>Hapus Catatan Permanen</span>
            </div>
            <button 
              onclick={() => (noteToDelete = null)}
              class="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X class="w-4 h-4" />
            </button>
          </div>

          <div class="p-4 space-y-4">
            <p class="text-xs text-slate-300">
              Apakah Anda yakin ingin menghapus catatan <strong class="text-white font-semibold">"{noteToDelete.title}"</strong> secara permanen?
            </p>
            {#if noteToDelete.isCloud}
              <div class="p-2 rounded bg-amber-500/10 border border-amber-500/30 text-[11px] text-amber-300">
                ☁️ Catatan ini tersinkronisasi di Supabase Cloud dan akan dihapus dari server cloud juga.
              </div>
            {/if}

            <div class="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
              <button 
                type="button"
                onclick={() => (noteToDelete = null)}
                class="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors"
              >
                Batal
              </button>
              <button 
                type="button"
                onclick={executeDeleteNote}
                class="px-4 py-1.5 rounded-lg text-xs font-semibold bg-red-600 hover:bg-red-500 text-white transition-colors shadow-md shadow-red-600/20"
              >
                Hapus Permanen
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}

    <!-- Modal Bersihkan Semua Data (Reset Total) -->
    {#if showClearAllModal}
      <div 
        class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        onclick={() => (showClearAllModal = false)}
        role="dialog"
        tabindex="-1"
      >
        <div 
          class="bg-slate-900 border border-red-900/60 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden text-slate-200"
          onclick={(e) => e.stopPropagation()}
          role="document"
        >
          <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between bg-red-950/40">
            <div class="flex items-center space-x-2 text-sm font-semibold text-red-400">
              <AlertTriangle class="w-4 h-4 text-red-400" />
              <span>Bersihkan Semua Data & Folder</span>
            </div>
            <button 
              onclick={() => (showClearAllModal = false)}
              class="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X class="w-4 h-4" />
            </button>
          </div>

          <div class="p-4 space-y-4">
            <p class="text-xs text-slate-300">
              Tindakan ini akan <strong class="text-red-400">menghapus seluruh catatan dan struktur folder</strong>:
            </p>
            <ul class="text-[11px] text-slate-400 list-disc list-inside space-y-1">
              <li>Semua catatan lokal akan dibersihkan</li>
              <li>Semua folder kustom akan dihapus</li>
              <li>Semua data di Supabase Cloud (jika terhubung) akan dihapus</li>
            </ul>

            <div class="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
              <button 
                type="button"
                onclick={() => (showClearAllModal = false)}
                class="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors"
              >
                Batal
              </button>
              <button 
                type="button"
                onclick={executeClearAllData}
                class="px-4 py-1.5 rounded-lg text-xs font-semibold bg-red-600 hover:bg-red-500 text-white transition-colors shadow-md shadow-red-600/20"
              >
                Ya, Bersihkan Total
              </button>
            </div>
          </div>
        </div>
      </div>
    {/if}

  </aside>
{/if}
