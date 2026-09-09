import SwiftUI

// MARK: - Store
//
// Estado observável do app: o root de scan e os grupos de projetos.
// O scan roda fora da main thread e publica o resultado na main.

@MainActor
final class AppStore: ObservableObject {
    @Published var groups: [ProjectGroup] = []
    @Published var isScanning = false

    private let rootKey = "rootPath"

    /// Diretório raiz do scan (persistido em UserDefaults). Default: ~/www.
    var rootPath: String {
        get { UserDefaults.standard.string(forKey: rootKey) ?? "\(NSHomeDirectory())/www" }
        set {
            UserDefaults.standard.set(newValue, forKey: rootKey)
            objectWillChange.send()
        }
    }

    /// Caminho amigável do root (~ no lugar do home).
    var rootDisplay: String {
        let home = NSHomeDirectory()
        return rootPath.hasPrefix(home) ? "~" + rootPath.dropFirst(home.count) : rootPath
    }

    /// Total de projetos detectados.
    var totalProjects: Int { groups.reduce(0) { $0 + $1.projects.count } }

    /// Re-executa o scan de forma assíncrona.
    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let root = URL(fileURLWithPath: rootPath)
        Task.detached(priority: .userInitiated) {
            let result = Scanner.scan(root: root)
            await MainActor.run {
                self.groups = result
                self.isScanning = false
            }
        }
    }
}
