# TODO app — onboarding for Claude

This folder is the source-of-truth for a personal TODO web app the user (Vale, GitHub: tigellus) actively uses every day. If you're a fresh Claude session reading this, here's everything you need to be useful immediately.

## What's in this folder

- **`todo.html`** — the entire app. Self-contained: HTML + CSS + vanilla JS, no build step, no external scripts. **Edit this file directly.** Never split it into multiple files; the user values single-file portability.
- **`active.json`** — the user's "Active" list (live data). Schema in §"Item schema" below.
- **`tracking.json`** — the user's "Tracking" list (waiting-for-others items).
- **`vision.json`** — `{ "text": "..." }` — the user's "Vision" (overarching goals). Rendered as bullets at the top of the app, collapsed by default for privacy. One bullet per `\n`-separated line.
- **`CLAUDE.md`** — this file.

There is **no build step, no package.json, no node_modules**. To verify a JS change, extract the `<script>` block and run `node --check`:
```bash
python3 -c "import re; open('/tmp/c.js','w').write(re.search(r'<script>(.*?)</script>', open('todo.html').read(), re.DOTALL).group(1))" && node --check /tmp/c.js
```

## What the app does

Two-column TODO list with priorities (`!!`, `!`, none), drag-and-drop between columns, inline rename, FLIP-animated re-sort, dark mode via `prefers-color-scheme`, multi-tab coordination via BroadcastChannel, and **two storage backends**:

1. **Local** — File System Access API (`showDirectoryPicker`). Writes `active.json`/`tracking.json` directly to a folder the user picks (this folder, in fact). Polls mtimes every 3s for external changes.
2. **GitHub** — Contents API to a private repo (the user uses `tigellus/todo-data`). Used so the app works on mobile, where File System Access API isn't available. Polls branch SHA every 30s.

Mode is stored in `localStorage` under `todo-app-config-v2` and dispatched on boot.

## Item schema

```js
{
  id: "i_<base36ts>_<rand>",     // string, unique
  text: "...",                    // string, the task
  priority: 0 | 1 | 2,            // 0=none, 1='!', 2='!!'
  done: false,                    // boolean
  createdAt: 1745323000000,       // ms epoch — when item was first created
  enteredListAt: 1745323000000,   // ms epoch — RESETS when item moves between Active/Tracking
                                  //            (drives the "waiting since" badge on Tracking)
  doneAt: null,                   // ms epoch when checked, else null
}
```

**Important**: `enteredListAt` resets on cross-list moves but NOT on priority changes or rename. The `migrateItems` function backfills it from `createdAt` for old items.

`STATE.vision` is `{ text: '' }` — initialized empty if `vision.json` is missing or malformed. `loadLocal`/`loadFromFolder`/`ghLoadAll` all guard with `typeof v.text === 'string'` so legacy folders without `vision.json` still work.

## Architecture pointers (line numbers may drift, grep for the symbol)

- **Mode dispatch**: `mode` global is `'local' | 'github' | 'none'`. `saveAll()` checks it and routes; boot sequence at the bottom of `<script>` checks it and either calls `tryRestoreFolder()` or `ghLoadAll()`.
- **GitHub backend**: all functions prefixed `gh*` (`ghReadFile`, `ghWriteFile`, `ghLoadAll`, `ghSaveAll`, `ghPoll`, `ghTestConnection`). Uses fine-grained PAT, stored in localStorage. Per-file SHA tracked in `ghShas` for concurrency; on 409/422 it refetches and retries once.
- **FLIP animation**: `snapshotPositions(ul)` before re-render, `playFlip(ul, before)` after, in a `requestAnimationFrame`. This is what makes re-sort look smooth.
- **Multi-tab guard**: `BroadcastChannel('todo-app-v1')` with 2s heartbeat ping and 5s timeout. The "⚠ Other tab open" indicator clears itself if no peer is heard from.
- **Inline edit**: `startEdit()` uses `contenteditable="plaintext-only"` with a `done` flag guard and `dataset.editing` to prevent double-init. Enter calls `finish(false)` directly, NOT `textEl.blur()` (the blur path was buggy).
- **Sort**: `activeItemsSorted(list)` filters out done, sorts by priority desc then `createdAt` asc.
- **Re-sort debounce**: priority changes wait 1s before re-sorting (so the user sees the new badge before the row jumps).

## Deployment (GitHub Pages mirror)

The app is published at `https://tigellus.github.io/todo/` (in the `tigellus/tigellus.github.io` repo, under `todo/index.html`). The user keeps **this folder as source-of-truth**.

- Local clone of `tigellus.github.io`: `/Users/valentinopacifici/Documents/webpage/tigellus.github.io` (lives outside Google Drive on purpose — git + Drive corrupts pack files).
- Deploy script: `./deploy.sh` in this folder. It copies `todo.html` → `<clone>/todo/index.html`, commits, and pushes. Idempotent (no-op if file is unchanged).

When the user asks for a change:
1. Edit `todo.html` here.
2. Verify with `node --check` as shown above.
3. Tell the user to run `./deploy.sh "optional commit message"` from this folder. Don't run it yourself unless the user asks — pushing to the public mirror is their call.

The `deploy.sh` clone path is hardcoded near the top — update it there if the user moves the clone.

## Hard rules / preferences (these are load-bearing)

- **Single self-contained HTML file.** No external scripts, no CDN imports, no build step. The token sits in the user's localStorage and they want zero supply-chain surface.
- **Never break the JSON schema** without a migration in `migrateItems()`. The user's real data is in `active.json` / `tracking.json` right next to this file.
- **Don't add features the user didn't ask for.** They explicitly rejected search/filter once already. Ship the smallest change that solves the problem.
- **Don't open `todo.html` inside the Cowork preview iframe** to test File System Access — it'll throw `SecurityError` (cross-origin sub-frames can't show directory pickers). Tell the user to test in Edge/Chrome directly.
- **Mobile constraint**: File System Access API doesn't work on iOS Safari. That's the whole reason GitHub mode exists. Don't propose a "let's switch to OPFS" or similar — it would break the desktop ↔ mobile sync.

## Things the user has corrected in the past (avoid repeating)

- Don't summarize what you just did at the end of every response — the diff is visible.
- When linking to files in this folder, use `computer://` links and the word "view" not "download".
- Keep responses succinct after sharing a file. The user looks at the file; they don't need a tour.

## Useful greps

```
# Find storage logic:           grep -n 'mode === ' todo.html
# Find GitHub backend:          grep -n '^async function gh\|^function gh' todo.html
# Find render entry points:     grep -n '^function render' todo.html
# Find keyboard shortcuts:      grep -n "addEventListener('keydown'" todo.html
```
