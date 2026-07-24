# Bakeneko Reader

Lector de manga para Linux, construido desde cero en Flutter + Kotlin.

## Por qué existe

La mayoría de lectores de manga de escritorio son ports de Android o apps Electron. Bakeneko nació para ser una aplicación **nativa de Linux** que respete las convenciones del sistema operativo: rutas XDG, socket UNIX, señales POSIX, y un instalador portable en forma de AppImage que funcione en cualquier distro sin dependencias externas.

El objetivo era demostrar que se puede tener la misma experiencia que Tachiyomi en el escritorio, sin emuladores, sin Wine, sin Electron.

---

## Cómo está hecho

### Arquitectura: 2 procesos POSIX

```
┌─────────────────────────────┐
│   Flutter app  (Dart)       │   IU, estado, lector
│                             │
│   DaemonClient              │
│   call("chapter.pages")     │
│         │  ▲                │
│         │  │  JSON-RPC \n   │
│         ▼  │                │
│   Unix Domain Socket        │
│   $XDG_RUNTIME_DIR/         │
│     bakeneko/daemon.sock    │
│         │  ▲                │
│         ▼  │                │
│   Daemon JVM (Kotlin)       │   Parsers de fuentes, HTTP
└─────────────────────────────┘
```

La UI y los parsers de fuentes corren en procesos separados, comunicándose por un **socket Unix de dominio** con JSON-RPC línea a línea. Esto permite:

- Actualizar los parsers (JAR) sin recompilar la UI.
- Aislar crashes del parser: si el daemon falla, la UI muestra el error en pantalla en lugar de cerrarse.
- Usar cualquier librería JVM para parsear fuentes (se usa [kotatsu-parsers](https://github.com/KoithaTechDev/kotatsu-parsers)).

### Stack técnico

| Capa | Tecnología |
|---|---|
| UI | Flutter 3.44 (Dart) + Riverpod |
| Parsers | Kotlin + kotatsu-parsers |
| IPC | Unix Domain Socket + JSON-RPC 2.0 |
| Base de datos | SQLite (drift) |
| Fuentes | MangaDex, MangaSee, Allen Scan y todas las soportadas por kotatsu-parsers |
| Distribución | AppImage universal (JRE empaquetada, sin dependencias externas) |
| Entorno dev | Nix shell (Flutter, JDK 21, clang, cmake, ninja, GTK3) |

### Estructura del repositorio

```
Bakeneko-Reader/
├── app/                   # Aplicación Flutter (UI)
│   └── lib/
│       ├── core/          # Modelos, DB, daemon client, XDG, settings, temas
│       └── features/      # browse, details, downloads, home, library, reader, settings
├── daemon/                # Proceso JVM (Kotlin)
│   └── src/main/kotlin/
│       ├── Main.kt        # Entrada: socket UNIX, accept loop, coroutinas
│       ├── Methods.kt     # Despachador JSON-RPC (catalog, pages, details...)
│       ├── Rpc.kt         # Tipos y códigos de error JSON-RPC estándar
│       ├── Models.kt      # DTOs Kotlin ↔ kotatsu-parsers
│       └── LoaderContext.kt # Instanciador de parsers por fuente
├── shell.nix              # Entorno de desarrollo reproducible
└── make_universal.sh      # Script para construir el AppImage universal
```

---

## Cómo correrlo en desarrollo

### Requisitos

- [Nix](https://nixos.org/download/) con flakes (o solo nix-shell clásico)
- Git

### Pasos

```bash
git clone https://github.com/CrowRei34/Bakeneko
cd Bakeneko

# Entra al entorno con todo lo necesario
nix-shell

# Compila el daemon (fat JAR)
cd daemon && ./gradlew shadowJar && cd ..

# Corre la app en modo desarrollo
cd app && flutter run -d linux
```

---

## Cómo construir el AppImage

El AppImage empaqueta automáticamente: el binario Flutter, el JAR del daemon, una JRE completa, libepoxy (para NixOS), y fuentes Roboto. No requiere ninguna dependencia en el sistema destino.

```bash
nix-shell
./make_universal.sh
# → genera Bakeneko-Universal-vX.AppImage
```

El AppImage resultante funciona en cualquier distribución Linux x86_64 moderna (Ubuntu, Fedora, Arch, NixOS, etc.).

---

## Debugging

### Dónde están los logs

El sistema de errores usa el flujo de estado de Riverpod como canal de propagación:

```
Parser web lanza excepción
  → Daemon convierte a JSON-RPC error {"error": {"code": -32xxx, "message": "..."}}
  → DaemonClient lanza RpcException en Dart
  → Controller captura en try/catch → guarda en state.error (String?)
  → Vista lee state.error → muestra en pantalla con botón "Reintentar"
```

Los `e.printStackTrace()` del daemon aparecen en el **stderr de la terminal** donde lanzaste la app.

### Errores comunes y su causa

| Mensaje en pantalla | Causa |
|---|---|
| `DaemonException: No se encuentra el JAR del daemon: /ruta/bakeneko-daemon.jar` | El JAR no está junto al ejecutable. En el AppImage esto ocurre si `Platform.script` en vez de `Platform.resolvedExecutable` fue usado para buscar la ruta. **Arreglado en v14.** |
| `DaemonException: El daemon no abrió el socket tras 15s` | Java no está en PATH o el JAR está corrupto. El AppImage incluye su propio JRE. |
| `DaemonException: socket cerrado` | El proceso `java -jar` murió inesperadamente. Ver stderr del terminal para el stack trace completo. |
| `RpcException: fuente desconocida: XYZ` | El nombre de la fuente no coincide con ningún `MangaParserSource`. |
| Portadas que no cargan (icono de estrella) | La fuente requiere el header `Referer` en las peticiones HTTP de imagen. El cliente de red no lo envía aún. |

### Rutas de datos en el sistema

Bakeneko sigue la especificación [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/):

| Directorio | Contenido |
|---|---|
| `~/.local/share/bakeneko/` | Biblioteca, base de datos SQLite, descargas |
| `~/.config/bakeneko/` | `settings.json` |
| `~/.cache/bakeneko/` | Caché de imágenes |
| `$XDG_RUNTIME_DIR/bakeneko/daemon.sock` | Socket del daemon (se borra al cerrar) |

Para limpiar todo y empezar desde cero:

```bash
rm -rf ~/.local/share/bakeneko ~/.config/bakeneko ~/.cache/bakeneko
```

---

## Licencia

Copyright (c) 2026, CrowRei34. Distribuido bajo licencia **BSD 3-Clause** — ver [LICENSE](LICENSE).

**kotatsu-parsers** (parsers de fuentes) es una librería de terceros desarrollada por KoithaTechDev y distribuida bajo su propia licencia. Bakeneko Reader la consume como dependencia de Gradle sin modificar ni redistribuir su código fuente.
