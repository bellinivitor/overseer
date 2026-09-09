# Feature 04 — apps-padrao-menu

Configurar os apps padrão (Editor/IDE e Terminal) e ampliar o menu de ações do
projeto (abrir repositório no navegador, abrir Claude Code).

## Critérios de aceite
- [x] Config → Geral tem seção "Aplicativos padrão" com pickers de Editor/IDE e Terminal (apps instalados detectados) e opção de escolher outro .app.
- [x] O menu do projeto usa e mostra os apps configurados ("Abrir no <IDE>", "Abrir no <Terminal>").
- [x] Menu tem "Abrir repositório" (remote git normalizado, sem credenciais, no navegador padrão).
- [x] Menu tem "Abrir Claude Code" (abre o terminal configurado na pasta e roda `claude`).

## Decisões
- Remote SSH é convertido para https; credenciais embutidas na URL são removidas antes de abrir (segurança).
- "Abrir Claude Code": Terminal/iTerm via AppleScript (cd + claude); demais terminais via script .command.
- "Abrir repositório" só aparece quando há remote `origin`.

## Tasks
- [x] [01 — Apps padrão + ações de menu](01-apps-padrao-menu.md)
