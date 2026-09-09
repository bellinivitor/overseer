# 🗂️ Overseer

**Todos os seus projetos de dev num clique, direto da barra de menu.** O Overseer
varre o seu `~/www`, lista os projetos agrupados por pasta e mostra, de cada um, o
status dos containers Docker, a branch git, o tamanho em disco e as linguagens —
deixando você subir ou derrubar os containers (com log ao vivo) sem abrir o Docker
Desktop.

> Inspirado no JetBrains Toolbox, com visual _liquid glass_. Mesmo padrão de build
> do [Soprano](../Soprano): SwiftUI puro, sem Xcode.

## Como buildar

```bash
./build.sh
open build/Overseer.app
```

O app aparece **só na barra de menu** (não vai pro Dock). Clique no ícone pra
abrir o painel.

### Ícone (opcional)

```bash
cd icon && ./makeicon.sh   # gera icon/AppIcon.icns
```

O `build.sh` embute o `AppIcon.icns` se ele existir.

## Stack

- SwiftUI nativo, `MenuBarExtra`, `LSUIElement`.
- Compilado com `swiftc` (`./build.sh`) — sem Xcode project.
- Sem sandbox: usa `Process` pra rodar `git` e `docker` nos projetos.

## Status

Em desenvolvimento pelo fluxo em `tasks/`. Roadmap do v1:

1. ✅ Esqueleto (menu bar + build)
2. ⬜ Scanner de projetos (varre e agrupa)
3. ⬜ Status git + docker
4. ⬜ Tamanho em disco + linguagens
5. ⬜ Ações + painel de logs
6. ⬜ Busca + polimento visual (liquid glass)
