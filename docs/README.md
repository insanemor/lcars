# Documentação

| Documento | Para quê |
|---|---|
| [features.md](./features.md) | **O que vem instalado** — inventário de tudo que uma instalação entrega, por profile e por módulo |
| [adding-a-host.md](./adding-a-host.md) | Adicionar uma máquina, escolher e criar profiles, resolver problemas comuns |
| [secrets.md](./secrets.md) | 1Password (CLI, GUI, agente SSH), dotfiles via Document, e opnix para serviços |
| [workflow.md](./workflow.md) | Como mudanças entram no repo: issue, branch, merge `--no-ff` |

Para instalar, comece pelo [README](../README.md) da raiz.

## Onde mexer em cada coisa

| Quero… | Vá em |
|---|---|
| Adicionar um pacote para todas as máquinas | `system/core/default.nix` |
| Adicionar um pacote só para mim | `vars/local.nix` (`userPackages`) |
| Mudar o preset de um tipo de máquina | `profiles/<nome>/default.nix` |
| Mudar algo só numa máquina | `machines/<host>/default.nix` |
| Configurar zsh, git, starship, direnv | `user/` |
| Trocar o ambiente gráfico | `system/wm/` |
| Abrir uma porta no firewall | `lcars.security.firewall.allowedTCPPorts` |
| Autorizar uma chave SSH | `lcars.security.sshKeys` |
