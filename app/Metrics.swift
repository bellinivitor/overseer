import Foundation

// MARK: - Métricas do projeto (tamanho em disco + linguagens)

struct ProjectMeta: Equatable {
    var size: String?         // ex.: "1,2 GB"; nil = não calculado
    var languages: [String] = []
    var loading: Bool = false
}

enum DiskSizer {
    /// Tamanho em disco via `du -sk` (KB) formatado. nil se falhar.
    static func size(at path: String) -> String? {
        guard let r = Shell.run("du", ["-sk", path], cwd: path, timeout: 90), r.status == 0 else { return nil }
        // saída: "123456\t/caminho"
        let field = r.stdout.split(whereSeparator: { $0 == "\t" || $0 == " " }).first
        guard let kbStr = field, let kb = Int64(kbStr) else { return nil }
        return format(bytes: kb * 1024)
    }

    static func format(bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

enum LanguageDetector {
    /// Extensão -> linguagem.
    static let extMap: [String: String] = [
        "swift": "Swift", "php": "PHP",
        "js": "JavaScript", "jsx": "JavaScript", "mjs": "JavaScript", "cjs": "JavaScript",
        "ts": "TypeScript", "tsx": "TypeScript",
        "vue": "Vue", "svelte": "Svelte",
        "py": "Python", "rb": "Ruby", "go": "Go", "rs": "Rust",
        "java": "Java", "kt": "Kotlin", "kts": "Kotlin",
        "c": "C", "h": "C", "cpp": "C++", "cc": "C++", "cxx": "C++", "hpp": "C++",
        "cs": "C#", "dart": "Dart", "ex": "Elixir", "exs": "Elixir",
        "html": "HTML", "css": "CSS", "scss": "CSS", "sass": "CSS", "less": "CSS",
        "sh": "Shell", "bash": "Shell", "sql": "SQL",
    ]

    /// Linguagens de marker files (sinal forte mesmo sem muitos arquivos-fonte).
    static func markerLanguages(at path: String) -> [String] {
        let fm = FileManager.default
        func has(_ f: String) -> Bool { fm.fileExists(atPath: "\(path)/\(f)") }
        var langs: [String] = []
        if has("composer.json") { langs.append("PHP") }
        if has("package.json") { langs.append(has("tsconfig.json") ? "TypeScript" : "JavaScript") }
        if has("Cargo.toml") { langs.append("Rust") }
        if has("go.mod") { langs.append("Go") }
        if has("Package.swift") { langs.append("Swift") }
        if has("pyproject.toml") || has("requirements.txt") || has("setup.py") { langs.append("Python") }
        if has("Gemfile") { langs.append("Ruby") }
        if has("pom.xml") || has("build.gradle") || has("build.gradle.kts") { langs.append("Java") }
        return langs
    }

    /// Detecta até 3 linguagens: conta extensões numa varredura rasa e combina
    /// com os markers. Limitada em profundidade e número de arquivos.
    static func detect(at path: String, maxDepth: Int = 2, fileBudget: Int = 4000) -> [String] {
        let fm = FileManager.default
        var counts: [String: Int] = [:]
        var seen = 0

        func walk(_ dir: String, depth: Int) {
            guard seen < fileBudget,
                  let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for name in entries {
                if seen >= fileBudget { return }
                let full = "\(dir)/\(name)"
                var isDir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &isDir)
                if isDir.boolValue {
                    if depth < maxDepth && !Scanner.skipDirs.contains(name) && !name.hasPrefix(".") {
                        walk(full, depth: depth + 1)
                    }
                } else {
                    seen += 1
                    let ext = (name as NSString).pathExtension.lowercased()
                    if let lang = extMap[ext] { counts[lang, default: 0] += 1 }
                }
            }
        }
        walk(path, depth: 0)

        // Ranking por contagem; markers entram com um peso base para não sumirem.
        for m in markerLanguages(at: path) { counts[m, default: 0] += 3 }

        return counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(3)
            .map { $0.key }
    }
}
