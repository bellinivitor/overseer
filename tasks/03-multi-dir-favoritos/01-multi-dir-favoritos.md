# Remover botão, multi-diretório e favoritos

> Status: done · Ordem: 01 · Depende de: —

## Critérios de aceite
- [x] Rodapé sem "Configurar diretório".
- [x] Store guarda `roots: [String]` (migra `rootPath` legado) + `favorites: Set`.
- [x] Scanner.scan(roots:) mescla e deduplica.
- [x] Config Geral: lista de diretórios com +/−; favoritos no card do topo.

## Definição de pronto
- [x] build.sh compila; merge e favoritos validados (harness + app rodando).
