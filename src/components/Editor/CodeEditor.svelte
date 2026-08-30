<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { EditorView, keymap, highlightActiveLine, lineNumbers, highlightActiveLineGutter } from '@codemirror/view';
  import { EditorState, Compartment } from '@codemirror/state';
  import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
  import { bracketMatching, syntaxHighlighting, defaultHighlightStyle } from '@codemirror/language';
  import { searchKeymap, highlightSelectionMatches } from '@codemirror/search';
  import { oneDark } from '@codemirror/theme-one-dark';
  import { markdown } from '@codemirror/lang-markdown';
  import { sql } from '@codemirror/lang-sql';
  import { editorStore } from '../../stores/editorStore.svelte';

  let editorContainer = $state<HTMLDivElement | null>(null);
  let view: EditorView | null = null;
  let languageCompartment = new Compartment();
  let isInternalUpdate = false;
  let currentLoadedTabId: string | null = null;
  let currentLanguageExt = '';

  let { onRunSql }: { onRunSql?: () => void } = $props();

  function getLanguageExtension(ext: string) {
    switch (ext.toLowerCase()) {
      case 'sql':
        return sql();
      case 'md':
      case 'markdown':
        return markdown();
      default:
        return [];
    }
  }

  function initEditor() {
    if (!editorContainer) return;
    if (view) {
      view.destroy();
      view = null;
    }

    const currentTab = editorStore.activeTab;
    const initialContent = currentTab ? currentTab.content : '';
    const initialExt = currentTab ? currentTab.file_extension : 'txt';
    currentLanguageExt = initialExt;
    currentLoadedTabId = currentTab ? `${currentTab.title}_${currentTab.file_path || ''}` : null;

    const state = EditorState.create({
      doc: initialContent,
      extensions: [
        lineNumbers(),
        highlightActiveLineGutter(),
        history(),
        bracketMatching(),
        highlightActiveLine(),
        highlightSelectionMatches(),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        oneDark,
        languageCompartment.of(getLanguageExtension(initialExt)),
        keymap.of([
          ...defaultKeymap,
          ...historyKeymap,
          ...searchKeymap,
          indentWithTab,
          {
            key: 'Mod-s',
            run: () => {
              editorStore.saveCurrentTab();
              return true;
            }
          },
          {
            key: 'Mod-Enter',
            run: () => {
              if (onRunSql) onRunSql();
              return true;
            }
          }
        ]),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            isInternalUpdate = true;
            const newContent = update.state.doc.toString();
            editorStore.updateContent(newContent);
            isInternalUpdate = false;
          }
          if (update.selectionSet) {
            const pos = update.state.selection.main.head;
            const line = update.state.doc.lineAt(pos);
            editorStore.updateCursor(line.number, pos - line.from + 1);
          }
        }),
        EditorView.theme({
          '&': {
            height: '100%',
            backgroundColor: '#090d16',
            color: '#f1f5f9'
          },
          '.cm-content': {
            caretColor: '#38bdf8',
            fontFamily: 'ui-monospace, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace',
            fontSize: '13.5px',
            lineHeight: '1.6'
          },
          '&.cm-focused .cm-cursor': {
            borderLeftColor: '#38bdf8'
          },
          '&.cm-focused .cm-selectionBackground, ::selection': {
            backgroundColor: '#1e293b'
          },
          '.cm-gutters': {
            backgroundColor: '#0b0f19',
            color: '#475569',
            borderRight: '1px solid #1e293b'
          }
        })
      ]
    });

    view = new EditorView({
      state,
      parent: editorContainer
    });
  }

  $effect(() => {
    const activeTab = editorStore.activeTab;
    if (!activeTab || !view || isInternalUpdate) return;

    const tabKey = `${activeTab.title}_${activeTab.file_path || ''}`;
    const docLength = view.state.doc.length;
    const currentDoc = view.state.doc.toString();

    // If tab switched or external content updated
    if (tabKey !== currentLoadedTabId || currentDoc !== activeTab.content) {
      currentLoadedTabId = tabKey;
      view.dispatch({
        changes: { from: 0, to: docLength, insert: activeTab.content }
      });
    }

    // Reconfigure language only if extension changed
    if (activeTab.file_extension !== currentLanguageExt) {
      currentLanguageExt = activeTab.file_extension;
      view.dispatch({
        effects: languageCompartment.reconfigure(getLanguageExtension(activeTab.file_extension))
      });
    }
  });

  onMount(() => {
    initEditor();
  });

  onDestroy(() => {
    if (view) {
      view.destroy();
      view = null;
    }
  });
</script>

<div class="h-full w-full relative overflow-hidden bg-slate-950 flex flex-col">
  <div bind:this={editorContainer} class="h-full w-full overflow-hidden"></div>
</div>
