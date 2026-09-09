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
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Conteúdo do menu

struct MenuContent: View {
    @ObservedObject var store: AppStore
    @State private var openLogFor: String?
    @State private var searchText = ""

    /// Grupos filtrados pela busca (nome, caminho ou grupo). Grupos sem match somem.
    private var filteredGroups: [ProjectGroup] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.groups }
        return store.groups.compactMap { g in
            if g.label.lowercased().contains(q) { return g }
            let hits = g.projects.filter {
                $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : ProjectGroup(id: g.id, label: g.label, projects: hits)
        }
    }

    var body: some View {
        Group {
            if let id = openLogFor {
                LogView(store: store, projectId: id, onBack: { openLogFor = nil })
            } else {
                list
            }
        }
        .frame(width: 360)
        .liquidGlass()
        .onAppear { if store.groups.isEmpty { store.rescan() } }
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
                        ForEach(filteredGroups) { group in
                            GroupSection(group: group, store: store,
                                         onOpenLog: { openLogFor = $0 })
                        }
                        if filteredGroups.isEmpty {
                            Text("Nenhum projeto para “\(searchText)”.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 460)
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
                Text("\(store.rootDisplay) · \(store.totalProjects) projetos")
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if store.isScanning {
                ProgressView().controlSize(.small)
                Text("Varrendo \(store.rootDisplay)…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Nenhum projeto encontrado em \(store.rootDisplay).")
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
            Button { store.chooseRoot() } label: {
                Text("Configurar diretório").font(.system(size: 11.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
    let onOpenLog: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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

            ForEach(group.projects) { project in
                ProjectRow(project: project, store: store, onOpenLog: onOpenLog)
            }
        }
    }
}

// MARK: - Linha do projeto

struct ProjectRow: View {
    let project: Project
    @ObservedObject var store: AppStore
    let onOpenLog: (String) -> Void

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
                statusDot
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
        .onHover { hovering = $0 }
    }

    /// Botão play/stop: sobe se estiver down, derruba se estiver up.
    @ViewBuilder private var composeButton: some View {
        Button {
            let goUp = !(status?.dockerUp == true)
            store.runCompose(project, up: goUp)
            onOpenLog(project.id)
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

    /// Menu de abrir o projeto.
    private var openMenu: some View {
        Menu {
            Button("Abrir no VS Code") { Actions.open(.vscode, path: project.path) }
            Button("Abrir no Finder") { Actions.open(.finder, path: project.path) }
            Button("Abrir no Terminal") { Actions.open(.terminal, path: project.path) }
            if store.logs[project.id] != nil {
                Divider()
                Button("Ver logs") { onOpenLog(project.id) }
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
    let projectId: String
    let onBack: () -> Void

    private var session: LogSession? { store.logs[projectId] }

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
                        Text(s.running ? "rodando…" : exitLabel(s.exitCode))
                            .font(.system(size: 10.5))
                            .foregroundStyle(s.running ? Color.secondary : (s.exitCode == 0 ? Color.green : Color.red))
                    }
                }
                Spacer()
                if session?.running == true { ProgressView().controlSize(.small) }
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
                .onChange(of: session?.lines.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func exitLabel(_ code: Int32?) -> String {
        guard let code else { return "concluído" }
        return code == 0 ? "concluído com sucesso" : "terminou com erro (código \(code))"
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
