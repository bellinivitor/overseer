<div align="center">

# 🗂️ Overseer

### Todos os seus projetos de dev, a um clique da barra de menu.

**Pare de caçar terminais e de abrir o Docker Desktop.** O Overseer mora na barra
de menu do seu Mac e te dá, num único painel, o raio-x de todos os projetos que
você tem na máquina: o que está no ar, em que branch, quanto ocupa em disco — e
sobe, derruba ou roda cada um sem sair do lugar.

![versão](https://img.shields.io/github/v/release/bellinivitor/overseer?include_prereleases&label=vers%C3%A3o)
![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![licença](https://img.shields.io/github/license/bellinivitor/overseer)

</div>

---

## Por que você vai querer

Quem toca vários projetos ao mesmo tempo vive a mesma dança: abrir o Docker
Desktop, lembrar em qual pasta estava, achar o terminal certo, subir o compose,
abrir a IDE, checar a branch… vezes cinco. O Overseer colapsa tudo isso num
painel só — **troca de contexto em segundos, não em minutos.**

## O que ele faz

- **🔎 Acha seus projetos sozinho.** Varre os diretórios que você escolher e
  agrupa por pasta, detectando projetos por `docker-compose`, `.git`,
  `package.json` ou `composer.json`.
- **🟢 Status ao vivo.** Vê num relance quais containers estão no ar (bolinha
  verde), a branch atual e se tem **alterações não commitadas** (com ahead/behind).
- **🐳 Docker sem Docker Desktop.** Sobe (`up -d`) e derruba (`down`) os
  containers de um projeto com um clique — e acompanha a saída num **painel de
  log ao vivo**.
- **⚡ Task runner embutido.** Roda o servidor de dev do projeto (`npm run dev`,
  `php artisan serve`, `cargo run`… **detectado automaticamente**) com log limpo,
  start/stop e o processo continuando vivo enquanto você trabalha.
- **📊 Contexto de cada projeto.** Tamanho em disco e principais linguagens,
  calculados em segundo plano.
- **🚀 Abra do seu jeito.** Duplo-clique abre na sua IDE; pelo menu você abre no
  Finder, no terminal, no **repositório do GitHub** (no navegador) ou manda um
  **"Abrir Claude Code"** já na pasta. Botão direito escolhe outra IDE na hora.
- **🌐 Um clique pro navegador.** Detecta as portas publicadas dos containers e
  oferece **"Abrir localhost:PORT"**.
- **⭐ Favoritos, busca e grupos.** Fixe os projetos do dia no topo, filtre por
  nome/caminho e minimize os grupos que não está usando (tudo persistido).
- **⌨️ Atalho global.** Defina um atalho e chame o Overseer de qualquer app.
- **🪶 Leve de verdade.** Sem timers em segundo plano: parado, fica em ~0% de CPU
  e alguns MB de RAM. Visual _liquid glass_ nativo.

## Instalação

Precisa de **macOS 13+** e das ferramentas de linha de comando do Xcode
(`xcode-select --install`).

```bash
git clone https://github.com/bellinivitor/overseer.git
cd overseer
./build.sh
open build/Overseer.app
```

O app aparece **só na barra de menu** (não ocupa o Dock). Clique no ícone de
camadas pra abrir o painel.

> **Ícone (opcional):** `cd icon && ./makeicon.sh` gera o `AppIcon.icns`, que o
> `build.sh` embute automaticamente.

## Primeiros passos

1. Abra o painel e clique em **⚙ → Geral → Diretórios de scan** para apontar
   onde ficam seus projetos (ex.: `~/www`, `~/code`). Pode adicionar vários.
2. Em **Aplicativos**, escolha seu **editor/IDE** e **terminal** padrão.
3. (Opcional) Em **Geral**, defina um **atalho global** pra abrir o Overseer.
4. Pronto: passe o mouse numa linha e use ▶ pra subir o Docker, ⚡ pra rodar o
   dev, ⭐ pra favoritar, ou duplo-clique pra abrir na IDE.

## Como funciona

- **SwiftUI nativo**, `MenuBarExtra` + `LSUIElement` (vive na barra de menu).
- Compilado direto com `swiftc` via `./build.sh` — **sem projeto Xcode**.
- Roda `git`, `docker` e o comando de dev via `Process`, no diretório de cada
  projeto. Nada sai da sua máquina.

## Privacidade

O Overseer não tem servidor, não coleta nada e não manda seus dados pra lugar
nenhum. A única chamada de rede é opcional: checar no GitHub se há uma versão
nova. Ao abrir o repositório no navegador, eventuais credenciais embutidas na URL
do remote são removidas antes.

## Contribuindo

Issues e PRs são bem-vindos. O desenvolvimento é organizado em `tasks/`, uma
feature por pasta.

## Licença

MIT © Vitor Bellini
