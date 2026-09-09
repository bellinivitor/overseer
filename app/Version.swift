import Foundation

// MARK: - Versão e checagem de atualização (padrão Soprano)

enum AppInfo {
    static let name = "Overseer"
    static let version = "0.1.1 beta"
    static let currentTag = "v0.1.1-beta"

    static let repoURL = "https://github.com/bellinivitor/overseer"
    static let releasesURL = "https://github.com/bellinivitor/overseer/releases"
    static let tagsAPI = "https://api.github.com/repos/bellinivitor/overseer/tags"
}

/// Núcleo numérico de uma tag ("v0.1.1-beta" -> [0,1,1]), ignorando 'v' e o
/// sufixo de pré-release ('-beta').
func versionCore(_ tag: String) -> [Int] {
    var s = tag
    if s.hasPrefix("v") { s.removeFirst() }
    if let dash = s.firstIndex(of: "-") { s = String(s[..<dash]) }
    return s.split(separator: ".").map { Int($0) ?? 0 }
}

/// true se a versão `a` for mais nova que `b` (compara número a número).
func isNewerVersion(_ a: String, than b: String) -> Bool {
    let x = versionCore(a), y = versionCore(b)
    for i in 0..<max(x.count, y.count) {
        let xi = i < x.count ? x[i] : 0
        let yi = i < y.count ? y[i] : 0
        if xi != yi { return xi > yi }
    }
    return false   // cores iguais -> não é "mais novo"
}
