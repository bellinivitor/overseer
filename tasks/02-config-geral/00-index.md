# Feature 02 — config-geral

Janela de configurações do Overseer, começando pela aba **Geral** com um select
de ordenação dos projetos.

## Objetivo
Dar um lugar para preferências do app e permitir ordenar os projetos por ordem
alfabética ou última modificação.

## Critérios de aceite
- [x] Botão de engrenagem no header abre a janela "Configurações do Overseer".
- [x] Janela em abas (`TabView`); primeira aba chamada **Geral**.
- [x] Aba Geral tem um select "Ordenar projetos por": Ordem alfabética | Última modificação.
- [x] A escolha reordena os projetos na hora e persiste entre execuções (UserDefaults).

## Decisões tomadas
- **"Última modificação"** = `contentModificationDate` da pasta do projeto (barato, capturado no scan). Refinamento futuro possível: usar o commit git mais recente.
- **Escopo da ordenação**: projetos dentro de cada grupo. Os grupos seguem em ordem alfabética.
- A aba Geral também expõe o diretório de scan atual + botão "Alterar…" (reaproveita o `chooseRoot`).

## Como testar
`./build.sh && open build/Overseer.app` → engrenagem no header → aba Geral →
trocar o select e ver a lista reordenar; reabrir o app e conferir que manteve.

## Tasks
- [x] [01 — Janela de config + aba Geral + ordenação](01-config-geral.md)
