import Foundation

// MARK: - Comando de dev por projeto (auto-detecção)

enum DevCommand {
    /// Detecta um comando de dev plausível a partir dos arquivos do projeto.
    /// Retorna "" se não souber sugerir.
    static func autodetect(at path: String) -> String {
        let fm = FileManager.default
        func has(_ f: String) -> Bool { fm.fileExists(atPath: "\(path)/\(f)") }

        if has("package.json") {
            if let scriptName = packageScript(at: path) { return "npm run \(scriptName)" }
            return "npm run dev"
        }
        if has("artisan") { return "php artisan serve" }
        if has("composer.json"), composerHasDev(at: path) { return "composer dev" }
        if has("Cargo.toml") { return "cargo run" }
        if has("go.mod") { return "go run ." }
        if has("manage.py") { return "python manage.py runserver" }
        return ""
    }

    /// Primeiro script útil do package.json (dev > start > serve).
    private static func packageScript(at path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: "\(path)/package.json"),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = obj["scripts"] as? [String: Any] else { return nil }
        for name in ["dev", "start", "serve"] where scripts[name] != nil { return name }
        return nil
    }

    private static func composerHasDev(at path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: "\(path)/composer.json"),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = obj["scripts"] as? [String: Any] else { return false }
        return scripts["dev"] != nil
    }
}
