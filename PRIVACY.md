# Privacy Policy for McClean

**Effective Date:** September 30, 2026  
**Last Updated:** September 30, 2026

McClean ("the Application") is a free, open-source macOS disk space analyzer and cleanup utility. We believe your file system and personal data belong strictly to you.

---

## 1. Zero Data Collection

McClean **does not collect, store, transmit, or share** any personal data, file names, directory structures, usage analytics, crash reports, or telemetry.

- **No Analytics or Tracking SDKs:** The Application contains no third-party analytics, advertising, or tracking frameworks.
- **No Accounts or Registration:** You never need to sign up or provide personal information to use McClean.
- **100% Local Processing:** All disk scanning, orphaned application detection, cache analysis, and file deletion operations occur entirely locally on your Mac.

---

## 2. File System Access & Permissions

To analyze disk usage and reclaim storage space, McClean scans folders that you explicitly authorize via standard macOS file selection dialogs (`NSOpenPanel`).

- **Security-Scoped Bookmarks:** When you grant access to a directory (such as your Home folder, `~/Downloads`, or `/Library`), McClean stores a standard macOS Security-Scoped Bookmark locally in your Mac's `UserDefaults` so you do not have to re-authorize the folder on every launch.
- **TCC & System Privacy:** McClean automatically skips sensitive Apple system-protected folders (such as Photos Library, Mail, Messages, and Safari history) to respect macOS Transparency, Consent, and Control (TCC) protections.
- **Revoking Access:** You can revoke folder permissions at any time inside McClean's Settings or by resetting permissions in macOS System Settings.

---

## 3. Optional AI Folder Diagnostics

McClean includes a built-in, offline heuristic engine ("Built-in Smart Heuristics") that evaluates unfamiliar hidden dot-directories locally without any network connection.

- **Optional Custom Endpoint:** If you explicitly configure an optional local LLM (such as Ollama running on `http://localhost:11434`) or a custom OpenAI-compatible API endpoint in Settings, McClean will send only the anonymized structural metadata of the specific folder you choose to inspect (folder name, child file extensions, and byte sizes) to the endpoint you configured.
- By default, no external network requests are ever made during scanning or cleanup.

---

## 4. Update Checks & Open Source Verification

In the direct GitHub release version of McClean, clicking **Check for Updates...** makes a standard HTTPS request to the public GitHub Releases API (`api.github.com/repos/Alex777x/McClean/releases/latest`) to compare the latest release tag against your installed version. In the Mac App Store version, updates are managed automatically by macOS and the App Store.

McClean is open-source software licensed under the MIT License:
- **GitHub Repository:** [https://github.com/Alex777x/McClean](https://github.com/Alex777x/McClean)
- **Support & Issues:** [https://github.com/Alex777x/McClean/issues](https://github.com/Alex777x/McClean/issues)
