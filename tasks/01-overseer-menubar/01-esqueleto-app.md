# Esqueleto do app (menu bar + build)

> Status: done · Ordem: 01 · Depende de: —

## Objetivo
Ter um `Overseer.app` que compila com `swiftc` (sem Xcode), aparece só na barra de
menu e abre um painel vazio — a base pra todo o resto.

## Contexto
- Espelhar o Soprano (`~/www/projects/Soprano`): `build.sh`, `Info.plist` gerado inline, `MenuBarExtra`, `LSUIElement`, codesign ad-hoc.
- Arquivos a criar: `build.sh`, `app/App.swift`, `icon/` (ícone), `README.md`, `.gitignore`, `CLAUDE.md` (contrato).
- Restrições: sem sandbox (precisamos de `Process` pra git/docker depois); macOS 13+ (`.glassEffect()` fica pra task 06 com fallback).

## Critérios de aceite
- [ ] `./build.sh` gera `build/Overseer.app` sem erros e sem Xcode.
- [ ] `open build/Overseer.app` mostra um ícone na barra de menu e NENHum ícone no Dock (`LSUIElement`).
- [ ] Clicar no ícone abre um `MenuBarExtra` (janela/popover) com um placeholder ("Overseer" + texto).
- [ ] Bundle id `com.bellini.overseer`; `.gitignore` ignora `build/` e `.DS_Store`.

## Fora de escopo
- Scan de projetos, docker, git, visual liquid glass final (tasks seguintes).

## Definição de pronto
- [ ] `build.sh` compila sem erros; app abre e some do Dock (evidência: rodar e conferir).
- [ ] Segue o padrão Soprano e o contrato do CLAUDE.md.
- [ ] Sem segredos, sem comando destrutivo.
