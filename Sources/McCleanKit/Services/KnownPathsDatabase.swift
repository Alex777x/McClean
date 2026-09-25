import Foundation

/// Metadata describing a known dotfile, cache directory, or macOS system bloat folder.
public struct KnownPathRule: Sendable {
    public let name: String
    public let associatedTool: String
    public let category: JunkCategory
    public let safetyLevel: SafetyLevel
    public let explanation: String
    /// Optional binary paths or app bundle names that indicate the parent tool is still installed.
    public let installedVerifyPaths: [String]
    
    public init(
        name: String,
        associatedTool: String,
        category: JunkCategory,
        safetyLevel: SafetyLevel,
        explanation: String,
        installedVerifyPaths: [String] = []
    ) {
        self.name = name
        self.associatedTool = associatedTool
        self.category = category
        self.safetyLevel = safetyLevel
        self.explanation = explanation
        self.installedVerifyPaths = installedVerifyPaths
    }
}

/// Comprehensive offline knowledge base of macOS dotfiles, wallpaper stores, developer caches, and protected paths.
public enum KnownPathsDatabase {
    
    /// Critical dot-folders and system folders that must be protected from accidental deletion.
    public static let protectedDotfileNames: Set<String> = [
        ".ssh",
        ".gnupg",
        ".aws",
        ".kube",
        ".netrc",
        ".gitconfig",
        ".zshrc",
        ".zprofile",
        ".zshenv",
        ".bashrc",
        ".bash_profile",
        ".profile",
        ".CFUserTextEncoding",
        ".DS_Store"
    ]
    
    /// Absolute path prefixes that are strictly forbidden from deletion.
    public static let forbiddenSystemPrefixes: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/private/var/db",
        "/Applications"
    ]
    
    /// Curated dictionary of known dot-directories in `~` (keyed by lowercase folder/file name).
    public static let dotfileRules: [String: KnownPathRule] = {
        let rules: [KnownPathRule] = [
            // Wallpaper & Media dot-directories (specifically mentioned by user!)
            KnownPathRule(
                name: ".wallpaper",
                associatedTool: "Wallpaper Manager / Custom Aerial Downloader",
                category: .wallpapersAndMedia,
                safetyLevel: .safe,
                explanation: "Hidden high-resolution wallpaper repository in your Home folder. Often stores 4K/8K video or lossless image wallpapers consuming gigabytes of space."
            ),
            KnownPathRule(
                name: ".wallpapers",
                associatedTool: "Wallpaper Pack / Third-Party Wallpaper Engine",
                category: .wallpapersAndMedia,
                safetyLevel: .safe,
                explanation: "Hidden directory storing downloaded ultra-HD static and live wallpapers."
            ),
            KnownPathRule(
                name: ".aerial",
                associatedTool: "Aerial Screensaver / Video Wallpapers",
                category: .wallpapersAndMedia,
                safetyLevel: .safe,
                explanation: "Downloaded 4K HDR Aerial video screensavers and wallpapers."
            ),
            
            // General Caches & Trash
            KnownPathRule(
                name: ".cache",
                associatedTool: "CLI Tools, Python, HuggingFace & XDG Apps",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Standard XDG cache directory used by command-line tools, compilers, pip, Playwright, and AI libraries. Safe to clean; tools rebuild caches on demand."
            ),
            KnownPathRule(
                name: ".Trash",
                associatedTool: "macOS Trash",
                category: .largeFilesAndDownloads,
                safetyLevel: .safe,
                explanation: "Files sitting in your macOS Trash that are still occupying physical blocks on your SSD."
            ),
            
            // Package Managers & Developer Caches
            KnownPathRule(
                name: ".npm",
                associatedTool: "Node.js / npm",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "npm package download cache (_cacache). Completely safe to delete; npm re-downloads packages only when needed.",
                installedVerifyPaths: ["/opt/homebrew/bin/npm", "/usr/local/bin/npm"]
            ),
            KnownPathRule(
                name: ".pnpm-store",
                associatedTool: "pnpm Package Manager",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Global content-addressable store for pnpm packages. Can grow to many GBs over time.",
                installedVerifyPaths: ["/opt/homebrew/bin/pnpm", "/usr/local/bin/pnpm"]
            ),
            KnownPathRule(
                name: ".yarn",
                associatedTool: "Yarn Package Manager",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Yarn Berry global package cache and releases.",
                installedVerifyPaths: ["/opt/homebrew/bin/yarn", "/usr/local/bin/yarn"]
            ),
            KnownPathRule(
                name: ".bun",
                associatedTool: "Bun JavaScript Runtime",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Bun runtime binary and global package install cache (~/.bun/install/cache).",
                installedVerifyPaths: ["/opt/homebrew/bin/bun", "/usr/local/bin/bun"]
            ),
            KnownPathRule(
                name: ".cargo",
                associatedTool: "Rust / Cargo",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Rust Cargo registry cache and installed crates. Cleaning registry/cache frees space while keeping cargo binaries.",
                installedVerifyPaths: ["/opt/homebrew/bin/cargo", "/usr/local/bin/cargo"]
            ),
            KnownPathRule(
                name: ".rustup",
                associatedTool: "Rust Toolchain Manager",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Installed Rust compiler toolchains and targets. Often 2–8 GB; safe to remove if you no longer compile Rust projects.",
                installedVerifyPaths: ["/opt/homebrew/bin/rustup", "/usr/local/bin/rustup"]
            ),
            KnownPathRule(
                name: ".gradle",
                associatedTool: "Gradle Build Tool (Android / Java / Kotlin)",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Gradle wrapper distributions and build caches. Frequently grows to 5–25 GB and is safe to purge.",
                installedVerifyPaths: ["/Applications/Android Studio.app", "/opt/homebrew/bin/gradle"]
            ),
            KnownPathRule(
                name: ".m2",
                associatedTool: "Apache Maven",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Maven local artifact repository (~/.m2/repository). Dependencies re-download on next build.",
                installedVerifyPaths: ["/opt/homebrew/bin/mvn", "/usr/local/bin/mvn"]
            ),
            KnownPathRule(
                name: ".cocoapods",
                associatedTool: "CocoaPods (iOS/macOS)",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "CocoaPods master specs repository and pod caches.",
                installedVerifyPaths: ["/opt/homebrew/bin/pod", "/usr/local/bin/pod"]
            ),
            KnownPathRule(
                name: ".pub-cache",
                associatedTool: "Flutter / Dart Pub",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Downloaded Dart and Flutter packages cache.",
                installedVerifyPaths: ["/opt/homebrew/bin/flutter", "/opt/homebrew/bin/dart"]
            ),
            KnownPathRule(
                name: ".swiftpm",
                associatedTool: "Swift Package Manager",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Swift Package Manager repository mirror and cache data."
            ),
            
            // AI Models & Local LLM Stores
            KnownPathRule(
                name: ".ollama",
                associatedTool: "Ollama Local LLMs",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Stores downloaded local LLM weights (~/.ollama/models). Often 5–100+ GB! Remove if you uninstalled Ollama or want to clear heavy models.",
                installedVerifyPaths: ["/Applications/Ollama.app", "/opt/homebrew/bin/ollama", "/usr/local/bin/ollama"]
            ),
            KnownPathRule(
                name: ".lmstudio",
                associatedTool: "LM Studio",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Contains local GGUF/MLX large language models downloaded by LM Studio.",
                installedVerifyPaths: ["/Applications/LM Studio.app"]
            ),
            KnownPathRule(
                name: ".huggingface",
                associatedTool: "HuggingFace Hub",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Cached ML models and datasets downloaded from HuggingFace."
            ),
            KnownPathRule(
                name: ".torch",
                associatedTool: "PyTorch",
                category: .developerAndAICaches,
                safetyLevel: .safe,
                explanation: "Pretrained PyTorch model weights and hub cache."
            ),
            
            // IDEs & Editors
            KnownPathRule(
                name: ".vscode",
                associatedTool: "Visual Studio Code",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "VS Code extensions Folder (~/.vscode/extensions). Safe to delete if you uninstalled VS Code or want a clean extension state.",
                installedVerifyPaths: ["/Applications/Visual Studio Code.app"]
            ),
            KnownPathRule(
                name: ".cursor",
                associatedTool: "Cursor AI Editor",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "Cursor editor extensions and local indexing data.",
                installedVerifyPaths: ["/Applications/Cursor.app"]
            ),
            KnownPathRule(
                name: ".windsurf",
                associatedTool: "Windsurf Editor",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "Windsurf IDE extensions and cache data.",
                installedVerifyPaths: ["/Applications/Windsurf.app"]
            ),
            KnownPathRule(
                name: ".android",
                associatedTool: "Android SDK / Emulator",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Android AVD virtual device images and build cache. AVDs can take 10–40 GB.",
                installedVerifyPaths: ["/Applications/Android Studio.app"]
            ),
            
            // Virtualization & Containers
            KnownPathRule(
                name: ".docker",
                associatedTool: "Docker Desktop",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Docker CLI plugins, buildx caches, and container config.",
                installedVerifyPaths: ["/Applications/Docker.app"]
            ),
            KnownPathRule(
                name: ".colima",
                associatedTool: "Colima Container Runtime",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "Colima Linux VM disk images for containers. Often 10–60 GB.",
                installedVerifyPaths: ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
            ),
            KnownPathRule(
                name: ".orbstack",
                associatedTool: "OrbStack",
                category: .developerAndAICaches,
                safetyLevel: .review,
                explanation: "OrbStack container and Linux VM data.",
                installedVerifyPaths: ["/Applications/OrbStack.app"]
            ),
            
            // Runtime Version Managers
            KnownPathRule(
                name: ".nvm",
                associatedTool: "Node Version Manager (nvm)",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "Contains installed Node.js versions and global node_modules."
            ),
            KnownPathRule(
                name: ".pyenv",
                associatedTool: "Python Version Manager (pyenv)",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "Installed Python interpreter versions."
            ),
            KnownPathRule(
                name: ".rbenv",
                associatedTool: "Ruby Version Manager (rbenv)",
                category: .hiddenDotfiles,
                safetyLevel: .review,
                explanation: "Installed Ruby versions and gems."
            ),
            
            // Protected Critical Directories
            KnownPathRule(
                name: ".ssh",
                associatedTool: "OpenSSH Keys & Config",
                category: .hiddenDotfiles,
                safetyLevel: .protected,
                explanation: "Contains your private SSH keys and server configurations. Protected from deletion."
            ),
            KnownPathRule(
                name: ".gnupg",
                associatedTool: "GPG Encryption Keys",
                category: .hiddenDotfiles,
                safetyLevel: .protected,
                explanation: "Contains your private PGP/GPG cryptographic keyring. Protected from deletion."
            ),
            KnownPathRule(
                name: ".aws",
                associatedTool: "AWS CLI Credentials",
                category: .hiddenDotfiles,
                safetyLevel: .protected,
                explanation: "Contains AWS access keys and cloud profiles. Protected from deletion."
            ),
            KnownPathRule(
                name: ".kube",
                associatedTool: "Kubernetes Config",
                category: .hiddenDotfiles,
                safetyLevel: .protected,
                explanation: "Contains Kubernetes cluster credentials (kubeconfig). Protected from deletion."
            )
        ]
        
        var map: [String: KnownPathRule] = [:]
        for rule in rules {
            map[rule.name.lowercased()] = rule
        }
        return map
    }()
    
    /// Checks whether a path is protected and must never be deleted automatically.
    public static func isProtectedPath(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL.path
        let lastComponent = url.lastPathComponent
        
        if protectedDotfileNames.contains(lastComponent) {
            return true
        }
        for prefix in forbiddenSystemPrefixes {
            if standardized == prefix || standardized.hasPrefix(prefix + "/") {
                // Allow /Applications uninstall ONLY when explicitly triggered for an .app bundle,
                // but block /Applications itself.
                if prefix == "/Applications" && standardized.hasSuffix(".app") {
                    continue
                }
                return true
            }
        }
        // Protect user Keychains
        if standardized.contains("/Library/Keychains") {
            return true
        }
        return false
    }
    
    /// Normalizes a user-supplied path (expanding `~` and resolving symlinks/relative segments) into a canonical POSIX path.
    public static func normalizeWhitelistPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
    
    /// Checks if a file URL or its `displayPath` matches any entry (or is inside a directory) in the user's custom whitelist.
    public static func matchesCustomWhitelist(url: URL, displayPath: String, whitelist: Set<String>) -> Bool {
        guard !whitelist.isEmpty else { return false }
        let stdPath = url.standardizedFileURL.path
        if whitelist.contains(stdPath) || whitelist.contains(displayPath) {
            return true
        }
        for entry in whitelist {
            let norm = normalizeWhitelistPath(entry)
            guard !norm.isEmpty else { continue }
            if stdPath == norm || stdPath.hasPrefix(norm + "/") {
                return true
            }
        }
        return false
    }
    
    /// Checks if the tool associated with a `KnownPathRule` appears to be uninstalled.
    public static func isRuleToolOrphaned(_ rule: KnownPathRule, installedAppNames: Set<String>) -> Bool {
        guard !rule.installedVerifyPaths.isEmpty else { return false }
        let fm = FileManager.default
        for verifyPath in rule.installedVerifyPaths {
            if fm.fileExists(atPath: verifyPath) {
                return false
            }
            let appName = URL(fileURLWithPath: verifyPath).deletingPathExtension().lastPathComponent.lowercased()
            if installedAppNames.contains(appName) {
                return false
            }
        }
        return true
    }
}
