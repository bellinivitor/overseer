import SwiftUI

// MARK: - App
//
// Overseer: app de menu bar que lista os projetos de dev de ~/www.
// Esta é a Task 01 — só o esqueleto: menu bar + painel placeholder.
// Scanner, status docker/git, tamanho, linguagens, ações e busca vêm nas
// próximas tasks.

@main
struct OverseerApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "square.stack.3d.up")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Conteúdo do menu (placeholder)

struct MenuContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Overseer")
                        .font(.system(size: 14.5, weight: .semibold))
                    Text("~/www")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            Text("Esqueleto pronto. Os projetos aparecem aqui nas próximas tasks.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Sair")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
        }
        .padding(16)
        .frame(width: 320)
    }
}
