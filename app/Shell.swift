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

    /// Eventos do streaming de um comando.
    enum StreamEvent {
        case line(String)
        case finished(Int32)
        case failed         // binário não encontrado ou falha ao iniciar
    }

    /// Acumula bytes e emite linhas completas (guarda o resto parcial).
    private final class LineBuffer {
        private var data = Data()
        func push(_ chunk: Data) -> [String] {
            data.append(chunk)
            var lines: [String] = []
            while let nl = data.firstIndex(of: 0x0A) {
                let lineData = data.subdata(in: data.startIndex..<nl)
                data.removeSubrange(data.startIndex...nl)
                lines.append(String(data: lineData, encoding: .utf8) ?? "")
            }
            return lines
        }
        func flush() -> String? {
            guard !data.isEmpty else { return nil }
            let s = String(data: data, encoding: .utf8)
            data.removeAll()
            return (s?.isEmpty ?? true) ? nil : s
        }
    }

    /// Lança um comando de shell (via `zsh -lc`, PATH de login) transmitindo
    /// stdout+stderr linha a linha, e devolve o `Process` para poder pará-lo.
    /// `onLine`/`onExit` são chamados fora da main thread. Usa `exec` no comando
    /// para o Process virar o próprio servidor (parar mata o servidor, não só o shell).
    static func launch(_ command: String, cwd: String,
                       onLine: @escaping (String) -> Void,
                       onExit: @escaping (Int32) -> Void) -> Process? {
        // exec faz o Process virar o próprio servidor (parar mata o servidor),
        // mas não funciona com comando composto — nesse caso roda sem exec.
        let isCompound = command.contains { ";&|\n".contains($0) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", isCompound ? command : "exec \(command)"]
        proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = environmentPath
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        let handle = pipe.fileHandleForReading
        let buffer = LineBuffer()

        handle.readabilityHandler = { h in
            let chunk = h.availableData
            if chunk.isEmpty { return }
            for line in buffer.push(chunk) { onLine(line) }
        }
        proc.terminationHandler = { p in
            handle.readabilityHandler = nil
            if let rest = try? handle.readToEnd(), !rest.isEmpty {
                for line in buffer.push(rest) { onLine(line) }
            }
            if let tail = buffer.flush() { onLine(tail) }
            onExit(p.terminationStatus)
        }

        do { try proc.run() } catch { return nil }
        return proc
    }

    /// Roda um comando transmitindo stdout+stderr linha a linha via AsyncStream.
    /// Termina com `.finished(status)` ou `.failed`. Consumir num contexto async.
    static func streamLines(_ command: String, _ args: [String], cwd: String) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            guard let bin = resolve(command) else {
                continuation.yield(.failed); continuation.finish(); return
            }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            proc.arguments = args
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = environmentPath
            proc.environment = env

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            let handle = pipe.fileHandleForReading
            let buffer = LineBuffer()

            handle.readabilityHandler = { h in
                let chunk = h.availableData
                if chunk.isEmpty { return }
                for line in buffer.push(chunk) { continuation.yield(.line(line)) }
            }

            proc.terminationHandler = { p in
                handle.readabilityHandler = nil
                let rest = try? handle.readToEnd()
                if let rest, !rest.isEmpty {
                    for line in buffer.push(rest) { continuation.yield(.line(line)) }
                }
                if let tail = buffer.flush() { continuation.yield(.line(tail)) }
                continuation.yield(.finished(p.terminationStatus))
                continuation.finish()
            }

            do { try proc.run() } catch {
                continuation.yield(.failed); continuation.finish()
            }
        }
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
