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
        }
        .frame(width: 440, height: 260)
        .padding(20)
    }
}

// MARK: - Aba Geral

struct GeralTab: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Form {
            Section {
                Picker("Ordenar projetos por", selection: Binding(
                    get: { store.sortOrder },
                    set: { store.sortOrder = $0 })) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Diretório de scan") {
                    HStack(spacing: 8) {
                        Text(store.rootDisplay)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Alterar…") { store.chooseRoot() }
                    }
                }
            } footer: {
                Text("A ordenação vale para os projetos dentro de cada grupo. Os grupos seguem em ordem alfabética.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
