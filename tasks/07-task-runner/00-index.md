# Feature 07 — task-runner

Rodar um comando de dev por projeto (npm run dev, php artisan serve…) direto do
painel, com log ao vivo e start/stop.

## Critérios de aceite
- [x] Comando de dev auto-detectado (package.json scripts, artisan, composer dev, cargo, go, manage.py) e editável por projeto (persistido).
- [x] Botão de dev (bolt) na linha inicia/para o comando e abre o painel de logs.
- [x] O processo é realmente morto ao parar (sem órfãos) — via exec + terminate.
- [x] Menu com "Rodar/Parar dev", "Definir comando de dev…" e "Ver logs do dev".

## Decisões
- Roda via `zsh -lc` (PATH de login). Comando simples usa `exec` (parar mata o servidor); composto roda sem exec.
- Painel de logs reutilizado (LogTarget distingue docker x dev).

## Tasks
- [x] [01 — Task runner por projeto](01-task-runner.md)
