# Feature 05 — sobre-versao

Aba "Sobre" e sistema de versão com checagem de atualização, no padrão do Soprano.

## Critérios de aceite
- [x] AppInfo com versão/tag/URLs + helpers versionCore/isNewerVersion.
- [x] checkForUpdate consulta as tags do GitHub e marca updateTag se houver versão nova.
- [x] Aba "Sobre" (ícone, versão, status de update, link do repo, git pull && ./build.sh).
- [x] Badge "Atualizar (tag)" no rodapé do painel quando há release nova.

## Decisões
- Versão inicial: 0.1.0 beta / tag v0.1.0-beta.
- Repo: github.com/bellinivitor/overseer (público).

## Tasks
- [x] [01 — Sobre + versão + update](01-sobre-versao.md)
