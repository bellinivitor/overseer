import Foundation

// MARK: - Dados do painel de detalhe
//
// Estruturas e sondagens carregadas sob demanda quando o usuário abre o detalhe
// de um projeto (clique único na linha). Ficam de fora do refresh em massa para
// não pesar o app parado: só rodam com o detalhe aberto.

/// Último commit do projeto (para "commitado há X").
struct LastCommit: Equatable {
    var relative: String   // ex.: "há 3 dias"
    var subject: String    // mensagem (assunto) do commit
    var author: String     // autor
}

/// Uso de recursos de um container (de `docker stats`).
struct ContainerStat: Identifiable, Equatable {
    let id: String         // nome do container (único no projeto)
    var name: String
    var cpu: String        // ex.: "12.34%"
    var mem: String        // ex.: "128MiB / 2GiB"
    var memPercent: Double // 0–100, para a barra
}

/// Um arquivo com alteração pendente (de `git status --porcelain`).
struct GitChange: Identifiable, Equatable {
    var id: String { path }
    let status: String   // código de 2 chars do porcelain, ex.: " M", "??", "A ", "R "
    let path: String
}

extension StatusProbe {
    /// Arquivos com alteração pendente (modificados, novos, removidos, renomeados).
    static func changes(at path: String) -> [GitChange] {
        guard let r = Shell.run("git", ["status", "--porcelain=v1"], cwd: path, timeout: 8),
              r.status == 0 else { return [] }
        var out: [GitChange] = []
        for raw in r.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            guard line.count > 3 else { continue }
            let code = String(line.prefix(2))
            var p = String(line.dropFirst(3))
            // Renomeado vem como "orig -> dest"; mostramos o destino.
            if let range = p.range(of: " -> ") { p = String(p[range.upperBound...]) }
            // Remove aspas que o git adiciona a caminhos com caracteres especiais.
            if p.hasPrefix("\"") && p.hasSuffix("\"") { p = String(p.dropFirst().dropLast()) }
            out.append(GitChange(status: code, path: p))
        }
        return out
    }

    /// Branches locais do repositório, já ordenadas alfabeticamente.
    static func localBranches(at path: String) -> [String] {
        guard let r = Shell.run("git", ["branch", "--format=%(refname:short)"], cwd: path, timeout: 8),
              r.status == 0 else { return [] }
        return r.stdout
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Último commit: relativo (%cr), assunto (%s) e autor (%an), separados por
    /// US (0x1F) para não confundir com espaços na mensagem.
    static func lastCommit(at path: String) -> LastCommit? {
        guard let r = Shell.run("git", ["log", "-1", "--format=%cr%x1f%s%x1f%an"], cwd: path, timeout: 8),
              r.status == 0 else { return nil }
        let parts = r.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\u{1f}")
        guard parts.count == 3 else { return nil }
        return LastCommit(relative: parts[0], subject: parts[1], author: parts[2])
    }

    /// Troca a branch atual (checkout). Retorna nil em sucesso ou a mensagem de
    /// erro do git (ex.: "your local changes would be overwritten").
    static func checkout(at path: String, branch: String) -> String? {
        guard let r = Shell.run("git", ["checkout", branch], cwd: path, timeout: 20) else {
            return "git não encontrado"
        }
        if r.status == 0 { return nil }
        let msg = r.stderr.isEmpty ? r.stdout : r.stderr
        return msg.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Guarda as alterações rastreadas (git stash push). Conservador: NÃO mexe
    /// em arquivos não rastreados, e é reversível via `git stash pop`.
    static func stash(at path: String) -> String? {
        guard let r = Shell.run("git", ["stash", "push", "-m", "overseer"], cwd: path, timeout: 20) else {
            return "git não encontrado"
        }
        if r.status == 0 { return nil }
        let msg = r.stderr.isEmpty ? r.stdout : r.stderr
        return msg.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Arquivos rastreados com alteração local (unstaged + staged).
    static func changedFiles(at path: String) -> Set<String> {
        var s = Set<String>()
        for args in [["diff", "--name-only"], ["diff", "--cached", "--name-only"]] {
            if let r = Shell.run("git", args, cwd: path, timeout: 8), r.status == 0 {
                s.formUnion(r.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
            }
        }
        return s
    }

    /// Arquivos que diferem entre o HEAD atual e `branch` (`git diff --name-only HEAD branch`).
    static func filesDiffering(at path: String, headVs branch: String) -> Set<String> {
        guard let r = Shell.run("git", ["diff", "--name-only", "HEAD", branch], cwd: path, timeout: 8),
              r.status == 0 else { return [] }
        return Set(r.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    /// Branches para as quais um `checkout` abortaria por conflito com as
    /// alterações locais. Vazio se a árvore está limpa (troca sempre segura).
    /// A troca só aborta quando um arquivo alterado localmente também difere
    /// entre o HEAD e o destino — é essa interseção que calculamos aqui.
    static func conflictingBranches(at path: String, current: String?, among branches: [String]) -> Set<String> {
        let dirty = changedFiles(at: path)
        guard !dirty.isEmpty else { return [] }
        var out = Set<String>()
        for b in branches where b != current {
            if !dirty.isDisjoint(with: filesDiffering(at: path, headVs: b)) { out.insert(b) }
        }
        return out
    }

    /// Uso de CPU/memória dos containers do projeto (`docker stats --no-stream`).
    /// Vazio se docker ausente ou nada no ar.
    static func dockerStats(at path: String) -> [ContainerStat] {
        guard let ids = Shell.run("docker", ["compose", "ps", "-q"], cwd: path, timeout: 15),
              ids.status == 0 else { return [] }
        let idList = ids.stdout.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard !idList.isEmpty else { return [] }

        let fmt = "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
        guard let r = Shell.run("docker", ["stats", "--no-stream", "--format", fmt] + idList, cwd: path, timeout: 25),
              r.status == 0 else { return [] }

        var out: [ContainerStat] = []
        for line in r.stdout.split(separator: "\n") {
            let f = line.components(separatedBy: "\t")
            guard f.count >= 4 else { continue }
            let pct = Double(f[3].replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)) ?? 0
            out.append(ContainerStat(id: f[0], name: f[0], cpu: f[1].trimmingCharacters(in: .whitespaces),
                                     mem: f[2].trimmingCharacters(in: .whitespaces), memPercent: pct))
        }
        return out
    }
}
