import AppKit
import UniformTypeIdentifiers

// MARK: - Ações de abrir o projeto

enum Actions {
    /// Revela o projeto no Finder.
    static func revealInFinder(_ path: String) {
        Shell.run("open", [path], cwd: path, timeout: 5)
    }

    /// Abre o projeto num app específico (nome ou caminho de .app), via `open -a`.
    static func open(inApp app: String, path: String) {
        Shell.run("open", ["-a", app, path], cwd: path, timeout: 5)
    }

    /// Abre um seletor de .app e devolve o caminho escolhido (não persiste).
    static func chooseAppToOpen() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Abrir"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    /// Abre uma URL no navegador padrão.
    static func openURL(_ url: String) {
        Shell.run("open", [url], cwd: NSHomeDirectory(), timeout: 5)
    }

    /// Abre o terminal configurado na pasta do projeto e roda `claude`.
    /// Terminal/iTerm rodam o comando via AppleScript; outros terminais recebem
    /// um script .command aberto na pasta.
    static func openClaudeCode(path: String, terminalApp: String) {
        let name = (terminalApp as NSString).lastPathComponent
            .replacingOccurrences(of: ".app", with: "")
        let command = "cd \(shellQuote(path)) && claude"

        switch name {
        case "iTerm", "iTerm2":
            runOsascript("""
            tell application "iTerm"
              activate
              set newWindow to (create window with default profile)
              tell current session of newWindow to write text "\(escapeAppleScript(command))"
            end tell
            """)
        case "Terminal":
            runOsascript("""
            tell application "Terminal"
              activate
              do script "\(escapeAppleScript(command))"
            end tell
            """)
        default:
            launchViaCommandFile(path: path, terminalApp: terminalApp)
        }
    }

    // MARK: helpers

    private static func runOsascript(_ script: String) {
        Shell.run("osascript", ["-e", script], cwd: NSHomeDirectory(), timeout: 10)
    }

    /// Fallback: cria um .command que faz cd + claude e abre no terminal escolhido.
    private static func launchViaCommandFile(path: String, terminalApp: String) {
        let script = "#!/bin/zsh\ncd \(shellQuote(path))\nexec claude\n"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("overseer-claude-\(UUID().uuidString).command")
        do {
            try script.write(to: tmp, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmp.path)
            Shell.run("open", ["-a", terminalApp, tmp.path], cwd: path, timeout: 5)
        } catch {
            // último recurso: só abre o terminal na pasta
            Shell.run("open", ["-a", terminalApp, path], cwd: path, timeout: 5)
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Catálogo de apps conhecidos (para os pickers de config)

enum AppCatalog {
    static let ides = [
        "Visual Studio Code", "Cursor", "Zed", "Sublime Text", "PhpStorm",
        "WebStorm", "IntelliJ IDEA", "PyCharm", "Xcode", "Windsurf", "Nova",
        "Fleet", "Android Studio",
    ]
    static let terminals = [
        "Terminal", "iTerm", "Warp", "Ghostty", "WezTerm", "kitty",
        "Alacritty", "Hyper", "Tabby",
    ]

    private static let dirs = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
    ]

    /// Filtra os nomes que têm um .app instalado.
    static func installed(_ names: [String]) -> [String] {
        names.filter { name in
            dirs.contains { FileManager.default.fileExists(atPath: "\($0)/\(name).app") }
        }
    }
}

// MARK: - Sessão de logs de um comando docker

struct LogSession: Equatable {
    var title: String        // ex.: "backend — docker compose up -d"
    var lines: [String]
    var running: Bool
    var exitCode: Int32?
    var stoppedByUser: Bool = false

    static let maxLines = 500
}

// MARK: - Sanitização de logs (remove códigos ANSI/escape)

enum LogSanitizer {
    /// Limpa uma linha de saída de terminal: remove sequências ANSI (cores,
    /// mover cursor, limpar linha), resolve carriage-returns (fica com o último
    /// segmento) e tira caracteres de controle restantes.
    static func clean(_ raw: String) -> String {
        var s = raw
        // CSI: ESC [ ... letra  (cores, [2K, [1A, [G, etc.)
        s = s.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        // OSC: ESC ] ... BEL
        s = s.replacingOccurrences(of: "\u{1B}\\][^\u{07}]*\u{07}", with: "", options: .regularExpression)
        // outras sequências ESC soltas
        s = s.replacingOccurrences(of: "\u{1B}[@-Z\\\\-_]", with: "", options: .regularExpression)
        // carriage return: mantém só o que ficou depois do último \r
        if s.contains("\r") { s = s.components(separatedBy: "\r").last ?? s }
        // caracteres de controle remanescentes (menos tab)
        s = s.replacingOccurrences(of: "[\u{00}-\u{08}\u{0B}\u{0C}\u{0E}-\u{1F}]", with: "", options: .regularExpression)
        return s
    }
}
