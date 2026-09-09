# Busca + polimento visual

> Status: done · Ordem: 06 · Depende de: 04, 05

## Objetivo
Adicionar busca/filtro e deixar o painel com a estética liquid glass do mockup,
fechando o v1.

## Contexto
- Busca: campo no topo que filtra projetos por nome e caminho em tempo real; grupos vazios somem.
- Visual: aplicar `.glassEffect()` (macOS Tahoe) com fallback `.ultraThinMaterial`; layout inspirado no `context-switcher.html` (header com título + subtítulo "~/www · N projetos", linhas com avatar/inicial + nome + branch + status + ações, chevrons por grupo, footer com resumo + "Configurar diretório").
- "Configurar diretório": abrir `NSOpenPanel` pra escolher o root e persistir em `UserDefaults` (liga com a task 02).
- Referências: `~/Downloads/context-switcher.html` (mockup) e `~/Downloads/CLAUDE.md` (visão).
- Restrições: manter tudo fluido; glass não pode prejudicar legibilidade; respeitar tema claro/escuro do macOS.

## Critérios de aceite
- [ ] Campo de busca filtra por nome/caminho; grupos sem resultado desaparecem.
- [ ] Painel tem aparência liquid glass (com fallback material em versões sem `.glassEffect()`).
- [ ] Header mostra root + contagem; footer resume grupos com containers ativos e tem "Configurar diretório".
- [ ] "Configurar diretório" troca o root de scan e persiste entre execuções.
- [ ] Layout coerente com o mockup (grupos, chips de branch, bolinha, ações).

## Fora de escopo
- Animações elaboradas / temas customizados além de claro-escuro.
- "Subir todos do grupo" e demais itens fora do v1.

## Definição de pronto
- [ ] `build.sh` compila; busca, glass e "Configurar diretório" testados (evidência: screenshot do painel final).
- [ ] UI fluida em claro e escuro.
- [ ] Segue o contrato do CLAUDE.md.
