# Git sujo + auto-refresh + badge + localhost

> Status: done · Ordem: 01 · Depende de: —

## Critérios de aceite
- [x] StatusProbe.gitInfo (branch/dirty/ahead/behind) e dockerInfo (up/portas).
- [x] UI: bolinha de dirty + ahead/behind na linha; itens localhost:PORT no menu.
- [x] Badge com runningCount na barra; scan no launch.
- [x] Timer de 5s só com painel aberto (onAppear/onDisappear).

## Definição de pronto
- [x] build.sh compila; probes validados (dirty real, porta 8099 exata); idle volta a ~0 após burst.
