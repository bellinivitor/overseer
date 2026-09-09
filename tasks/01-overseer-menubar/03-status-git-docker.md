# Status git + docker

> Status: todo · Ordem: 03 · Depende de: 02

## Objetivo
Mostrar, por projeto, a branch git atual e se os containers estão up/down.

## Contexto
- Helper de shell via `Process` (padrão Soprano) para rodar comandos no diretório do projeto.
- Branch: `git rev-parse --abbrev-ref HEAD` (só em projetos com `.git`).
- Docker: `docker compose ps --format json` (só em projetos com `docker-compose.yml/.yaml`); considerar "up" se houver ao menos um serviço em execução.
- Atualização assíncrona por projeto; cache do último status; refresh recomputa.
- Restrições: `docker`/`git` podem faltar no PATH ou demorar → tratar erro/timeout sem travar; projeto sem git não mostra branch, sem compose não mostra bolinha.

## Critérios de aceite
- [ ] Projeto com `.git` mostra a branch atual (chip, estilo mockup).
- [ ] Projeto com compose mostra bolinha verde (up) / cinza (down) refletindo o estado real.
- [ ] Status carrega de forma assíncrona; refresh recomputa e a UI não trava enquanto isso.
- [ ] Comando ausente/erro é tratado silenciosamente (sem branch/sem bolinha), sem crash.

## Fora de escopo
- Start/stop e painel de logs (task 05).
- Tamanho/linguagens (task 04).

## Definição de pronto
- [ ] `build.sh` compila; branch e bolinha conferidos num projeto up e num down (evidência: subir um compose e comparar).
- [ ] Sem travar a UI; erros tratados.
- [ ] Segue o contrato do CLAUDE.md.
