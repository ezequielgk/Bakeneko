# Entorno de desarrollo reproducible para Bakeneko-Reader.
# Uso:  nix-shell        # entra al shell con todas las deps
#   o bien:  nix-shell --run 'flutter --version'
#
# Provee: toolchain C/C++ (flutter desktop nativo), GTK3, JDK 21 (daemon),
# Flutter SDK, Gradle, sqlite3, socat (probar el daemon UDS), git, jq.
let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  name = "bakeneko";

  packages = with pkgs; [
    # --- Flutter desktop (Linux) toolchain ---
    clang
    # libstdc++.so.6: lo necesita el binario Flutter precompilado en runtime
    # (clang solo trae el envoltorio; el runtime C++ vive en stdenv.cc.cc.lib).
    stdenv.cc.cc.lib
    cmake
    ninja
    pkg-config
    gtk3
    pcre
    cairo
    pango
    gdk-pixbuf
    glib
    libepoxy
    harfbuzz
    freetype

    # --- Flutter & Dart ---
    flutter

    # --- Daemon (Kotlin/JVM) ---
    jdk21
    gradle

    # --- Runtime / utilidades ---
    sqlite                 # libsqlite3 para el FFI de la app
    socat                 # probar el socket del daemon: socat - UNIX-CONNECT:...socket
    git
    jq                    # inspeccionar JSON-RPC
    curl
    unzip
  ];

  # Flutter necesita GTK en el entorno de enlace runtime.
  shellHook = ''
    export JAVA_HOME=${pkgs.jdk21}
    export FLUTTER_ROOT=${pkgs.flutter}
    export FLUTTER_SUPPRESS_ANALYTICS=true
    # sqlite3 (FFI) necesita encontrar libsqlite3.so en el shell de desarrollo.
    # En build empaquetado lo provee sqlite3_flutter_libs junto al binario.
    # stdenv.cc.cc.lib provee libstdc++.so.6 que el binario Flutter precompilado
    # carga en runtime pero nix-shell no expone por defecto.
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo ""
    echo "  bakeneko dev shell"
    echo "  flutter:  $(flutter --version 2>/dev/null | head -1 | sed 's/^[«"]//; s/[»"].*//')"
    echo "  java:     $(java -version 2>&1 | head -1)"
    echo "  shell:    nix-shell  |  build daemon:  (cd daemon && ./gradlew shadowJar)"
    echo ""
  '';
}