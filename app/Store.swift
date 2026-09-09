import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @Published var remotes: [String: String] = [:]          // URL do repositório git
    @Published var updateTag: String?                        // tag mais recente no GitHub, se != atual
    @Published var devRuns: [String: LogSession] = [:]       // execução do comando de dev
    private var devProcesses: [String: Process] = [:]        // handles para parar

    private let rootKey = "rootPath"        // legado (diretório único)
    private let rootsKey = "rootPaths"      // atual (lista de diretórios)
    private let sortKey = "sortOrder"
    private let favKey = "favorites"
    private let ideKey = "ideApp"
    private let terminalKey = "terminalApp"
    private let maxConcurrentProbes = 6

    init() {
        // Scan inicial no launch para o badge da barra refletir o estado sem
        // precisar abrir o painel. Depois disso o app fica ocioso (sem timers)
        // até uma interação/refresh.
        rescan()
        checkForUpdate()
    }

    // MARK: Aplicativos padrão (IDE / Terminal)

    /// App usado em "Abrir no editor" (nome ou caminho de .app). Default: VS Code.
    var ideApp: String {
        get { UserDefaults.standard.string(forKey: ideKey) ?? "Visual Studio Code" }
        set { UserDefaults.standard.set(newValue, forKey: ideKey); objectWillChange.send() }
    }

    /// App usado em "Abrir no terminal". Default: Terminal.
    var terminalApp: String {
        get { UserDefaults.standard.string(forKey: terminalKey) ?? "Terminal" }
        set { UserDefaults.standard.set(newValue, forKey: terminalKey); objectWillChange.send() }
    }

    /// Nome amigável de um app (tira caminho e ".app").
    func appDisplayName(_ s: String) -> String {
        let base = (s as NSString).lastPathComponent
        return base.hasSuffix(".app") ? String(base.dropLast(4)) : base
    }

    var ideDisplayName: String { appDisplayName(ideApp) }
    var terminalDisplayName: String { appDisplayName(terminalApp) }

    /// Abre o seletor para escolher um .app (editor ou terminal).
    func chooseApp(terminal: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Escolher"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if terminal { terminalApp = url.path } else { ideApp = url.path }
    }

    // MARK: Ordenação

    /// Critério de ordenação dos projetos (persistido). Muda a ordem na hora.
    var sortOrder: SortOrder {
        get { SortOrder(rawValue: UserDefaults.standard.string(forKey: sortKey) ?? "") ?? .alphabetical }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sortKey)
            objectWillChange.send()
            applySort()
        }
    }

    /// Ordena uma lista de projetos conforme `sortOrder`.
    func sorted(_ list: [Project]) -> [Project] {
        let order = sortOrder
        return list.sorted { a, b in
            switch order {
            case .alphabetical:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .modified:
                return (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
            }
        }
    }

    /// Reordena os projetos dentro de cada grupo conforme `sortOrder`.
    func applySort() {
        groups = groups.map { var g = $0; g.projects = sorted(g.projects); return g }
    }

    // MARK: Diretórios de scan (múltiplos)

    /// Diretórios raiz do scan (persistidos). Default: ~/www. Migra o valor
    /// antigo de diretório único, se existir.
    var roots: [String] {
        get {
            if let arr = UserDefaults.standard.stringArray(forKey: rootsKey), !arr.isEmpty { return arr }
            if let legacy = UserDefaults.standard.string(forKey: rootKey) { return [legacy] }
            return ["\(NSHomeDirectory())/www"]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: rootsKey)
            objectWillChange.send()
        }
    }

    /// Caminho amigável (~ no lugar do home).
    func display(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// Subtítulo do header: o único caminho, ou "N diretórios".
    var rootsSummary: String {
        let r = roots
        return r.count == 1 ? display(r[0]) : "\(r.count) diretórios"
    }

    /// Adiciona um diretório (via NSOpenPanel) e re-varre.
    func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adicionar"
        panel.directoryURL = URL(fileURLWithPath: roots.first ?? NSHomeDirectory())
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var r = roots
        guard !r.contains(url.path) else { return }
        r.append(url.path)
        roots = r
        resetAndRescan()
    }

    /// Remove um diretório da lista e re-varre (mantém ao menos um).
    func removeRoot(_ path: String) {
        var r = roots
        r.removeAll { $0 == path }
        if r.isEmpty { r = ["\(NSHomeDirectory())/www"] }
        roots = r
        resetAndRescan()
    }

    private func resetAndRescan() {
        groups = []
        status = [:]
        meta = [:]
        logs = [:]
        rescan()
    }

    // MARK: Favoritos

    /// IDs (caminhos) dos projetos favoritados.
    var favorites: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: favKey) ?? []) }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: favKey)
            objectWillChange.send()
        }
    }

    func isFavorite(_ project: Project) -> Bool { favorites.contains(project.id) }

    func toggleFavorite(_ project: Project) {
        var f = favorites
        if f.contains(project.id) { f.remove(project.id) } else { f.insert(project.id) }
        favorites = f
    }

    /// Projetos favoritados (achatados de todos os grupos), já ordenados.
    var favoriteProjects: [Project] {
        sorted(groups.flatMap { $0.projects }.filter { favorites.contains($0.id) })
    }

    // MARK: Atualização (GitHub)

    /// Consulta as tags do repositório e sinaliza se a mais recente for mais
    /// nova que a versão instalada.
    func checkForUpdate() {
        guard let url = URL(string: AppInfo.tagsAPI) else { return }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Overseer-app", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            let names = arr.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
            let newest = names.max { isNewerVersion($1, than: $0) }
            Task { @MainActor in
                if let newest, isNewerVersion(newest, than: AppInfo.currentTag) {
                    self?.updateTag = newest
                } else {
                    self?.updateTag = nil
                }
            }
        }.resume()
    }

    // MARK: Contagens

    /// Total de projetos detectados.
    var totalProjects: Int { groups.reduce(0) { $0 + $1.projects.count } }

    /// Nº de grupos com ao menos um projeto com containers no ar.
    var activeGroupsCount: Int {
        groups.filter { g in g.projects.contains { status[$0.id]?.dockerUp == true } }.count
    }

    /// Re-executa o scan de forma assíncrona (varre todos os diretórios).
    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let urls = roots.map { URL(fileURLWithPath: $0) }
        Task.detached(priority: .userInitiated) {
            let result = Scanner.scan(roots: urls)
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
                        let git = p.hasGit ? StatusProbe.gitInfo(at: p.path) : GitInfo(branch: nil, dirty: false, ahead: 0, behind: 0)
                        let dk = p.hasCompose ? StatusProbe.dockerInfo(at: p.path) : DockerInfo(up: nil, ports: [])
                        let remote = p.hasGit ? StatusProbe.gitRemoteURL(at: p.path) : nil
                        await MainActor.run {
                            self.status[p.id] = ProjectStatus(branch: git.branch, dockerUp: dk.up,
                                                              dirty: git.dirty, ahead: git.ahead, behind: git.behind,
                                                              ports: dk.ports, loading: false)
                            self.remotes[p.id] = remote
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

    // MARK: Task runner (comando de dev por projeto)

    /// Comando de dev do projeto: override salvo ou auto-detecção.
    func devCommand(for project: Project) -> String {
        if let saved = UserDefaults.standard.string(forKey: "dev:\(project.id)"), !saved.isEmpty {
            return saved
        }
        return DevCommand.autodetect(at: project.path)
    }

    func setDevCommand(_ cmd: String, for project: Project) {
        let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: "dev:\(project.id)")
        objectWillChange.send()
    }

    func hasDevCommand(_ project: Project) -> Bool { !devCommand(for: project).isEmpty }

    /// Abre um prompt para editar o comando de dev do projeto.
    func promptDevCommand(for project: Project) {
        let alert = NSAlert()
        alert.messageText = "Comando de dev — \(project.name)"
        alert.informativeText = "Roda no diretório do projeto (via zsh -lc)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = devCommand(for: project)
        field.placeholderString = "ex.: npm run dev"
        alert.accessoryView = field
        alert.addButton(withTitle: "Salvar")
        alert.addButton(withTitle: "Cancelar")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            setDevCommand(field.stringValue, for: project)
        }
    }
    func isDevRunning(_ project: Project) -> Bool { devRuns[project.id]?.running == true }

    func toggleDev(_ project: Project) {
        if isDevRunning(project) { stopDev(project) } else { runDev(project) }
    }

    func runDev(_ project: Project) {
        let id = project.id
        guard devRuns[id]?.running != true else { return }
        let cmd = devCommand(for: project)
        guard !cmd.isEmpty else { return }
        devRuns[id] = LogSession(title: "\(project.name) — \(cmd)", lines: [], running: true, exitCode: nil)

        let proc = Shell.launch(cmd, cwd: project.path,
            onLine: { line in
                DispatchQueue.main.async { MainActor.assumeIsolated { self.appendDevLog(id, line) } }
            },
            onExit: { code in
                DispatchQueue.main.async { MainActor.assumeIsolated {
                    self.devRuns[id]?.running = false
                    self.devRuns[id]?.exitCode = code
                    self.devProcesses[id] = nil
                } }
            })

        if let proc {
            devProcesses[id] = proc
        } else {
            devRuns[id]?.running = false
            appendDevLog(id, "erro: não consegui iniciar o comando")
        }
    }

    func stopDev(_ project: Project) { stopDev(id: project.id) }

    /// Para o comando de dev pelo id, marcando que foi o usuário (para o status
    /// mostrar "parado" em vez de "erro").
    func stopDev(id: String) {
        devRuns[id]?.stoppedByUser = true
        if let p = devProcesses[id], p.isRunning {
            p.terminate()   // SIGTERM; o exec faz o Process ser o próprio servidor
        }
    }

    /// Nº de comandos de dev rodando (para o badge da barra de menu).
    var devRunningCount: Int { devRuns.values.filter { $0.running }.count }

    private func appendDevLog(_ id: String, _ line: String) {
        let clean = LogSanitizer.clean(line)
        if clean.isEmpty { return }   // descarta linhas só de controle
        devRuns[id]?.lines.append(clean)
        if let n = devRuns[id]?.lines.count, n > LogSession.maxLines {
            devRuns[id]?.lines.removeFirst(n - LogSession.maxLines)
        }
    }

    private func appendLog(_ id: String, _ line: String) {
        let clean = LogSanitizer.clean(line)
        if clean.isEmpty { return }
        logs[id]?.lines.append(clean)
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
            let git = project.hasGit ? StatusProbe.gitInfo(at: project.path) : GitInfo(branch: nil, dirty: false, ahead: 0, behind: 0)
            let dk = project.hasCompose ? StatusProbe.dockerInfo(at: project.path) : DockerInfo(up: nil, ports: [])
            let remote = project.hasGit ? StatusProbe.gitRemoteURL(at: project.path) : nil
            await MainActor.run {
                self.status[project.id] = ProjectStatus(branch: git.branch, dockerUp: dk.up,
                                                        dirty: git.dirty, ahead: git.ahead, behind: git.behind,
                                                        ports: dk.ports, loading: false)
                self.remotes[project.id] = remote
            }
        }
    }

    // MARK: Auto-refresh (só docker, para o timer com o painel aberto)

    /// Nº de projetos com containers no ar.
    var runningCount: Int {
        status.values.filter { $0.dockerUp == true }.count
    }

    /// Recalcula só o estado docker (up + portas) dos projetos com compose,
    /// preservando os campos de git. Leve o bastante para rodar a cada poucos
    /// segundos enquanto o painel está aberto.
    func refreshDockerStates() {
        let targets = groups.flatMap { $0.projects }.filter { $0.hasCompose }
        guard !targets.isEmpty else { return }
        let limit = maxConcurrentProbes
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var it = targets.makeIterator()
                func addNext() {
                    guard let p = it.next() else { return }
                    group.addTask {
                        let dk = StatusProbe.dockerInfo(at: p.path)
                        await MainActor.run {
                            var s = self.status[p.id] ?? ProjectStatus()
                            s.dockerUp = dk.up
                            s.ports = dk.ports
                            s.loading = false
                            self.status[p.id] = s
                        }
                    }
                }
                for _ in 0..<limit { addNext() }
                for await _ in group { addNext() }
            }
        }
    }
}
