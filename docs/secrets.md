# Secrets e integração com 1Password

Este repo deliberadamente não guarda nenhum secret em texto plano na árvore pública.

## Dois padrões lado a lado

| Caso de uso | Abordagem | Estado hoje |
|---|---|---|
| **Credenciais de serviços systemd** (senha de banco, token de API, certificado TLS) | `services.onepassword-secrets` (opnix) | **disponível, nada declarado** |
| **Dotfiles** (`.zshrc`, `.gitconfig`, `.inputrc`) | Itens do tipo *Document* no seu vault | funciona; lista vazia por padrão |

Sobre a coluna da direita: o input `opnix` está em `flake.nix` e o módulo é
carregado em toda máquina, mas **este repo não declara secret nenhum com ele**.
A seção [OpNix](#opnix) abaixo é o que você precisa escrever, não algo que já
está no ar. O mesmo vale para os dotfiles: a fiação existe e funciona, mas
`vars.dotfilesFrom1Password` vem vazio.

## 1Password CLI/GUI

Módulo `system/app/1password/default.nix`:

- `programs._1password.enable` — CLI (`op`)
- `programs._1password-gui.enable` — Aplicativo desktop, com `polkitPolicyOwners`

Controle pelas opções `lcars.apps.onePassword.*` (`enableCli`, `enableGui`,
`enableSshAgent`, `polkitOwner`), cujos defaults vêm de `vars/local.nix`.

**Não existe `services._1password` no NixOS.** O agente SSH não é um serviço do
sistema: é um recurso do próprio aplicativo, ligado em **Settings → Developer →
Use the SSH agent**. O que o módulo faz é apontar o `ssh` do sistema para o
socket que o app cria:

```
Host *
  IdentityAgent ~/.1password/agent.sock
```

Depois de instalar, abra a GUI e faça pareamento com o app mobile via QR code (o 1Password 8 suporta isso sem conta de email). Depois de pareado, desbloqueie qualquer sessão da área de trabalho em que confia e o agente SSH expõe as chaves do host.

O 1Password é software proprietário. O módulo libera exatamente esses pacotes
via `nixpkgs.config.allowUnfreePredicate`, sem ligar `allowUnfree` global.

## OpNix

> **Nada disto está declarado no repo.** O módulo está carregado e pronto; o
> exemplo abaixo é o que você acrescenta na sua máquina quando tiver um serviço
> que precise de secret.

Para serviços que precisam de um secret em disco:

```nix
services.onepassword-secrets = {
  enable = true;
  tokenFile = "/etc/opnix-token";
  secrets.db-password = {
    reference = "op://Homelab/Postgres/password";
    services = [ "postgresql" ];
  };
};
```

`/etc/opnix-token` precisa conter um token de conta de serviço (`ops_...`), criado em 1Password → Developer Settings. Trate esse token como um secret normal — rotação trimestral é recomendada.

## Dotfiles vindos do 1Password

Para `.zshrc`/`.gitconfig` e similares, guarde-os como um item **Document** num vault pessoal. Depois liste-os em `vars/local.nix`:

```nix
dotfilesFrom1Password = [ "zshrc" "gitconfig" ];
```

Use os caminhos **sem** `./` — eles viram nomes de atributo em
`xdg.configFile`. O item correspondente no vault é
`op://<vault>/dotfiles-<rel>/file`.

Durante `nixos-rebuild switch`, o Home Manager lê os itens Document correspondentes e popula `~/.config/dotfiles/`. Como cada máquina tem seu próprio vault ou referência única por dotfile, os secrets ficam isolados por escopo.

## Escape hatch

Se algum pedaço pessoal se recusar a morar no 1Password (por exemplo, scripts locais referenciando `$HOME/<caminho-secreto>`), coloque em:

```bash
~/.config/home-manager/private.nix
```

O Home Manager carrega esse arquivo automaticamente depois de `user/`. Ele NÃO fica neste repo e NÃO é rastreado em lugar nenhum por padrão.

## Por que não um repo privado?

Manter tudo em 1Password + arquivos locais em `~/.config/home-manager` significa:

1. O repo pode continuar **público** sem vazar bits de identidade.
2. Ainda existe uma fonte única da verdade (seu vault).
3. Adicionar um segundo repo adiciona atrito (overrides de input, sincronização, deploy keys) sem benefício proporcional.
4. Quando chegar a hora de crescer um repo privado, o input `lcars-private` já está cabeado e comentado em `flake.nix` — basta ligar o interruptor.

## Quando migrar para um repo privado

Adicione `lcars-private` se:
- Você quiser histórico pessoal em git (não só o estado atual)
- Colaborar com outras pessoas numa infra compartilhada
- Ultrapassar o modelo um-usuário-por-máquina
- Hostnames/layouts de rede merecerem uma camada extra

Descomente no `flake.nix`, faça push do repo e rode:

```bash
nixos-rebuild switch --flake .#<host> \
  --override-input lcars-private "git+ssh://git@github.com/<voce>/lcars-private.git"
```
