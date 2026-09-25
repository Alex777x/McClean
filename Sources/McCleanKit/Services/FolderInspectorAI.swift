import Foundation

public enum AIProviderMode: String, CaseIterable, Identifiable, Sendable {
    case offlineHeuristic = "Built-in Smart Heuristics (Offline & Free)"
    case localOllama = "Local Ollama (localhost:11434)"
    case customAPI = "Custom OpenAI-Compatible API"
    
    public var id: String { rawValue }
}

/// Deep folder inspector that analyzes directory contents (extensions, structure, parent app status)
/// using either the built-in heuristic engine, a local Ollama LLM, or a custom API key.
public enum FolderInspectorAI {
    
    public static func inspect(
        item: ScanItem,
        mode: AIProviderMode = .offlineHeuristic,
        ollamaModel: String = "llama3.2",
        customEndpoint: String = "https://api.openai.com/v1/chat/completions",
        apiKey: String = ""
    ) async -> String {
        let structuralSummary = collectFolderStructureSummary(for: item.url)
        
        switch mode {
        case .offlineHeuristic:
            return generateHeuristicReport(for: item, structure: structuralSummary)
            
        case .localOllama:
            if let ollamaReply = await queryLocalOllama(item: item, structure: structuralSummary, model: ollamaModel) {
                return ollamaReply
            }
            return generateHeuristicReport(for: item, structure: structuralSummary)
                + "\n\n(Note: Local Ollama was not reachable at localhost:11434; used built-in heuristic engine.)"
            
        case .customAPI:
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let apiReply = await queryCustomAPI(item: item, structure: structuralSummary, endpoint: customEndpoint, apiKey: apiKey) {
                return apiReply
            }
            return generateHeuristicReport(for: item, structure: structuralSummary)
        }
    }
    
    // MARK: - Structural Metadata Sampler
    
    private struct FolderStructureSummary: Sendable {
        let topSubentries: [String]
        let dominantExtensions: [(ext: String, count: Int)]
        let containsCacheMarkers: Bool
        let containsMediaFiles: Bool
        let containsModelWeights: Bool
        let containsDatabaseOrConfig: Bool
    }
    
    private static func collectFolderStructureSummary(for url: URL) -> FolderStructureSummary {
        if TCCGuard.shouldSkipTraversal(of: url) {
            return FolderStructureSummary(
                topSubentries: [],
                dominantExtensions: [],
                containsCacheMarkers: false,
                containsMediaFiles: false,
                containsModelWeights: false,
                containsDatabaseOrConfig: false
            )
        }
        let fm = FileManager.default
        let topEntries = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
            .filter { $0 != ".DS_Store" }
            .prefix(12)
            .map { $0 }
        
        var extCounts: [String: Int] = [:]
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]) {
            var sampled = 0
            for case let fileURL as URL in enumerator {
                if TCCGuard.shouldSkipTraversal(of: fileURL) {
                    enumerator.skipDescendants()
                    continue
                }
                sampled += 1
                if sampled > 400 { break }
                let ext = fileURL.pathExtension.lowercased()
                if !ext.isEmpty {
                    extCounts[ext, default: 0] += 1
                }
            }
        }
        
        let sortedExts = extCounts.sorted { $0.value > $1.value }.prefix(6).map { (ext: $0.key, count: $0.value) }
        let extSet = Set(extCounts.keys)
        let lowerEntries = Set(topEntries.map { $0.lowercased() })
        
        let cacheMarkers = lowerEntries.contains("cache") || lowerEntries.contains("caches") || lowerEntries.contains("logs") || lowerEntries.contains("tmp") || extSet.contains("log")
        let mediaMarkers = !extSet.isDisjoint(with: ["mov", "mp4", "heic", "png", "jpg", "jpeg", "mkv", "webm"])
        let modelMarkers = !extSet.isDisjoint(with: ["gguf", "safetensors", "bin", "onnx", "pt", "pth", "mlx"])
        let dbMarkers = !extSet.isDisjoint(with: ["sqlite", "db", "plist", "json", "toml", "yaml", "yml"])
        
        return FolderStructureSummary(
            topSubentries: Array(topEntries),
            dominantExtensions: sortedExts,
            containsCacheMarkers: cacheMarkers,
            containsMediaFiles: mediaMarkers,
            containsModelWeights: modelMarkers,
            containsDatabaseOrConfig: dbMarkers
        )
    }
    
    // MARK: - Offline Heuristic Engine
    
    private static func generateHeuristicReport(for item: ScanItem, structure: FolderStructureSummary) -> String {
        var lines: [String] = []
        lines.append("Smart Inspection: \(item.name) (\(item.formattedSize))")
        lines.append("Path: \(item.displayPath)")
        
        if let app = item.associatedAppName {
            lines.append("Origin: \(app)\(item.isOrphaned ? " [App appears UNINSTALLED]" : "")")
        }
        
        if !structure.topSubentries.isEmpty {
            lines.append("Contents Sample: \(structure.topSubentries.prefix(6).joined(separator: ", "))")
        }
        
        if !structure.dominantExtensions.isEmpty {
            let extSummary = structure.dominantExtensions.map { ".\($0.ext) (\($0.count))" }.joined(separator: ", ")
            lines.append("File Types Found: \(extSummary)")
        }
        
        // Provide intelligent diagnosis based on contents
        if structure.containsModelWeights {
            lines.append("Diagnosis: Contains large AI/ML model weights (.gguf / .safetensors / .bin). Deleting this frees massive disk space immediately; you can re-download specific models later if needed.")
        } else if structure.containsMediaFiles && (item.category == .wallpapersAndMedia || item.name.lowercased().contains("wallpaper") || item.url.path.contains("idleassetsd")) {
            lines.append("Diagnosis: Contains high-resolution video/image wallpaper assets. 100% safe to delete — macOS or your wallpaper app will only download the active wallpaper if needed.")
        } else if item.isOrphaned {
            lines.append("Diagnosis: No installed application in /Applications matches this directory. It is almost certainly leftover baggage from an app you previously removed. Safe to delete unless you plan to reinstall the app and keep old settings.")
        } else if item.safetyLevel == .safe || structure.containsCacheMarkers {
            lines.append("Diagnosis: Contains temporary cache or diagnostic artifacts. Deleting this is completely safe and will not lose personal documents or credentials.")
        } else if item.safetyLevel == .protected {
            lines.append("Diagnosis: Contains critical security keys or shell environment configuration. Keep this folder protected.")
        } else if structure.containsDatabaseOrConfig {
            lines.append("Diagnosis: Contains local configuration files or databases. Delete only if you no longer use \(item.associatedAppName ?? item.name) or want to reset its state.")
        } else {
            lines.append("Diagnosis: \(item.explanation)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Local Ollama & Custom API Queries
    
    private static func queryLocalOllama(
        item: ScanItem,
        structure: FolderStructureSummary,
        model: String
    ) async -> String? {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return nil }
        let prompt = buildPrompt(item: item, structure: structure)
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        request.httpBody = body
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String,
              !text.isEmpty else {
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func queryCustomAPI(
        item: ScanItem,
        structure: FolderStructureSummary,
        endpoint: String,
        apiKey: String
    ) async -> String? {
        guard let url = URL(string: endpoint) else { return nil }
        let prompt = buildPrompt(item: item, structure: structure)
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a concise macOS storage expert. Explain what the given macOS folder is and whether it is safe to delete in 3 short bullet points."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 220
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        request.httpBody = body
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func buildPrompt(item: ScanItem, structure: FolderStructureSummary) -> String {
        let exts = structure.dominantExtensions.map { ".\($0.ext)" }.joined(separator: ", ")
        let subs = structure.topSubentries.prefix(8).joined(separator: ", ")
        return """
        Analyze this macOS path for disk cleanup:
        Path: \(item.displayPath)
        Size: \(item.formattedSize)
        Orphaned from uninstalled app: \(item.isOrphaned ? "Yes" : "No")
        Sample sub-items: \(subs)
        File extensions inside: \(exts)
        Explain concisely: 1) What app/tool created it, 2) What happens if deleted, 3) Safe to delete?
        """
    }
}
