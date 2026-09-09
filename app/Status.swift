import Foundation

// MARK: - Status
//
// Estado dinâmico de um projeto: branch git e se os containers estão up.
// Ambos calculados via Shell (fora da main thread).

struct ProjectStatus: Equatable {
    var branch: String?      // nil = sem git / não lido
    var dockerUp: Bool?      // nil = sem docker/compose ou desconhecido
    var dirty: Bool = false  // tem alterações não commitadas
    var ahead: Int = 0       // commits à frente do upstream
    var behind: Int = 0      // commits atrás do upstream
    var ports: [Int] = []    // portas publicadas dos containers no ar
    var loading: Bool = false
}

/// Resultado consolidado de `git status`.
struct GitInfo {
    var branch: String?
    var dirty: Bool
    var ahead: Int
    var behind: Int
}

/// Resultado consolidado de `docker compose ps`.
struct DockerInfo {
    var up: Bool?
    var ports: [Int]
}

enum StatusProbe {
    /// Branch + estado (dirty/ahead/behind) numa única chamada
    /// (`git status --porcelain=v1 --branch`).
    static func gitInfo(at path: String) -> GitInfo {
        guard let r = Shell.run("git", ["status", "--porcelain=v1", "--branch"], cwd: path, timeout: 8),
              r.status == 0 else {
            return GitInfo(branch: nil, dirty: false, ahead: 0, behind: 0)
        }
        let lines = r.stdout.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var branch: String?, ahead = 0, behind = 0, dirty = false

        if let first = lines.first, first.hasPrefix("##") {
            let body = first.dropFirst(2).trimmingCharacters(in: .whitespaces)
            // "main...origin/main [ahead 1, behind 2]" — nome vai até "..." ou espaço
            let namePart = body.split(separator: " ").first.map(String.init) ?? String(body)
            branch = namePart.components(separatedBy: "...").first
            ahead = intAfter("ahead ", in: body)
            behind = intAfter("behind ", in: body)
            dirty = lines.dropFirst().contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        } else {
            dirty = lines.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        if branch?.isEmpty ?? true { branch = nil }
        return GitInfo(branch: branch, dirty: dirty, ahead: ahead, behind: behind)
    }

    private static func intAfter(_ needle: String, in s: String) -> Int {
        guard let r = s.range(of: needle) else { return 0 }
        let digits = s[r.upperBound...].prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    /// URL https do remote `origin` (normalizada de SSH), ou nil se não houver.
    static func gitRemoteURL(at path: String) -> String? {
        guard let r = Shell.run("git", ["remote", "get-url", "origin"], cwd: path, timeout: 8),
              r.status == 0 else { return nil }
        return GitRemote.normalize(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Estado docker + portas publicadas via `docker compose ps --format json`.
    /// up: true se algum serviço rodando; false se nenhum; nil se docker ausente.
    static func dockerInfo(at path: String) -> DockerInfo {
        guard let r = Shell.run("docker", ["compose", "ps", "--format", "json"], cwd: path, timeout: 25) else {
            return DockerInfo(up: nil, ports: [])   // docker não encontrado
        }
        if r.status != 0 { return DockerInfo(up: false, ports: []) }
        let out = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty { return DockerInfo(up: false, ports: []) }

        // Formato pode ser um array JSON ou um objeto por linha (compose novo).
        var objs: [[String: Any]] = []
        if let data = out.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            objs = arr
        } else {
            for line in out.split(separator: "\n") {
                if let d = line.data(using: .utf8),
                   let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    objs.append(o)
                }
            }
        }

        var up = false
        var ports = Set<Int>()
        for o in objs {
            let state = (o["State"] as? String ?? "").lowercased()
            if state.contains("running") || state.contains("up") { up = true }
            if let pubs = o["Publishers"] as? [[String: Any]] {
                for p in pubs {
                    if let pp = p["PublishedPort"] as? Int, pp > 0 { ports.insert(pp) }
                }
            }
        }
        return DockerInfo(up: up, ports: ports.sorted())
    }
}

// MARK: - Normalização de remote git para URL de navegador

enum GitRemote {
    /// Converte um remote (SSH ou HTTPS) numa URL https abrível no navegador.
    /// Ex.: git@github.com:owner/repo.git -> https://github.com/owner/repo
    static func normalize(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        var url = raw

        if url.hasPrefix("git@") {
            // git@host:owner/repo(.git)
            let afterUser = url.dropFirst(4)  // remove "git@"
            guard let colon = afterUser.firstIndex(of: ":") else { return nil }
            let host = afterUser[afterUser.startIndex..<colon]
            let pathPart = afterUser[afterUser.index(after: colon)...]
            url = "https://\(host)/\(pathPart)"
        } else if url.hasPrefix("ssh://") {
            // ssh://git@host/owner/repo(.git)
            url = "https://" + url.dropFirst("ssh://".count)
            url = url.replacingOccurrences(of: "git@", with: "")
        }

        if url.hasSuffix(".git") { url = String(url.dropLast(4)) }
        guard url.hasPrefix("http") else { return nil }

        // Remove credenciais embutidas (ex.: token@host) — nunca abrir no
        // navegador uma URL com segredo.
        if let scheme = url.range(of: "://") {
            let after = url[scheme.upperBound...]
            let parts = after.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            var authority = String(parts.first ?? "")
            if let at = authority.lastIndex(of: "@") {
                authority = String(authority[authority.index(after: at)...])
            }
            let rest = parts.count > 1 ? "/" + parts[1] : ""
            url = String(url[..<scheme.upperBound]) + authority + rest
        }
        return url
    }
}
