# Overseer

App de menu bar para Mac que lista os projetos de dev de `~/www`, agrupados por
diretório, com status de containers Docker, branch git, tamanho em disco e
linguagens — permitindo start/stop rápido (com painel de logs) sem abrir o Docker
Desktop.

## Stack / build
- SwiftUI nativo, `MenuBarExtra`, `LSUIElement` (só barra de menu).
- Compilado com `swiftc` via `./build.sh` — **sem Xcode project** (padrão do
  projeto Soprano em `~/www/projects/Soprano`).
- `.app` com assinatura ad-hoc (`codesign --sign -`). **Sem sandbox**, para poder
  rodar `git`/`docker` via `Process`/shell.

## Arquitetura
- `app/` — código Swift (`App.swift` como entrypoint `@main`; arquivos separados
  por responsabilidade conforme o app cresce: model, scanner, shell, views).
- `icon/` — `makeicon.swift` desenha o ícone; `makeicon.sh` gera o `.icns`.
- `build.sh` — compila `build/Overseer.app`.
- `tasks/` — features e tasks do fluxo `dev-planejar`/`dev-task` (versionado).

## Contrato de trabalho
- Nada destrutivo (não apagar dados, não mexer em config de sistema).
- Sem segredos no código.
- Mudanças pequenas e revisáveis; um commit por task (Conventional Commits).
- Evidência real: `./build.sh` compila sem erros + verificação manual do critério
  de aceite antes de marcar uma task como `done`.
- Sem adicionar dependências externas (só frameworks do sistema) sem alinhar.

## Testes
Projeto Swift compilado com `swiftc`, sem suíte de testes automatizada (como o
Soprano). "Pronto" = build limpo + verificação manual com evidência.
