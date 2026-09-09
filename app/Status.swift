import Foundation

// MARK: - Status
//
// Estado dinâmico de um projeto: branch git e se os containers estão up.
// Ambos calculados via Shell (fora da main thread).

struct ProjectStatus: Equatable {
    var branch: String?      // nil = sem git / não lido
    var dockerUp: Bool?      // nil = sem docker/compose ou desconhecido
    var loading: Bool = false
}

enum StatusProbe {
    /// Branch atual (ex.: "main"), ou nil se não for repo git.
    static func gitBranch(at path: String) -> String? {
        guard let r = Shell.run("git", ["rev-parse", "--abbrev-ref", "HEAD"], cwd: path, timeout: 8),
              r.status == 0 else { return nil }
        let b = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? nil : b
    }

    /// URL https do remote `origin` (normalizada de SSH), ou nil se não houver.
    static func gitRemoteURL(at path: String) -> String? {
        guard let r = Shell.run("git", ["remote", "get-url", "origin"], cwd: path, timeout: 8),
              r.status == 0 else { return nil }
        return GitRemote.normalize(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// true se há containers em execução para o compose do projeto; false se
    /// nenhum; nil se docker não está disponível.
    /// Usa `docker compose ps -q`: por padrão lista só serviços em execução.
    static func dockerUp(at path: String) -> Bool? {
        guard let r = Shell.run("docker", ["compose", "ps", "-q"], cwd: path, timeout: 25) else {
            return nil  // docker não encontrado
        }
        if r.status != 0 { return false }  // compose presente mas nada up (ou erro) -> down
        return !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
