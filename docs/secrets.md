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
`userSettings.dotfilesFrom1Password` vem vazio.

## 1Password CLI/GUI

Módulo `system/app/1password/default.nix`:

- `programs._1password.enable` — CLI (`op`)
- `programs._1password-gui.enable` — Aplicativo desktop, com `polkitPolicyOwners`

Controle pelas opções `lcars.system.app.onePassword.*` (`enableCli`, `enableGui`,
`enableSshAgent`, `polkitOwner`), cujos defaults vêm de `settings.nix`.

**Não existe `services._1password` no NixOS.** O agente SSH não é um serviço do
sistema: é um recurso do próprio aplicativo, ligado em **Settings → Developer →
Use the SSH agent**. O que o módulo faz é apontar o `ssh` do sistema para o
socket que o app cria:

```
Host *
  IdentityAgent ~/.1password/agent.sock
```

Depois de instalar, abra a GUI e faça pareamento com o app mobile via QR code (o 1Password 8 suporta isso sem conta de email). Depois de pareado, desbloqueie qualquer sessão da área de trabalho em que confia e o agente SSH expõe as chaves do host.

### A integração do `op` com o aplicativo é outra caixa

Pela mesma lógica do agente SSH, o `op` só conversa com o aplicativo se você
ligar isso **dentro dele** — e são duas opções, não uma:

| Onde | O quê |
|---|---|
| Settings → Security | **Unlock using system authentication** |
| Settings → Developer | **Integrate with 1Password CLI** |

São chaves independentes: ter o agente SSH funcionando **não** significa que a
do CLI está ligada. Sem ela, `op account list` vem vazio — mesmo com o
aplicativo aberto e logado.

E aí o `op read` **não** se limita a devolver erro: se houver um terminal, ele
abre o fluxo de configuração e pergunta `Do you want to add an account manually
now? [Y/n]`. Foi o que aconteceu no meio de um `nupdate` numa máquina nova
(#161). Redirecionar o stderr não segura o prompt, nem fechar o stdin: o `op`
escreve direto em `/dev/tty`. Por isso todo `op read` deste repositório roda
sob `setsid` — sem terminal de controle, ele falha em vez de perguntar, e a
ativação nunca fica esperando alguém digitar.

O que o NixOS faz por você é o outro lado: `programs._1password` instala o
wrapper `setgid` de `op` (grupo `onepassword-cli`) e `programs._1password-gui`
o de `1Password-BrowserSupport` (grupo `onepassword`), além da regra polkit
gerada por `polkitPolicyOwners`. **Ninguém precisa ser membro desses grupos** —
o setgid existe para o processo recebê-los ao executar. `id -nG` não listar
nada de 1Password é o normal, e não um diagnóstico (#53).

### Por que essas caixas não dá para versionar

A pergunta é natural: se tudo neste repositório é declarativo, por que essas
três opções são cliques?

O aplicativo guarda as preferências em `~/.config/1Password/settings/settings.json`,
e as chaves são exatamente estas:

| Chave | Caixa correspondente |
|---|---|
| `security.authenticatedUnlock.enabled` | Unlock using system authentication |
| `sshAgent.enabled` | Use the SSH agent |
| `developers.cliSharedLockState.enabled` | Integrate with 1Password CLI |

Só que o mesmo arquivo traz um bloco `authTags`, com **uma assinatura por
preferência sensível** — strings de 43 caracteres, uma para cada chave acima.
O 1Password assina essas opções para que ligá-las exija passar pelo aplicativo
autenticado. Escrever `sshAgent.enabled = true` por fora, pelo Home Manager ou
por um script de ativação, produz um valor sem assinatura válida — e o
aplicativo o descarta.

Isso é desenho, não limitação a contornar: ligar o agente SSH ou o
desbloqueio por sistema editando um arquivo seria justamente o que a assinatura
existe para impedir. Some-se a isso que o arquivo é mutável e reescrito pelo
próprio aplicativo a cada mudança de preferência, o que já basta para um
symlink read-only do store estar fora de questão.

**Portanto: três cliques por máquina nova, uma vez.** É o mesmo custo do
pareamento inicial da conta, e pela mesma razão.

O 1Password é software proprietário, e não há nada a declarar no módulo por
causa disso: `system/unfree.nix` liga `nixpkgs.config.allowUnfree = true` para
o sistema inteiro. Até a #66 a liberação era nome a nome, por uma lista que
cada módulo alimentava; o histórico dessa decisão — e de como revertê-la —
está no comentário daquele arquivo.

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

Para `.zshrc`/`.gitconfig` e similares, guarde-os como um item **Document** num vault pessoal. Depois liste-os em `settings.nix`:

```nix
dotfilesFrom1Password = [ "zshrc" "gitconfig" ];
```

Use os caminhos **sem** `./` — eles viram nomes de atributo em
`xdg.configFile`. O item correspondente no vault é
`op://<vault>/dotfiles-<rel>/file`.

Durante `nixos-rebuild switch`, o Home Manager lê os itens Document correspondentes e popula `~/.config/dotfiles/`. Como cada máquina tem seu próprio vault ou referência única por dotfile, os secrets ficam isolados por escopo.

## Refresh token do OneDrive

O cliente [abi-1/onedrive](https://github.com/abraunegg/onedrive) precisa de um
`refresh_token` em `~/.config/onedrive/refresh_token` para o `onedrivegui`
sincronizar sem prompt de OAuth (é ele quem roda o cliente por baixo — ver
"O motor é o onedrivegui" abaixo). O `user/app/onedrive.nix` materializa
esse arquivo na ativação do Home Manager a partir do item
`onedrive/refresh_token` do vault — mesmo padrão de tolerância a `op`
indisponível usado pelos dotfiles e pelo opencode: sem CLI ou sem login, sai
uma linha amarela e a sincronização não sobe, em vez de quebrar o rebuild.

O item **existe, mas você precisa criá-lo** na primeira instalação. O ciclo é
uma vez por máquina — na prática, uma vez por conta Microsoft:

```bash
# 1. Autentica no OneDrive pelo navegador e cria o refresh_token local
onedrive
#   ... segue as instruções, autoriza, espera o cliente baixar a config ...
#   Ctrl+C quando terminar (o que queremos é o arquivo, não a sincronização
#   contínua — quem sobe é o serviço).

# 2. Cria o item no vault com o conteúdo do arquivo
op item create \
  --category "Login" \
  --title "onedrive" \
  --vault "Dotfiles" \
  "refresh_token=$(cat ~/.config/onedrive/refresh_token)"

# 3. Re-roda a ativação para puxar do 1Password
nupdate
```

Daí em diante, toda ativação sobrescreve o arquivo a partir do 1Password, e
`systemctl --user status onedrivegui` mostra o serviço rodando. Se o token
expirar (a Microsoft não avisa), basta re-rodar o passo 2 com o novo
conteúdo do arquivo local.

**O motor é o `onedrivegui`, não `services.onedrive`.** O jeito "óbvio"
(unit systemd do NixOS como motor, GUI só de visor por cima) não funciona:
o `onedrivegui` não tem modo "observar" um processo alheio — a tela de
progresso só existe para o processo que ele mesmo lança, e o cliente
`onedrive` recusa uma segunda instância no mesmo confdir. Por isso quem
sincroniza é o próprio `onedrivegui`, subindo como `systemd.user.services.onedrivegui`
(ver `user/app/onedrive.nix`) junto da sessão gráfica — sem sessão gráfica,
não sincroniza (diferente do `services.onedrive` original, que subia antes
de qualquer login). `system/app/onedrive/default.nix` continua existindo
para quem preferir esse motor puro noutro host/profile.

**O `sync_dir` é semeado uma vez a partir de `lcars.user.onedrive.syncDir`
(default `~/OneDrive`), e não mora no 1Password.** `~/.config/onedrive/config`,
`~/.config/onedrive-gui/profiles` e `~/.config/onedrive-gui/gui_settings`
nascem como arquivo real e gravável na primeira ativação — não como
`xdg.configFile`/symlink, porque o `onedrivegui` regrava esses arquivos
sempre que abre, e symlink somente-leitura pro Nix store quebra o app
(issue #131). Na prática isso quer dizer que a flag só vale na primeira
vez: depois que o arquivo existe, mudar o `sync_dir` é editar
`~/.config/onedrive/config` direto ou pelo `onedrivegui`, não mais pela
flag + `nupdate`. O profile já nasce com `auto_sync = True` (sincroniza sem
precisar de "Play") e o `gui_settings` com `start_minimized = True` (não
abre janela toda sessão gráfica) — o app deve abrir direto na conta, sem
passar pelo assistente de importação.

A activation do token (a que fala em "refresh_token" acima) é separada:
continua tocando só nele a cada ativação, e reinicia `onedrivegui.service`
depois de escrever um token novo, porque o cliente só lê o token na própria
inicialização.

## bot_token do herdr-telegram-plugin

O [herdr-telegram-plugin](https://github.com/mvallebr/herdr-telegram-plugin)
(cada pane do herdr como um tópico de fórum no Telegram) precisa de um
`bot_token` para o daemon (`systemd.user.services.herdr-telegram`, ver
`user/app/herdr-telegram.nix`) autenticar contra a API do Telegram. Mesmo
padrão de tolerância a `op` indisponível usado pelo onedrive e pelo opencode:
sem CLI ou sem login, a ativação avisa e segue — a unit sobe e falha por
falta de token até o segredo existir (visível em
`journalctl --user -u herdr-telegram`).

O item **não existe por padrão** — crie-o na primeira instalação:

```bash
# 1. Fale com @BotFather no Telegram, /newbot, e guarde o token que ele der.

# 2. Cria o item no vault com o token
op item create \
  --category "Login" \
  --title "herdr telegram bot" \
  --vault "Dotfiles" \
  "token=<token do @BotFather>"

# 3. Re-roda a ativação para puxar do 1Password
nupdate
```

Daí em diante, toda ativação sobrescreve
`~/.config/herdr-telegram/bot_token.env` a partir do 1Password e reinicia
`herdr-telegram.service`. Falta um passo manual, único por chat e não
automatizável: depois do primeiro deploy com o token certo, mande `/pair`
para o bot no grupo/tópico do Telegram para autorizar o chat — o daemon grava
isso em `~/.local/state/herdr-telegram/state.json`, fora do Nix.

**O `bot_token` nunca vai para o Nix store.** `~/.config/herdr-telegram/config.toml`
é gerado por `xdg.configFile` (link read-only para o store) e só carrega
ajustes sem segredo (`progress_interval_ms`); o token chega ao processo por
`EnvironmentFile=` do systemd, apontando para o arquivo mutável que a
ativação escreve — nunca por um valor embutido na unit nem no `config.toml`.

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
