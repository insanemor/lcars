# onedrive.nix — o cliente OneDrive (abi-1/onedrive) do lado do sistema.
#
# Opt-in por `lcars.system.app.onedrive.enable`, ligado no profile. A flag é
# declarada aqui mesmo.
#
# O QUE ESTE MÓDULO FAZ
# ---------------------
# Habilita `services.onedrive`, que instala o pacote `onedrive` e cria duas
# unidades **do usuário**:
#
#   - `onedrive@.service`        template; o ExecStart é
#                                 `onedrive --monitor --confdir=%h/.config/%i`
#   - `onedrive-launcher.service` oneshot com `wantedBy = default.target`,
#                                 que lê `~/.config/onedrive-launcher` para
#                                 decidir qual(is) instância(s) subir. Sem
#                                 esse arquivo, sobe a padrão `onedrive`,
#                                 cujo confdir é `~/.config/onedrive`.
#
# `--monitor` é hardcoded no ExecStart pelo módulo do nixpkgs — não há option
# pública para desligar. Para uma única conta, não é preciso criar
# `~/.config/onedrive-launcher`: o default já casa com o que o `user/`
# escreve.
#
# O QUE ELE NÃO FAZ, E QUE O HOME MANAGER FAZ
# --------------------------------------------
# O `services.onedrive` não expõe `syncDir` nem `configFile`: o `sync_dir` vive
# em `~/.config/onedrive/config` (gerado pelo próprio cliente na primeira
# execução, default `~/OneDrive`), e o `refresh_token` em
# `~/.config/onedrive/refresh_token` (gerado pelo OAuth inicial). A ativação
# do Home Manager materializa esse token a partir de um item 1Password —
# ver `user/app/onedrive.nix`.
#
# Por que duas árvores: `services.onedrive` é uma unit **do usuário** que sobe
# na sessão, e a ativação que escreve o token também é do usuário (roda na
# `home-manager-<user>.service`). Os dois lados têm que concordar sobre o
# caminho, e a fonte da verdade do diretório é a activation.
{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.lcars.system.app.onedrive;
in
{
  options.lcars.system.app.onedrive = {
    enable = mkEnableOption ''
      o cliente OneDrive (abi-1/onedrive) como serviço do usuário, com
      `--monitor` ligado e confdir em `~/.config/onedrive`
    '';
  };

  config = mkIf cfg.enable {
    services.onedrive.enable = true;
  };
}
