<script lang="ts">
  import MarkdownIt from 'markdown-it';
  import DOMPurify from 'dompurify';
  import { editorStore } from '../../stores/editorStore.svelte';

  const md = new MarkdownIt({
    html: false,
    linkify: true,
    typographer: true,
    breaks: true
  });

  let renderedHtml = $derived.by(() => {
    const rawContent = editorStore.activeTab?.content || '';
    const dirtyHtml = md.render(rawContent);
    return DOMPurify.sanitize(dirtyHtml);
  });
</script>

<div class="h-full w-full overflow-y-auto p-6 bg-slate-900/50 text-slate-200 markdown-body select-text">
  {#if renderedHtml}
    {@html renderedHtml}
  {:else}
    <div class="h-full flex items-center justify-center text-slate-500 text-sm italic">
      Empty Markdown document
    </div>
  {/if}
</div>

<style>
  :global(.markdown-body h1) {
    font-size: 1.75rem;
    font-weight: 700;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #334155;
    color: #f8fafc;
  }
  :global(.markdown-body h2) {
    font-size: 1.4rem;
    font-weight: 600;
    margin-top: 1.5rem;
    margin-bottom: 0.75rem;
    padding-bottom: 0.25rem;
    border-bottom: 1px solid #1e293b;
    color: #f1f5f9;
  }
  :global(.markdown-body h3) {
    font-size: 1.15rem;
    font-weight: 600;
    margin-top: 1.25rem;
    margin-bottom: 0.5rem;
    color: #e2e8f0;
  }
  :global(.markdown-body p) {
    margin-bottom: 0.85rem;
    line-height: 1.65;
    color: #cbd5e1;
  }
  :global(.markdown-body ul, .markdown-body ol) {
    margin-bottom: 1rem;
    padding-left: 1.5rem;
    color: #cbd5e1;
  }
  :global(.markdown-body ul) {
    list-style-type: disc;
  }
  :global(.markdown-body ol) {
    list-style-type: decimal;
  }
  :global(.markdown-body li) {
    margin-bottom: 0.25rem;
  }
  :global(.markdown-body code) {
    background-color: #0f172a;
    color: #38bdf8;
    padding: 0.15rem 0.35rem;
    border-radius: 0.25rem;
    font-size: 0.85em;
    font-family: ui-monospace, SFMono-Regular, monospace;
    border: 1px solid #1e293b;
  }
  :global(.markdown-body pre) {
    background-color: #0b0f19;
    padding: 1rem;
    border-radius: 0.5rem;
    overflow-x: auto;
    margin-bottom: 1rem;
    border: 1px solid #1e293b;
  }
  :global(.markdown-body pre code) {
    background-color: transparent;
    padding: 0;
    border: none;
    color: #f1f5f9;
  }
  :global(.markdown-body blockquote) {
    border-left: 3px solid #3b82f6;
    padding-left: 1rem;
    margin-left: 0;
    margin-bottom: 1rem;
    color: #94a3b8;
    font-style: italic;
  }
  :global(.markdown-body table) {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 1rem;
  }
  :global(.markdown-body th, .markdown-body td) {
    border: 1px solid #334155;
    padding: 0.5rem 0.75rem;
    text-align: left;
  }
  :global(.markdown-body th) {
    background-color: #1e293b;
    font-weight: 600;
  }
  :global(.markdown-body a) {
    color: #60a5fa;
    text-decoration: underline;
  }
</style>
