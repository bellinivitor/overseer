# Feature 03 — multi-dir-favoritos

Remove o "Configurar diretório" do painel, permite configurar N diretórios de
scan e adiciona favoritar projeto (card no topo, estilo Soprano).

## Critérios de aceite
- [x] Painel inicial não tem mais "Configurar diretório" ao lado de "Sair".
- [x] Config → Geral lista N diretórios com adicionar/remover; scan varre e junta todos.
- [x] Favoritar um projeto (estrela/menu) sobe ele para um card "Favoritos" no topo.
- [x] Favoritos e diretórios persistem entre execuções.

## Decisões
- Favoritar **move** o projeto para o card do topo (sai do grupo, sem duplicar).
- Header mostra o caminho único, ou "N diretórios" quando há mais de um.
- Grupos continuam mesclados por label; projetos duplicados entre roots são deduplicados.
- Skip de `wp-includes`/`wp-admin` para não listar libs internas do WordPress.

## Tasks
- [x] [01 — Remover botão, multi-diretório e favoritos](01-multi-dir-favoritos.md)
