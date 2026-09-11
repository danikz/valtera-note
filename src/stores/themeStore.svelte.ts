import { ipc } from '../services/ipc';

export type ThemeMode = 'dark' | 'light' | 'system';
export type ThemePreset = 'slate' | 'tokyo' | 'dracula' | 'emerald' | 'nord' | 'github-light';

export interface EditorPreferences {
  fontSize: number;
  fontFamily: string;
  tabSize: number;
  wordWrap: boolean;
  lineNumbers: boolean;
  autoSaveDelay: number;
}

class ThemeStore {
  mode = $state<ThemeMode>('dark');
  preset = $state<ThemePreset>('slate');
  
  fontSize = $state<number>(13.5);
  fontFamily = $state<string>('ui-monospace, "JetBrains Mono", Menlo, Consolas, monospace');
  tabSize = $state<number>(2);
  wordWrap = $state<boolean>(false);
  lineNumbers = $state<boolean>(true);
  autoSaveDelay = $state<number>(1000);

  private systemDarkListener: ((e: MediaQueryListEvent) => void) | null = null;

  constructor() {
    this.init();
  }

  async init() {
    if (typeof window === 'undefined') return;

    try {
      // 1. Load saved preferences from SQLite / localStorage
      const savedMode = await ipc.getAppSetting('theme_mode');
      if (savedMode && ['dark', 'light', 'system'].includes(savedMode)) {
        this.mode = savedMode as ThemeMode;
      }

      const savedPreset = await ipc.getAppSetting('theme_preset');
      if (savedPreset && ['slate', 'tokyo', 'dracula', 'emerald', 'nord', 'github-light'].includes(savedPreset)) {
        this.preset = savedPreset as ThemePreset;
      }

      const savedFontSize = await ipc.getAppSetting('editor_font_size');
      if (savedFontSize) {
        const parsed = parseFloat(savedFontSize);
        if (!isNaN(parsed) && parsed >= 10 && parsed <= 28) {
          this.fontSize = parsed;
        }
      }

      const savedFontFamily = await ipc.getAppSetting('editor_font_family');
      if (savedFontFamily) {
        this.fontFamily = savedFontFamily;
      }

      const savedTabSize = await ipc.getAppSetting('editor_tab_size');
      if (savedTabSize) {
        const parsed = parseInt(savedTabSize, 10);
        if (parsed === 2 || parsed === 4) {
          this.tabSize = parsed;
        }
      }

      const savedWordWrap = await ipc.getAppSetting('editor_word_wrap');
      if (savedWordWrap !== null) {
        this.wordWrap = savedWordWrap === 'true';
      }

      const savedLineNumbers = await ipc.getAppSetting('editor_line_numbers');
      if (savedLineNumbers !== null) {
        this.lineNumbers = savedLineNumbers === 'true';
      }

      const savedAutoSave = await ipc.getAppSetting('editor_auto_save_delay');
      if (savedAutoSave) {
        const parsed = parseInt(savedAutoSave, 10);
        if (!isNaN(parsed)) {
          this.autoSaveDelay = parsed;
        }
      }
    } catch (e) {
      console.warn('Failed to load theme settings, using defaults:', e);
    }

    // 2. Setup System Theme listener if system mode
    if (typeof window !== 'undefined' && window.matchMedia) {
      const media = window.matchMedia('(prefers-color-scheme: dark)');
      this.systemDarkListener = (e: MediaQueryListEvent) => {
        if (this.mode === 'system') {
          this.applyToDom();
        }
      };
      media.addEventListener('change', this.systemDarkListener);
    }

    // 3. Apply active theme to document DOM
    this.applyToDom();
  }

  isDarkEffective(): boolean {
    if (this.mode === 'system') {
      if (typeof window !== 'undefined' && window.matchMedia) {
        return window.matchMedia('(prefers-color-scheme: dark)').matches;
      }
      return true;
    }
    return this.mode === 'dark';
  }

  applyToDom() {
    if (typeof document === 'undefined') return;

    const isDark = this.isDarkEffective();
    const root = document.documentElement;

    // Toggle theme-dark / theme-light classes
    if (isDark) {
      root.classList.remove('theme-light');
      root.classList.add('theme-dark');
      root.setAttribute('data-theme', 'dark');
    } else {
      root.classList.remove('theme-dark');
      root.classList.add('theme-light');
      root.setAttribute('data-theme', 'light');
    }

    // Clean all preset classes and apply active
    root.classList.remove('preset-slate', 'preset-tokyo', 'preset-dracula', 'preset-emerald', 'preset-nord', 'preset-github-light');
    root.classList.add(`preset-${this.preset}`);
    root.setAttribute('data-preset', this.preset);

    // Apply font variables
    root.style.setProperty('--editor-font-size', `${this.fontSize}px`);
    root.style.setProperty('--editor-font-family', this.fontFamily);
  }

  async setMode(newMode: ThemeMode) {
    this.mode = newMode;
    // If switching to light mode and preset was dark-specific, adjust to github-light if user wants, or keep preset
    if (newMode === 'light' && this.preset !== 'github-light') {
      this.preset = 'github-light';
      await ipc.setAppSetting('theme_preset', 'github-light');
    } else if (newMode === 'dark' && this.preset === 'github-light') {
      this.preset = 'slate';
      await ipc.setAppSetting('theme_preset', 'slate');
    }

    this.applyToDom();
    await ipc.setAppSetting('theme_mode', newMode);
  }

  async toggleMode() {
    const nextMode: ThemeMode = this.isDarkEffective() ? 'light' : 'dark';
    await this.setMode(nextMode);
  }

  async setPreset(newPreset: ThemePreset) {
    this.preset = newPreset;
    // Automatically align mode with preset type
    if (newPreset === 'github-light') {
      this.mode = 'light';
      await ipc.setAppSetting('theme_mode', 'light');
    } else {
      this.mode = 'dark';
      await ipc.setAppSetting('theme_mode', 'dark');
    }

    this.applyToDom();
    await ipc.setAppSetting('theme_preset', newPreset);
  }

  async setFontSize(size: number) {
    this.fontSize = size;
    this.applyToDom();
    await ipc.setAppSetting('editor_font_size', size.toString());
  }

  async setFontFamily(family: string) {
    this.fontFamily = family;
    this.applyToDom();
    await ipc.setAppSetting('editor_font_family', family);
  }

  async setTabSize(size: number) {
    this.tabSize = size;
    await ipc.setAppSetting('editor_tab_size', size.toString());
  }

  async setWordWrap(wrap: boolean) {
    this.wordWrap = wrap;
    await ipc.setAppSetting('editor_word_wrap', wrap.toString());
  }

  async setLineNumbers(show: boolean) {
    this.lineNumbers = show;
    await ipc.setAppSetting('editor_line_numbers', show.toString());
  }

  async setAutoSaveDelay(delay: number) {
    this.autoSaveDelay = delay;
    await ipc.setAppSetting('editor_auto_save_delay', delay.toString());
  }
}

export const themeStore = new ThemeStore();
