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
        }
        .frame(width: 440, height: 280)
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
