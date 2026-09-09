import SwiftUI

// MARK: - Store
//
// Estado observável do app: o root de scan e os grupos de projetos.
// O scan roda fora da main thread e publica o resultado na main.

@MainActor
final class AppStore: ObservableObject {
    @Published var groups: [ProjectGroup] = []
    @Published var isScanning = false
    @Published var status: [String: ProjectStatus] = [:]   // por project.id

    private let rootKey = "rootPath"
    private let maxConcurrentProbes = 6

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
                self.refreshAllStatus()
            }
        }
    }

    /// Recalcula branch git + status docker de todos os projetos, com no máximo
    /// `maxConcurrentProbes` sondagens simultâneas.
    func refreshAllStatus() {
        let targets = groups.flatMap { $0.projects }.filter { $0.hasGit || $0.hasCompose }
        guard !targets.isEmpty else { return }
        for p in targets {
            status[p.id] = ProjectStatus(branch: status[p.id]?.branch,
                                         dockerUp: status[p.id]?.dockerUp,
                                         loading: true)
        }
        let limit = maxConcurrentProbes
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var it = targets.makeIterator()
                func addNext() {
                    guard let p = it.next() else { return }
                    group.addTask {
                        let branch = p.hasGit ? StatusProbe.gitBranch(at: p.path) : nil
                        let up = p.hasCompose ? StatusProbe.dockerUp(at: p.path) : nil
                        await MainActor.run {
                            self.status[p.id] = ProjectStatus(branch: branch, dockerUp: up, loading: false)
                        }
                    }
                }
                for _ in 0..<limit { addNext() }
                for await _ in group { addNext() }
            }
        }
    }

    /// Recalcula o status de um único projeto (usado após start/stop).
    func refreshStatus(for project: Project) {
        status[project.id] = ProjectStatus(branch: status[project.id]?.branch,
                                           dockerUp: status[project.id]?.dockerUp,
                                           loading: true)
        Task.detached(priority: .userInitiated) {
            let branch = project.hasGit ? StatusProbe.gitBranch(at: project.path) : nil
            let up = project.hasCompose ? StatusProbe.dockerUp(at: project.path) : nil
            await MainActor.run {
                self.status[project.id] = ProjectStatus(branch: branch, dockerUp: up, loading: false)
            }
        }
    }
}
