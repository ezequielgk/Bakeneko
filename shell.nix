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
    # Evita el warning de licencia de Android (no usamos Android)
    export FLUTTER_SUPPRESS_ANALYTICS=true
    echo ""
    echo "  bakeneko dev shell"
    echo "  flutter:  $(flutter --version 2>/dev/null | head -1 | sed 's/^[«"]//; s/[»"].*//')"
    echo "  java:     $(java -version 2>&1 | head -1)"
    echo "  shell:    nix-shell  |  build daemon:  (cd daemon && ./gradlew shadowJar)"
    echo ""
  '';
}