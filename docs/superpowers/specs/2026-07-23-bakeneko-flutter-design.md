# Bakeneko-Reader — Rediseño en Flutter

- **Fecha:** 2026-07-23
- **Proyecto nuevo:** `/home/crow/Documents/Bakeneko-Reader` (monorepo `bakeneko/`)
- **Origen:** refactor de `CrowRei34/Bakeneko-Reader` (Futon Desktop, Kotlin Compose Multiplatform)
- **Plataforma:** GNU/Linux (POSIX). Binario nativo de escritorio.
- **Licencia:** GPLv3 (heredada del original)

## 1. Objetivo

Reescribir Bakeneko-Reader en Flutter manteniendo **todas** las funcionalidades del
original (catálogo con múltiples fuentes, favoritos, historial, descargas offline,
detalles, lector), usando el diseño del mockup Figma (paleta espresso/terracotta/sage,
sidebar, bibliotecas personalizadas, ajustes con temas), y aplicando la filosofía
**doas**: mínimo código, dependencias contadas, cero code-generation, máxima
eficiencia y robustez.

## 2. Requisitos y decisiones acordadas

1. **Fuentes de manga:** Flutter (UI) + daemon Kotlin de parsers como sidecar
   (reutiliza `futon-parsers` de Kotatsu para conservar todas las fuentes).
2. **UI:** implementar el mockup de Figma Make
   (`/home/crow/Downloads/Manga Reader Desktop UI (Community).zip`).
3. **Plataformas:** solo Linux.
4. **Datos:** instalación limpia con rutas XDG (sin migrar `~/.futon`).
5. **Arquitectura:** UDS + JSON-RPC + dependencias mínimas (opción A).

## 3. Arquitectura general

Monorepo con dos runtimes coordinados:

```
bakeneko/
├── app/       # Flutter (Dart puro) — UI, DB local, descargas, reader
├── daemon/    # Kotlin/JVM headless — envoltorio sobre futon-parsers
└── docs/      # specs y planes
```

- La app Flutter lanza el daemon como proceso hijo, habla con él por un socket
  Unix de dominio y lo termina al cerrarse.
- El daemon no persiste estado: es un traductor sin sesiones entre la API de
  parsers (Kotlin) y el cliente (Dart).

### Principios doas aplicados
- Un archivo = una responsabilidad.
- Sin code-generation (ni drift, ni freezed, ni riverpod_generator, ni build_runner).
- Dependencias mínimas (ver §6): las justas y necesarias.
- El daemon reutiliza el `DesktopMangaLoaderContext` ya probado del original.
- SQL a mano (espíritu del `Database.sq` original) sobre FFI de `sqlite3`.

## 4. Daemon — protocolo y ciclo de vida

### Transporte
- **Socket Unix de dominio** en `$XDG_RUNTIME_DIR/bakeneko/daemon.sock`
  (fallback `/tmp/bakeneko-$UID/daemon.sock` si `XDG_RUNTIME_DIR` no existe).
- Directorio con permisos `0700` → solo el usuario puede conectar.
- Implementado con NIO de Java 21 (`UnixDomainSocketAddress`,
  `ServerSocketChannel.open()` con `StandardProtocolFamily.UNIX`), sin dependencias
  de red externas.
- Peticiones distribuidas en un pool fijo de hebras para no bloquear el socket.

### Protocolo — JSON-RPC delimitado por líneas
Una request por línea (`\n`), una response por línea. Sin cabeceras HTTP.

```jsonc
// request
{"id":1,"method":"catalog.list","params":{"source":"MANGADEX","offset":0,"query":""}}
// response ok
{"id":1,"result":[{...manga...}]}
// response error
{"id":1,"error":{"code":-32000,"message":"fuente no soportada"}}
```

Los objetos `manga`, `chapter` y `page` viajan como **blobs opacos**: el cliente
guarda el JSON completo y lo reenvía en métodos posteriores (`manga.details`,
`chapter.pages`, `page.url`). El daemon los deserializa de vuelta a los modelos
de `futon-parsers`. Esto mantiene el daemon sin estado y robusto ante reinicios.

### Métodos
| Método | Params | Result |
|---|---|---|
| `ping` | — | `{"version":"…"}` |
| `sources.list` | — | `[{id, name, locale}]` |
| `catalog.list` | `source, offset, query?` | `[mangaBlob]` |
| `manga.details` | `source, mangaBlob` | manga con `chapters` |
| `chapter.pages` | `source, chapterBlob` | `[pageBlob]` |
| `page.url` | `source, pageBlob` | `url` (string) |
| `source.headers` | `source` | `{header: value}` |

### Ciclo de vida
- La app comprueba si el socket existe y responde a `ping`; si no, lanza
  `java -jar bakeneko-daemon.jar` esperando hasta 15 s a que el socket aparezca.
- El daemon sale limpio si el proceso padre muere o el socket aceptador se cierra.
- Cada request en `try/catch`: respuesta de error sin tumbar el bucle; timeout de lectura por request.
- Build: fat JAR con el plugin `shadow` de Gradle; dependencias: `futon-parsers`,
  `okhttp`, `nashorn-core` (igual que el original).

## 5. App Flutter — módulos y estado

### Estructura por feature
```
lib/
├── main.dart
├── core/
│   ├── xdg.dart              # rutas XDG (data/config/cache/runtime)
│   ├── daemon/
│   │   ├── daemon_client.dart   # spawn + connect + codec JSON-RPC
│   │   └── rpc.dart             # codificación/decodificación de frames
│   ├── db/
│   │   ├── database.dart        # abre sqlite, PRAGMA user_version, migraciones
│   │   ├── schema.sql           # DDL a mano
│   │   └── dao/  (manga, chapter, category, history, download)
│   ├── downloads/
│   │   └── download_manager.dart # cola FIFO persistente, semáforo(3), progreso
│   ├── theme/
│   │   ├── tokens.dart          # paleta espresso/sage/tan/terracotta/cream
│   │   └── app_theme.dart       # ThemeData claro/oscuro + acentos
│   └── models.dart             # Manga, Chapter, Page, Settings (inmutables)
└── features/
    ├── home/   browse/   library/   details/   reader/
    ├── downloads/   extensions/   settings/
    └── shell/                    # sidebar + IndexedStack + navegación
```
Cada feature: `*_view.dart` (UI) + `*_controller.dart` (Notifier Riverpod) +
`*_widgets.dart` (privados).

### Gestión de estado
- **Riverpod sin codegen.** `Notifier<_Estado>` que expone `AsyncValue<Estado>`
  inmutable; la UI observa con `ref.watch`. Servicios (daemon client, DAOs,
  download manager) inyectados como `Provider` por constructor → testeables.
- **Navegación sin go_router:** shell con sidebar (enum `NavSection`) +
  `IndexedStack` de secciones + pila simple para Detalles/Lector gestionada por
  un `NavigationController` (~50 líneas).

### Imágenes
- `cached_network_image` con `cacheManager` apuntando a
  `$XDG_CACHE_HOME/bakeneko/covers`.
- Headers del daemon (Referer/UA) en cada petición para saltar hotlink-protection
  (comportamiento del original conservado).

## 6. Modelo de datos — DB, XDG y descargas

### Rutas XDG
```
$XDG_DATA_HOME/bakeneko/   → bakeneko.db, downloads/<fuente>/<mangaHash>/<capHash>/
$XDG_CONFIG_HOME/bakeneko/ → settings.json
$XDG_CACHE_HOME/bakeneko/  → covers/
$XDG_RUNTIME_DIR/bakeneko/  → daemon.sock (0700)
```
(`~/.local/share`, `~/.config`, `~/.cache`, `/run/user/$UID` por defecto.)

### DB — SQLite vía `sqlite3` (FFI), SQL a mano
`schema.sql` con `PRAGMA user_version` para migraciones. Tablas:

- `manga(id PK, source, url, title, cover_url, description, blob_json, UNIQUE(source,url))`
- `chapter(manga_id FK, url, name, number, read BOOL, blob_json, PK(manga_id,url))`
- `category(id PK, name, color, auto_download BOOL)`
- `manga_category(manga_id FK, category_id FK, PK(manga_id,category_id))`
- `history(manga_id PK FK, chapter_index, page_index, updated_at)`
- `download(chapter_id PK, state, total_pages, done_pages)` — cola persistente

`blob_json` guarda el blob opaco del daemon para reconstruir objetos del parser
sin re-pedir al catálogo.

### Descargas
- `DownloadManager` con cola FIFO en memoria + persistida en `download`.
- 3 descargas paralelas (semáforo); páginas como `0001.jpg` + marca `completed.txt`
  (mismo layout que el original → lectura offline idéntica).
- Reanudación de páginas ya bajadas; escritura a `.part` + rename atómico.
- Stream de progreso a la UI vía StateProvider/Riverpod (estados
  idle/queued/downloading/done/error igual que el mockup).

### Settings
Un único `settings.json` legible:
`themeMode (light|dark|system)`, `accent (terracotta|sage)`, `gridDensity
(compact|comfortable|large)`, `defaultReadMode (webtoon|paginated)`,
`enabledSources: [...]`, `readerColorFilter (none|grayscale|sepia|bluelight)`.

## 7. UI — mapeo del mockup y pantallas

Fiel al mockup Figma: sidebar espresso con secciones; paleta exacta; tipografía
Inter; radio 10px; temas claro/oscuro/acento sage; densidad de grid configurable;
paneles de filtros de biblioteca; popover "añadir a categoría"; cola de descargas
con estados animados (`dl-spin`, `dl-pulse`); pantalla de ajustes completa
(reader/content/languages/extensions/appearance).

### Secciones del sidebar
| Sección | Origen | Funcionalidad |
|---|---|---|
| Home | mockup | Continue Reading (history) + Recently Added |
| Biblioteca | mockup | categorías con color, filtros, tabs, popover añadir, overflow |
| Explorar | **nueva** (acordada) | barra de búsqueda + selector de fuente + grid infinito (catálogo original) |
| Descargas | mockup | cola persistente, estados, estadísticas de almacenamiento |
| Extensiones | mockup | `sources.list`; on/off guardado en `settings.enabledSources` |
| Ajustes | mockup | reader/content/languages/extensions/appearance |

### Lector (no estaba en el mockup)
Misma UX del original re-tematizada con la paleta nueva: webtoon (lista vertical) /
paginado (pager horizontal), barra inferior con capítulo anterior/siguiente y toggle
de modo. **Nuevos filtros de color** (acordados): B/N (escala de grises), sepia,
luz azul — implementados con `ColorFiltered` (cero dependencias, costo ínfimo).
Historial automático al cambiar de capítulo/página (conservado).

## 8. Robustez y manejo de errores

- **Daemon:** request en `try/catch` → respuesta de error sin tumbrar el loop;
  `CancellationException` se relanza; líneas malformadas se responden y descartan;
  salida limpia si padre/socket mueren; timeout de lectura por request.
- **App daemon caído:** el cliente detecta proceso muerto, banner "reiniciando
  motor de fuentes" y re-lanzado con backoff (máx. 3 intentos).
- **Errores de red/fuente:** estado de error por pantalla con botón reintentar y
  log copiable (como la UI actual).
- **Descargas:** `.part` + rename atómico; no re-descargar páginas existentes;
  estado de error persistido por capítulo.

## 9. Testing

- **Dart (unit):** rutas XDG, codec JSON-RPC, DAOs con SQLite en memoria, lógica
  del `DownloadManager` con daemon falso, serialización de settings, navegación.
- **Daemon (JUnit):** codec JSON y dispatch con parser falso.
- **Smoke manual:** catálogo → detalles → lector → descarga offline contra MangaDex real.
- Principio: tests donde hay lógica, no en UI trivial.

## 10. Entorno y distribución

### Fase 0 — requisitos del sistema
- **JDK 21:** ya disponible en `~/.jdk/jdk-21.0.4+7` (fijar `JAVA_HOME`).
- **Flutter SDK:** instalar (canal estable).
- **Toolchain Linux (apt):** `clang`, `cmake`, `ninja-build`, `pkg-config`,
  `libgtk-3-dev`, `liblzma-dev`, `libstdc++-12-dev`.
- Verificar con `flutter doctor`.

### Distribución
- `flutter build linux` → bundle en `app/build/linux/x64/release/bundle/`.
- Fat JAR del daemon `daemon/build/libs/bakeneko-daemon-all.jar`.
- Launcher `bakeneko` (script shell POSIX): fija rutas, arranca la app (que a su
  vez lanza el daemon). Empaquetado AppImage/deb como fase opcional posterior.

## 11. Dependencias (contadas)

**Dart (`app/pubspec.yaml`):**
- `flutter_riverpod` (sin riverpod_generator / sin build_runner)
- `sqlite3`, `sqlite3_flutter_libs`
- `cached_network_image`
- `path`, `path_provider`
- Dev: `flutter_test`, `mocktail`

**Daemon (`daemon/build.gradle.kts`):** `futon-parsers`, `okhttp`,
`nashorn-core`, `com.github.johnrengelman.shadow` (fat jar).

Nada más. Sin ORM, sin codegen, sin router pesado.

## 12. Fases de implementación

| # | Fase | Entregable verificable |
|---|---|---|
| 0 | Entorno | `flutter doctor` verde; `JAVA_HOME`→JDK21 |
| 1 | Scaffold | Monorepo `bakeneko/` con `app/` (flutter create) y `daemon/` (Gradle) |
| 2 | Daemon | JSON-RPC sobre UDS, 7 métodos, fat JAR; probado con `socat` vs MangaDex |
| 3 | Core Dart | `xdg`, `settings`, `schema.sql`+DAOs, cliente daemon; con tests |
| 4 | Explorar + Detalles | end-to-end: búsqueda/scroll infinito → detalles con capítulos y modo bulk |
| 5 | Lector | webtoon/paginado, historial, filtros de color |
| 6 | Home + Biblioteca | Continue Reading, Recently Added, categorías, filtros |
| 7 | Descargas | cola persistente, 3 paralelas, pantalla de cola, lectura offline |
| 8 | Extensiones + Ajustes | fuentes on/off; tema/acento/densidad aplicados app-wide |
| 9 | Pulido | estados de error/vacío, launcher, README/AGENTS.md, verificación completa |