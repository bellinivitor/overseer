import Foundation

// MARK: - Model

/// Um projeto de dev detectado no diretório de scan.
struct Project: Identifiable, Hashable {
    let id: String          // caminho completo (único)
    let name: String        // nome da pasta
    let path: String        // caminho completo
    let group: String       // pasta pai relativa ao root (ex.: "urbs/sci")
    let hasCompose: Bool     // tem docker-compose.yml/.yaml
    let hasGit: Bool         // tem .git
    let markers: Set<String> // arquivos que marcaram como projeto

    /// Caminho amigável (~ no lugar do home) para exibição.
    var displayPath: String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// Iniciais para o avatar (ex.: "tristar-courier" -> "TC").
    var initials: String {
        let parts = name.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " || $0 == "." })
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? String(name.prefix(2)).uppercased() : letters.joined()
    }
}

/// Um grupo de projetos, pela pasta pai comum.
struct ProjectGroup: Identifiable {
    let id: String      // = label
    let label: String   // ex.: "urbs/sci"
    var projects: [Project]
}
