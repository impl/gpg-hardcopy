# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, ... }: {
        packages.default = with pkgs; stdenvNoCC.mkDerivation rec {
          pname = "gpg-hardcopy";
          version = if self.sourceInfo ? rev then self.sourceInfo.rev else "dirty";

          src = ./.;

          meta = {
            description = "Generate a PDF of a PGP key";
            homepage = "https://github.com/impl/gpg-hardcopy";
            license = lib.licenses.asl20;
          };

          nativeBuildInputs = [ makeWrapper ];
          buildInputs = [
            coreutils
            ghostscript
            gnupg
            imagemagick
            jq
            librsvg
            pandoc
            qrencode
            texlive.combined.scheme-small
            util-linux
            zbar
          ];

          doCheck = true;
          checkInputs = [ bash shellcheck ];
          checkPhase = ''
            runHook preCheck
            ( cd src && shellcheck *.bash )
            ( cd t && shellcheck *.bash )
            bash t/main.bash
            runHook postCheck
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/${pname}
            cp src/* $out/share/${pname}
            makeWrapper ${bash}${bash.shellPath} $out/bin/gpg-hardcopy \
              --add-flags -c \
              --add-flags -- \
              --add-flags "'. $out/share/${pname}/main.bash && gpg_hardcopy::main \"\$@\"'" \
              --add-flags '"$0"' \
              --prefix PATH : ${lib.makeBinPath buildInputs} \
              --prefix OSFONTDIR : ${noto-fonts}/share/fonts
            runHook postInstall
          '';
        };
      };
    };
}
