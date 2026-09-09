import SwiftUI

// MARK: - Janela de configurações
//
// TabView com abas de configuração. Por ora só "Geral" (ordenação); a estrutura
// já deixa espaço para novas abas.

struct ConfigWindow: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TabView {
            GeralTab(store: store)
                .tabItem { Label("Geral", systemImage: "gearshape") }
            AplicativosTab(store: store)
                .tabItem { Label("Aplicativos", systemImage: "app.badge") }
            SobreTab(store: store)
                .tabItem { Label("Sobre", systemImage: "info.circle") }
        }
        .frame(width: 440, height: 300)
        .padding(20)
    }
}

// MARK: - Aba Geral

struct GeralTab: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Form {
            Section("Ordenação") {
                Picker("Ordenar projetos por", selection: Binding(
                    get: { store.sortOrder },
                    set: { store.sortOrder = $0 })) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                ForEach(store.roots, id: \.self) { path in
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(store.display(path))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            store.removeRoot(path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .disabled(store.roots.count <= 1)
                        .help("Remover")
                    }
                }
                Button {
                    store.addRoot()
                } label: {
                    Label("Adicionar diretório", systemImage: "plus")
                }
            } header: {
                Text("Diretórios de scan")
            } footer: {
                Text("O Overseer varre todos os diretórios listados (profundidade 3) e junta os projetos. A ordenação vale dentro de cada grupo; os grupos seguem alfabéticos.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Aba Aplicativos

struct AplicativosTab: View {
    @ObservedObject var store: AppStore

    private var ideOptions: [String] {
        var o = AppCatalog.installed(AppCatalog.ides)
        if !o.contains(store.ideApp) { o.append(store.ideApp) }
        return o
    }
    private var terminalOptions: [String] {
        var o = AppCatalog.installed(AppCatalog.terminals)
        if !o.contains(store.terminalApp) { o.append(store.terminalApp) }
        return o
    }

    var body: some View {
        Form {
            Section {
                Picker("Editor / IDE", selection: Binding(
                    get: { store.ideApp }, set: { store.ideApp = $0 })) {
                    ForEach(ideOptions, id: \.self) { Text(store.appDisplayName($0)).tag($0) }
                }
                HStack {
                    Spacer()
                    Button("Escolher outro editor…") { store.chooseApp(terminal: false) }
                        .controlSize(.small)
                }

                Picker("Terminal", selection: Binding(
                    get: { store.terminalApp }, set: { store.terminalApp = $0 })) {
                    ForEach(terminalOptions, id: \.self) { Text(store.appDisplayName($0)).tag($0) }
                }
                HStack {
                    Spacer()
                    Button("Escolher outro terminal…") { store.chooseApp(terminal: true) }
                        .controlSize(.small)
                }
            } header: {
                Text("Aplicativos padrão")
            } footer: {
                Text("Usados nas ações “Abrir no…” e “Abrir Claude Code” do menu de cada projeto.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Aba Sobre

struct SobreTab: View {
    @ObservedObject var store: AppStore
    private let repoURL = URL(string: AppInfo.repoURL)!
    private let releasesURL = URL(string: AppInfo.releasesURL)!

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name).font(.title).bold()
                    Text("versão \(AppInfo.version)").font(.caption).foregroundStyle(.secondary)
                }
            }

            Text("Seus projetos de dev na barra de menu: status Docker, branch git, tamanho, linguagens e start/stop com log — sem abrir o Docker Desktop.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Status de atualização (checado no GitHub).
            if let t = store.updateTag {
                Link(destination: releasesURL) {
                    Label("Nova versão disponível: \(t)", systemImage: "arrow.down.circle.fill")
                }
                .foregroundStyle(.orange).bold()
            } else {
                Label("Você está na versão mais recente", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "link").foregroundStyle(.secondary)
                Link("github.com/bellinivitor/overseer", destination: repoURL)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Atualizações saem no GitHub. Acompanhe o repositório e, para atualizar, rode:")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("git pull && ./build.sh")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
            }

            Spacer()
            Text("Feito por Vitor Bellini · Licença MIT")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
