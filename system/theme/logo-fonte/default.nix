# logo-fonte — a fonte do sistema, com o logo da SimbioIT dentro dela.
#
# Recebe um pacote de Nerd Font e devolve o mesmo pacote com quatro glifos a
# mais, em U+F8F0 a U+F8F3, que juntos desenham o logo. É o que permite ao
# prompt mostrar a marca no lugar do ícone de sistema (veja o os_icon em
# user/shell/zsh.nix).
#
# POR QUE PATCHEAR A FONTE, E NÃO INSTALAR UMA SÓ COM O LOGO
#
# Porque o terminal não vai procurar. Uma fonte separada depende de fallback
# do fontconfig, e o Konsole não faz: o `fc-match` aponta para ela, o
# `fc-list` a encontra, e mesmo assim saem caixinhas — o processo abre outro
# arquivo, o que se confirma em /proc/<pid>/maps. O glifo tem que estar dentro
# da fonte que o terminal carrega, exatamente como a casinha que o p10k mostra
# no diretório (U+F015, 'fa-house', um glifo da própria Nerd Font).
#
# O QUE ISTO CUSTA
#
# Um build da fonte por atualização do pacote — alguns minutos, cacheados
# depois. Só os arquivos que o sistema realmente usa são patcheados; as
# variantes que ninguém carrega ficam como vieram.
{
  lib,
  stdenvNoCC,
  python3,
  # o pacote da Nerd Font a patchear
  fonte,
  # quais arquivos dentro dele recebem os glifos. O padrão cobre os quatro
  # estilos que um terminal pede (normal, negrito, itálico e os dois juntos),
  # nas três variantes de espaçamento que as Nerd Fonts trazem.
  estilos ? [
    "Regular"
    "Bold"
    "Italic"
    "BoldItalic"
  ],
}:

stdenvNoCC.mkDerivation {
  pname = "${lib.getName fonte}-simbioit";
  inherit (fonte) version;

  src = fonte;

  nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];

  dontConfigure = true;
  dontBuild = true;

  installPhase =
    let
      # -name '*-Regular.ttf' -o -name '*-Bold.ttf' -o ...
      padroes = lib.concatMapStringsSep " -o " (e: "-name '*-${e}.ttf'") estilos;
    in
    ''
      runHook preInstall

      # O pacote da fonte vem do store, só leitura. A cópia precisa ser
      # gravável, senão o patch falha na hora de salvar por cima.
      cp -r --no-preserve=mode,ownership "$src" "$out"

      # A autoverificação do desenho roda antes de tocar em qualquer fonte:
      # ela pega arte com linhas de larguras diferentes e quadrado a cavalo na
      # fronteira de duas células — erros que, sem isto, só apareceriam como
      # um logo torto no terminal de alguém.
      python3 ${./.}/logo.py

      mapfile -d "" alvos < <(find "$out" -type f \( ${padroes} \) -print0)

      if [ ''${#alvos[@]} -eq 0 ]; then
        echo "logo-fonte: nenhum arquivo casou com os estilos pedidos" >&2
        echo "            (${lib.concatStringsSep ", " estilos})" >&2
        echo "            sem os glifos, o prompt mostra caixinhas — então isto é erro." >&2
        exit 1
      fi

      echo "logo-fonte: injetando o logo em ''${#alvos[@]} arquivo(s) de fonte"
      PYTHONPATH=${./.} python3 ${./.}/patch.py "''${alvos[@]}"

      runHook postInstall
    '';

  meta = {
    description = "${lib.getName fonte} com os glifos do logo da SimbioIT (U+F8F0 a U+F8F3)";
    inherit (fonte.meta) license platforms;
  };
}
