# McClean — macOS Storage & Dotfiles Cleaner

<p align="center">
  <img src="Resources/icon_preview.png" width="128" height="128" alt="McClean App Icon" />
</p>

<p align="center">
  <strong>Deep storage reclamation for macOS — hidden dotfiles, 4K/8K aerial wallpapers, AI/LLM caches, and orphaned app leftovers.</strong><br/>
  Built with native SwiftUI, macOS 26+ Liquid Glass, and an offline-first AI Folder Inspector.
</p>

---

## Key Features

1. **No Subscriptions, No In-App Purchases** — Every feature is unlocked out of the box with a single purchase on the Mac App Store.
2. **Deep Hidden Dotfiles & Wallpaper Discovery** — Finds `~/.wallpaper`, `/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS`, `~/.ollama`, `~/.cache/huggingface`, `~/.npm`, `~/.cargo`, and unknown hidden dot-directories in `~`.
3. **True Orphaned App Leftover Detection** — Indexes installed `.app` bundles across `/Applications`, `/System/Applications`, and `~/Applications` and flags only leftover containers/caches from **uninstalled** apps.
4. **AI Folder Inspector** — Explains what any unfamiliar hidden folder is, which application created it, and whether it is safe to delete—using a 100% offline heuristic engine or optional local Ollama (`http://127.0.0.1:11434`) / OpenAI-compatible endpoints.

---

## Building & Verification

### 1. Build & Package `McClean.app`
```zsh
zsh build_app.sh --app-store
open ./McClean.app
```

### 2. Run Automated Verification Suites
```zsh
./McClean.app/Contents/MacOS/McClean --self-test
./McClean.app/Contents/MacOS/McClean --ui-smoke-test
```

---

## Copyright & Privacy

- **Copyright:** © 2026 Anatoli Aliaksandrou. All rights reserved.
- **Privacy Policy:** Read our [Privacy Policy](PRIVACY.md).
