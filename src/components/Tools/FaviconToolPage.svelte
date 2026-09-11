<script lang="ts">
  import { onMount } from 'svelte';
  import JSZip from 'jszip';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { convertFileSrc } from '@tauri-apps/api/core';
  import { readFile } from '@tauri-apps/plugin-fs';
  import { 
    Upload, 
    Download, 
    Copy, 
    Check, 
    Sparkles, 
    Globe, 
    Smartphone, 
    Laptop, 
    Code, 
    FileCode, 
    Trash2, 
    RefreshCw, 
    Palette, 
    Eye, 
    SlidersHorizontal, 
    Layers, 
    ExternalLink,
    CheckCircle2,
    AlertCircle,
    Image as ImageIcon,
    FolderArchive,
    Lock,
    Search,
    Star
  } from 'lucide-svelte';
  import { editorStore } from '../../stores/editorStore.svelte';

  let { onBack }: { onBack?: () => void } = $props();

  // Drag and Drop state
  let isDragging = $state(false);
  let unlistenTauriDragDrop: (() => void) | null = null;

  // Settings
  let appName = $state('Valtera Note');
  let shortName = $state('Valtera');
  let pathPrefix = $state('/');
  let bgColor = $state('#ffffff');
  let isTransparentBg = $state(true);
  let iconPaddingPercent = $state(0); // 0 to 25%
  let cornerRadius = $state<'square' | 'rounded' | 'circle'>('rounded');
  let activeTab = $state<'mockup' | 'assets' | 'html'>('mockup');
  let copiedToast = $state<string | null>(null);
  let isGenerating = $state(false);

  // Image source state
  let sourceImageSrc = $state<string>('');
  let sourceImageElement: HTMLImageElement | null = null;
  let fileInputRef: HTMLInputElement | null = null;

  // Generated blob caches
  type IconSpec = {
    name: string;
    width: number;
    height: number;
    category: 'android' | 'apple' | 'browser' | 'ms';
    label: string;
    blob?: Blob;
    dataUrl?: string;
  };

  const ICON_SPECS: Omit<IconSpec, 'blob' | 'dataUrl'>[] = [
    // Android PWA
    { name: 'android-icon-36x36.png', width: 36, height: 36, category: 'android', label: 'Android LDPI (36x36)' },
    { name: 'android-icon-48x48.png', width: 48, height: 48, category: 'android', label: 'Android MDPI (48x48)' },
    { name: 'android-icon-72x72.png', width: 72, height: 72, category: 'android', label: 'Android HDPI (72x72)' },
    { name: 'android-icon-96x96.png', width: 96, height: 96, category: 'android', label: 'Android XHDPI (96x96)' },
    { name: 'android-icon-144x144.png', width: 144, height: 144, category: 'android', label: 'Android XXHDPI (144x144)' },
    { name: 'android-icon-192x192.png', width: 192, height: 192, category: 'android', label: 'Android XXXHDPI (192x192)' },

    // Apple iOS Touch
    { name: 'apple-icon-57x57.png', width: 57, height: 57, category: 'apple', label: 'iPhone Classic (57x57)' },
    { name: 'apple-icon-60x60.png', width: 60, height: 60, category: 'apple', label: 'iPhone iOS 7+ (60x60)' },
    { name: 'apple-icon-72x72.png', width: 72, height: 72, category: 'apple', label: 'iPad Classic (72x72)' },
    { name: 'apple-icon-76x76.png', width: 76, height: 76, category: 'apple', label: 'iPad iOS 7+ (76x76)' },
    { name: 'apple-icon-114x114.png', width: 114, height: 114, category: 'apple', label: 'iPhone Retina (114x114)' },
    { name: 'apple-icon-120x120.png', width: 120, height: 120, category: 'apple', label: 'iPhone Retina HD (120x120)' },
    { name: 'apple-icon-144x144.png', width: 144, height: 144, category: 'apple', label: 'iPad Retina (144x144)' },
    { name: 'apple-icon-152x152.png', width: 152, height: 152, category: 'apple', label: 'iPad Pro (152x152)' },
    { name: 'apple-icon-180x180.png', width: 180, height: 180, category: 'apple', label: 'iPhone 6+/X/11/12+ (180x180)' },
    { name: 'apple-icon.png', width: 180, height: 180, category: 'apple', label: 'Apple Touch Default (180x180)' },
    { name: 'apple-icon-precomposed.png', width: 180, height: 180, category: 'apple', label: 'Apple Precomposed (180x180)' },

    // Standard Browser Favicons
    { name: 'favicon-16x16.png', width: 16, height: 16, category: 'browser', label: 'Browser Tab 16x16' },
    { name: 'favicon-32x32.png', width: 32, height: 32, category: 'browser', label: 'Browser Tab Retina 32x32' },
    { name: 'favicon-96x96.png', width: 96, height: 96, category: 'browser', label: 'Google TV / Desktop 96x96' },

    // Microsoft Windows Tiles
    { name: 'ms-icon-70x70.png', width: 70, height: 70, category: 'ms', label: 'Windows Small Tile (70x70)' },
    { name: 'ms-icon-144x144.png', width: 144, height: 144, category: 'ms', label: 'Windows Tile 144x144' },
    { name: 'ms-icon-150x150.png', width: 150, height: 150, category: 'ms', label: 'Windows Medium Tile (150x150)' },
    { name: 'ms-icon-310x310.png', width: 310, height: 310, category: 'ms', label: 'Windows Large Tile (310x310)' }
  ];

  let generatedIcons = $state<IconSpec[]>([]);
  let icoBlob = $state<Blob | null>(null);

  // Derived Clean Prefix
  let normalizedPrefix = $derived.by(() => {
    let p = pathPrefix.trim();
    if (!p) return '/';
    if (!p.endsWith('/')) p += '/';
    return p;
  });

  // Derived HTML Snippet
  let htmlSnippet = $derived.by(() => {
    const p = normalizedPrefix;
    const tc = isTransparentBg ? '#ffffff' : bgColor;
    return `<!-- Favicon & Touch Icons for Web & Mobile -->
<link rel="apple-touch-icon" sizes="57x57" href="${p}apple-icon-57x57.png">
<link rel="apple-touch-icon" sizes="60x60" href="${p}apple-icon-60x60.png">
<link rel="apple-touch-icon" sizes="72x72" href="${p}apple-icon-72x72.png">
<link rel="apple-touch-icon" sizes="76x76" href="${p}apple-icon-76x76.png">
<link rel="apple-touch-icon" sizes="114x114" href="${p}apple-icon-114x114.png">
<link rel="apple-touch-icon" sizes="120x120" href="${p}apple-icon-120x120.png">
<link rel="apple-touch-icon" sizes="144x144" href="${p}apple-icon-144x144.png">
<link rel="apple-touch-icon" sizes="152x152" href="${p}apple-icon-152x152.png">
<link rel="apple-touch-icon" sizes="180x180" href="${p}apple-icon-180x180.png">
<link rel="icon" type="image/png" sizes="192x192" href="${p}android-icon-192x192.png">
<link rel="icon" type="image/png" sizes="32x32" href="${p}favicon-32x32.png">
<link rel="icon" type="image/png" sizes="96x96" href="${p}favicon-96x96.png">
<link rel="icon" type="image/png" sizes="16x16" href="${p}favicon-16x16.png">
<link rel="manifest" href="${p}manifest.json">
<meta name="msapplication-TileColor" content="${tc}">
<meta name="msapplication-TileImage" content="${p}ms-icon-144x144.png">
<meta name="theme-color" content="${tc}">`;
  });

  // Derived Manifest JSON
  let manifestSnippet = $derived.by(() => {
    const p = normalizedPrefix;
    const tc = isTransparentBg ? '#ffffff' : bgColor;
    const manifest = {
      name: appName || 'My Web Application',
      short_name: shortName || 'App',
      icons: [
        { src: `${p}android-icon-36x36.png`, sizes: '36x36', type: 'image/png', density: '0.75' },
        { src: `${p}android-icon-48x48.png`, sizes: '48x48', type: 'image/png', density: '1.0' },
        { src: `${p}android-icon-72x72.png`, sizes: '72x72', type: 'image/png', density: '1.5' },
        { src: `${p}android-icon-96x96.png`, sizes: '96x96', type: 'image/png', density: '2.0' },
        { src: `${p}android-icon-144x144.png`, sizes: '144x144', type: 'image/png', density: '3.0' },
        { src: `${p}android-icon-192x192.png`, sizes: '192x192', type: 'image/png', density: '4.0' }
      ],
      theme_color: tc,
      background_color: tc,
      display: 'standalone'
    };
    return JSON.stringify(manifest, null, 2);
  });

  // Derived Browserconfig XML
  let browserconfigSnippet = $derived.by(() => {
    const p = normalizedPrefix;
    const tc = isTransparentBg ? '#ffffff' : bgColor;
    return `<?xml version="1.0" encoding="utf-8"?>
<browserconfig>
    <msapplication>
        <tile>
            <square70x70logo src="${p}ms-icon-70x70.png"/>
            <square150x150logo src="${p}ms-icon-150x150.png"/>
            <square310x310logo src="${p}ms-icon-310x310.png"/>
            <TileColor>${tc}</TileColor>
        </tile>
    </msapplication>
</browserconfig>`;
  });

  // Build default high-res SVG sample on startup
  function createDefaultSampleLogo(): string {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
      <defs>
        <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#3b82f6"/>
          <stop offset="50%" stop-color="#2563eb"/>
          <stop offset="100%" stop-color="#1d4ed8"/>
        </linearGradient>
        <linearGradient id="glow" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#60a5fa" stop-opacity="0.8"/>
          <stop offset="100%" stop-color="#3b82f6" stop-opacity="0.2"/>
        </linearGradient>
      </defs>
      <rect width="512" height="512" rx="112" fill="url(#g)"/>
      <path d="M128 140 L256 380 L384 140 L310 140 L256 265 L202 140 Z" fill="#ffffff" filter="drop-shadow(0px 8px 16px rgba(0,0,0,0.25))"/>
      <circle cx="256" cy="190" r="28" fill="#93c5fd"/>
    </svg>`;
    return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
  }

  // Load image element
  function loadImage(src: string): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => resolve(img);
      img.onerror = (e) => reject(e);
      img.src = src;
    });
  }

  // Generate binary multi-resolution .ico from PNG ArrayBuffers
  function buildIcoBinary(pngBuffers: { width: number; height: number; buffer: ArrayBuffer }[]): Uint8Array {
    const numImages = pngBuffers.length;
    const headerLen = 6;
    const dirEntryLen = 16;
    const totalHeaderLen = headerLen + dirEntryLen * numImages;

    let totalSize = totalHeaderLen;
    for (const img of pngBuffers) {
      totalSize += img.buffer.byteLength;
    }

    const out = new Uint8Array(totalSize);
    const view = new DataView(out.buffer);

    // ICO Header
    view.setUint16(0, 0, true); // Reserved
    view.setUint16(2, 1, true); // Type: 1 = ICO
    view.setUint16(4, numImages, true); // Count

    let currentOffset = totalHeaderLen;

    for (let i = 0; i < numImages; i++) {
      const img = pngBuffers[i];
      const entryOffset = headerLen + i * dirEntryLen;
      view.setUint8(entryOffset + 0, img.width >= 256 ? 0 : img.width);
      view.setUint8(entryOffset + 1, img.height >= 256 ? 0 : img.height);
      view.setUint8(entryOffset + 2, 0); // Palette count
      view.setUint8(entryOffset + 3, 0); // Reserved
      view.setUint16(entryOffset + 4, 1, true); // Planes
      view.setUint16(entryOffset + 6, 32, true); // Bits per pixel
      view.setUint32(entryOffset + 8, img.buffer.byteLength, true); // Data length
      view.setUint32(entryOffset + 12, currentOffset, true); // Data offset

      out.set(new Uint8Array(img.buffer), currentOffset);
      currentOffset += img.buffer.byteLength;
    }

    return out;
  }

  // Main generator function
  async function generateAllIcons() {
    if (!sourceImageElement) return;
    isGenerating = true;

    try {
      const results: IconSpec[] = [];
      const icoSources: { width: number; height: number; buffer: ArrayBuffer }[] = [];

      for (const spec of ICON_SPECS) {
        const canvas = document.createElement('canvas');
        canvas.width = spec.width;
        canvas.height = spec.height;
        const ctx = canvas.getContext('2d');
        if (!ctx) continue;

        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        // 1. Background fill
        if (!isTransparentBg) {
          ctx.fillStyle = bgColor;
          if (cornerRadius === 'circle') {
            ctx.beginPath();
            ctx.arc(spec.width / 2, spec.height / 2, Math.min(spec.width, spec.height) / 2, 0, Math.PI * 2);
            ctx.fill();
          } else if (cornerRadius === 'rounded') {
            const r = spec.width * 0.18;
            ctx.beginPath();
            ctx.roundRect(0, 0, spec.width, spec.height, r);
            ctx.fill();
          } else {
            ctx.fillRect(0, 0, spec.width, spec.height);
          }
        }

        // 2. Padding calculation
        const padRatio = iconPaddingPercent / 100;
        const padX = spec.width * padRatio;
        const padY = spec.height * padRatio;
        const drawW = spec.width - padX * 2;
        const drawH = spec.height - padY * 2;

        ctx.drawImage(sourceImageElement, padX, padY, drawW, drawH);

        // 3. To Blob
        const blob = await new Promise<Blob | null>((resolve) => {
          canvas.toBlob((b) => resolve(b), 'image/png');
        });

        if (blob) {
          const dataUrl = canvas.toDataURL('image/png');
          results.push({
            ...spec,
            blob,
            dataUrl
          });

          // If size is 16, 32, or 48, feed into favicon.ico generator
          if (spec.width === 16 || spec.width === 32 || spec.width === 48) {
            const buf = await blob.arrayBuffer();
            icoSources.push({ width: spec.width, height: spec.height, buffer: buf });
          }
        }
      }

      // If 48x48 was not in standard specs, create one for ICO
      const has48 = icoSources.some((s) => s.width === 48);
      if (!has48 && sourceImageElement) {
        const c48 = document.createElement('canvas');
        c48.width = 48;
        c48.height = 48;
        const ctx48 = c48.getContext('2d');
        if (ctx48) {
          ctx48.imageSmoothingEnabled = true;
          ctx48.imageSmoothingQuality = 'high';
          ctx48.drawImage(sourceImageElement, 0, 0, 48, 48);
          const b48 = await new Promise<Blob | null>((resolve) => c48.toBlob((b) => resolve(b), 'image/png'));
          if (b48) {
            const buf48 = await b48.arrayBuffer();
            icoSources.push({ width: 48, height: 48, buffer: buf48 });
          }
        }
      }

      // Generate multi-resolution ICO
      icoSources.sort((a, b) => a.width - b.width);
      if (icoSources.length > 0) {
        const icoBytes = buildIcoBinary(icoSources);
        icoBlob = new Blob([icoBytes.buffer as ArrayBuffer], { type: 'image/x-icon' });
      }

      generatedIcons = results;
    } catch (err) {
      console.error('Error generating favicons:', err);
      showToast('Gagal memproses gambar favicon');
    } finally {
      isGenerating = false;
    }
  }

  // Handle File Upload
  function handleFileSelect(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files && target.files[0]) {
      const file = target.files[0];
      const reader = new FileReader();
      reader.onload = async (e) => {
        const result = e.target?.result as string;
        if (result) {
          sourceImageSrc = result;
          sourceImageElement = await loadImage(result);
          await generateAllIcons();
          showToast(`Gambar "${file.name}" berhasil dimuat`);
        }
      };
      reader.readAsDataURL(file);
    }
  }

  // Handle HTML5 Drag and Drop
  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    e.stopPropagation();
    isDragging = true;
  }

  function handleDragLeave(e: DragEvent) {
    e.preventDefault();
    e.stopPropagation();
    if (e.currentTarget === e.target) {
      isDragging = false;
    }
  }

  async function handleHtml5Drop(e: DragEvent) {
    e.preventDefault();
    e.stopPropagation();
    isDragging = false;

    if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      if (file.type.startsWith('image/') || file.name.match(/\.(png|jpe?g|svg|webp|ico|gif|bmp)$/i)) {
        const reader = new FileReader();
        reader.onload = async (ev) => {
          const result = ev.target?.result as string;
          if (result) {
            sourceImageSrc = result;
            sourceImageElement = await loadImage(result);
            await generateAllIcons();
            showToast(`Gambar "${file.name}" berhasil dimuat`);
          }
        };
        reader.readAsDataURL(file);
      } else {
        showToast('Format berkas tidak didukung. Harap gunakan PNG, SVG, JPG, atau WebP.');
      }
    }
  }

  // Handle Tauri Native File Path Drop (from Windows Explorer)
  async function handleNativeFilePath(filePath: string) {
    const fileName = filePath.split(/[\\/]/).pop() || filePath;
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    if (!['png', 'jpg', 'jpeg', 'svg', 'webp', 'ico', 'gif', 'bmp'].includes(ext)) {
      showToast('Format berkas tidak didukung. Harap gunakan PNG, SVG, JPG, atau WebP.');
      return;
    }

    try {
      // 1. Try reading binary bytes via plugin-fs
      const bytes = await readFile(filePath);
      const mime = ext === 'svg' ? 'image/svg+xml' : ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : ext === 'webp' ? 'image/webp' : 'image/png';
      const blob = new Blob([bytes], { type: mime });
      const objectUrl = URL.createObjectURL(blob);
      sourceImageSrc = objectUrl;
      sourceImageElement = await loadImage(objectUrl);
      await generateAllIcons();
      showToast(`Gambar "${fileName}" berhasil dimuat`);
    } catch (err) {
      // 2. Fallback to convertFileSrc
      try {
        const src = convertFileSrc(filePath);
        sourceImageSrc = src;
        sourceImageElement = await loadImage(src);
        await generateAllIcons();
        showToast(`Gambar "${fileName}" berhasil dimuat`);
      } catch (e2) {
        console.error('Failed to load dropped file:', e2);
        showToast(`Gagal membaca berkas: ${fileName}`);
      }
    }
  }

  // Download All as ZIP
  async function handleDownloadAllZip() {
    if (generatedIcons.length === 0) {
      showToast('Belum ada ikon yang digenerate');
      return;
    }

    try {
      showToast('Mengemas berkas ZIP...');
      const zip = new JSZip();

      // 1. Add all 24 PNG files
      for (const icon of generatedIcons) {
        if (icon.blob) {
          zip.file(icon.name, icon.blob);
        }
      }

      // 2. Add favicon.ico
      if (icoBlob) {
        zip.file('favicon.ico', icoBlob);
      }

      // 3. Add manifest.json
      zip.file('manifest.json', manifestSnippet);

      // 4. Add browserconfig.xml
      zip.file('browserconfig.xml', browserconfigSnippet);

      // 5. Add README.html with instructions & copyable tags
      const readmeContent = `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Panduan Pemasangan Favicon - Valtera Note</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 760px; margin: 40px auto; line-height: 1.6; color: #1e293b; padding: 0 20px; }
    h1 { color: #0f172a; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px; }
    pre { background: #0f172a; color: #f8fafc; padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; }
    code { font-family: monospace; }
  </style>
</head>
<body>
  <h1>Paket Favicon Lengkap (27 Berkas)</h1>
  <p>Paket ini digenerate secara lokal menggunakan <strong>Valtera Note Favicon Generator</strong>.</p>
  <h3>Langkah 1: Letakkan berkas di folder root web Anda</h3>
  <p>Ekstrak semua berkas di ZIP ini ke dalam root directory website (misalnya: <code>public/</code> atau root HTML Anda).</p>
  <h3>Langkah 2: Salin kode berikut ke dalam &lt;head&gt; dokumen HTML Anda:</h3>
  <pre><code>${htmlSnippet.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</code></pre>
</body>
</html>`;
      zip.file('README.html', readmeContent);

      // Generate ZIP blob
      const zipBlob = await zip.generateAsync({ type: 'blob' });
      const url = URL.createObjectURL(zipBlob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `favicons-${new Date().toISOString().slice(0, 10)}.zip`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      showToast('Paket favicons.zip berhasil diunduh!');
    } catch (e) {
      console.error('ZIP creation error:', e);
      showToast('Gagal membuat berkas ZIP');
    }
  }

  // Single file download
  function handleDownloadSingleFile(name: string, blob: Blob) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast(`${name} diunduh!`);
  }

  // Copy Snippet Actions
  async function handleCopyHtml() {
    try {
      await navigator.clipboard.writeText(htmlSnippet);
      showToast('Kode HTML <head> tersalin!');
    } catch (e) {
      showToast('Gagal menyalin');
    }
  }

  async function handleCopyManifest() {
    try {
      await navigator.clipboard.writeText(manifestSnippet);
      showToast('manifest.json tersalin!');
    } catch (e) {
      showToast('Gagal menyalin');
    }
  }

  function handleExportHtmlToNewTab() {
    editorStore.addTab('favicon_head.html', 'html', htmlSnippet);
    if (onBack) onBack();
  }

  async function handleLoadDefaultLogo() {
    isGenerating = true;
    try {
      // 1. Fetch official Valtera logo from /logo.png
      const res = await fetch('/logo.png');
      if (res.ok) {
        const blob = await res.blob();
        const reader = new FileReader();
        reader.onload = async () => {
          const dataUrl = reader.result as string;
          sourceImageSrc = dataUrl;
          try {
            const img = await loadImage(dataUrl);
            sourceImageElement = img;
            await generateAllIcons();
            showToast('Logo resmi Valtera berhasil dimuat');
          } catch (loadErr) {
            console.error('Error rendering image element from dataUrl:', loadErr);
          }
        };
        reader.readAsDataURL(blob);
        return;
      }
    } catch (err) {
      console.warn('Gagal memuat /logo.png via fetch, mencoba fallback langsung', err);
    }

    // 2. Direct Image loader fallback for /logo.png
    try {
      const img = await loadImage('/logo.png');
      sourceImageSrc = '/logo.png';
      sourceImageElement = img;
      await generateAllIcons();
      showToast('Logo resmi Valtera berhasil dimuat');
      return;
    } catch (e) {
      console.warn('Gagal memuat /logo.png langsung, menggunakan generator sampel', e);
    }

    // 3. Fallback to SVG sample
    const sample = createDefaultSampleLogo();
    sourceImageSrc = sample;
    loadImage(sample).then(async (img) => {
      sourceImageElement = img;
      await generateAllIcons();
      showToast('Logo sampel dimuat');
    });
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2200);
  }

  // Startup: Load default emblem logo and listen for Tauri native drag-drop
  onMount(() => {
    handleLoadDefaultLogo();

    if (typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window) {
      getCurrentWindow().onDragDropEvent(async (event) => {
        if (event.payload.type === 'enter' || event.payload.type === 'over') {
          isDragging = true;
        } else if (event.payload.type === 'leave') {
          isDragging = false;
        } else if (event.payload.type === 'drop') {
          isDragging = false;
          if (event.payload.paths && event.payload.paths.length > 0) {
            await handleNativeFilePath(event.payload.paths[0]);
          }
        }
      }).then((unlisten) => {
        unlistenTauriDragDrop = unlisten;
      }).catch((err) => {
        console.warn('onDragDropEvent registration failed:', err);
      });
    }

    return () => {
      if (unlistenTauriDragDrop) {
        unlistenTauriDragDrop();
      }
    };
  });
</script>

<div 
  ondragover={handleDragOver}
  ondragenter={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleHtml5Drop}
  class="h-full w-full flex flex-col md:flex-row overflow-hidden divide-y md:divide-y-0 md:divide-x divide-slate-800 bg-slate-950 text-slate-100 select-none relative"
>
  <!-- ============================================== -->
  <!-- LEFT PANE: CONTROLS & SETTINGS                 -->
  <!-- ============================================== -->
  <aside class="w-full md:w-[290px] lg:w-[320px] xl:w-[340px] flex flex-col overflow-hidden bg-slate-950/80 border-r border-slate-800 flex-shrink-0">
    <!-- Header -->
    <div class="h-10 px-3.5 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs font-medium flex-shrink-0">
      <div class="flex items-center space-x-2">
        <Sparkles class="w-4 h-4 text-amber-400" />
        <span class="font-bold text-slate-100">Favicon Generator</span>
      </div>
      <button 
        onclick={handleLoadDefaultLogo}
        class="px-2 py-0.5 rounded text-[11px] bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer flex items-center space-x-1"
        title="Muat Ulang Logo Resmi Valtera"
      >
        <RefreshCw class="w-3 h-3 text-blue-400" />
        <span>Logo Valtera</span>
      </button>
    </div>

    <!-- Scrollable Control Panel Body -->
    <div class="flex-1 overflow-y-auto p-4 space-y-4 text-xs">
      <!-- Upload Zone -->
      <div class="space-y-1.5">
        <span class="text-[11px] font-semibold text-slate-300 uppercase tracking-wider">Unggah Gambar Sumber</span>
        <div 
          onclick={() => fileInputRef?.click()}
          ondragover={handleDragOver}
          ondragenter={handleDragOver}
          ondragleave={handleDragLeave}
          ondrop={handleHtml5Drop}
          role="button"
          tabindex="0"
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && fileInputRef?.click()}
          class="border-2 border-dashed rounded-xl p-4 flex flex-col items-center justify-center text-center cursor-pointer transition-all group shadow-xs {isDragging ? 'border-blue-400 bg-blue-600/20 ring-4 ring-blue-500/30 scale-[1.02]' : 'border-slate-700/80 hover:border-blue-500/80 bg-slate-900/40 hover:bg-slate-900/70'}"
        >
          <input 
            type="file" 
            bind:this={fileInputRef} 
            onchange={handleFileSelect} 
            accept="image/png, image/jpeg, image/svg+xml, image/webp" 
            class="hidden" 
          />
          <div class="w-10 h-10 rounded-xl {isDragging ? 'bg-blue-600/40 text-blue-300 animate-bounce' : 'bg-slate-800 group-hover:bg-blue-600/20 text-slate-400 group-hover:text-blue-400'} flex items-center justify-center mb-2 transition-colors">
            <Upload class="w-5 h-5" />
          </div>
          {#if isDragging}
            <p class="text-xs font-bold text-blue-300 animate-pulse">
              Lepaskan Gambar di Sini!
            </p>
            <p class="text-[11px] text-blue-400/90 mt-0.5 font-medium">
              Langsung diolah menjadi 27 ikon
            </p>
          {:else}
            <p class="text-xs font-semibold text-slate-200 group-hover:text-blue-300 transition-colors">
              Klik atau Tarik Gambar ke Sini
            </p>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Mendukung PNG, SVG, JPG, WebP (Rekomendasi 512×512)
            </p>
          {/if}
        </div>
      </div>

      <!-- Current Source Preview & Quick Attributes -->
      <div class="p-3 bg-slate-900/50 border border-slate-800 rounded-xl flex items-center space-x-3">
        <div class="w-12 h-12 rounded-lg bg-slate-950 border border-slate-800 flex items-center justify-center overflow-hidden p-1 flex-shrink-0 shadow-inner">
          {#if sourceImageSrc}
            <img src={sourceImageSrc} alt="Preview Sumber" class="w-full h-full object-contain" />
          {:else}
            <ImageIcon class="w-6 h-6 text-slate-600" />
          {/if}
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-xs font-semibold text-slate-200 truncate">Logo Master (Valtera)</p>
          <p class="text-[11px] text-slate-500">27 berkas siap digenerate otomatis</p>
        </div>
        <button 
          onclick={() => fileInputRef?.click()}
          class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer"
        >
          Ganti
        </button>
      </div>

      <!-- Canvas Customization Options -->
      <div class="space-y-3 pt-1 border-t border-slate-800/80">
        <span class="text-[11px] font-semibold text-slate-300 uppercase tracking-wider">Kustomisasi Tampilan</span>

        <!-- Background Mode -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="text-slate-400">Latar Belakang (Background):</span>
            <label class="flex items-center space-x-1.5 text-[11px] text-slate-300 cursor-pointer">
              <input 
                type="checkbox" 
                bind:checked={isTransparentBg} 
                onchange={generateAllIcons}
                class="rounded border-slate-700 bg-slate-900 text-blue-600 focus:ring-0 cursor-pointer" 
              />
              <span>Transparan</span>
            </label>
          </div>

          {#if !isTransparentBg}
            <div class="flex items-center space-x-2 animate-in fade-in duration-150">
              <input 
                type="color" 
                bind:value={bgColor} 
                onchange={generateAllIcons}
                class="w-7 h-7 rounded border border-slate-700 bg-transparent cursor-pointer p-0" 
              />
              <input 
                type="text" 
                bind:value={bgColor} 
                onchange={generateAllIcons}
                class="flex-1 px-2.5 py-1 bg-slate-900 border border-slate-800 rounded-lg text-xs font-mono text-slate-200 uppercase focus:outline-none focus:border-blue-500" 
              />
            </div>
          {/if}
        </div>

        <!-- Padding Slider -->
        <div class="space-y-1">
          <div class="flex items-center justify-between text-xs">
            <span class="text-slate-400">Padding / Jarak Tepi:</span>
            <span class="font-mono text-blue-400 font-semibold">{iconPaddingPercent}%</span>
          </div>
          <input 
            type="range" 
            min="0" 
            max="25" 
            step="1" 
            bind:value={iconPaddingPercent} 
            onchange={generateAllIcons}
            class="w-full accent-blue-500 cursor-pointer" 
          />
          <p class="text-[10px] text-slate-500">Beri padding agar logo tidak terpotong saat ikon membulat di HP.</p>
        </div>

        <!-- Corner Style -->
        <div class="space-y-1.5">
          <span class="text-slate-400 text-xs">Bentuk Pratinjau:</span>
          <div class="grid grid-cols-3 gap-1.5 bg-slate-950 p-1 rounded-lg border border-slate-800">
            <button 
              onclick={() => { cornerRadius = 'square'; generateAllIcons(); }}
              class="py-1 text-[11px] rounded transition-all cursor-pointer font-medium {cornerRadius === 'square' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
            >
              Kotak
            </button>
            <button 
              onclick={() => { cornerRadius = 'rounded'; generateAllIcons(); }}
              class="py-1 text-[11px] rounded transition-all cursor-pointer font-medium {cornerRadius === 'rounded' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
            >
              Squircle
            </button>
            <button 
              onclick={() => { cornerRadius = 'circle'; generateAllIcons(); }}
              class="py-1 text-[11px] rounded transition-all cursor-pointer font-medium {cornerRadius === 'circle' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
            >
              Lingkaran
            </button>
          </div>
        </div>
      </div>

      <!-- Web App Manifest Metadata -->
      <div class="space-y-2 pt-1 border-t border-slate-800/80">
        <span class="text-[11px] font-semibold text-slate-300 uppercase tracking-wider">Metadata Web & PWA</span>

        <div class="space-y-1">
          <label class="text-[11px] text-slate-400">Nama Aplikasi (App Name):</label>
          <input 
            type="text" 
            bind:value={appName} 
            class="w-full px-2.5 py-1 bg-slate-900 border border-slate-800 rounded-lg text-xs text-slate-200 focus:outline-none focus:border-blue-500" 
          />
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div class="space-y-1">
            <label class="text-[11px] text-slate-400">Nama Singkat:</label>
            <input 
              type="text" 
              bind:value={shortName} 
              class="w-full px-2.5 py-1 bg-slate-900 border border-slate-800 rounded-lg text-xs text-slate-200 focus:outline-none focus:border-blue-500" 
            />
          </div>

          <div class="space-y-1">
            <label class="text-[11px] text-slate-400">Prefix URL Path:</label>
            <input 
              type="text" 
              bind:value={pathPrefix} 
              placeholder="/" 
              class="w-full px-2.5 py-1 bg-slate-900 border border-slate-800 rounded-lg text-xs font-mono text-slate-200 focus:outline-none focus:border-blue-500" 
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Bottom Master Download Action Bar -->
    <div class="p-3 bg-slate-900/90 border-t border-slate-800 flex flex-col space-y-2 flex-shrink-0">
      <button 
        onclick={handleDownloadAllZip}
        disabled={isGenerating || generatedIcons.length === 0}
        class="w-full py-2 px-3 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white text-xs font-bold flex items-center justify-center space-x-2 transition-all cursor-pointer shadow-lg shadow-blue-500/20 disabled:opacity-40 disabled:cursor-not-allowed"
      >
        <FolderArchive class="w-4 h-4" />
        <span>Unduh Paket ZIP (27 Berkas)</span>
      </button>

      <div class="grid grid-cols-2 gap-2">
        <button 
          onclick={handleCopyHtml}
          class="py-1.5 px-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-[11px] font-medium flex items-center justify-center space-x-1.5 transition-colors cursor-pointer"
        >
          <Code class="w-3.5 h-3.5 text-emerald-400" />
          <span>Salin HTML</span>
        </button>

        <button 
          onclick={handleCopyManifest}
          class="py-1.5 px-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-[11px] font-medium flex items-center justify-center space-x-1.5 transition-colors cursor-pointer"
        >
          <FileCode class="w-3.5 h-3.5 text-purple-400" />
          <span>Salin Manifest</span>
        </button>
      </div>
    </div>
  </aside>

  <!-- ============================================== -->
  <!-- RIGHT PANE: LIVE MOCKUPS, ASSET GRID & CODE   -->
  <!-- ============================================== -->
  <main class="flex-1 flex flex-col overflow-hidden bg-slate-950/40">
    <!-- Right Header Tabs -->
    <header class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs font-medium flex-shrink-0">
      <div class="flex items-center space-x-1 bg-slate-950 p-0.5 rounded-lg border border-slate-800">
        <button 
          onclick={() => (activeTab = 'mockup')}
          class="px-3 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {activeTab === 'mockup' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
        >
          <Eye class="w-3.5 h-3.5" />
          <span>Simulasi Nyata (Mockup)</span>
        </button>

        <button 
          onclick={() => (activeTab = 'assets')}
          class="px-3 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {activeTab === 'assets' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
        >
          <Layers class="w-3.5 h-3.5" />
          <span>Semua 27 Berkas</span>
          <span class="ml-1 px-1 py-0.2 rounded text-[10px] font-mono {activeTab === 'assets' ? 'bg-blue-700 text-blue-100' : 'bg-slate-800 text-slate-400'}">
            27
          </span>
        </button>

        <button 
          onclick={() => (activeTab = 'html')}
          class="px-3 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {activeTab === 'html' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
        >
          <Code class="w-3.5 h-3.5" />
          <span>Kode &lt;head&gt;</span>
        </button>
      </div>

      <!-- Quick Export to Note tab -->
      <button 
        onclick={handleExportHtmlToNewTab}
        class="hidden sm:flex items-center space-x-1 px-2.5 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer"
        title="Buka kode HTML di tab editor baru"
      >
        <ExternalLink class="w-3.5 h-3.5 text-slate-400" />
        <span>Buka di Tab Catatan</span>
      </button>
    </header>

    <!-- Canvas Content -->
    <div class="flex-1 overflow-y-auto p-4 md:p-6 lg:p-8 select-text">
      <!-- ============================================== -->
      <!-- TAB 1: REAL-WORLD MOCKUPS                      -->
      <!-- ============================================== -->
      {#if activeTab === 'mockup'}
        <div class="w-full max-w-7xl mx-auto space-y-6 lg:space-y-8">
          <!-- Section Header -->
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-1 border-b border-slate-800/80">
            <div>
              <h2 class="text-base font-bold text-slate-100 flex items-center space-x-2">
                <Globe class="w-5 h-5 text-blue-400" />
                <span>Simulasi Tampilan di Berbagai Platform & Browser</span>
              </h2>
              <p class="text-xs text-slate-400 mt-0.5">
                Pratinjau langsung bagaimana ikon Anda tampil di jendela browser desktop, layar ponsel iOS & Android, hingga hasil pencarian Google.
              </p>
            </div>
            <div class="flex items-center space-x-2">
              <span class="inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse mr-1.5"></span>
                27 Ikon Terkonfigurasi
              </span>
            </div>
          </div>

          <!-- 1. FULL WIDTH DESKTOP BROWSER WINDOW MOCKUP -->
          <div class="bg-slate-900 border border-slate-700/80 rounded-2xl overflow-hidden shadow-2xl ring-1 ring-white/5">
            <!-- Browser Chrome: Window Controls & Tab Bar -->
            <div class="bg-slate-950 px-3 pt-2.5 flex items-center space-x-2 border-b border-slate-800">
              <!-- Window Buttons (Mac style) -->
              <div class="flex items-center space-x-2 px-2">
                <div class="w-3 h-3 rounded-full bg-rose-500/80 hover:opacity-80 transition-opacity"></div>
                <div class="w-3 h-3 rounded-full bg-amber-500/80 hover:opacity-80 transition-opacity"></div>
                <div class="w-3 h-3 rounded-full bg-emerald-500/80 hover:opacity-80 transition-opacity"></div>
              </div>

              <!-- Tabs Strip -->
              <div class="flex items-center space-x-1 flex-1 min-w-0 pl-2">
                <!-- Active Tab -->
                <div class="bg-slate-900 border-t border-x border-slate-700/80 rounded-t-xl px-4 py-2 flex items-center space-x-2.5 max-w-sm sm:max-w-md w-full shadow-xs relative -bottom-[1px]">
                  <div class="w-4 h-4 flex-shrink-0 flex items-center justify-center">
                    {#if generatedIcons.find(i => i.width === 32)?.dataUrl}
                      <img src={generatedIcons.find(i => i.width === 32)?.dataUrl} alt="Favicon" class="w-4 h-4 object-contain" />
                    {:else if sourceImageSrc}
                      <img src={sourceImageSrc} alt="Favicon" class="w-4 h-4 object-contain" />
                    {:else}
                      <Globe class="w-4 h-4 text-blue-400" />
                    {/if}
                  </div>
                  <span class="text-xs text-slate-100 font-medium truncate flex-1">{appName || 'Valtera Note'} — Solusi Digital</span>
                  <span class="text-slate-500 hover:text-slate-300 text-xs px-1 cursor-pointer">✕</span>
                </div>

                <!-- Inactive Tab (Background) -->
                <div class="hidden md:flex items-center space-x-2 px-3 py-1.5 text-xs text-slate-500 hover:text-slate-300 rounded-t-lg transition-colors cursor-default max-w-[160px]">
                  <Globe class="w-3.5 h-3.5 text-slate-600 flex-shrink-0" />
                  <span class="truncate">Dokumentasi API</span>
                </div>

                <!-- New Tab (+) -->
                <button class="w-6 h-6 rounded hover:bg-slate-800 text-slate-500 hover:text-slate-300 flex items-center justify-center text-xs transition-colors cursor-default" title="Tab Baru">
                  +
                </button>
              </div>
            </div>

            <!-- Browser Navigation Bar (Omnibar / URL bar) -->
            <div class="bg-slate-900 px-4 py-2.5 border-b border-slate-800 flex items-center space-x-3 text-xs">
              <div class="flex items-center space-x-2 text-slate-500">
                <button class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors" title="Kembali">←</button>
                <button class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors" title="Maju">→</button>
                <button class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors" title="Muat Ulang">↻</button>
              </div>

              <!-- Address / Search Pill -->
              <div class="flex-1 bg-slate-950 border border-slate-800 hover:border-slate-700/80 rounded-full px-3.5 py-1.5 flex items-center space-x-2 text-xs shadow-inner transition-colors">
                <Lock class="w-3.5 h-3.5 text-emerald-400 flex-shrink-0" />
                <span class="text-slate-500">https://</span>
                <span class="text-slate-100 font-semibold truncate">valtera.co.id</span>
                <span class="text-slate-400 truncate">/app/dashboard</span>
                <div class="ml-auto flex items-center space-x-1.5 text-slate-500">
                  <span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 font-mono">27 Assets</span>
                  <Star class="w-3.5 h-3.5 text-amber-400/70" />
                </div>
              </div>
            </div>

            <!-- Browser Bookmarks Bar -->
            <div class="bg-slate-950/60 px-4 py-1.5 border-b border-slate-800/80 flex items-center space-x-4 text-[11px] text-slate-400 overflow-x-auto">
              <!-- Active Pinned Bookmark -->
              <div class="flex items-center space-x-1.5 font-medium text-slate-200 bg-slate-800/80 px-2 py-0.5 rounded border border-slate-700/50 flex-shrink-0">
                {#if generatedIcons.find(i => i.width === 16)?.dataUrl}
                  <img src={generatedIcons.find(i => i.width === 16)?.dataUrl} alt="Favicon" class="w-3.5 h-3.5 object-contain" />
                {:else if sourceImageSrc}
                  <img src={sourceImageSrc} alt="Favicon" class="w-3.5 h-3.5 object-contain" />
                {/if}
                <span>{shortName || appName}</span>
              </div>

              <div class="flex items-center space-x-1.5 text-slate-400 hover:text-slate-200 cursor-pointer flex-shrink-0">
                <span>🌐</span>
                <span>Dashboard</span>
              </div>
              <div class="flex items-center space-x-1.5 text-slate-400 hover:text-slate-200 cursor-pointer flex-shrink-0">
                <span>📚</span>
                <span>Dokumentasi</span>
              </div>
              <div class="flex items-center space-x-1.5 text-slate-400 hover:text-slate-200 cursor-pointer flex-shrink-0">
                <span>⚡</span>
                <span>Fitur Baru</span>
              </div>
            </div>

            <!-- Realistic Webpage Viewport Content Preview -->
            <div class="p-6 md:p-8 bg-slate-950/90 min-h-[220px] flex flex-col justify-between">
              <div class="max-w-3xl space-y-3">
                <div class="inline-flex items-center space-x-2 px-2.5 py-1 rounded-full bg-blue-900/30 border border-blue-500/30 text-blue-400 text-xs font-semibold">
                  <Sparkles class="w-3 h-3" />
                  <span>Ekosistem Favicon Komprehensif</span>
                </div>
                <h3 class="text-xl md:text-2xl font-bold text-white tracking-tight">
                  {appName || 'Valtera Note'}
                </h3>
                <p class="text-xs md:text-sm text-slate-400 leading-relaxed max-w-2xl">
                  Ikon dan metadata web Anda otomatis terkonfigurasi dengan standar modern. Mendukung favicon desktop resolusi ganda, Apple Web Clip, Android Chrome PWA Web App Manifest, dan tile Windows 10/11.
                </p>
              </div>

              <!-- Mini Feature Pills -->
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-6 border-t border-slate-800/80 mt-6">
                <div class="p-3 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center space-x-3">
                  <div class="w-8 h-8 rounded-lg bg-blue-600/20 text-blue-400 flex items-center justify-center font-bold text-xs">
                    16-48
                  </div>
                  <div>
                    <p class="text-xs font-semibold text-slate-200">favicon.ico Multi-Res</p>
                    <p class="text-[10px] text-slate-500">Mendukung browser legacy & modern</p>
                  </div>
                </div>

                <div class="p-3 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center space-x-3">
                  <div class="w-8 h-8 rounded-lg bg-purple-600/20 text-purple-400 flex items-center justify-center font-bold text-xs">
                    180px
                  </div>
                  <div>
                    <p class="text-xs font-semibold text-slate-200">Apple Touch Icon</p>
                    <p class="text-[10px] text-slate-500">iOS Safari, iPad & macOS dock</p>
                  </div>
                </div>

                <div class="p-3 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center space-x-3">
                  <div class="w-8 h-8 rounded-lg bg-emerald-600/20 text-emerald-400 flex items-center justify-center font-bold text-xs">
                    PWA
                  </div>
                  <div>
                    <p class="text-xs font-semibold text-slate-200">Android manifest.json</p>
                    <p class="text-[10px] text-slate-500">Instalasi aplikasi web progresif</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- 2. DEVICE & PLATFORM PREVIEWS (4 EQUAL CARDS) -->
          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
            <!-- CARD 1: iOS HOME SCREEN -->
            <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col justify-between space-y-4 shadow-md hover:border-slate-700 transition-colors">
              <div class="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                <span class="font-bold text-slate-200 flex items-center space-x-1.5">
                  <Smartphone class="w-4 h-4 text-purple-400" />
                  <span>Apple iOS Safari</span>
                </span>
                <span class="text-[10px] font-mono text-purple-400 bg-purple-950/60 px-1.5 py-0.5 rounded border border-purple-800/50">180×180</span>
              </div>

              <!-- iOS Mockup Frame -->
              <div class="h-44 rounded-xl bg-gradient-to-b from-indigo-950/60 via-purple-950/40 to-slate-950 border border-slate-800/80 flex flex-col items-center justify-center p-4 relative overflow-hidden group">
                <div class="absolute w-28 h-28 rounded-full bg-purple-600/10 blur-2xl pointer-events-none"></div>

                <div class="w-20 h-20 rounded-[22px] bg-slate-900/90 border border-white/20 shadow-2xl shadow-purple-900/40 flex items-center justify-center overflow-hidden p-2 z-10 transition-transform group-hover:scale-105">
                  {#if generatedIcons.find(i => i.width === 180)?.dataUrl}
                    <img src={generatedIcons.find(i => i.width === 180)?.dataUrl} alt="Apple Icon" class="w-full h-full object-contain" />
                  {:else if sourceImageSrc}
                    <img src={sourceImageSrc} alt="Apple Icon" class="w-full h-full object-contain" />
                  {/if}
                </div>
                <span class="text-xs font-semibold text-slate-200 mt-2 z-10 tracking-tight drop-shadow-md">{shortName || appName}</span>
              </div>

              <div class="space-y-1 text-[11px] text-slate-400 pt-1">
                <div class="flex items-center justify-between text-slate-300 font-medium">
                  <span>Apple Web Clip</span>
                  <span class="text-slate-500">apple-icon.png</span>
                </div>
                <p class="text-[11px] text-slate-500">Ikon layar beranda iPhone, iPad, serta Safari bookmarks & Siri suggestions.</p>
              </div>
            </div>

            <!-- CARD 2: ANDROID PWA CHROME -->
            <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col justify-between space-y-4 shadow-md hover:border-slate-700 transition-colors">
              <div class="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                <span class="font-bold text-slate-200 flex items-center space-x-1.5">
                  <Smartphone class="w-4 h-4 text-emerald-400" />
                  <span>Android PWA Chrome</span>
                </span>
                <span class="text-[10px] font-mono text-emerald-400 bg-emerald-950/60 px-1.5 py-0.5 rounded border border-emerald-800/50">192×192</span>
              </div>

              <!-- Android Mockup Frame -->
              <div class="h-44 rounded-xl bg-gradient-to-b from-teal-950/60 via-emerald-950/40 to-slate-950 border border-slate-800/80 flex flex-col items-center justify-center p-4 relative overflow-hidden group">
                <div class="absolute w-28 h-28 rounded-full bg-emerald-600/10 blur-2xl pointer-events-none"></div>

                <div class="relative z-10">
                  <div class="w-20 h-20 rounded-full bg-slate-900/90 border border-white/20 shadow-2xl shadow-emerald-900/40 flex items-center justify-center overflow-hidden p-3 transition-transform group-hover:scale-105">
                    {#if generatedIcons.find(i => i.width === 192)?.dataUrl}
                      <img src={generatedIcons.find(i => i.width === 192)?.dataUrl} alt="Android Icon" class="w-full h-full object-contain" />
                    {:else if sourceImageSrc}
                      <img src={sourceImageSrc} alt="Android Icon" class="w-full h-full object-contain" />
                    {/if}
                  </div>
                  <!-- Chrome mini badge -->
                  <div class="absolute bottom-0 right-0 w-6 h-6 rounded-full bg-slate-900 border-2 border-slate-950 flex items-center justify-center shadow-md">
                    <Globe class="w-3.5 h-3.5 text-emerald-400" />
                  </div>
                </div>
                <span class="text-xs font-semibold text-slate-200 mt-2 z-10 tracking-tight drop-shadow-md">{shortName || appName}</span>
              </div>

              <div class="space-y-1 text-[11px] text-slate-400 pt-1">
                <div class="flex items-center justify-between text-slate-300 font-medium">
                  <span>Web App Manifest</span>
                  <span class="text-slate-500">manifest.json</span>
                </div>
                <p class="text-[11px] text-slate-500">Digunakan untuk Add to Homescreen, Splash Screen PWA, dan App Switcher Android.</p>
              </div>
            </div>

            <!-- CARD 3: GOOGLE SERP SEARCH RESULT -->
            <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col justify-between space-y-4 shadow-md hover:border-slate-700 transition-colors">
              <div class="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                <span class="font-bold text-slate-200 flex items-center space-x-1.5">
                  <Search class="w-4 h-4 text-blue-400" />
                  <span>Google SERP Preview</span>
                </span>
                <span class="text-[10px] font-mono text-blue-400 bg-blue-950/60 px-1.5 py-0.5 rounded border border-blue-800/50">Google SEO</span>
              </div>

              <!-- Google SERP Card -->
              <div class="h-44 rounded-xl bg-slate-950 border border-slate-800/80 p-3.5 flex flex-col justify-center space-y-2 relative overflow-hidden">
                <!-- Breadcrumb with Favicon -->
                <div class="flex items-center space-x-2">
                  <div class="w-7 h-7 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center overflow-hidden flex-shrink-0 p-1 shadow-inner">
                    {#if generatedIcons.find(i => i.width === 32)?.dataUrl}
                      <img src={generatedIcons.find(i => i.width === 32)?.dataUrl} alt="Favicon SERP" class="w-4 h-4 object-contain" />
                    {:else if sourceImageSrc}
                      <img src={sourceImageSrc} alt="Favicon SERP" class="w-4 h-4 object-contain" />
                    {/if}
                  </div>
                  <div class="min-w-0 flex-1 leading-tight">
                    <span class="text-xs font-semibold text-slate-200 truncate block">{appName || 'Valtera Note'}</span>
                    <span class="text-[10px] text-slate-400 truncate block">https://valtera.co.id › app</span>
                  </div>
                  <span class="text-slate-600 text-xs">⋮</span>
                </div>

                <!-- Title link -->
                <p class="text-xs font-bold text-blue-400 hover:underline cursor-pointer line-clamp-1">
                  {appName} - Platform Aplikasi Web & Produktivitas
                </p>

                <!-- Snippet text -->
                <p class="text-[10px] text-slate-400 leading-snug line-clamp-2">
                  Solusi modern dengan performa tinggi. Ikon favicon siap tampil tajam di hasil pencarian Google desktop dan mobile.
                </p>
              </div>

              <div class="space-y-1 text-[11px] text-slate-400 pt-1">
                <div class="flex items-center justify-between text-slate-300 font-medium">
                  <span>Google Search Result</span>
                  <span class="text-slate-500">favicon-32x32</span>
                </div>
                <p class="text-[11px] text-slate-500">Ikon Google Search Engine otomatis terindeks dari tag favicon standar.</p>
              </div>
            </div>

            <!-- CARD 4: WINDOWS LIVE TILE & TASKBAR -->
            <div class="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col justify-between space-y-4 shadow-md hover:border-slate-700 transition-colors">
              <div class="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                <span class="font-bold text-slate-200 flex items-center space-x-1.5">
                  <Laptop class="w-4 h-4 text-cyan-400" />
                  <span>Windows 10/11 & Edge</span>
                </span>
                <span class="text-[10px] font-mono text-cyan-400 bg-cyan-950/60 px-1.5 py-0.5 rounded border border-cyan-800/50">150×150</span>
              </div>

              <!-- Windows Mockup Frame -->
              <div class="h-44 rounded-xl bg-slate-950 border border-slate-800/80 p-3 flex flex-col justify-between relative overflow-hidden group">
                <!-- Windows Start Tile -->
                <div class="flex items-center justify-center flex-1">
                  <div class="w-20 h-20 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-sm shadow-xl p-2 flex flex-col items-center justify-center relative transition-transform group-hover:scale-105">
                    {#if generatedIcons.find(i => i.width === 150)?.dataUrl}
                      <img src={generatedIcons.find(i => i.width === 150)?.dataUrl} alt="MS Icon" class="w-10 h-10 object-contain drop-shadow" />
                    {:else if sourceImageSrc}
                      <img src={sourceImageSrc} alt="MS Icon" class="w-10 h-10 object-contain drop-shadow" />
                    {/if}
                    <span class="text-[9px] text-white/95 font-semibold absolute bottom-1 left-1.5 truncate max-w-[70px]">{shortName || appName}</span>
                  </div>
                </div>

                <!-- Windows Taskbar Strip Preview -->
                <div class="bg-slate-900/90 border border-slate-800 rounded-lg px-2.5 py-1 flex items-center space-x-2 text-xs">
                  <div class="w-3.5 h-3.5 text-blue-400 font-bold flex items-center justify-center">⊞</div>
                  <div class="h-3 w-[1px] bg-slate-700"></div>
                  <!-- Pinned app icon on taskbar -->
                  <div class="relative flex flex-col items-center px-1.5 py-0.5 bg-slate-800/90 rounded">
                    {#if generatedIcons.find(i => i.width === 32)?.dataUrl}
                      <img src={generatedIcons.find(i => i.width === 32)?.dataUrl} alt="Taskbar" class="w-4 h-4 object-contain" />
                    {:else if sourceImageSrc}
                      <img src={sourceImageSrc} alt="Taskbar" class="w-4 h-4 object-contain" />
                    {/if}
                    <div class="w-3 h-0.5 rounded-full bg-blue-400 mt-0.5"></div>
                  </div>
                  <div class="text-[10px] text-slate-500 font-mono ml-auto">Taskbar</div>
                </div>
              </div>

              <div class="space-y-1 text-[11px] text-slate-400 pt-1">
                <div class="flex items-center justify-between text-slate-300 font-medium">
                  <span>Microsoft browserconfig</span>
                  <span class="text-slate-500">ms-icon</span>
                </div>
                <p class="text-[11px] text-slate-500">Mendukung pinned sites Microsoft Edge dan Windows Start Menu live tiles.</p>
              </div>
            </div>
          </div>
        </div>

      <!-- ============================================== -->
      <!-- TAB 2: ALL 27 ASSET FILES                      -->
      <!-- ============================================== -->
      {:else if activeTab === 'assets'}
        <div class="w-full max-w-7xl mx-auto space-y-6 lg:space-y-8">
          <!-- Assets Header -->
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-800/80">
            <div>
              <h2 class="text-base font-bold text-slate-100 flex items-center space-x-2">
                <Layers class="w-5 h-5 text-blue-400" />
                <span>Daftar Lengkap 27 Berkas Favicon Siap Pakai</span>
              </h2>
              <p class="text-xs text-slate-400 mt-0.5">
                Semua berkas dioptimalkan otomatis untuk standar W3C, Apple iOS, Google Android PWA, dan Microsoft Windows.
              </p>
            </div>
            <button 
              onclick={handleDownloadAllZip}
              disabled={isGenerating || generatedIcons.length === 0}
              class="px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white text-xs font-bold flex items-center space-x-2 transition-all cursor-pointer shadow-lg shadow-blue-500/20 flex-shrink-0 self-start sm:self-auto disabled:opacity-40"
            >
              <Download class="w-4 h-4" />
              <span>Unduh Paket ZIP (27 Berkas)</span>
            </button>
          </div>

          <!-- Groups -->
          <!-- 1. Standard Browser & ICO -->
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <h3 class="text-xs font-bold text-blue-400 uppercase tracking-wider flex items-center space-x-1.5">
                <span>Favicon Browser Standar & Multi-Resolution ICO</span>
              </h3>
              <span class="text-[11px] text-slate-500 font-mono">4 Berkas</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3.5">
              <!-- Special favicon.ico card -->
              <div class="p-3 bg-slate-900/90 border border-blue-500/50 hover:border-blue-400 rounded-xl flex flex-col justify-between group transition-all shadow-md shadow-blue-500/5 relative overflow-hidden">
                <div class="absolute top-1.5 right-1.5">
                  <span class="text-[9px] font-bold px-1.5 py-0.5 rounded bg-blue-600/30 text-blue-300 border border-blue-500/40">ICO</span>
                </div>

                <div 
                  class="h-20 w-full rounded-lg bg-slate-950 border border-slate-800/80 flex items-center justify-center p-2 mb-2.5 relative group-hover:border-slate-700 transition-colors"
                  style="background-image: radial-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 0); background-size: 8px 8px;"
                >
                  {#if generatedIcons.find(i => i.width === 32)?.dataUrl}
                    <img src={generatedIcons.find(i => i.width === 32)?.dataUrl} alt="favicon.ico" class="max-h-12 max-w-12 object-contain transition-transform group-hover:scale-110" />
                  {/if}
                </div>

                <div>
                  <p class="text-xs font-bold text-slate-100 truncate" title="favicon.ico">favicon.ico</p>
                  <p class="text-[10px] text-emerald-400 font-mono mt-0.5">16, 32, 48px</p>
                </div>

                <div class="mt-2.5 pt-2 border-t border-slate-800 flex items-center justify-between">
                  <span class="text-[10px] text-slate-500">Binary ICO</span>
                  {#if icoBlob}
                    <button 
                      onclick={() => icoBlob && handleDownloadSingleFile('favicon.ico', icoBlob)}
                      class="p-1 rounded bg-slate-800 hover:bg-blue-600 text-slate-300 hover:text-white transition-colors cursor-pointer"
                      title="Unduh favicon.ico"
                    >
                      <Download class="w-3.5 h-3.5" />
                    </button>
                  {/if}
                </div>
              </div>

              {#each generatedIcons.filter(i => i.category === 'browser') as icon}
                <div class="p-3 bg-slate-900/90 border border-slate-800 hover:border-slate-700 rounded-xl flex flex-col justify-between group transition-all shadow-xs">
                  <div 
                    class="h-20 w-full rounded-lg bg-slate-950 border border-slate-800/80 flex items-center justify-center p-2 mb-2.5 relative group-hover:border-slate-700 transition-colors"
                    style="background-image: radial-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 0); background-size: 8px 8px;"
                  >
                    {#if icon.dataUrl}
                      <img src={icon.dataUrl} alt={icon.name} class="max-h-12 max-w-12 object-contain transition-transform group-hover:scale-110" />
                    {/if}
                  </div>

                  <div>
                    <p class="text-xs font-semibold text-slate-200 truncate" title={icon.name}>{icon.name}</p>
                    <p class="text-[10px] text-slate-500 font-mono mt-0.5">{icon.width} × {icon.height} px</p>
                  </div>

                  <div class="mt-2.5 pt-2 border-t border-slate-800/80 flex items-center justify-between">
                    <span class="text-[10px] text-slate-500 uppercase font-mono">PNG</span>
                    {#if icon.blob}
                      <button 
                        onclick={() => icon.blob && handleDownloadSingleFile(icon.name, icon.blob)}
                        class="p-1 rounded bg-slate-800 hover:bg-blue-600 text-slate-300 hover:text-white transition-colors cursor-pointer"
                        title="Unduh {icon.name}"
                      >
                        <Download class="w-3.5 h-3.5" />
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <!-- 2. Android PWA Icons -->
          <div class="space-y-3 pt-4 border-t border-slate-800/80">
            <div class="flex items-center justify-between">
              <h3 class="text-xs font-bold text-emerald-400 uppercase tracking-wider">
                Android Chrome & PWA Icons
              </h3>
              <span class="text-[11px] text-slate-500 font-mono">6 Berkas</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3.5">
              {#each generatedIcons.filter(i => i.category === 'android') as icon}
                <div class="p-3 bg-slate-900/90 border border-slate-800 hover:border-slate-700 rounded-xl flex flex-col justify-between group transition-all shadow-xs">
                  <div 
                    class="h-20 w-full rounded-lg bg-slate-950 border border-slate-800/80 flex items-center justify-center p-2 mb-2.5 relative group-hover:border-slate-700 transition-colors"
                    style="background-image: radial-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 0); background-size: 8px 8px;"
                  >
                    {#if icon.dataUrl}
                      <img src={icon.dataUrl} alt={icon.name} class="max-h-14 max-w-14 object-contain transition-transform group-hover:scale-110" />
                    {/if}
                  </div>

                  <div>
                    <p class="text-xs font-semibold text-slate-200 truncate" title={icon.name}>{icon.name}</p>
                    <p class="text-[10px] text-slate-500 font-mono mt-0.5">{icon.width} × {icon.height} px</p>
                  </div>

                  <div class="mt-2.5 pt-2 border-t border-slate-800/80 flex items-center justify-between">
                    <span class="text-[10px] text-slate-500 uppercase font-mono">Android</span>
                    {#if icon.blob}
                      <button 
                        onclick={() => icon.blob && handleDownloadSingleFile(icon.name, icon.blob)}
                        class="p-1 rounded bg-slate-800 hover:bg-emerald-600 text-slate-300 hover:text-white transition-colors cursor-pointer"
                        title="Unduh {icon.name}"
                      >
                        <Download class="w-3.5 h-3.5" />
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <!-- 3. Apple Touch Icons -->
          <div class="space-y-3 pt-4 border-t border-slate-800/80">
            <div class="flex items-center justify-between">
              <h3 class="text-xs font-bold text-purple-400 uppercase tracking-wider">
                Apple Touch Icons (iOS & macOS)
              </h3>
              <span class="text-[11px] text-slate-500 font-mono">11 Berkas</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3.5">
              {#each generatedIcons.filter(i => i.category === 'apple') as icon}
                <div class="p-3 bg-slate-900/90 border border-slate-800 hover:border-slate-700 rounded-xl flex flex-col justify-between group transition-all shadow-xs">
                  <div 
                    class="h-20 w-full rounded-lg bg-slate-950 border border-slate-800/80 flex items-center justify-center p-2 mb-2.5 relative group-hover:border-slate-700 transition-colors"
                    style="background-image: radial-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 0); background-size: 8px 8px;"
                  >
                    {#if icon.dataUrl}
                      <img src={icon.dataUrl} alt={icon.name} class="max-h-14 max-w-14 object-contain transition-transform group-hover:scale-110" />
                    {/if}
                  </div>

                  <div>
                    <p class="text-xs font-semibold text-slate-200 truncate" title={icon.name}>{icon.name}</p>
                    <p class="text-[10px] text-slate-500 font-mono mt-0.5">{icon.width} × {icon.height} px</p>
                  </div>

                  <div class="mt-2.5 pt-2 border-t border-slate-800/80 flex items-center justify-between">
                    <span class="text-[10px] text-slate-500 uppercase font-mono">Apple</span>
                    {#if icon.blob}
                      <button 
                        onclick={() => icon.blob && handleDownloadSingleFile(icon.name, icon.blob)}
                        class="p-1 rounded bg-slate-800 hover:bg-purple-600 text-slate-300 hover:text-white transition-colors cursor-pointer"
                        title="Unduh {icon.name}"
                      >
                        <Download class="w-3.5 h-3.5" />
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <!-- 4. Windows Microsoft Tiles -->
          <div class="space-y-3 pt-4 border-t border-slate-800/80">
            <div class="flex items-center justify-between">
              <h3 class="text-xs font-bold text-cyan-400 uppercase tracking-wider">
                Microsoft Windows Start Tiles
              </h3>
              <span class="text-[11px] text-slate-500 font-mono">4 Berkas</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
              {#each generatedIcons.filter(i => i.category === 'ms') as icon}
                <div class="p-3 bg-slate-900/90 border border-slate-800 hover:border-slate-700 rounded-xl flex flex-col justify-between group transition-all shadow-xs">
                  <div 
                    class="h-20 w-full rounded-lg bg-slate-950 border border-slate-800/80 flex items-center justify-center p-2 mb-2.5 relative group-hover:border-slate-700 transition-colors"
                    style="background-image: radial-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 0); background-size: 8px 8px;"
                  >
                    {#if icon.dataUrl}
                      <img src={icon.dataUrl} alt={icon.name} class="max-h-14 max-w-14 object-contain transition-transform group-hover:scale-110" />
                    {/if}
                  </div>

                  <div>
                    <p class="text-xs font-semibold text-slate-200 truncate" title={icon.name}>{icon.name}</p>
                    <p class="text-[10px] text-slate-500 font-mono mt-0.5">{icon.width} × {icon.height} px</p>
                  </div>

                  <div class="mt-2.5 pt-2 border-t border-slate-800/80 flex items-center justify-between">
                    <span class="text-[10px] text-slate-500 uppercase font-mono">Windows</span>
                    {#if icon.blob}
                      <button 
                        onclick={() => icon.blob && handleDownloadSingleFile(icon.name, icon.blob)}
                        class="p-1 rounded bg-slate-800 hover:bg-cyan-600 text-slate-300 hover:text-white transition-colors cursor-pointer"
                        title="Unduh {icon.name}"
                      >
                        <Download class="w-3.5 h-3.5" />
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <!-- 5. Configuration Files -->
          <div class="space-y-3 pt-4 border-t border-slate-800/80">
            <div class="flex items-center justify-between">
              <h3 class="text-xs font-bold text-amber-400 uppercase tracking-wider">
                Berkas Konfigurasi Web & PWA
              </h3>
              <span class="text-[11px] text-slate-500 font-mono">2 Berkas</span>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="p-4 bg-slate-900 border border-slate-800 rounded-xl flex items-center justify-between shadow-xs">
                <div>
                  <p class="text-sm font-bold text-slate-100">manifest.json</p>
                  <p class="text-xs text-slate-400 mt-0.5">Web App Manifest standar untuk Android & PWA</p>
                </div>
                <button 
                  onclick={handleCopyManifest}
                  class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-colors cursor-pointer flex items-center space-x-1.5"
                >
                  <Copy class="w-3.5 h-3.5 text-purple-400" />
                  <span>Salin JSON</span>
                </button>
              </div>

              <div class="p-4 bg-slate-900 border border-slate-800 rounded-xl flex items-center justify-between shadow-xs">
                <div>
                  <p class="text-sm font-bold text-slate-100">browserconfig.xml</p>
                  <p class="text-xs text-slate-400 mt-0.5">Konfigurasi XML untuk Windows Start Menu Tiles</p>
                </div>
                <button 
                  onclick={() => {
                    navigator.clipboard.writeText(browserconfigSnippet);
                    showToast('browserconfig.xml tersalin!');
                  }}
                  class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-colors cursor-pointer flex items-center space-x-1.5"
                >
                  <Copy class="w-3.5 h-3.5 text-cyan-400" />
                  <span>Salin XML</span>
                </button>
              </div>
            </div>
          </div>
        </div>

      <!-- ============================================== -->
      <!-- TAB 3: HTML CODE & MANIFEST                    -->
      <!-- ============================================== -->
      {:else}
        <div class="w-full max-w-7xl mx-auto space-y-6 lg:space-y-8">
          <!-- Section Header -->
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-800/80">
            <div>
              <h2 class="text-base font-bold text-slate-100 flex items-center space-x-2">
                <Code class="w-5 h-5 text-emerald-400" />
                <span>Kode HTML &lt;head&gt; & Konfigurasi Ekosistem</span>
              </h2>
              <p class="text-xs text-slate-400 mt-0.5">
                Salin dan tempelkan blok kode ini di dalam tag &lt;head&gt; halaman web Anda agar seluruh 27 favicon otomatis terhubung.
              </p>
            </div>
            <div class="flex items-center space-x-2 flex-shrink-0">
              <button 
                onclick={handleExportHtmlToNewTab}
                class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-medium transition-colors cursor-pointer flex items-center space-x-1.5"
                title="Buka kode di tab editor baru"
              >
                <ExternalLink class="w-3.5 h-3.5 text-blue-400" />
                <span>Buka di Tab Baru</span>
              </button>
              <button 
                onclick={handleCopyHtml}
                class="px-3.5 py-1.5 rounded-lg bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer shadow-xs"
              >
                <Copy class="w-3.5 h-3.5 text-emerald-400" />
                <span>Salin Kode HTML</span>
              </button>
            </div>
          </div>

          <!-- HTML Snippet Box -->
          <div class="relative bg-slate-900/80 border border-slate-800 rounded-2xl overflow-hidden shadow-xl ring-1 ring-white/5">
            <div class="h-9 px-4 bg-slate-950/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-400">
              <div class="flex items-center space-x-2 font-mono">
                <span class="w-2.5 h-2.5 rounded-full bg-slate-700"></span>
                <span>index.html &lt;head&gt;</span>
              </div>
              <span class="text-[11px] text-slate-500">HTML5 Web Standards</span>
            </div>
            <pre class="p-5 font-mono text-xs text-slate-200 leading-relaxed overflow-x-auto whitespace-pre select-text">{htmlSnippet}</pre>
          </div>

          <!-- Manifest & Browserconfig Snippet Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 pt-2">
            <!-- Manifest Box -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-xs font-bold text-slate-200">Isi Berkas manifest.json</h3>
                  <p class="text-[11px] text-slate-400">Diletakkan di root atau folder public bersama ikon.</p>
                </div>
                <button 
                  onclick={handleCopyManifest}
                  class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                >
                  <Copy class="w-3 h-3 text-purple-400" />
                  <span>Salin Manifest</span>
                </button>
              </div>
              <div class="bg-slate-900/80 border border-slate-800 rounded-xl overflow-hidden shadow-inner">
                <pre class="p-4 font-mono text-xs text-slate-300 leading-relaxed overflow-x-auto whitespace-pre max-h-[300px] select-text">{manifestSnippet}</pre>
              </div>
            </div>

            <!-- Browserconfig Box -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-xs font-bold text-slate-200">Isi Berkas browserconfig.xml</h3>
                  <p class="text-[11px] text-slate-400">Konfigurasi XML untuk Windows Start tiles.</p>
                </div>
                <button 
                  onclick={() => {
                    navigator.clipboard.writeText(browserconfigSnippet);
                    showToast('browserconfig.xml tersalin!');
                  }}
                  class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                >
                  <Copy class="w-3 h-3 text-cyan-400" />
                  <span>Salin XML</span>
                </button>
              </div>
              <div class="bg-slate-900/80 border border-slate-800 rounded-xl overflow-hidden shadow-inner">
                <pre class="p-4 font-mono text-xs text-slate-300 leading-relaxed overflow-x-auto whitespace-pre max-h-[300px] select-text">{browserconfigSnippet}</pre>
              </div>
            </div>
          </div>

          <!-- Quick Setup Guide -->
          <div class="p-5 bg-slate-900/40 border border-slate-800/90 rounded-2xl space-y-3">
            <h4 class="text-xs font-bold text-slate-200 uppercase tracking-wider flex items-center space-x-2">
              <Sparkles class="w-4 h-4 text-amber-400" />
              <span>Panduan Penempatan Berkas di Berbagai Framework</span>
            </h4>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
              <div class="p-3 bg-slate-950/60 rounded-xl border border-slate-800/80 space-y-1">
                <p class="font-semibold text-blue-400">Vite / Svelte / React</p>
                <p class="text-slate-400 text-[11px]">
                  Ekstrak semua berkas dari ZIP langsung ke dalam folder <code class="text-slate-200 bg-slate-800 px-1 py-0.5 rounded">/public/</code>.
                </p>
              </div>

              <div class="p-3 bg-slate-950/60 rounded-xl border border-slate-800/80 space-y-1">
                <p class="font-semibold text-purple-400">Next.js / Astro</p>
                <p class="text-slate-400 text-[11px]">
                  Letakkan seluruh berkas ke folder <code class="text-slate-200 bg-slate-800 px-1 py-0.5 rounded">/public/</code> agar dapat diakses dari root domain.
                </p>
              </div>

              <div class="p-3 bg-slate-950/60 rounded-xl border border-slate-800/80 space-y-1">
                <p class="font-semibold text-emerald-400">HTML Tradisional</p>
                <p class="text-slate-400 text-[11px]">
                  Letakkan semua berkas di direktori utama yang sejajar dengan berkas <code class="text-slate-200 bg-slate-800 px-1 py-0.5 rounded">index.html</code>.
                </p>
              </div>
            </div>
          </div>
        </div>
      {/if}
    </div>
  </main>

  <!-- Toast Notification -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2.5 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400 flex-shrink-0" />
      <span class="font-medium">{copiedToast}</span>
    </div>
  {/if}

  <!-- Global Drag and Drop Active Overlay -->
  {#if isDragging}
    <div class="pointer-events-none absolute inset-0 z-50 bg-slate-950/75 backdrop-blur-xs flex flex-col items-center justify-center p-6 text-center animate-in fade-in duration-100">
      <div class="p-8 rounded-2xl border-2 border-dashed border-blue-400 bg-blue-950/60 shadow-2xl flex flex-col items-center space-y-3 max-w-sm w-full">
        <div class="w-16 h-16 rounded-2xl bg-blue-600 text-white flex items-center justify-center shadow-lg animate-bounce">
          <Upload class="w-8 h-8" />
        </div>
        <div class="space-y-1">
          <p class="text-base font-bold text-slate-100">Jatuhkan Gambar ke Sini</p>
          <p class="text-xs text-blue-300">Format PNG, SVG, JPG, atau WebP</p>
        </div>
      </div>
    </div>
  {/if}
</div>
