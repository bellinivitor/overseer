import SwiftUI

// MARK: - Painel de detalhe do projeto
//
// Aberto com clique único na linha. Concentra as ações do projeto (git, docker
// com uso de recursos, e abrir em apps) num só lugar, deixando a linha da lista
// enxuta. Hierarquia de navegação: lista → detalhe → log.
//
// Estética: chrome nativo de macOS — barra de navegação com voltar, seções
// agrupadas (estilo Ajustes do Sistema), pop-up nativo de branch e botões
// .bordered para as ações principais.

struct ProjectDetailView: View {
    @ObservedObject var store: AppStore
    let project: Project
    let onBack: () -> Void
    let onOpenLog: (LogTarget) -> Void

    @State private var branches: [String] = []
    @State private var conflictingBranches: Set<String> = []
    @State private var changes: [GitChange] = []
    @State private var lastCommit: LastCommit?
    @State private var stats: [ContainerStat] = []
    @State private var loadingGit = false
    @State private var loadingStats = false
    @State private var busyGit = false          // checkout/stash em andamento
    @State private var gitError: String?
    @State private var backHover = false
    @State private var branchHover = false

    private var status: ProjectStatus? { store.status[project.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if project.hasGit { section("Git") { gitContent } }
                    if project.hasCompose { section("Docker") { dockerContent } }
                    section("Ações") { actionsContent }
                }
                .padding(14)
            }
            .frame(minHeight: 300, maxHeight: 460)
        }
        .onAppear {
            loadGit()
            if status?.dockerUp == true { loadStats() }
        }
    }

    // MARK: Barra de navegação

    private var header: some View {
        HStack(spacing: 11) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(backHover ? 0.10 : 0)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { backHover = $0 }
            .help("Voltar à lista")

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.gradient)
                .frame(width: 32, height: 32)
                .overlay(Text(project.initials)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(project.displayPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            Button {
                store.toggleFavorite(project)
            } label: {
                Image(systemName: store.isFavorite(project) ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(store.isFavorite(project) ? Color.yellow : Color.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(store.isFavorite(project) ? "Remover dos favoritos" : "Favoritar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Git

    @ViewBuilder private var gitContent: some View {
        // Branch atual como pop-up nativo de largura total (trunca no meio).
        branchPicker

        // Estado do repo numa linha própria, para nunca competir por largura
        // com o nome da branch.
        HStack(spacing: 8) {
            if status?.dirty == true {
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("não commitado").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .fixedSize()
            } else if status?.branch != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(.green)
                    Text("limpo").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .fixedSize()
            }
            Spacer(minLength: 0)
            if let s = status, s.ahead > 0 || s.behind > 0 {
                Text((s.ahead > 0 ? "↑\(s.ahead) " : "") + (s.behind > 0 ? "↓\(s.behind)" : ""))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help("\(s.ahead) à frente, \(s.behind) atrás do upstream")
            }
        }

        // Arquivos não commitados.
        if !changes.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                ForEach(changes.prefix(15)) { changeRow($0) }
                if changes.count > 15 {
                    Text("+\(changes.count - 15) arquivo(s)")
                        .font(.system(size: 10.5)).foregroundStyle(.tertiary).padding(.leading, 24)
                }
            }
        }

        Divider()

        // Última atividade.
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 18)
            if loadingGit && lastCommit == nil {
                Text("carregando…").font(.system(size: 12)).foregroundStyle(.tertiary)
            } else if let c = lastCommit {
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.subject).font(.system(size: 12)).lineLimit(1)
                    Text("\(c.relative) · \(c.author)")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("sem commits").font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }

        // Stash (só quando há o que guardar).
        if status?.dirty == true {
            Button {
                gitError = nil
                runGit { done in store.stashChanges(project) { err in gitError = err; done() } }
            } label: {
                Label("Stash", systemImage: "tray.and.arrow.down")
            }
            .controlSize(.small)
            .disabled(busyGit)
            .help("git stash push — guarda as alterações rastreadas")
        }

        if let err = gitError {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                    Text(friendlyGitError(err))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(err)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12)))
        }
    }

    /// Traduz os erros de checkout mais comuns para um recado acionável; para o
    /// resto, uma mensagem genérica (o texto cru do git aparece logo abaixo).
    private func friendlyGitError(_ err: String) -> String {
        let e = err.lowercased()
        if e.contains("would be overwritten") || e.contains("commit your changes or stash") {
            return "Não dá pra trocar: há alterações não commitadas. Faça Stash (ou commit) primeiro — nada foi perdido."
        }
        if e.contains("did not match any") || e.contains("invalid reference") {
            return "Branch não encontrada."
        }
        return "Não foi possível trocar de branch — nada foi alterado."
    }

    private func changeRow(_ c: GitChange) -> some View {
        let badge = changeBadge(c.status)
        return HStack(spacing: 8) {
            Text(badge.letter)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(badge.color)
                .frame(width: 16, alignment: .center)
            Text(c.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .help("\(badge.help): \(c.path)")
    }

    /// Letra + cor + descrição para o código de status do porcelain.
    private func changeBadge(_ status: String) -> (letter: String, color: Color, help: String) {
        if status == "??" { return ("?", .secondary, "Novo (não rastreado)") }
        let s = Set(status)
        if s.contains("U") { return ("U", .red, "Conflito (unmerged)") }
        if s.contains("D") { return ("D", .red, "Removido") }
        if s.contains("R") { return ("R", .blue, "Renomeado") }
        if s.contains("A") { return ("A", .green, "Adicionado") }
        if s.contains("M") { return ("M", .orange, "Modificado") }
        return (status.trimmingCharacters(in: .whitespaces), .secondary, "Alterado")
    }

    /// Pop-up nativo mostrando a branch atual; escolher outra faz o checkout.
    private var branchPicker: some View {
        Menu {
            if branches.isEmpty {
                Text("Nenhuma branch")
            } else {
                ForEach(branches, id: \.self) { b in
                    let conflicts = conflictingBranches.contains(b)
                    Button {
                        guard b != status?.branch else { return }
                        gitError = nil
                        runGit { done in store.switchBranch(project, to: b) { err in gitError = err; done() } }
                    } label: {
                        if b == status?.branch {
                            Label(b, systemImage: "checkmark")
                        } else if conflicts {
                            Label("\(b)  —  conflita com suas alterações", systemImage: "exclamationmark.triangle")
                        } else {
                            Text(b)
                        }
                    }
                    .disabled(conflicts)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 10)).foregroundStyle(.secondary)
                if busyGit {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(status?.branch ?? "—")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                // Disclosure em accent, dentro de um quadradinho — sinaliza que
                // é um pop-up para trocar de branch.
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15)))
            }
            .foregroundStyle(.primary)
            .padding(.leading, 9).padding(.trailing, 4).padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(branchHover ? 0.11 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { branchHover = $0 }
        .help("Trocar de branch")
        .disabled(busyGit || branches.isEmpty)
    }

    // MARK: Docker + recursos

    @ViewBuilder private var dockerContent: some View {
        let up = status?.dockerUp == true
        HStack(spacing: 8) {
            Circle()
                .fill(up ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 8, height: 8)
                .shadow(color: up ? Color.green.opacity(0.6) : .clear, radius: 3)
            Text(up ? "containers no ar" : "containers parados")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            composeButton
        }

        if let ports = status?.ports, !ports.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "network").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 18)
                ForEach(ports, id: \.self) { port in
                    Button("localhost:\(port)") { Actions.openURL("http://localhost:\(port)") }
                        .buttonStyle(.link)
                        .font(.system(size: 11.5, design: .monospaced))
                }
            }
        }

        if up {
            Divider()
            HStack(spacing: 6) {
                Text("Uso de recursos").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { loadStats() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(loadingStats)
                .help("Atualizar uso de recursos")
            }
            if loadingStats && stats.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("medindo…").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            } else if stats.isEmpty {
                Text("sem dados de uso").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 7) { ForEach(stats) { statRow($0) } }
            }
        }
    }

    private func statRow(_ stat: ContainerStat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(stat.name)
                    .font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Text(stat.cpu)
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary)
                    .help("CPU")
            }
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(memColor(stat.memPercent).gradient)
                            .frame(width: max(3, geo.size.width * min(stat.memPercent, 100) / 100))
                    }
                }
                .frame(height: 5)
                Text(stat.mem)
                    .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary).fixedSize()
            }
        }
    }

    private func memColor(_ pct: Double) -> Color {
        pct > 85 ? .red : (pct > 60 ? .orange : .accentColor)
    }

    @ViewBuilder private var composeButton: some View {
        let running = store.logs[project.id]?.running == true
        let up = status?.dockerUp == true
        Button {
            store.runCompose(project, up: !up)
            onOpenLog(LogTarget(id: project.id, dev: false))
        } label: {
            if running {
                ProgressView().controlSize(.small)
            } else {
                Label(up ? "Derrubar" : "Subir", systemImage: up ? "stop.fill" : "play.fill")
            }
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .tint(up ? .red : .green)
        .disabled(running)
    }

    // MARK: Ações (abrir em apps + dev)

    @ViewBuilder private var actionsContent: some View {
        ActionRow(title: "Abrir no \(store.ideDisplayName)", icon: "chevron.left.forwardslash.chevron.right", tint: .accentColor) {
            Actions.open(inApp: store.ideApp, path: project.path)
        }
        ActionRow(title: "Abrir no Finder", icon: "folder") { Actions.revealInFinder(project.path) }
        ActionRow(title: "Abrir no \(store.terminalDisplayName)", icon: "terminal") {
            Actions.open(inApp: store.terminalApp, path: project.path)
        }
        ActionRow(title: "Abrir Claude Code", icon: "sparkles") {
            Actions.openClaudeCode(path: project.path, terminalApp: store.terminalApp)
        }
        if let remote = store.remotes[project.id] {
            ActionRow(title: "Abrir repositório", icon: "arrow.up.right.square") { Actions.openURL(remote) }
        }

        Divider().padding(.vertical, 3)

        let running = store.isDevRunning(project)
        if store.hasDevCommand(project) {
            ActionRow(title: running ? "Ver log do dev (rodando)" : "Rodar dev",
                      icon: running ? "bolt.fill" : "bolt",
                      tint: running ? .green : .secondary) {
                if !running { store.runDev(project) }
                onOpenLog(LogTarget(id: project.id, dev: true))
            }
        }
        ActionRow(title: "Definir comando de dev…", icon: "pencil") { store.promptDevCommand(for: project) }
        if store.devRuns[project.id] != nil {
            ActionRow(title: "Ver log do dev", icon: "doc.text") { onOpenLog(LogTarget(id: project.id, dev: true)) }
        }
    }

    // MARK: Seção genérica (rótulo + grupo)

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 9) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
                )
        }
    }

    // MARK: Carregamento

    private func loadGit() {
        loadingGit = true
        let path = project.path
        let current = status?.branch
        let dirty = status?.dirty == true
        Task.detached(priority: .userInitiated) {
            let bs = StatusProbe.localBranches(at: path)
            let lc = StatusProbe.lastCommit(at: path)
            // Só calcula conflitos/arquivos quando há alterações locais (senão a
            // troca é sempre segura e não vale gastar chamadas extras de git).
            let conflicts = dirty ? StatusProbe.conflictingBranches(at: path, current: current, among: bs) : []
            let ch = dirty ? StatusProbe.changes(at: path) : []
            await MainActor.run {
                self.branches = bs
                self.lastCommit = lc
                self.conflictingBranches = conflicts
                self.changes = ch
                self.loadingGit = false
            }
        }
    }

    private func loadStats() {
        loadingStats = true
        let path = project.path
        Task.detached(priority: .utility) {
            let s = StatusProbe.dockerStats(at: path)
            await MainActor.run {
                self.stats = s
                self.loadingStats = false
            }
        }
    }

    /// Executa uma ação de git que reporta conclusão, controlando o estado busy.
    private func runGit(_ op: (@escaping () -> Void) -> Void) {
        guard !busyGit else { return }
        busyGit = true
        op {
            busyGit = false
            loadGit()   // recarrega branches/último commit após a mudança
        }
    }
}

// MARK: - Linha de ação (estilo item de menu nativo, com hover)

private struct ActionRow: View {
    let title: String
    let icon: String
    var tint: Color = .secondary
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12.5))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(hover ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
