# Ações + painel de logs

> Status: done · Ordem: 05 · Depende de: 03

## Objetivo
Permitir subir/derrubar os containers de um projeto com um clique, vendo a saída
do compose ao vivo num painel dentro do app, e abrir o projeto no editor/Finder.

## Contexto
- Play/stop: `docker compose up -d` / `docker compose down` no diretório do projeto, via `Process`.
- Painel de logs: capturar stdout+stderr do processo em streaming (pipe + leitura incremental) e exibir num painel rolável dentro do app; enquanto roda, a bolinha vira estado "loading"; ao terminar, recomputa o status (task 03) → verde/cinza.
- Abrir: ações pra abrir o projeto no VS Code (`open -a` / `code`), no Finder (`open <path>`) e no Terminal (`open -a Terminal <path>`).
- Restrições: um processo por projeto por vez; tratar falha (compose ausente, erro de build) mostrando a saída de erro no painel; não bloquear a UI; encerrar/limpar o pipe ao fechar o painel.

## Critérios de aceite
- [ ] Play sobe os containers (`up -d`) e o painel mostra a saída do compose ao vivo; ao fim, bolinha fica verde.
- [ ] Stop derruba (`down`) e a bolinha fica cinza; a saída aparece no painel.
- [ ] Durante a execução há um estado visual de "rodando" e a UI não trava.
- [ ] Abrir no VS Code, Finder e Terminal funciona a partir da linha do projeto.
- [ ] Erro do compose aparece no painel sem crashar o app.

## Fora de escopo
- "Subir todos do grupo" (fora do v1).
- Busca e polimento visual final (task 06).

## Definição de pronto
- [ ] `build.sh` compila; testado up+down real num projeto com compose (ex.: `urbs/sci`), com evidência do painel de logs e da mudança de bolinha.
- [ ] Streaming sem travar a UI; erros tratados.
- [ ] Segue o contrato do CLAUDE.md.
