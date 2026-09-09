# Scanner de projetos

> Status: done · Ordem: 02 · Depende de: 01

## Objetivo
Varrer o diretório raiz (default `~/www`) e produzir a lista de projetos
agrupados por pasta pai, exibida no painel.

## Contexto
- Model `Project` (nome, path, grupo, flags de detecção) e `ProjectGroup` (label + projetos).
- Scanner: percorre o root com profundidade 2; um diretório é "projeto" se contém `docker-compose.yml`/`.yaml`, `.git`, `composer.json` ou `package.json`.
- Agrupamento por pasta pai relativa ao root (ex.: `tristar`, `urbs/sci`, `projects`).
- Root configurável (guardar em `UserDefaults`), default `~/www`. Botão de refresh.
- Restrições: rodar o scan off-main-thread; não travar a UI; ignorar `node_modules`, `vendor`, `.git` internos ao descer.

## Critérios de aceite
- [ ] Painel lista os projetos reais de `~/www`, agrupados por pasta pai, com contagem por grupo (bate com o `~/www` do usuário).
- [ ] Cada linha mostra nome + caminho (avatar/ícone pode ser placeholder aqui).
- [ ] Botão de refresh re-executa o scan.
- [ ] Root lido de `UserDefaults` com default `~/www`.

## Fora de escopo
- Status git/docker, tamanho, linguagens, busca (tasks seguintes).
- UI de "Configurar diretório" (task 06) — por ora pode ser default fixo + refresh.

## Definição de pronto
- [ ] `build.sh` compila; lista/grupos conferidos contra `~/www` real (evidência).
- [ ] Scan assíncrono, UI não trava.
- [ ] Segue o contrato do CLAUDE.md.
