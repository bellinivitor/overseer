# Feature 01 — overseer-menubar

App de menu bar para Mac (SwiftUI, padrão Soprano) que lista os projetos de dev
de `~/www`, agrupados por pasta, com status Docker + branch git + tamanho em
disco + linguagens, e permite start/stop com painel de logs, busca e abrir no
editor/Finder.

## Objetivo
Trocar de contexto entre projetos sem abrir Docker Desktop: ver tudo num painel
liquid glass na barra de menu e subir/derrubar containers em um clique.

## Critérios de aceite (da feature)
- [ ] `./build.sh` gera `build/Overseer.app` sem Xcode; roda como `LSUIElement` (só menu bar).
- [ ] Ao abrir, lista os projetos de `~/www` (profundidade 2), agrupados por pasta pai, com contagem por grupo.
- [ ] Cada projeto mostra: nome, caminho, branch git, bolinha docker up/down, tamanho em disco, linguagens.
- [ ] Play/stop roda `docker compose up -d` / `down` e abre um painel de logs streamando a saída ao vivo.
- [ ] Busca filtra por nome/caminho; ações de abrir em VS Code / Finder / Terminal funcionam.
- [ ] Visual liquid glass (`.glassEffect()` com fallback `.ultraThinMaterial`), inspirado no mockup.

## Decisões tomadas (do planejamento)
- **Nome/identidade:** Overseer · bundle `com.bellini.overseer` · pasta `~/www/projects/overseer`.
- **Stack/build:** SwiftUI puro compilado com `swiftc` via `build.sh` (sem Xcode project), igual ao Soprano. `LSUIElement`, codesign ad-hoc, sem sandbox (permite `Process`/shell pra `git`/`docker`).
- **Diretório de scan:** configurável, default `~/www`, profundidade 2. Detecção por `docker-compose.yml/.yaml`, `.git`, `composer.json`, `package.json`.
- **Execução do docker:** painel de logs dentro do app streamando stdout/stderr do compose (não background silencioso, não Terminal externo).
- **Extras no v1:** tamanho em disco (`du -sh`, assíncrono + cache) e linguagens (marker files + extensões dominantes).
- **Fora do v1:** "subir todos do grupo", auto-start por regra, persistência de histórico.

## Como testar
1. `./build.sh && open build/Overseer.app`
2. Conferir lista/grupos contra o `~/www` real (tristar, urbs/sci, lexxen, projects…).
3. Num projeto com compose (ex.: `urbs/sci`), clicar play → ver painel de logs e a bolinha virar verde; clicar stop → cinza.
4. Verificar branch, tamanho e linguagens de alguns projetos; testar a busca.

## Nota sobre testes
Projeto Swift compilado com `swiftc` (padrão Soprano), sem suíte de testes
automatizada. "Definição de pronto" de cada task = `build.sh` compila sem erros +
verificação manual do critério de aceite (com evidência real, conforme o contrato).

## Tasks
- [x] [01 — Esqueleto do app](01-esqueleto-app.md) · build.sh, Info.plist, MenuBarExtra, ícone, README
- [x] [02 — Scanner de projetos](02-scanner-projetos.md) · varre e agrupa
- [x] [03 — Status git + docker](03-status-git-docker.md) · branch + bolinha up/down
- [x] [04 — Tamanho + linguagens](04-tamanho-linguagens.md) · du -sh + detecção de linguagens
- [x] [05 — Ações + painel de logs](05-acoes-painel-logs.md) · play/stop, logs, abrir editor/Finder
- [ ] [06 — Busca + polimento visual](06-busca-polimento-visual.md) · filtro, liquid glass, header/footer
