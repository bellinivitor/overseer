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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if store.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.groups) { group in
                            GroupSection(group: group, store: store)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 460)
            }
            Divider()
            footer
        }
        .frame(width: 360)
        .onAppear { if store.groups.isEmpty { store.rescan() } }
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
        HStack {
            Text(store.isScanning ? "Atualizando…" : "\(store.groups.count) grupos")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Sair")
                    .font(.system(size: 11.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Grupo

struct GroupSection: View {
    let group: ProjectGroup
    @ObservedObject var store: AppStore

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
                ProjectRow(project: project, status: store.status[project.id])
            }
        }
    }
}

// MARK: - Linha do projeto

struct ProjectRow: View {
    let project: Project
    let status: ProjectStatus?

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
            }
            Spacer(minLength: 0)

            statusDot
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
