# sudo-askpass.nix — diálogo gráfico pro sudo quando não há terminal.
#
# Opt-in por `lcars.user.sudoAskpass.enable`, ligado no profile. A flag vem
# do config do NixOS (veja user/options.nix).
#
# O problema que resolve
# -----------------------
# O botão "Update" do plugin nix-monitor (user/wm/noctalia.nix) abre um
# terminal e roda `nupdate`, que chama `nixos-rebuild switch --elevate=sudo`.
# O terminal que o noctalia abre não fornece um TTY que o sudo reconheça pra
# ler a senha — testado ao vivo: `sudo -A -v` fora de terminal interativo
# falha com "um terminal é necessário para ler a senha; use a opção -S ... ou
# configure um auxiliar de askpass" (#121).
#
# Isso não é bug do sudo nem da senha em si: rodar `nupdate` num terminal de
# verdade pede e aceita a senha normalmente.
#
# A saída: `SUDO_ASKPASS`
# ------------------------
# O próprio sudo já suporta nativamente um "auxiliar de askpass" por essa
# variável de ambiente — sem TTY, ele executa o programa apontado e lê a
# senha da saída padrão dele, em vez de falhar. Testado ao vivo com
# `zenity --password`: o diálogo abre na tela normalmente.
#
# Isto NÃO afrouxa política de sudo nenhuma. A senha continua obrigatória
# sempre — muda só o canal por onde ela é pedida quando não há terminal.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  # `SUDO_ASKPASS` é executado sem argumentos — não dá pra passar `--title`
  # direto na variável de ambiente, daí o wrapper.
  askpass = pkgs.writeShellScriptBin "lcars-sudo-askpass" ''
    exec ${lib.getExe pkgs.zenity} --password --title="sudo"
  '';
in
lib.mkIf osConfig.lcars.user.sudoAskpass.enable {
  home.packages = [ askpass ];
  home.sessionVariables.SUDO_ASKPASS = lib.getExe askpass;
}
