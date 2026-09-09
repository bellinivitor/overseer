import AppKit

// MARK: - Ações de abrir o projeto

enum OpenTarget {
    case finder, vscode, terminal
}

enum Actions {
    /// Abre o projeto no destino escolhido, via `open -a`.
    static func open(_ target: OpenTarget, path: String) {
        switch target {
        case .finder:
            Shell.run("open", [path], cwd: path, timeout: 5)
        case .vscode:
            // Tenta o CLI `code`; se não houver, abre o app.
            if Shell.resolve("code") != nil {
                Shell.run("code", [path], cwd: path, timeout: 5)
            } else {
                Shell.run("open", ["-a", "Visual Studio Code", path], cwd: path, timeout: 5)
            }
        case .terminal:
            Shell.run("open", ["-a", "Terminal", path], cwd: path, timeout: 5)
        }
    }
}

// MARK: - Sessão de logs de um comando docker

struct LogSession: Equatable {
    var title: String        // ex.: "backend — docker compose up -d"
    var lines: [String]
    var running: Bool
    var exitCode: Int32?

    static let maxLines = 500
}
