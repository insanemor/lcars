# beeptui.nix — o cliente TUI do Beeper Desktop (beeptui.com) no ambiente do
# usuário.
#
# Opt-in por `lcars.user.beeptui.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# O PACOTE
# --------
# beeptui não está no nixpkgs (não é um crate publicado, e não há derivação
# upstream) — só existe como binário pré-compilado nas releases do GitHub
# (mitchmalone/beeptui, MIT). Por isso a derivação mora aqui, não em
# `home.packages = [ pkgs.beeptui ]`: é `fetchurl` do release `linux-x64`,
# patchado com `autoPatchelfHook` porque o binário sai linkado contra o glibc
# do sistema onde foi buildado, não do Nix store.
#
# `ldd` no binário baixado mostra só dependências padrão de C
# (libc/libpthread/libdl/libm) — nada além do que o próprio stdenv já provê
# via `autoPatchelfHook`, então não precisa de `buildInputs` extra.
#
# `dontStrip = true` é obrigatório, não cosmético. O binário é um executável
# Bun standalone (`bun build --compile`): o `bun` real com o bundle do
# beeptui anexado depois do fim do ELF. O `strip` do fixupPhase reescreve o
# arquivo a partir dos section headers e descarta esse trailer — o binário
# continua rodando, só que vira o `bun` puro (confirmado: `--version` reporta
# a versão do Bun, não do beeptui, e a tela é o `--help` do Bun). Testado
# localmente: com `dontStrip`, `--version` reporta 0.4.1 e o binário abre a
# TUI de verdade.
#
# Atualizar de versão é manual: trocar `version` e o `sha256` abaixo pelos da
# nova release — o `sha256sums.txt` que o GitHub Releases publica junto tem o
# hash hex do asset `beeptui-linux-x64` (o mesmo que `fetchurl` espera aqui).
#
# O QUE FICA DE FORA
# -------------------
# beeptui é só o cliente TUI — ele depende do Beeper Desktop rodando
# localmente (app proprietário, Electron), que este módulo não instala nem
# gerencia. Sem o Beeper Desktop aberto, o beeptui sobe e falha ao conectar;
# isso é esperado e é responsabilidade de quem liga a flag, não deste módulo.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.beeptui.enable (
  let
    beeptui = pkgs.stdenv.mkDerivation {
      pname = "beeptui";
      version = "0.4.1";

      src = pkgs.fetchurl {
        url = "https://github.com/mitchmalone/beeptui/releases/download/v0.4.1/beeptui-linux-x64";
        sha256 = "3ce9de73dfabc86e0d18b0245471cba1d47f3407f55143e433f5d1cf6db4d9a2";
      };

      dontUnpack = true;
      dontStrip = true;
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];

      installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/bin/beeptui
        runHook postInstall
      '';

      meta = {
        description = "TUI keyboard-first para o Beeper unified inbox (WhatsApp, Slack, Telegram, Signal, Discord, Instagram, X DMs)";
        homepage = "https://www.beeptui.com";
        license = lib.licenses.mit;
        platforms = [ "x86_64-linux" ];
        maintainers = [ ];
      };
    };
  in
  {
    home.packages = [ beeptui ];
  }
)
