# DIVE + Rojo

Este repositório já está preparado para usar o **Rojo**.

## Estrutura

- `default.project.json`: mapeia a árvore do jogo (DataModel)
- `src/shared`: vai para `ReplicatedStorage/DIVE`
- `src/server`: vai para `ServerScriptService/DIVE`
- `src/client`: vai para `StarterPlayer/StarterPlayerScripts/DIVE`

## Como rodar

1) Instale o Rojo (CLI) no seu PC (ex.: via `cargo install rojo` ou usando o gerenciador que você preferir).

2) No terminal, dentro desta pasta, rode:

```powershell
rojo serve default.project.json
```

3) No Roblox Studio, instale/abra o plugin do Rojo e conecte no servidor (porta padrão `34872`).

## Extrair (exportar) um Place existente pro repo

Se você já tem um jogo pronto no Roblox Studio e quer “puxar tudo” (scripts e instâncias) pro repositório, use o **Syncback** (Rojo `7.7.0-rc.1+`).

1) No Roblox Studio: `File > Save to File...` e salve um `.rbxl`/`.rbxlx` dentro desta pasta (ex.: `place.rbxlx`).

2) No terminal, rode:

```powershell
rojo syncback -y syncback.project.json --input place.rbxlx
```

Isso vai criar/atualizar a pasta `src/` (ex.: `src/Workspace`, `src/ReplicatedStorage`, etc) com o conteúdo exportado.

## Teste rápido

- Ao iniciar o jogo, você deve ver prints do Server e do Client no output usando o módulo `ReplicatedStorage.DIVE.Shared`.
