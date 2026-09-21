{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
  darwin,
  makeWrapper,
  python313,
  writeShellScriptBin,
}:
let
  codesignShim = writeShellScriptBin "codesign" ''
    [[ " $* " == *" /nix/store/"* ]] && exit 0
    exec /usr/bin/codesign "$@"
  '';

  pythonEnv = python313.withPackages (
    ps: with ps; [
      (robotframework.overridePythonAttrs rec {
        version = "6.1";
        src = fetchPypi {
          pname = "robotframework";
          inherit version;
          extension = "zip";
          hash = "sha256-qU4LPE+K4IwKTce/9vqKUXMFZRA/jGgqLYOR2ppGl/U=";
        };
        doCheck = false;
      })
      psutil
      pyyaml
      telnetlib3
      construct
      pyelftools
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "renode";
  version = "1.17.0";

  src = fetchurl {
    url = "https://github.com/renode/renode/releases/download/v${finalAttrs.version}/renode-${finalAttrs.version}.osx-arm64-portable.dmg";
    hash = "sha256-Y7H7aRIH9QPOqTfk7I+tPgaKUX0KusPCTAIGxi9sTRI=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
    darwin.autoSignDarwinBinariesHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r . $out/Applications/Renode.app
    macos=$out/Applications/Renode.app/Contents/MacOS

    mkdir -p $out/bin
    ln -s $macos/renode $out/bin/renode
    ln -s $macos/renode-test $out/bin/renode-test

    # Keep Renode UI state outside the read-only Nix store.
    wrapProgram $macos/platform-lib/osx-arm64/renode-ui \
      --add-flags '--path="''${XDG_DATA_HOME:-$HOME/Library/Application Support}/renode/ui"'

    # Renode re-signs renode-ui on startup, but the Nix store is read-only.
    # It is already signed by autoSignDarwinBinariesHook at build time.
    wrapProgram $macos/renode \
      --prefix PATH : ${codesignShim}/bin

    # Provide the Python dependencies required by renode-test.
    wrapProgram $macos/renode-test \
      --prefix PATH : ${pythonEnv}/bin

    runHook postInstall
  '';

  meta = {
    description = "Virtual development framework for complex embedded systems";
    homepage = "https://renode.io";
    downloadPage = "https://github.com/renode/renode";
    license = lib.licenses.mit;
    mainProgram = "renode";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
