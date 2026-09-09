# Janela de config + aba Geral + ordenação

> Status: done · Ordem: 01 · Depende de: —

## Objetivo
Criar a janela de configurações (abas) com a aba Geral e um select de ordenação
dos projetos (alfabética | última modificação), persistido.

## Critérios de aceite
- [x] Engrenagem no header abre a janela "Configurações do Overseer".
- [x] `TabView` com a primeira aba "Geral".
- [x] Select "Ordenar projetos por" com as duas opções; reordena na hora.
- [x] Persistência em UserDefaults (`sortOrder`).

## Definição de pronto
- [x] `build.sh` compila sem erros.
- [x] Ordenação por mtime validada contra projetos reais (harness).
- [x] Segue o contrato do CLAUDE.md.
