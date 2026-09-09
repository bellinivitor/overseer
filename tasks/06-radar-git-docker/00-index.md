# Feature 06 — radar-git-docker

Torna o painel um radar de "onde estou / o que está rodando": git sujo,
auto-refresh do docker com o painel aberto, badge na barra de menu e abrir
localhost:PORT.

## Critérios de aceite
- [x] Linha do projeto indica alterações não commitadas (bolinha) e ahead/behind.
- [x] Status docker atualiza sozinho a cada ~5s enquanto o painel está aberto (para ao fechar).
- [x] Ícone da barra mostra quantos projetos estão com containers no ar.
- [x] Menu do projeto lista "Abrir localhost:PORT" para as portas publicadas quando up.

## Decisões
- `git status --porcelain=v1 --branch` numa chamada dá branch + dirty + ahead/behind.
- `docker compose ps --format json` dá up + portas publicadas (Publishers.PublishedPort).
- Scan inicial no launch para o badge refletir sem abrir o painel; sem timers com o painel fechado (idle ~0).
- Auto-refresh recalcula só o docker (preserva git), com concorrência limitada.

## Tasks
- [x] [01 — Git sujo + auto-refresh + badge + localhost](01-radar.md)
