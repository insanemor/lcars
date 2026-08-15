# Documentação

| Documento | Para quê |
|---|---|
| [features.md](./features.md) | **O que vem instalado** — inventário de tudo que uma instalação entrega, por profile e por módulo |
| [adding-a-host.md](./adding-a-host.md) | Adicionar uma máquina, escolher e criar profiles, resolver problemas comuns |
| [secrets.md](./secrets.md) | 1Password (CLI, GUI, agente SSH), dotfiles via Document, e opnix para serviços |
| [workflow.md](./workflow.md) | Como mudanças entram no repo: issue, branch, merge `--no-ff`, e o `scripts/check.sh` |

Para instalar, comece pelo [README](../README.md) da raiz.

## Onde mexer em cada coisa

| Quero… | Vá em |
|---|---|
| **Mudar qualquer coisa da minha instalação** | **`settings.nix`** |
| Renomear a máquina | renomear o diretório em `machines/` — é dele que vem o `networking.hostName` |
| Adicionar um pacote para todas as máquinas | `systemSettings.extraPackages` |
| Adicionar um pacote só para mim | `userSettings.packages` |
| Mudar o preset de um tipo de máquina | `profiles/<nome>/default.nix` |
| Mudar algo só numa máquina | `machines/<host>/default.nix` |
| Configurar zsh, git, direnv | `user/` |
| **Ligar ou desligar** zsh, git, direnv, dotfiles | `lcars.user.<módulo>.enable` (no profile ou na máquina) |
| Ligar ou desligar um módulo de sistema | `lcars.system.<caminho>.enable` (idem) |
| Trocar o ambiente gráfico | `system/wm/` |
| Abrir uma porta no firewall | `lcars.system.security.firewall.allowedTCPPorts` (no profile ou na máquina) |
| Autorizar uma chave SSH | `userSettings.sshKeys` |
