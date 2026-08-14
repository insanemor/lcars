# Adicionando um novo host

Este documento explica o fluxo para adicionar uma nova máquina ao flake.

## 1. Clone o repo

```bash
git clone https://github.com/<dono>/lcars-public ~/lcars-public
cd ~/lcars-public
```

## 2. Gere suas vars privadas

```bash
nix run .#bootstrap
# ou: ./scripts/bootstrap.sh
```

Isso escreve `vars/local.nix`, que está no `.gitignore`. Contém seu usuário, nome completo, email, locale e preferências do 1Password.

## 3. Crie o diretório do host

```bash
cp -r hosts/template hosts/$(hostname -s)
```

Dentro de `hosts/<host>/default.nix`:

- Substitua `<replace-me>` pelo hostname real
- Ative `lcars.vm.enable`, `lcars.laptop.enable` e `lcars.desktop.enable` conforme o tipo de máquina

## 4. Gere a configuração de hardware

Na máquina **alvo**, rode:

```bash
nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
```

`hardware-configuration.nix` está no `.gitignore` por padrão. Revise em busca de números de série ou identificadores que você não quer expor; faça commit só depois da revisão manual.

## 5. Registre o host no `flake.nix`

```nix
nixosConfigurations = {
  meu-laptop = self.mkHost "meu-laptop" [ ./modules/laptop ./modules/desktop ];
  meu-pc     = self.mkHost "meu-pc"     [ ./modules/desktop ];
  minha-vm   = self.mkHost "minha-vm"   [ ./modules/vm ];
};
```

## 6. Builda e ativa

```bash
nixos-rebuild switch --flake .#meu-laptop
```

Para um dry-run primeiro:

```bash
nixos-rebuild dry-activate --flake .#meu-laptop
```

## Resolução de problemas

| Sintoma | Causa |
|---|---|
| `vars/local.nix` não encontrado | Rode `nix run .#bootstrap` |
| `cannot find hosts/<host>` | O diretório do host precisa bater com o nome usado em `mkHost` |
| `lcars.onePassword.enable` ausente | Você não incluiu o módulo `common` — ele é puxado por `mkHost` |
| Setup do `home-manager` pulado | Você contornou o `mkHost`. Sempre instancie hosts por meio dele |
