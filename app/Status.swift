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
