import Foundation

// MARK: - Shell
//
// Executa comandos externos (git, docker, du…) via Process. Um app de menu bar
// aberto pelo Finder herda um PATH mínimo, então resolvemos o binário nos
// caminhos comuns (Homebrew, /usr/local, /usr/bin) e passamos um PATH decente
// para os subprocessos (o `docker compose` chama outros binários).

enum Shell {
    /// Caminhos onde procurar binários, na ordem de preferência.
    static let searchPaths = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        "/usr/sbin", "/sbin",
    ]

    /// PATH montado para os subprocessos.
    static var environmentPath: String {
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return (searchPaths + [existing]).filter { !$0.isEmpty }.joined(separator: ":")
    }

    /// Resolve o caminho absoluto de um binário, ou nil se não encontrar.
    static func resolve(_ name: String) -> String? {
        if name.hasPrefix("/") { return FileManager.default.isExecutableFile(atPath: name) ? name : nil }
        for dir in searchPaths {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    /// Roda `command args…` em `cwd`, com timeout. Retorna nil se o binário não
    /// existe ou estourou o tempo. Chamar sempre fora da main thread.
    @discardableResult
    static func run(_ command: String, _ args: [String], cwd: String, timeout: TimeInterval = 20) -> Result? {
        guard let bin = resolve(command) else { return nil }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = environmentPath
        proc.environment = env

        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return nil
        }

        // Timeout: mata o processo se demorar demais.
        let deadline = DispatchTime.now() + timeout
        let queue = DispatchQueue(label: "overseer.shell.timeout")
        queue.asyncAfter(deadline: deadline) {
            if proc.isRunning { proc.terminate() }
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        return Result(
            status: proc.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "")
    }
}
