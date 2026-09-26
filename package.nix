{
  lib,
  stdenv,
  stdenvNoCC,
  fetchPypi,
  fetchurl,
  _7zz,
  darwin,
  makeWrapper,
  autoPatchelfHook,
  glib,
  gtk3,
  icu,
  libpng,
  openssl,
  webkitgtk_4_1,
  zlib,
  python313,
  writeShellScriptBin,
}:

let
  pname = "renode";
  version = "1.17.0";

  inherit (stdenv.hostPlatform) isDarwin system;

  releases = {
    aarch64-darwin = {
      file = "${pname}-${version}.osx-arm64-portable.dmg";
      hash = "sha256-Y7H7aRIH9QPOqTfk7I+tPgaKUX0KusPCTAIGxi9sTRI=";
    };

    x86_64-linux = {
      file = "${pname}-${version}.linux-portable.tar.gz";
      hash = "sha256-S6fGi1niRH8YjvS0sRL8zNKAJYLEYL7tzrY7hOVgWl8=";
    };

    aarch64-linux = {
      file = "${pname}-${version}.linux-arm64-portable.tar.gz";
      hash = "sha256-6QUVeEEUQb+0e3feA4HPujutzgNmM2f6tWFHL9eAfx8=";
    };
  };

  appDir = if isDarwin then "Applications/Renode.app" else "lib/${pname}";
  binDir = appDir + lib.optionalString isDarwin "/Contents/MacOS";

  dlopenLibs = lib.makeLibraryPath [
    glib
    gtk3
    icu
    openssl
    webkitgtk_4_1
  ];

  codesignShim = writeShellScriptBin "codesign" ''
    [[ " $* " == *" /nix/store/"* ]] && exit 0
    exec /usr/bin/codesign "$@"
  '';

  pythonEnv = python313.withPackages (ps: [
    (ps.robotframework.overridePythonAttrs {
      version = "6.1";
      src = fetchPypi {
        pname = "robotframework";
        version = "6.1";
        extension = "zip";
        hash = "sha256-qU4LPE+K4IwKTce/9vqKUXMFZRA/jGgqLYOR2ppGl/U=";
      };
      doCheck = false;
    })
    ps.psutil
    ps.pyyaml
    ps.telnetlib3
    ps.construct
    ps.pyelftools
  ]);
in

stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/renode/renode/releases/download/v${version}/${releases.${system}.file}";
    inherit (releases.${system}) hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals isDarwin [
    _7zz
    darwin.autoSignDarwinBinariesHook
  ]
  ++ lib.optional (!isDarwin) autoPatchelfHook;

  buildInputs = lib.optionals (!isDarwin) [
    gtk3
    libpng
    stdenv.cc.cc.lib
    zlib
  ];

  dontStrip = true; # Stripping breaks platform-lib/*/renode-ui, causing patchelf to fail.

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/${appDir}"
    cp -r . "$out/${appDir}"

    root="$out/${binDir}"

    ln -s "$root/renode" "$out/bin/renode"
    ln -s "$root/renode-test" "$out/bin/renode-test"

    # Keep Renode UI state outside the read-only Nix store.
    wrapProgram "$root/platform-lib/"*/renode-ui \
      --add-flags '--path="''${XDG_DATA_HOME:-$HOME/.local/share}/renode/ui"'

    # Provide the Python dependencies required by renode-test.
    wrapProgram "$root/renode-test" \
      --prefix PATH : "${pythonEnv}/bin"

    # Renode re-signs renode-ui on startup, but the Nix store is read-only.
    # The app is already signed by autoSignDarwinBinariesHook.
    ${lib.optionalString isDarwin ''
      wrapProgram "$root/renode" \
        --prefix PATH : "${codesignShim}/bin"
    ''}

    # These libraries are loaded dynamically and are therefore invisible to autoPatchelfHook.
    ${lib.optionalString (!isDarwin) ''
      wrapProgram "$root/renode" \
        --suffix LD_LIBRARY_PATH : "${dlopenLibs}"
    ''}

    runHook postInstall
  '';

  meta = {
    description = "Virtual development framework for complex embedded systems";
    homepage = "https://renode.io";
    downloadPage = "https://github.com/renode/renode";
    license = lib.licenses.mit;
    mainProgram = "renode";
    platforms = lib.attrNames releases;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
