# Tamanho em disco + linguagens

> Status: done · Ordem: 04 · Depende de: 02

## Objetivo
Mostrar, por projeto, o tamanho ocupado em disco e as principais linguagens usadas.

## Contexto
- Tamanho: `du -sh <path>` (ou `du -sk` para ordenar), rodado assíncrono; cache por projeto pra não recomputar a cada abertura. Mostrar "…" enquanto calcula.
- Linguagens: heurística leve — marker files (`composer.json`→PHP, `package.json`→JS/TS, `Cargo.toml`→Rust, `go.mod`→Go, `*.xcodeproj`/`Package.swift`→Swift, `requirements.txt`/`pyproject.toml`→Python…) + contagem das extensões dominantes no topo do projeto (ignorando `node_modules`, `vendor`, `.git`). Exibir 1–3 linguagens como chips.
- Restrições: `du` em projeto com `node_modules` grande é lento → sempre assíncrono, nunca no main thread; contagem de extensões deve ser rasa/limitada pra não varrer a árvore inteira.

## Critérios de aceite
- [ ] Cada projeto mostra o tamanho em disco (ex.: `1,2 GB`), calculado sem travar a UI.
- [ ] Cada projeto mostra 1–3 linguagens detectadas coerentes com o conteúdo real.
- [ ] Tamanho fica em cache; abrir de novo não recomputa até um refresh.

## Fora de escopo
- Precisão tipo GitHub Linguist — é heurística leve, intencionalmente.
- Ações e busca (tasks 05/06).

## Definição de pronto
- [ ] `build.sh` compila; tamanho e linguagens conferidos em ≥3 projetos reais (evidência: comparar `du -sh` no terminal).
- [ ] Cálculos assíncronos + cache; UI fluida.
- [ ] Segue o contrato do CLAUDE.md.
