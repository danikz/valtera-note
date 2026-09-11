<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    Key, 
    RefreshCw, 
    Copy, 
    Check, 
    Eye, 
    EyeOff, 
    Database, 
    ShieldCheck, 
    Terminal, 
    Sliders, 
    Sparkles, 
    Code, 
    FileText, 
    Layers, 
    CheckCircle2, 
    AlertTriangle,
    Info
  } from 'lucide-svelte';

  // Character sets
  const UPPERCASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const LOWERCASE = 'abcdefghijklmnopqrstuvwxyz';
  const NUMBERS = '0123456789';
  // MySQL Safe symbols: do NOT break SQL quotes (', "), backticks, backslashes, semicolons, or URI components (@, :, /, ?, #, %)
  const MYSQL_SAFE_SYMBOLS = '!$^*_+-=.,~';
  // Full symbols for users wanting maximum entropy
  const ALL_SYMBOLS = '!@#$%^&*()_+-=[]{}|;:,.<>?~';
  // Ambiguous characters
  const AMBIGUOUS = '0O1Il|';

  // Options state
  let length = $state<number>(24);
  let useUpper = $state(true);
  let useLower = $state(true);
  let useNumbers = $state(true);
  let useSymbols = $state(true);
  let symbolMode = $state<'mysql-safe' | 'all'>('mysql-safe');
  let excludeAmbiguous = $state(true);
  let presetMode = $state<'mysql-safe' | 'alphanumeric' | 'high-security' | 'custom'>('mysql-safe');

  // Generator state
  let generatedPassword = $state('');
  let showPassword = $state(true);
  let copiedToast = $state<string | null>(null);

  // Active sub-tab
  let activeTab = $state<'single' | 'sql' | 'env' | 'batch'>('single');

  // SQL & Config generator helper state
  let sqlUsername = $state('valtera_user');
  let sqlHost = $state('%');
  let sqlDatabase = $state('valtera_db');

  // Batch generator state
  let batchCount = $state(5);
  let batchPasswords = $state<string[]>([]);

  function applyPreset(preset: 'mysql-safe' | 'alphanumeric' | 'high-security') {
    presetMode = preset;
    if (preset === 'mysql-safe') {
      length = 24;
      useUpper = true;
      useLower = true;
      useNumbers = true;
      useSymbols = true;
      symbolMode = 'mysql-safe';
      excludeAmbiguous = true;
    } else if (preset === 'alphanumeric') {
      length = 24;
      useUpper = true;
      useLower = true;
      useNumbers = true;
      useSymbols = false;
      excludeAmbiguous = true;
    } else if (preset === 'high-security') {
      length = 32;
      useUpper = true;
      useLower = true;
      useNumbers = true;
      useSymbols = true;
      symbolMode = 'all';
      excludeAmbiguous = false;
    }
    generate();
  }

  function getAvailableCharset(): string {
    let chars = '';
    if (useUpper) chars += UPPERCASE;
    if (useLower) chars += LOWERCASE;
    if (useNumbers) chars += NUMBERS;
    if (useSymbols) {
      chars += (symbolMode === 'mysql-safe' ? MYSQL_SAFE_SYMBOLS : ALL_SYMBOLS);
    }
    if (excludeAmbiguous) {
      chars = chars.split('').filter(c => !AMBIGUOUS.includes(c)).join('');
    }
    return chars || (UPPERCASE + LOWERCASE + NUMBERS);
  }

  function generateSecureRandomPassword(len: number): string {
    const charset = getAvailableCharset();
    const array = new Uint32Array(len);
    window.crypto.getRandomValues(array);
    let result = '';
    for (let i = 0; i < len; i++) {
      result += charset[array[i] % charset.length];
    }
    return result;
  }

  function generate() {
    generatedPassword = generateSecureRandomPassword(length);
    if (activeTab === 'batch') {
      generateBatch();
    }
  }

  function generateBatch() {
    const list: string[] = [];
    for (let i = 0; i < batchCount; i++) {
      list.push(generateSecureRandomPassword(length));
    }
    batchPasswords = list;
  }

  // Password analysis
  let passwordStats = $derived.by(() => {
    const pwd = generatedPassword;
    if (!pwd) return { entropy: 0, strength: 'none', label: '-', color: 'bg-slate-700', text: 'text-slate-500', uCount: 0, lCount: 0, nCount: 0, sCount: 0 };

    const charsetSize = getAvailableCharset().length;
    const entropy = Math.round(pwd.length * Math.log2(Math.max(charsetSize, 2)));

    let strength: 'weak' | 'medium' | 'strong' | 'very-strong' = 'weak';
    let label = 'Lemah';
    let color = 'bg-red-500';
    let text = 'text-red-400';

    if (entropy >= 128) {
      strength = 'very-strong';
      label = 'Sangat Kuat (Standar Enterprise / Root)';
      color = 'bg-emerald-500';
      text = 'text-emerald-400';
    } else if (entropy >= 80) {
      strength = 'strong';
      label = 'Kuat (Aman untuk Database Production)';
      color = 'bg-blue-500';
      text = 'text-blue-400';
    } else if (entropy >= 50) {
      strength = 'medium';
      label = 'Sedang (Cukup untuk Database Dev)';
      color = 'bg-amber-500';
      text = 'text-amber-400';
    } else {
      strength = 'weak';
      label = 'Rentan (Terlalu Pendek)';
      color = 'bg-red-500';
      text = 'text-red-400';
    }

    const uCount = (pwd.match(/[A-Z]/g) || []).length;
    const lCount = (pwd.match(/[a-z]/g) || []).length;
    const nCount = (pwd.match(/[0-9]/g) || []).length;
    const sCount = pwd.length - uCount - lCount - nCount;

    return {
      entropy,
      strength,
      label,
      color,
      text,
      uCount,
      lCount,
      nCount,
      sCount
    };
  });

  async function copyToClipboard(text: string, label: string = 'Password tersalin!') {
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      copiedToast = label;
      setTimeout(() => {
        if (copiedToast === label) copiedToast = null;
      }, 2000);
    } catch (err) {
      console.warn('Clipboard write error:', err);
    }
  }

  // Generate when component mounts
  onMount(() => {
    generate();
  });
</script>

<div class="h-full w-full flex flex-col bg-slate-950 text-slate-100 overflow-hidden select-none">
  <!-- Main Scrollable Area -->
  <div class="flex-1 overflow-y-auto p-4 md:p-6 flex flex-col items-center">
    <div class="w-full max-w-5xl space-y-6">

      <!-- Header & Intro -->
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-slate-800">
        <div class="space-y-1">
          <div class="flex items-center space-x-2">
            <div class="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400 shadow-xs">
              <Database class="w-4 h-4" />
            </div>
            <h2 class="text-lg font-bold text-white tracking-tight">MySQL & Database Password Generator</h2>
            <span class="px-2 py-0.5 text-[11px] font-mono rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-medium">
              MySQL Connection Safe
            </span>
          </div>
          <p class="text-xs text-slate-400 leading-relaxed max-w-2xl">
            Menghasilkan password kriptografi acak yang dijamin <strong>tidak akan merusak koneksi MySQL</strong>, string <code class="text-slate-300">DATABASE_URL</code>, atau script SQL (bebas kutip tunggal, ganda, backslash, dan simbol pemisah URL).
          </p>
        </div>

        <!-- Quick Presets -->
        <div class="flex items-center gap-1.5 bg-slate-900 border border-slate-800 p-1 rounded-xl">
          <button 
            onclick={() => applyPreset('mysql-safe')}
            class="px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors cursor-pointer {presetMode === 'mysql-safe' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
          >
            MySQL Safe (Rekomendasi)
          </button>
          <button 
            onclick={() => applyPreset('alphanumeric')}
            class="px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors cursor-pointer {presetMode === 'alphanumeric' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
          >
            Alphanumeric Only
          </button>
          <button 
            onclick={() => applyPreset('high-security')}
            class="px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors cursor-pointer {presetMode === 'high-security' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
          >
            DBA / Root 32-bit
          </button>
        </div>
      </div>

      <!-- Hero Generated Password Display -->
      <div class="bg-gradient-to-b from-slate-900 to-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-2xl space-y-4">
        <div class="flex items-center justify-between">
          <span class="text-xs font-mono font-medium text-slate-400 uppercase tracking-wider flex items-center space-x-1.5">
            <Key class="w-3.5 h-3.5 text-blue-400" />
            <span>Hasil Password Database</span>
          </span>

          <div class="flex items-center space-x-2">
            <button 
              onclick={() => showPassword = !showPassword}
              class="p-1.5 rounded-lg bg-slate-800/80 hover:bg-slate-800 text-slate-400 hover:text-white text-xs flex items-center space-x-1 cursor-pointer transition-colors"
              title={showPassword ? 'Sembunyikan password' : 'Tampilkan password'}
            >
              {#if showPassword}
                <EyeOff class="w-3.5 h-3.5" />
                <span class="text-[11px]">Sembunyikan</span>
              {:else}
                <Eye class="w-3.5 h-3.5" />
                <span class="text-[11px]">Tampilkan</span>
              {/if}
            </button>
          </div>
        </div>

        <!-- Password String Box -->
        <div class="relative flex items-center bg-slate-950 border border-slate-800 rounded-xl px-4 py-3.5 focus-within:border-blue-500 transition-colors shadow-inner">
          <input 
            type={showPassword ? 'text' : 'password'} 
            readonly 
            value={generatedPassword}
            class="w-full bg-transparent font-mono text-base md:text-xl font-bold tracking-wider text-blue-300 focus:outline-none select-all pr-24"
          />

          <!-- Action Buttons in Input -->
          <div class="absolute right-2 flex items-center space-x-1.5">
            <button 
              onclick={generate}
              class="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all cursor-pointer shadow-xs active:scale-95"
              title="Acak ulang password (Generate New)"
            >
              <RefreshCw class="w-4 h-4" />
            </button>

            <button 
              onclick={() => copyToClipboard(generatedPassword, 'Password berhasil disalin!')}
              class="px-3 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1.5 transition-all cursor-pointer shadow-md shadow-blue-900/30 active:scale-95"
              title="Salin password ke clipboard"
            >
              {#if copiedToast === 'Password berhasil disalin!'}
                <Check class="w-4 h-4 text-emerald-300" />
                <span>Tersalin!</span>
              {:else}
                <Copy class="w-4 h-4" />
                <span>Salin Password</span>
              {/if}
            </button>
          </div>
        </div>

        <!-- Strength Meter & Breakdown -->
        <div class="space-y-2 pt-1">
          <div class="flex items-center justify-between text-xs">
            <div class="flex items-center space-x-2">
              <span class="text-slate-400">Tingkat Keamanan:</span>
              <span class="font-semibold {passwordStats.text}">{passwordStats.label}</span>
            </div>
            <div class="flex items-center space-x-2 font-mono text-[11px] text-slate-400">
              <span>{length} karakter</span>
              <span>•</span>
              <span>{passwordStats.entropy} bits entropy</span>
            </div>
          </div>

          <!-- Strength Bar -->
          <div class="w-full h-1.5 bg-slate-950 rounded-full overflow-hidden flex gap-1 p-0.5">
            <div class="h-full rounded-full transition-all duration-300 {passwordStats.entropy >= 40 ? passwordStats.color : 'bg-slate-800'} w-1/4"></div>
            <div class="h-full rounded-full transition-all duration-300 {passwordStats.entropy >= 70 ? passwordStats.color : 'bg-slate-800'} w-1/4"></div>
            <div class="h-full rounded-full transition-all duration-300 {passwordStats.entropy >= 100 ? passwordStats.color : 'bg-slate-800'} w-1/4"></div>
            <div class="h-full rounded-full transition-all duration-300 {passwordStats.entropy >= 128 ? passwordStats.color : 'bg-slate-800'} w-1/4"></div>
          </div>

          <!-- Character Composition Badges -->
          <div class="flex flex-wrap items-center gap-2 pt-1 text-[11px] font-mono">
            <span class="px-2 py-0.5 rounded bg-slate-800/80 text-slate-300 border border-slate-700/60">
              <strong class="text-blue-400">{passwordStats.uCount}</strong> Huruf Besar
            </span>
            <span class="px-2 py-0.5 rounded bg-slate-800/80 text-slate-300 border border-slate-700/60">
              <strong class="text-blue-400">{passwordStats.lCount}</strong> Huruf Kecil
            </span>
            <span class="px-2 py-0.5 rounded bg-slate-800/80 text-slate-300 border border-slate-700/60">
              <strong class="text-emerald-400">{passwordStats.nCount}</strong> Angka
            </span>
            <span class="px-2 py-0.5 rounded bg-slate-800/80 text-slate-300 border border-slate-700/60">
              <strong class="text-amber-400">{passwordStats.sCount}</strong> Simbol
            </span>
          </div>
        </div>
      </div>

      <!-- Controls & Customization Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

        <!-- Left 1/3: Generator Settings -->
        <div class="lg:col-span-1 bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-5 h-fit">
          <div class="flex items-center space-x-2 text-sm font-bold text-slate-200">
            <Sliders class="w-4 h-4 text-blue-400" />
            <span>Pengaturan Karakter</span>
          </div>

          <!-- Length Slider -->
          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs">
              <label for="length-slider" class="text-slate-300 font-medium">Panjang Password:</label>
              <span class="font-mono text-blue-400 font-bold px-2 py-0.5 rounded bg-blue-500/10 border border-blue-500/20">
                {length} chars
              </span>
            </div>
            <input 
              id="length-slider"
              type="range" 
              min="8" 
              max="64" 
              bind:value={length} 
              oninput={() => { presetMode = 'custom'; generate(); }}
              class="w-full accent-blue-500 cursor-pointer"
            />
            <div class="flex items-center justify-between gap-1 pt-1">
              {#each [16, 24, 32, 48] as len}
                <button 
                  onclick={() => { length = len; presetMode = 'custom'; generate(); }}
                  class="px-2 py-1 rounded-md text-[11px] font-mono transition-colors {length === len ? 'bg-blue-600/30 text-blue-300 border border-blue-500/50' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}"
                >
                  {len}
                </button>
              {/each}
            </div>
          </div>

          <!-- Character Set Checkboxes -->
          <div class="space-y-2.5 text-xs">
            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={useUpper} 
                onchange={() => { presetMode = 'custom'; generate(); }}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Huruf Besar (A - Z)</span>
            </label>

            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={useLower} 
                onchange={() => { presetMode = 'custom'; generate(); }}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Huruf Kecil (a - z)</span>
            </label>

            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={useNumbers} 
                onchange={() => { presetMode = 'custom'; generate(); }}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Angka (0 - 9)</span>
            </label>

            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={useSymbols} 
                onchange={() => { presetMode = 'custom'; generate(); }}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Sertakan Simbol Khusus</span>
            </label>

            {#if useSymbols}
              <div class="pl-6 space-y-1.5 pt-1">
                <label class="flex items-center space-x-2 text-[11px] cursor-pointer text-slate-400 hover:text-slate-200">
                  <input 
                    type="radio" 
                    name="symbolMode" 
                    value="mysql-safe" 
                    bind:group={symbolMode}
                    onchange={() => { presetMode = 'custom'; generate(); }}
                    class="text-blue-500 focus:ring-blue-500 bg-slate-950"
                  />
                  <span>MySQL Safe (<code class="text-blue-300 font-mono">!$^*_+-=.,~</code>)</span>
                </label>
                <label class="flex items-center space-x-2 text-[11px] cursor-pointer text-slate-400 hover:text-slate-200">
                  <input 
                    type="radio" 
                    name="symbolMode" 
                    value="all" 
                    bind:group={symbolMode}
                    onchange={() => { presetMode = 'custom'; generate(); }}
                    class="text-blue-500 focus:ring-blue-500 bg-slate-950"
                  />
                  <span>Semua Simbol ASCII</span>
                </label>
              </div>
            {/if}

            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white pt-2 border-t border-slate-800">
              <input 
                type="checkbox" 
                bind:checked={excludeAmbiguous} 
                onchange={() => { presetMode = 'custom'; generate(); }}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Kecualikan Karakter Ambigu (<code class="text-slate-400 font-mono">0, O, I, l, 1</code>)</span>
            </label>
          </div>

          <!-- Info Box -->
          <div class="p-3 bg-blue-950/30 border border-blue-900/40 rounded-xl text-[11px] text-blue-300 leading-relaxed flex items-start space-x-2">
            <Info class="w-4 h-4 text-blue-400 flex-shrink-0 mt-0.5" />
            <span>Simbol <strong>MySQL Safe</strong> otomatis menghindari karakter kutip (<code class="text-slate-200">' " `</code>), backslash (<code class="text-slate-200">\</code>), titik koma (<code class="text-slate-200">;</code>), dan pemisah URL agar tidak error saat dimasukkan ke <code class="text-slate-200">DATABASE_URL</code> atau command line.</span>
          </div>
        </div>

        <!-- Right 2/3: Integration Tabs (SQL Snippets, Connection Strings, Batch) -->
        <div class="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-4 flex flex-col">
          <!-- Sub-Tab Switcher -->
          <div class="flex items-center gap-2 border-b border-slate-800 pb-3">
            <button 
              onclick={() => activeTab = 'single'}
              class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'single' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
            >
              <Key class="w-3.5 h-3.5" />
              <span>Ringkasan</span>
            </button>

            <button 
              onclick={() => activeTab = 'sql'}
              class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'sql' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
            >
              <Terminal class="w-3.5 h-3.5" />
              <span>Query SQL Siap Pakai</span>
            </button>

            <button 
              onclick={() => activeTab = 'env'}
              class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'env' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
            >
              <FileText class="w-3.5 h-3.5" />
              <span>.env & Connection URL</span>
            </button>

            <button 
              onclick={() => { activeTab = 'batch'; generateBatch(); }}
              class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'batch' ? 'bg-blue-600 text-white shadow-xs' : 'text-slate-400 hover:text-white hover:bg-slate-800'}"
            >
              <Layers class="w-3.5 h-3.5" />
              <span>Batch Generate</span>
            </button>
          </div>

          <!-- Content Tab 1: Single Overview -->
          {#if activeTab === 'single'}
            <div class="space-y-4 py-2 text-xs">
              <div class="space-y-2">
                <h4 class="font-bold text-slate-200 text-sm">Mengapa Menggunakan MySQL Safe Password?</h4>
                <p class="text-slate-400 leading-relaxed">
                  Banyak generator password umum menghasilkan karakter seperti <code class="text-amber-400"># @ / : ' \ " ;</code>. Karakter-karakter tersebut sering kali merusak:
                </p>
                <ul class="list-disc pl-5 space-y-1 text-slate-400">
                  <li>String koneksi URL seperti <code class="text-slate-300">mysql://user:pass@localhost:3306/db</code> (karakter <code class="text-amber-400">@</code> atau <code class="text-amber-400">:</code> membingungkan parser URL).</li>
                  <li>Script SQL <code class="text-slate-300">IDENTIFIED BY 'password'</code> (tanda kutip di dalam password akan memutus string SQL).</li>
                  <li>Perintah CLI terminal atau file konfigurasi <code class="text-slate-300">.env</code>.</li>
                </ul>
              </div>

              <div class="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-3">
                <div class="flex items-center justify-between">
                  <span class="font-mono text-slate-400 text-xs">Cuplikan Cepat untuk MySQL:</span>
                  <button 
                    onclick={() => copyToClipboard(`ALTER USER '${sqlUsername}'@'${sqlHost}' IDENTIFIED BY '${generatedPassword}';\nFLUSH PRIVILEGES;`, 'SQL Query tersalin!')}
                    class="text-blue-400 hover:text-blue-300 text-xs font-semibold flex items-center space-x-1 cursor-pointer"
                  >
                    <Copy class="w-3 h-3" />
                    <span>Salin Query ALTER USER</span>
                  </button>
                </div>
                <pre class="font-mono text-xs text-emerald-400 overflow-x-auto p-2 bg-slate-900 rounded-lg select-text">ALTER USER 'root'@'localhost' IDENTIFIED BY '{generatedPassword}';
FLUSH PRIVILEGES;</pre>
              </div>
            </div>

          <!-- Content Tab 2: Ready SQL Queries -->
          {:else if activeTab === 'sql'}
            <div class="space-y-4 py-1 text-xs">
              <!-- Parameters Input -->
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 p-3 bg-slate-950 border border-slate-800 rounded-xl">
                <div class="space-y-1">
                  <label for="sql-user-input" class="text-[11px] text-slate-400 font-medium">Username MySQL:</label>
                  <input 
                    id="sql-user-input"
                    type="text" 
                    bind:value={sqlUsername}
                    placeholder="valtera_user"
                    class="w-full px-2.5 py-1.5 bg-slate-900 border border-slate-800 rounded-lg text-xs text-slate-200 font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div class="space-y-1">
                  <label for="sql-host-input" class="text-[11px] text-slate-400 font-medium">Host / Akses:</label>
                  <input 
                    id="sql-host-input"
                    type="text" 
                    bind:value={sqlHost}
                    placeholder="localhost atau %"
                    class="w-full px-2.5 py-1.5 bg-slate-900 border border-slate-800 rounded-lg text-xs text-slate-200 font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div class="space-y-1">
                  <label for="sql-db-input" class="text-[11px] text-slate-400 font-medium">Nama Database:</label>
                  <input 
                    id="sql-db-input"
                    type="text" 
                    bind:value={sqlDatabase}
                    placeholder="valtera_db"
                    class="w-full px-2.5 py-1.5 bg-slate-900 border border-slate-800 rounded-lg text-xs text-slate-200 font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <!-- SQL 1: ALTER USER (Ganti Password) -->
              <div class="p-3.5 bg-slate-950 border border-slate-800 rounded-xl space-y-2">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-slate-200">1. Ubah / Reset Password User yang Sudah Ada</span>
                  <button 
                    onclick={() => copyToClipboard(`ALTER USER '${sqlUsername}'@'${sqlHost}' IDENTIFIED BY '${generatedPassword}';\nFLUSH PRIVILEGES;`, 'Query ALTER USER tersalin!')}
                    class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <Copy class="w-3 h-3 text-blue-400" />
                    <span>Salin</span>
                  </button>
                </div>
                <pre class="font-mono text-xs text-blue-300 p-2.5 bg-slate-900 rounded-lg overflow-x-auto select-text">ALTER USER '{sqlUsername}'@'{sqlHost}' IDENTIFIED BY '{generatedPassword}';
FLUSH PRIVILEGES;</pre>
              </div>

              <!-- SQL 2: CREATE USER + GRANT PRIVILEGES -->
              <div class="p-3.5 bg-slate-950 border border-slate-800 rounded-xl space-y-2">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-slate-200">2. Buat User Baru & Beri Hak Akses (Privileges)</span>
                  <button 
                    onclick={() => copyToClipboard(`CREATE USER '${sqlUsername}'@'${sqlHost}' IDENTIFIED BY '${generatedPassword}';\nGRANT ALL PRIVILEGES ON ${sqlDatabase}.* TO '${sqlUsername}'@'${sqlHost}';\nFLUSH PRIVILEGES;`, 'Query CREATE USER tersalin!')}
                    class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <Copy class="w-3 h-3 text-blue-400" />
                    <span>Salin</span>
                  </button>
                </div>
                <pre class="font-mono text-xs text-emerald-300 p-2.5 bg-slate-900 rounded-lg overflow-x-auto select-text">CREATE USER '{sqlUsername}'@'{sqlHost}' IDENTIFIED BY '{generatedPassword}';
GRANT ALL PRIVILEGES ON {sqlDatabase}.* TO '{sqlUsername}'@'{sqlHost}';
FLUSH PRIVILEGES;</pre>
              </div>
            </div>

          <!-- Content Tab 3: Environment & Connection URL -->
          {:else if activeTab === 'env'}
            <div class="space-y-4 py-1 text-xs">
              <!-- .env DATABASE_URL -->
              <div class="p-3.5 bg-slate-950 border border-slate-800 rounded-xl space-y-2">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-slate-200">Format .env (Prisma, Laravel, Node.js, Drizzle)</span>
                  <button 
                    onclick={() => copyToClipboard(`DATABASE_URL="mysql://${sqlUsername}:${generatedPassword}@127.0.0.1:3306/${sqlDatabase}"`, 'DATABASE_URL tersalin!')}
                    class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <Copy class="w-3 h-3 text-blue-400" />
                    <span>Salin</span>
                  </button>
                </div>
                <pre class="font-mono text-xs text-blue-300 p-2.5 bg-slate-900 rounded-lg overflow-x-auto select-text">DATABASE_URL="mysql://{sqlUsername}:{generatedPassword}@127.0.0.1:3306/{sqlDatabase}"</pre>
              </div>

              <!-- Docker Compose -->
              <div class="p-3.5 bg-slate-950 border border-slate-800 rounded-xl space-y-2">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-slate-200">Format Docker (docker-compose.yml)</span>
                  <button 
                    onclick={() => copyToClipboard(`environment:\n  MYSQL_ROOT_PASSWORD: "${generatedPassword}"\n  MYSQL_DATABASE: "${sqlDatabase}"\n  MYSQL_USER: "${sqlUsername}"\n  MYSQL_PASSWORD: "${generatedPassword}"`, 'Docker env tersalin!')}
                    class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <Copy class="w-3 h-3 text-blue-400" />
                    <span>Salin</span>
                  </button>
                </div>
                <pre class="font-mono text-xs text-purple-300 p-2.5 bg-slate-900 rounded-lg overflow-x-auto select-text">environment:
  MYSQL_ROOT_PASSWORD: "{generatedPassword}"
  MYSQL_DATABASE: "{sqlDatabase}"
  MYSQL_USER: "{sqlUsername}"
  MYSQL_PASSWORD: "{generatedPassword}"</pre>
              </div>
            </div>

          <!-- Content Tab 4: Batch Generation -->
          {:else if activeTab === 'batch'}
            <div class="space-y-4 py-1 text-xs">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-2">
                  <span class="text-slate-400">Jumlah:</span>
                  {#each [5, 10, 20] as cnt}
                    <button 
                      onclick={() => { batchCount = cnt; generateBatch(); }}
                      class="px-2.5 py-1 rounded text-xs font-mono transition-colors {batchCount === cnt ? 'bg-blue-600 text-white font-bold' : 'bg-slate-800 text-slate-400 hover:text-white'}"
                    >
                      {cnt} Password
                    </button>
                  {/each}
                </div>

                <div class="flex items-center space-x-2">
                  <button 
                    onclick={generateBatch}
                    class="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-xs font-medium flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <RefreshCw class="w-3.5 h-3.5" />
                    <span>Acak Semua</span>
                  </button>
                  <button 
                    onclick={() => copyToClipboard(batchPasswords.join('\n'), 'Semua password tersalin!')}
                    class="px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1 cursor-pointer transition-colors"
                  >
                    <Copy class="w-3.5 h-3.5" />
                    <span>Salin Semua ({batchPasswords.length})</span>
                  </button>
                </div>
              </div>

              <!-- Batch Password List -->
              <div class="space-y-2 max-h-80 overflow-y-auto pr-1">
                {#each batchPasswords as pwd, idx}
                  <div class="flex items-center justify-between p-2.5 bg-slate-950 border border-slate-800 rounded-xl hover:border-slate-700 transition-colors">
                    <span class="font-mono text-xs text-blue-300 font-medium select-all">{pwd}</span>
                    <button 
                      onclick={() => copyToClipboard(pwd, `Password #${idx + 1} tersalin!`)}
                      class="px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-mono flex items-center space-x-1 cursor-pointer transition-colors"
                    >
                      <Copy class="w-3 h-3 text-slate-400" />
                      <span>Salin</span>
                    </button>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>

      </div>

    </div>
  </div>

  <!-- Toast Notification -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2.5 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400" />
      <span>{copiedToast}</span>
    </div>
  {/if}
</div>
