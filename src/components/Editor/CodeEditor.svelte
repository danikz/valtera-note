<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { EditorView, keymap, highlightActiveLine, lineNumbers, highlightActiveLineGutter } from '@codemirror/view';
  import { EditorState, Compartment } from '@codemirror/state';
  import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
  import { bracketMatching, syntaxHighlighting, defaultHighlightStyle } from '@codemirror/language';
  import { searchKeymap, highlightSelectionMatches } from '@codemirror/search';
  import { autocompletion, completionKeymap } from '@codemirror/autocomplete';
  import { oneDark } from '@codemirror/theme-one-dark';
  import { markdown } from '@codemirror/lang-markdown';
  import { sql } from '@codemirror/lang-sql';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { emojiCompletionSource } from '../../utils/emojis';

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

  function handleInsertText(e: Event) {
    const customEvent = e as CustomEvent<string>;
    const text = customEvent.detail;
    if (!view || !text) return;

    const { from, to } = view.state.selection.main;
    view.dispatch({
      changes: { from, to, insert: text },
      selection: { anchor: from + text.length },
      scrollIntoView: true
    });
    view.focus();
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
        autocompletion({
          override: [
            (context) => {
              // 1. Emoji autocompletion when typing :
              const emojiMatch = context.matchBefore(/:[a-zA-Z0-9_\-+]{1,}/);
              if (emojiMatch || (context.explicit && context.matchBefore(/:/))) {
                return emojiCompletionSource(context);
              }
              // 2. Default language completions (SQL, etc.)
              const sources = context.state.languageDataAt<any>('autocomplete', context.pos);
              for (const source of sources) {
                if (typeof source === 'function') {
                  const res = source(context);
                  if (res) return res;
                }
              }
              return null;
            }
          ],
          defaultKeymap: true,
          icons: false
        }),
        keymap.of([
          ...defaultKeymap,
          ...historyKeymap,
          ...searchKeymap,
          ...completionKeymap,
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
          },
          '.cm-tooltip.cm-tooltip-autocomplete': {
            backgroundColor: '#0f172a',
            border: '1px solid #334155',
            borderRadius: '8px',
            boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5)',
            padding: '4px'
          },
          '.cm-tooltip-autocomplete ul': {
            maxHeight: '220px',
            fontFamily: 'ui-monospace, "SF Mono", Menlo, Consolas, monospace'
          },
          '.cm-tooltip-autocomplete ul li': {
            padding: '4px 8px',
            borderRadius: '6px',
            fontSize: '12px',
            color: '#cbd5e1'
          },
          '.cm-tooltip-autocomplete ul li[aria-selected]': {
            backgroundColor: '#1d4ed8',
            color: '#ffffff'
          },
          '.cm-completionLabel': {
            fontWeight: '600'
          },
          '.cm-completionDetail': {
            marginLeft: '8px',
            fontStyle: 'normal',
            color: '#94a3b8',
            fontSize: '11px'
          },
          '.cm-tooltip-autocomplete ul li[aria-selected] .cm-completionDetail': {
            color: '#bfdbfe'
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
    if (typeof window !== 'undefined') {
      window.addEventListener('valtera:insert-text', handleInsertText);
    }
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('valtera:insert-text', handleInsertText);
    }
    if (view) {
      view.destroy();
      view = null;
    }
  });
</script>

<div class="h-full w-full relative overflow-hidden bg-slate-950 flex flex-col">
  <div bind:this={editorContainer} class="h-full w-full overflow-hidden"></div>
</div>

