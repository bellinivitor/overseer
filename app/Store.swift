import SwiftUI
import AppKit

// MARK: - Store
//
// Estado observável do app: o root de scan e os grupos de projetos.
// O scan roda fora da main thread e publica o resultado na main.

@MainActor
final class AppStore: ObservableObject {
    @Published var groups: [ProjectGroup] = []
    @Published var isScanning = false
    @Published var status: [String: ProjectStatus] = [:]   // por project.id
    @Published var meta: [String: ProjectMeta] = [:]        // tamanho + linguagens
    @Published var logs: [String: LogSession] = [:]         // sessão de logs por projeto

    private let rootKey = "rootPath"
    private let sortKey = "sortOrder"
    private let maxConcurrentProbes = 6

    /// Critério de ordenação dos projetos (persistido). Muda a ordem na hora.
    var sortOrder: SortOrder {
        get { SortOrder(rawValue: UserDefaults.standard.string(forKey: sortKey) ?? "") ?? .alphabetical }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sortKey)
            objectWillChange.send()
            applySort()
        }
    }

    /// Reordena os projetos dentro de cada grupo conforme `sortOrder`.
    func applySort() {
        let order = sortOrder
        groups = groups.map { group in
            var g = group
            g.projects.sort { a, b in
                switch order {
                case .alphabetical:
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                case .modified:
                    return (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
                }
            }
            return g
        }
    }

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

    /// Nº de grupos com ao menos um projeto com containers no ar.
    var activeGroupsCount: Int {
        groups.filter { g in g.projects.contains { status[$0.id]?.dockerUp == true } }.count
    }

    /// Abre um NSOpenPanel para escolher o root de scan e re-varre.
    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Escolher"
        panel.directoryURL = URL(fileURLWithPath: rootPath)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        rootPath = url.path
        groups = []
        status = [:]
        meta = [:]
        logs = [:]
        rescan()
    }

    /// Re-executa o scan de forma assíncrona.
    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let root = URL(fileURLWithPath: rootPath)
        Task.detached(priority: .userInitiated) {
            let result = Scanner.scan(root: root)
            await MainActor.run {
                self.groups = result
                self.applySort()
                self.isScanning = false
                self.refreshAllStatus()
                self.refreshAllMeta(force: true)
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

    /// Calcula tamanho em disco + linguagens de todos os projetos, com cache
    /// (só recalcula o que falta, a menos que `force`). Concorrência limitada.
    func refreshAllMeta(force: Bool = false) {
        let all = groups.flatMap { $0.projects }
        let targets = force ? all : all.filter { meta[$0.id]?.size == nil }
        guard !targets.isEmpty else { return }
        for p in targets {
            meta[p.id] = ProjectMeta(size: meta[p.id]?.size, languages: meta[p.id]?.languages ?? [], loading: true)
        }
        let limit = maxConcurrentProbes
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var it = targets.makeIterator()
                func addNext() {
                    guard let p = it.next() else { return }
                    group.addTask {
                        let langs = LanguageDetector.detect(at: p.path)
                        let size = DiskSizer.size(at: p.path)
                        await MainActor.run {
                            self.meta[p.id] = ProjectMeta(size: size, languages: langs, loading: false)
                        }
                    }
                }
                for _ in 0..<limit { addNext() }
                for await _ in group { addNext() }
            }
        }
    }

    /// Sobe (`up -d`) ou derruba (`down`) os containers do projeto, transmitindo
    /// a saída do compose para uma LogSession e recomputando o status no fim.
    func runCompose(_ project: Project, up: Bool) {
        let id = project.id
        guard logs[id]?.running != true else { return }  // já rodando
        let cmd = up ? "up -d" : "down"
        logs[id] = LogSession(title: "\(project.name) — docker compose \(cmd)",
                              lines: [], running: true, exitCode: nil)
        status[id] = ProjectStatus(branch: status[id]?.branch, dockerUp: status[id]?.dockerUp, loading: true)

        let args = up ? ["compose", "up", "-d"] : ["compose", "down"]
        // Task herda o MainActor (AppStore é @MainActor): mutações ordenadas na main.
        Task {
            for await ev in Shell.streamLines("docker", args, cwd: project.path) {
                switch ev {
                case .line(let l):
                    appendLog(id, l)
                case .finished(let code):
                    logs[id]?.running = false
                    logs[id]?.exitCode = code
                    refreshStatus(for: project)
                case .failed:
                    appendLog(id, "erro: docker não encontrado no PATH")
                    logs[id]?.running = false
                    logs[id]?.exitCode = -1
                    status[id]?.loading = false
                }
            }
        }
    }

    private func appendLog(_ id: String, _ line: String) {
        logs[id]?.lines.append(line)
        if let n = logs[id]?.lines.count, n > LogSession.maxLines {
            logs[id]?.lines.removeFirst(n - LogSession.maxLines)
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
