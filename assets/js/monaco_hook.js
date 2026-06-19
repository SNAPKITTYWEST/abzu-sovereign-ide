// Monaco Editor — LiveView hook
// Loads Monaco from CDN, binds to phx-hook="MonacoEditor"

let MonacoEditor = {
  mounted() {
    const el = this.el;
    const initialCode = el.dataset.code || '';

    require.config({ paths: { vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });

    require(['vs/editor/editor.main'], () => {
      // Register Elixir language
      monaco.languages.register({ id: 'elixir' });
      monaco.languages.setMonarchTokensProvider('elixir', elixirTokens());

      this._editor = monaco.editor.create(el, {
        value: initialCode,
        language: 'elixir',
        theme: 'abzu-dark',
        fontFamily: '"JetBrains Mono", "Fira Code", "Cascadia Code", monospace',
        fontSize: 14,
        lineHeight: 22,
        minimap: { enabled: false },
        scrollBeyondLastLine: false,
        automaticLayout: true,
        padding: { top: 16, bottom: 16 },
        cursorBlinking: 'phase',
        renderLineHighlight: 'gutter',
        bracketPairColorization: { enabled: true },
        guides: { bracketPairs: true },
        suggest: { preview: true },
        wordWrap: 'off',
      });

      // Define ABZU dark theme
      monaco.editor.defineTheme('abzu-dark', {
        base: 'vs-dark',
        inherit: true,
        rules: [
          { token: 'keyword',   foreground: 'a855f7', fontStyle: 'bold' },
          { token: 'string',    foreground: '10b981' },
          { token: 'comment',   foreground: '4b5563', fontStyle: 'italic' },
          { token: 'atom',      foreground: '06b6d4' },
          { token: 'number',    foreground: 'f97316' },
          { token: 'operator',  foreground: 'dc2626' },
          { token: 'module',    foreground: 'fbbf24', fontStyle: 'bold' },
          { token: 'function',  foreground: 'e2e8f0' },
          { token: 'macro',     foreground: 'a855f7' },
        ],
        colors: {
          'editor.background':           '#030712',
          'editor.foreground':           '#e2e8f0',
          'editorLineNumber.foreground': '#374151',
          'editorLineNumber.activeForeground': '#6b7280',
          'editor.lineHighlightBackground': '#111827',
          'editor.selectionBackground':  '#1e1b4b',
          'editorCursor.foreground':     '#dc2626',
          'editor.findMatchBackground':  '#7f1d1d',
        }
      });

      monaco.editor.setTheme('abzu-dark');

      // Push code changes to LiveView
      this._editor.onDidChangeModelContent(() => {
        const code = this._editor.getValue();
        this.pushEvent('code_change', { code });
      });

      // Ctrl/Cmd+Enter → run
      this._editor.addCommand(
        monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter,
        () => this.pushEvent('run', {})
      );

      // Ctrl/Cmd+Shift+B → BOB complete
      this._editor.addCommand(
        monaco.KeyMod.CtrlCmd | monaco.KeyMod.Shift | monaco.KeyCode.KeyB,
        () => this.pushEvent('bob_complete', {})
      );
    });
  },

  updated() {
    // If LiveView pushes new code (e.g. BOB repair), update editor
    const newCode = this.el.dataset.code;
    if (this._editor && newCode && newCode !== this._editor.getValue()) {
      const model = this._editor.getModel();
      model.pushEditOperations([], [{
        range: model.getFullModelRange(),
        text: newCode
      }], () => null);
    }
  },

  destroyed() {
    if (this._editor) this._editor.dispose();
  }
};

function elixirTokens() {
  return {
    keywords: [
      'defmodule', 'def', 'defp', 'defmacro', 'defmacrop', 'defprotocol',
      'defimpl', 'defstruct', 'defexception', 'do', 'end', 'case', 'cond',
      'if', 'unless', 'else', 'when', 'fn', 'for', 'with', 'try', 'rescue',
      'catch', 'after', 'raise', 'throw', 'receive', 'send', 'spawn', 'use',
      'import', 'require', 'alias', 'in', 'not', 'and', 'or', 'true', 'false',
      'nil', 'quote', 'unquote', '__MODULE__', '__FILE__', '__DIR__', '__ENV__',
    ],
    tokenizer: {
      root: [
        [/#.*$/, 'comment'],
        [/"(?:[^"\\]|\\.)*"/, 'string'],
        [/'[^']*'/, 'string'],
        [/~[a-z]\(.*?\)/, 'string'],
        [/~[A-Z]\(.*?\)/, 'string'],
        [/:[a-zA-Z_][a-zA-Z0-9_?!]*/, 'atom'],
        [/\b(defmodule|defprotocol|defimpl)\b/, { token: 'module', next: '@module' }],
        [/\b(def|defp|defmacro|defmacrop)\b/, 'keyword'],
        [/\b(do|end|case|cond|if|unless|else|when|fn|for|with|try|rescue|catch|after|raise|throw|receive)\b/, 'keyword'],
        [/\b(use|import|require|alias)\b/, 'keyword'],
        [/\b(true|false|nil)\b/, 'keyword'],
        [/\b[A-Z][a-zA-Z0-9_]*\b/, 'module'],
        [/@[a-zA-Z_][a-zA-Z0-9_]*/, 'macro'],
        [/\b\d+(\.\d+)?\b/, 'number'],
        [/[|><\-+*\/=!&^%]+/, 'operator'],
        [/[a-zA-Z_][a-zA-Z0-9_?!]*/, 'function'],
      ],
      module: [
        [/\s+/, ''],
        [/[A-Z][a-zA-Z0-9_.]*/, { token: 'module', next: '@pop' }],
      ],
    }
  };
}

export default MonacoEditor;
