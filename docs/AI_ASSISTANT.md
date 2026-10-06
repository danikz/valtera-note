# 🤖 AI Assistant Guide — Valtera Note

Valtera Note ships with a built-in AI Assistant using a **Bring Your Own Key (BYO)** model: no middleman server, no subscription from us — you use your own API key from the provider of your choice. Requests are sent **directly from the Rust backend** to the provider (no CORS issues), and the configuration is stored **only on this device**.

---

## 1. Supported Providers

| Provider | Type | Base URL | Example Model |
| :--- | :--- | :--- | :--- |
| **Anthropic Claude** | Native Messages API | `https://api.anthropic.com` | `claude-sonnet-4-5` |
| **OpenAI** | OpenAI-compatible | `https://api.openai.com/v1` | `gpt-4o-mini` |
| **OpenRouter** | OpenAI-compatible | `https://openrouter.ai/api/v1` | `anthropic/claude-sonnet-4.5` |
| **Groq** | OpenAI-compatible | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| **Ollama (local)** | OpenAI-compatible | `http://localhost:11434/v1` | `llama3.1` |

- Any endpoint following the **OpenAI-compatible** standard (`/chat/completions`) works out of the box — including LM Studio, Together, etc.
- **Ollama/LM Studio** = 100% offline. Ideal for highly sensitive content, since the text never leaves your device.
- One-click presets are available in the settings screen; just fill in your API key afterwards.

---

## 2. Setup (Once)

1. Open **Settings → AI Assistant** (or `Ctrl+,`).
2. Click one of the **Quick Presets** (OpenAI / Anthropic / OpenRouter / Groq / Ollama).
3. Enter the **API Key** from that provider.
4. Click **Test Connection** — besides validating, the app automatically **fetches the provider's real model list**, and the *Model* field will show dropdown suggestions.
5. Pick a model → **Save**. Done — a green indicator appears in the Settings sidebar.

> 💡 A stored key is not wiped when you re-save the configuration with an empty key field (empty = keep the existing key).

---

## 3. AI Chat Sidebar (Chat)

Open it with **`Ctrl+Shift+A`** or the **✨** button in the top-right titlebar.

- **Multi-turn**: the AI remembers the conversation while the panel is open; the 🗑️ button starts a fresh chat.
- **Read active note** (toggle): the content of the open note is sent as context — the AI knows what you're talking about.
- **Include selected text** (toggle): the block you've highlighted in the editor is sent too — perfect for asking about a specific code/config snippet.
- **Quick prompts**: summarize the note, review for potential issues, build a task list, or have the AI write.
- `Enter` = send, `Shift+Enter` = new line.

---

## 4. Writing to Notes (Write-to-Note)

Ask the AI to modify the note, for example:

> *"fix the typos in this note and update it"*
> *"add a Summary section at the end of the note"*

The AI replies with a short explanation + a **`valtera-write`** block containing the complete updated note. The sidebar shows a card:

- **Replace Entire Note** — after confirmation, the editor content is updated in place (minimal diff, no cursor jump) and cloud auto-sync runs as usual.
- **Copy Only** — to review it manually first.

Once applied you'll see ✅ *Note updated*.

> This protocol relies on system instructions, so it **works with every provider** — including small models without tool-calling support.

### Quick Actions in the Editor (Ctrl+Shift+A → or the Edit menu)

Besides chat, there are one-click actions that operate on the **selected text** (or the whole note if nothing is selected):

| Action | Result |
| :--- | :--- |
| **Summarize** | Compact bullet-point summary |
| **Improve Writing** | Fixed spelling & grammar |
| **→ English / → Indonesia** | Translation |
| **Explain** | Plain-language explanation |
| **Commit Msg** | A single conventional-commit line |
| **Custom prompt** | Free-form instructions |

Results can be **copied**, **replace the selection**, or be **inserted at the cursor**.

---

## 5. Privacy

- The API key & AI configuration are stored **only in this device's local database**.
- Requests go straight from the app to the provider — **no middleman server**.
- ⚠️ **Important**: text sent to the AI leaves your device as **plaintext** — Valtera Note's E2E encryption protects local storage & cloud sync, not AI requests. For the most sensitive content, use a **local Ollama** provider.

---

## 6. Troubleshooting

| Problem | Cause & Fix |
| :--- | :--- |
| `missing required key baseUrl` | Bug in versions < 0.1.19 — update the app (arguments are now dual-cased). |
| `HTTP 401` on test connection | Wrong/expired API key — double-check the key. |
| `HTTP 404` on test connection | Wrong Base URL — OpenAI needs the `/v1` suffix, Anthropic does not. |
| Empty response / model not found | Typo in the model name — use the model list from **Test Connection** (OpenRouter uses the `vendor/model` format). |
| `model list failed to load` | Some compatible endpoints don't provide `GET /models` — type the model name manually; chat still works. |
| AI writes outside the block / no block at all | Re-run the request with the word "update the note" — the protocol needs a clear instruction to write. |
