import Foundation

// MARK: - Scanner
//
// Varre o diretório raiz procurando projetos e os agrupa pela pasta pai.
// Um diretório é "projeto" se contém um dos marker files (ou .git). Ao achar um
// projeto, não desce mais dentro dele (subpastas de um projeto não viram
// projetos). Pastas pesadas (node_modules, vendor…) são ignoradas na descida.

enum Scanner {
    /// Arquivos que marcam um diretório como projeto.
    static let markerFiles = [
        "docker-compose.yml", "docker-compose.yaml",
        "composer.json", "package.json",
    ]

    /// Pastas que nunca vale a pena varrer (grandes ou irrelevantes).
    static let skipDirs: Set<String> = [
        "node_modules", "vendor", ".git", ".build", "build", "dist",
        ".next", "Pods", "DerivedData", "target", ".venv", "venv",
        "wp-includes", "wp-admin",   // guts do WordPress (libs empacotadas)
    ]

    /// Detecta se `url` é um projeto e quais markers encontrou.
    static func detect(_ url: URL) -> Set<String> {
        let fm = FileManager.default
        var found = Set<String>()
        for m in markerFiles where fm.fileExists(atPath: url.appendingPathComponent(m).path) {
            found.insert(m)
        }
        if fm.fileExists(atPath: url.appendingPathComponent(".git").path) {
            found.insert(".git")
        }
        return found
    }

    /// Varre vários roots e mescla os grupos (por label, sem projetos duplicados).
    static func scan(roots: [URL], maxDepth: Int = 3) -> [ProjectGroup] {
        var byLabel: [String: [Project]] = [:]
        var seen = Set<String>()
        for root in roots {
            for group in scan(root: root, maxDepth: maxDepth) {
                for p in group.projects where !seen.contains(p.id) {
                    seen.insert(p.id)
                    byLabel[group.label, default: []].append(p)
                }
            }
        }
        return byLabel
            .map { ProjectGroup(id: $0.key, label: $0.key,
                                projects: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Varre o `root` e devolve os grupos de projetos ordenados.
    /// maxDepth 3 cobre a hierarquia real (ex.: urbs/sci/backend) sem descer em
    /// libs empacotadas fundo demais (ex.: wordpress/wp-includes/...).
    static func scan(root: URL, maxDepth: Int = 3) -> [ProjectGroup] {
        var projects: [Project] = []
        let fm = FileManager.default
        let rootStd = root.standardizedFileURL

        func walk(_ dir: URL, depth: Int) {
            let markers = detect(dir)
            if !markers.isEmpty {
                let modified = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                projects.append(Project(
                    id: dir.path,
                    name: dir.lastPathComponent,
                    path: dir.path,
                    group: groupLabel(for: dir, root: rootStd),
                    hasCompose: markers.contains("docker-compose.yml") || markers.contains("docker-compose.yaml"),
                    hasGit: markers.contains(".git"),
                    markers: markers,
                    modified: modified))
                return  // não desce dentro de um projeto
            }
            guard depth < maxDepth,
                  let entries = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles])
            else { return }

            for e in entries {
                let isDir = (try? e.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir && !skipDirs.contains(e.lastPathComponent) {
                    walk(e, depth: depth + 1)
                }
            }
        }

        walk(rootStd, depth: 0)

        let byGroup = Dictionary(grouping: projects, by: { $0.group })
        return byGroup
            .map { key, value in
                ProjectGroup(id: key, label: key,
                             projects: value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Label do grupo: caminho da pasta pai relativo ao root (ex.: "urbs/sci").
    /// Projeto direto na raiz usa o nome da própria raiz.
    static func groupLabel(for projectDir: URL, root: URL) -> String {
        let parent = projectDir.deletingLastPathComponent().standardizedFileURL
        let rootComps = root.pathComponents
        let parentComps = parent.pathComponents
        guard parentComps.count > rootComps.count else {
            return root.lastPathComponent
        }
        return parentComps.suffix(from: rootComps.count).joined(separator: "/")
    }
}
