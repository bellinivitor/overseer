import SwiftUI

// MARK: - App
//
// Overseer: app de menu bar que lista os projetos de dev de ~/www.
// Task 02 — scanner: varre o root, agrupa por pasta pai e lista.
// Status docker/git, tamanho, linguagens, ações e busca vêm nas próximas tasks.

@main
struct OverseerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            Image(systemName: "square.stack.3d.up")
            if store.devRunningCount > 0 {
                Text("\(store.devRunningCount)")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Configurações do Overseer", id: "config") {
            ConfigWindow(store: store)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Conteúdo do menu

/// Qual painel de logs abrir: docker (compose) ou dev (task runner).
struct LogTarget: Equatable {
    let id: String
    let dev: Bool
}

struct MenuContent: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var openLog: LogTarget?
    @State private var searchText = ""
    @State private var autoRefresh: Timer?

    private var query: String { searchText.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Grupos filtrados pela busca. Favoritos continuam aqui (marcados com a
    /// estrela) e também aparecem no card do topo. Grupos sem match somem.
    private var filteredGroups: [ProjectGroup] {
        let q = query
        guard !q.isEmpty else { return store.groups }
        return store.groups.compactMap { g in
            if g.label.lowercased().contains(q) { return g }
            let hits = g.projects.filter {
                $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : ProjectGroup(id: g.id, label: g.label, projects: hits)
        }
    }

    /// Favoritos filtrados pela busca.
    private var filteredFavorites: [Project] {
        let q = query
        let favs = store.favoriteProjects
        guard !q.isEmpty else { return favs }
        return favs.filter { $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if let target = openLog {
                LogView(store: store, target: target, onBack: { openLog = nil })
            } else {
                list
            }
        }
        .frame(width: 380)
        .liquidGlass()
        .onAppear {
            if store.groups.isEmpty { store.rescan() }
            startAutoRefresh()
        }
        .onDisappear { stopAutoRefresh() }
    }

    /// Refresh leve do status docker a cada 5s enquanto o painel está aberto
    /// (parado ao fechar — não afeta o consumo ocioso).
    private func startAutoRefresh() {
        autoRefresh?.invalidate()
        autoRefresh = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            store.refreshDockerStates()
        }
    }
    private func stopAutoRefresh() {
        autoRefresh?.invalidate()
        autoRefresh = nil
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !store.groups.isEmpty { searchField }
            Divider()
            if store.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !filteredFavorites.isEmpty {
                            FavoritesCard(store: store, projects: filteredFavorites,
                                          onOpenLog: { openLog = $0 })
                        }
                        ForEach(filteredGroups) { group in
                            GroupSection(group: group, store: store,
                                         onOpenLog: { openLog = $0 })
                        }
                        if filteredGroups.isEmpty && filteredFavorites.isEmpty {
                            Text("Nenhum projeto para “\(searchText)”.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 360, maxHeight: 480)
            }
            Divider()
            footer
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Buscar projeto…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Overseer")
                    .font(.system(size: 14.5, weight: .semibold))
                Text("\(store.rootsSummary) · \(store.totalProjects) projetos")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(store.isScanning)
            .help("Atualizar")

            Button {
                openWindow(id: "config")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Configurações")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if store.isScanning {
                ProgressView().controlSize(.small)
                Text("Varrendo \(store.rootsSummary)…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Nenhum projeto encontrado em \(store.rootsSummary).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(footerHint)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            if let t = store.updateTag {
                Link(destination: URL(string: AppInfo.releasesURL)!) {
                    Label("Atualizar (\(t))", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .help("Nova versão disponível no GitHub")
            }
            Button { NSApplication.shared.terminate(nil) } label: {
                Text("Sair").font(.system(size: 11.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footerHint: String {
        if store.isScanning { return "Atualizando…" }
        let active = store.activeGroupsCount
        return active > 0 ? "\(active) grupo(s) com containers ativos" : "\(store.groups.count) grupos"
    }
}

// MARK: - Grupo

struct GroupSection: View {
    let group: ProjectGroup
    @ObservedObject var store: AppStore
    let onOpenLog: (LogTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !group.label.isEmpty {
                HStack(spacing: 6) {
                    Text(group.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(group.projects.count)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            ForEach(group.projects) { project in
                ProjectRow(project: project, store: store, onOpenLog: onOpenLog)
            }
        }
    }
}

// MARK: - Card de favoritos (topo)

struct FavoritesCard: View {
    @ObservedObject var store: AppStore
    let projects: [Project]
    let onOpenLog: (LogTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text("Favoritos")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)

            ForEach(projects) { project in
                ProjectRow(project: project, store: store, onOpenLog: onOpenLog)
            }
            .padding(.bottom, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Linha do projeto

struct ProjectRow: View {
    let project: Project
    @ObservedObject var store: AppStore
    let onOpenLog: (LogTarget) -> Void

    @State private var hovering = false

    private var status: ProjectStatus? { store.status[project.id] }
    private var meta: ProjectMeta? { store.meta[project.id] }
    private var isRunning: Bool { store.logs[project.id]?.running == true }

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(project.initials)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let branch = status?.branch {
                        Text(branch)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
                    }
                    if status?.dirty == true {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                            .help("Alterações não commitadas")
                    }
                    if let s = status, s.ahead > 0 || s.behind > 0 {
                        Text((s.ahead > 0 ? "↑\(s.ahead)" : "") + (s.behind > 0 ? "↓\(s.behind)" : ""))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .help("\(s.ahead) à frente, \(s.behind) atrás do upstream")
                    }
                }
                Text(project.displayPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                metaLine
            }
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                favoriteButton
                statusDot
                if store.hasDevCommand(project) { devButton }
                if project.hasCompose { composeButton }
                openMenu
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(hovering ? 0.07 : 0))
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())   // torna toda a linha (inclusive vazios) hoverável
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            Actions.open(inApp: store.ideApp, path: project.path)
        }
        .help("Duplo-clique abre no \(store.ideDisplayName)")
        .contextMenu { contextMenuItems }
    }

    /// Menu de contexto (botão direito): abre direto a lista de IDEs disponíveis.
    @ViewBuilder private var contextMenuItems: some View {
        ForEach(AppCatalog.installed(AppCatalog.ides), id: \.self) { app in
            Button(store.appDisplayName(app)) {
                Actions.open(inApp: app, path: project.path)
            }
        }
        Divider()
        Button("Outro app…") {
            if let app = Actions.chooseAppToOpen() {
                Actions.open(inApp: app, path: project.path)
            }
        }
    }

    /// Estrela de favorito: aparece no hover ou quando já é favorito.
    @ViewBuilder private var favoriteButton: some View {
        let fav = store.isFavorite(project)
        Button {
            store.toggleFavorite(project)
        } label: {
            Image(systemName: fav ? "star.fill" : "star")
                .font(.system(size: 11))
                .foregroundStyle(fav ? Color.yellow : Color.secondary)
        }
        .buttonStyle(.plain)
        .opacity(fav || hovering ? 1 : 0)
        .help(fav ? "Remover dos favoritos" : "Favoritar")
    }

    /// Botão play/stop: sobe se estiver down, derruba se estiver up.
    @ViewBuilder private var composeButton: some View {
        Button {
            let goUp = !(status?.dockerUp == true)
            store.runCompose(project, up: goUp)
            onOpenLog(LogTarget(id: project.id, dev: false))
        } label: {
            if isRunning {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: status?.dockerUp == true ? "stop.fill" : "play.fill")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
            }
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .help(status?.dockerUp == true ? "Derrubar containers" : "Subir containers")
    }

    /// Botão do task runner (comando de dev).
    /// - Parado: inicia o comando e abre o log.
    /// - Rodando: apenas abre o log (NÃO para — parar é no painel), mantendo o
    ///   servidor vivo em background.
    @ViewBuilder private var devButton: some View {
        let running = store.isDevRunning(project)
        Button {
            if !running { store.runDev(project) }
            onOpenLog(LogTarget(id: project.id, dev: true))
        } label: {
            Image(systemName: running ? "bolt.fill" : "bolt")
                .font(.system(size: 11))
                .foregroundStyle(running ? Color.green : Color.secondary)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .help(running ? "Ver log do dev (rodando)" : "Rodar dev (\(store.devCommand(for: project)))")
    }

    /// Menu de abrir o projeto.
    private var openMenu: some View {
        Menu {
            Button(store.isFavorite(project) ? "Remover dos favoritos" : "Favoritar") {
                store.toggleFavorite(project)
            }
            Divider()
            Button("Abrir no \(store.ideDisplayName)") { Actions.open(inApp: store.ideApp, path: project.path) }
            Button("Abrir no Finder") { Actions.revealInFinder(project.path) }
            Button("Abrir no \(store.terminalDisplayName)") { Actions.open(inApp: store.terminalApp, path: project.path) }
            Button("Abrir Claude Code") { Actions.openClaudeCode(path: project.path, terminalApp: store.terminalApp) }
            if let ports = status?.ports, !ports.isEmpty {
                Divider()
                ForEach(ports, id: \.self) { port in
                    Button("Abrir localhost:\(port)") { Actions.openURL("http://localhost:\(port)") }
                }
            }
            if let remote = store.remotes[project.id] {
                Divider()
                Button("Abrir repositório") { Actions.openURL(remote) }
            }
            Divider()
            if store.hasDevCommand(project) {
                Button(store.isDevRunning(project) ? "Parar dev" : "Rodar dev") {
                    store.toggleDev(project)
                    onOpenLog(LogTarget(id: project.id, dev: true))
                }
            }
            Button("Definir comando de dev…") { store.promptDevCommand(for: project) }
            if store.logs[project.id] != nil {
                Button("Ver logs do Docker") { onOpenLog(LogTarget(id: project.id, dev: false)) }
            }
            if store.devRuns[project.id] != nil {
                Button("Ver logs do dev") { onOpenLog(LogTarget(id: project.id, dev: true)) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11))
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Linha de metadados: tamanho em disco + chips de linguagem.
    @ViewBuilder private var metaLine: some View {
        HStack(spacing: 5) {
            if let size = meta?.size {
                Text(size)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if meta?.loading == true {
                Text("…").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            ForEach(meta?.languages ?? [], id: \.self) { lang in
                Text(lang)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
        }
        .padding(.top, 1)
    }

    /// Bolinha de status docker: verde (up), cinza (down), oculta se sem compose.
    @ViewBuilder private var statusDot: some View {
        if project.hasCompose {
            if status?.loading == true {
                ProgressView().controlSize(.mini)
            } else if let up = status?.dockerUp {
                Circle()
                    .fill(up ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                    .shadow(color: up ? Color.green.opacity(0.6) : .clear, radius: 3)
                    .help(up ? "Containers no ar" : "Containers parados")
            } else {
                Circle().fill(Color.secondary.opacity(0.25)).frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Painel de logs

struct LogView: View {
    @ObservedObject var store: AppStore
    let target: LogTarget
    let onBack: () -> Void

    private var session: LogSession? {
        target.dev ? store.devRuns[target.id] : store.logs[target.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session?.title ?? "Logs")
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    if let s = session {
                        Text(statusText(s))
                            .font(.system(size: 10.5))
                            .foregroundStyle(statusColor(s))
                    }
                }
                Spacer()
                if session?.running == true {
                    ProgressView().controlSize(.small)
                }
                // Controles do dev: Parar (rodando) / Rodar de novo (parado).
                if target.dev, let s = session {
                    if s.running {
                        headerButton("Parar", icon: "stop.fill", tint: .red) {
                            store.stopDev(id: target.id)
                        }
                    } else {
                        headerButton("Rodar de novo", icon: "play.fill", tint: .accentColor) {
                            store.rerunDev(id: target.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array((session?.lines ?? []).enumerated()), id: \.offset) { idx, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(10)
                }
                .frame(height: 380)
                .onAppear {
                    // Ao abrir/reabrir, vai direto pro fim (sem animação).
                    DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: session?.lines.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func headerButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.15)))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func statusText(_ s: LogSession) -> String {
        if s.running { return "rodando…" }
        if s.stoppedByUser { return "parado" }
        guard let code = s.exitCode else { return "concluído" }
        return code == 0 ? "concluído com sucesso" : "terminou com erro (código \(code))"
    }

    private func statusColor(_ s: LogSession) -> Color {
        if s.running { return .secondary }
        if s.stoppedByUser { return .secondary }
        return s.exitCode == 0 ? .green : .red
    }
}

// MARK: - Liquid glass (Tahoe) com fallback material

extension View {
    /// Aplica o efeito liquid glass no macOS Tahoe (26+); cai para
    /// .ultraThinMaterial em versões anteriores.
    @ViewBuilder func liquidGlass() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.ultraThinMaterial)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
