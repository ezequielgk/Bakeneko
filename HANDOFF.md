# HANDOFF — Bakeneko-Reader (refactor a Flutter)

Documento para retomar el proyecto con otra IA. **Leer entero antes de empezar.**

---

## 1. Qué es esto

Refactor de **Bakeneko-Reader** (original `CrowRei34/Bakeneko-Reader`, app Kotlin
Compose Multiplatform Desktop, fork de Kotatsu) a **Flutter/Linux** aplicando la
filosofía **doas**: mínimo código, dependencias contadas, cero code-generation,
máxima eficiencia y robustez. Mantiene **todas** las funcionalidades del original
y usa un **diseño nuevo de Figma** (paleta espresso/terracotta/sage, sidebar,
bibliotecas, ajustes).

**Ubicación:** `/home/crow/Documents/Bakeneko-Reader`
**Repo git local** (sin remoto): 7 commits, fases 0-5 completas.
**Spec de diseño:** `docs/superpowers/specs/2026-07-23-bakeneko-flutter-design.md`
(léelo para el contexto completo de decisiones).

---

## 2. Arquitectura (decidida e inmutable)

**Monorepo `bakeneko/` con dos runtimes:**

```
bakeneko/
├── app/       # Flutter (Dart puro) — UI, DB local, descargas, reader
├── daemon/    # Kotlin/JVM headless — envoltorio sobre futon-parsers
└── docs/
```

- **App Flutter** lanza el daemon como proceso hijo (`java -jar daemon.jar`), le
  habla por **socket Unix de dominio** con **JSON-RPC delimitado por líneas**,
  lo mata al cerrarse.
- **Daemon** es un traductor sin estado entre la API de `futon-parsers` (Kotlin,
  cientos de fuentes de manga tipo Kotatsu) y el cliente Dart.
- **Socket:** `$XDG_RUNTIME_DIR/bakeneko/daemon.sock` (fallback
  `/tmp/bakeneko-$UID/`), permisos `0600`.
- **Datos:** rutas XDG (`~/.local/share/bakeneko`, `~/.config`, `~/.cache`).

### Protocolo JSON-RPC (7 métodos, implementados y probados)
| Método | Params | Result |
|---|---|---|
| `ping` | — | `{version, java}` |
| `sources.list` | — | `[{id, name}]` |
| `catalog.list` | `source, offset, query?` | `[manga...]` (blob opaco completo) |
| `manga.details` | `source, manga(blob)` | manga con `chapters` |
| `chapter.pages` | `source, chapter(blob)` | `[page...]` |
| `page.url` | `source, page(blob)` | url final de imagen |
| `source.headers` | `source` | `{header: value}` |

Formato: `{"id":N,"method":"x","params":{...},"jsonrpc":"2.0"}\n`. Los blobs
manga/chapter/page viajan **opacos** (el cliente los guarda y reenvía; el daemon
reconstruye con source+url). Respuestas: `{"id":N,"result":...}` o
`{"id":N,"error":{code,message}}`.

### Stack y dependencias (MÍNIMAS — no añadir más sin pensar)
**Dart (`app/pubspec.yaml`):** `flutter_riverpod` (sin codegen), `sqlite3` +
`sqlite3_flutter_libs` (FFI, SQL a mano), `cached_network_image`, `path`,
`path_provider`. Dev: `flutter_test`, `flutter_lints`, `mocktail`. **Nada más.**
Sin drift, sin freezed, sin go_router, sin build_runner.

**Daemon (`daemon/build.gradle.kts`):** `futon-parsers:f287c414a6` (jitpack),
`okhttp:4.12`, `nashorn-core:15.4` (JS eval de parsers), `kotlinx-coroutines`,
`kotlinx-serialization-json` (marshalling DTOs), plugin `com.gradleup.shadow`
(fat JAR). Repos necesarios: `google()`, `mavenCentral()`, `jitpack`.

### Filosofía doas aplicada
- Un archivo = una responsabilidad. DAOs separados por tabla.
- Sin code-generation. Modelos inmutables con `const` ctor + `copyWith` a mano.
- SQL a mano en `schema.dart` (string), migraciones vía `PRAGMA user_version`.
- Riverpod sin `riverpod_generator` (providers manuales).
- Navegación sin `go_router` (`NavigationController` de ~50 líneas + `IndexedStack`).

---

## 3. Cómo arrancar el entorno (OBLIGATORIO)

**Todo se corre dentro de `nix-shell`** (reproducible). No hay nada instalado en
el sistema excepto lo que el `shell.nix` provee.

```bash
cd /home/crow/Documents/Bakeneko-Reader
nix-shell    # entra al shell con flutter, jdk21, clang, cmake, ninja, gtk3, sqlite, socat, jq
```

El `shellHook` ya exporta `JAVA_HOME`, `FLUTTER_ROOT` y `LD_LIBRARY_PATH` (este
último para que `sqlite3` FFI encuentre `libsqlite3.so` en los **tests**).

> **Nix ya está configurado en este sistema**: `doas ln -s /etc/sv/nix-daemon
> /var/service/nix-daemon` y `nix-channel --add ...` ya se hicieron. Si el
> nix-shell falla, verificar que `sv status nix-daemon` diga `run:`.

### Comandos de verificación (dentro de nix-shell)
```bash
# Daemon: compilar fat JAR + tests
cd daemon && ./gradlew shadowJar test          # jar: build/libs/bakeneko-daemon.jar (17MB)

# App: análisis + tests + build linux
cd app && flutter pub get
flutter analyze                                # 0 errores (infos cosméticos OK)
flutter test                                   # 22 tests pasan
flutter build linux --debug                    # binario: build/linux/x64/debug/bundle/bakeneko

# Smoke manual del daemon (sin la app):
cd daemon
export XDG_RUNTIME_DIR=/tmp/bk-e2e && mkdir -p $XDG_RUNTIME_DIR
java -jar build/libs/bakeneko-daemon.jar &    # arranca, escucha UDS
printf '{"id":1,"method":"ping"}\n' | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/bakeneko/daemon.sock
# => {"id":1,"result":{"version":"1.0.0","java":"21.0.12"},"jsonrpc":"2.0"}
printf '{"id":2,"method":"sources.list"}\n' | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/bakeneko/daemon.sock
# MangaDex con red real:
printf '{"id":3,"method":"catalog.list","params":{"source":"MANGADEX","offset":0}}\n' \
  | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/bakeneko/daemon.sock
```

### Regla de commits
`git -c user.name=crow -c user.email=crow@local commit -m "faseN: ..."` (no hay
git config global, hay que pasarlo cada vez). Estilo de mensajes: ver `git log`.

---

## 4. Estado actual — qué está HECHO

| Fase | Estado | Commit |
|---|---|---|
| 0 Entorno (nix-shell reproducible) | ✅ | `2afc75e` |
| 1 Scaffold monorepo | ✅ | `bbc15b3` |
| 2 Daemon JSON-RPC/UDS (probado vs MangaDex real) | ✅ | `7518b9a` |
| 3 Core Dart (xdg/settings/db/cliente daemon) | ✅ | `11697e2` |
| 4 Shell + Explorar + Detalles (end-to-end) | ✅ | `d537ea2` |
| 5 Lector webtoon/paginado + filtros de color | ✅ | `0d90b00` |
| 6 Home + Biblioteca | ❌ EN CURSO | — |
| 7 Descargas | ❌ | — |
| 8 Extensiones + Ajustes | ❌ | — |
| 9 Pulido | ❌ | — |

**Verificado:** `flutter analyze` 0 errores, 22 tests Dart pasan, tests JUnit
pasan, build linux OK, daemon probado contra MangaDex real (devuelve mangas con
portadas, URLs y descripciones).

### Archivos actuales (estructura)
```
app/lib/
├── main.dart                          # bootstrap (Xdg, AppDatabase, DAOs, overrides)
├── app.dart                           # ProviderScope raíz, providers, MaterialApp, BakenekoApp
├── core/
│   ├── xdg.dart                       # rutas XDG (data/config/cache/runtime) + ensureDirs
│   ├── settings.dart                  # Settings inmutable + SettingsStore (settings.json)
│   ├── models.dart                    # Manga/Chapter/Page/Source/Category/Download/HistoryEntry/MangaRef
│   ├── daemon/
│   │   ├── rpc.dart                   # codec JSON-RPC (request/response, RpcException)
│   │   └── daemon_client.dart         # spawn JVM +jar, connect UDS, facade tipado 7 métodos
│   ├── db/
│   │   ├── database.dart              # AppDatabase (sqlite3 FFI, PRAGMA user_version migraciones)
│   │   ├── schema.dart                # SQL embebido (string crudo)
│   │   └── dao/{manga,chapter,category,history,download}_dao.dart
│   └── theme/
│       ├── app_theme.dart             # paleta mockup + colorSchemeFor + appTheme
│       └── icons.dart                 # mapeo iconos mockup -> Material Icons
└── features/
    ├── shell/shell_view.dart          # sidebar + IndexedStack + nav + overlay Lector
    ├── browse/{browse_controller,browse_view}.dart   # Explorar (HECHO)
    ├── details/{details_controller,details_view}.dart # Detalles (HECHO)
    ├── reader/{reader_controller,reader_state,reader_view}.dart  # Lector (HECHO)
    └── {home,library,downloads,extensions,settings}/*_view.dart   # STUBS (placeholder)

daemon/src/main/kotlin/io/github/bakeneko/daemon/
├── Main.kt            # ServerSocketChannel UDS + accept loop + dispatch
├── LoaderContext.kt   # puerto del DesktopMangaLoaderContext original (JVM headless)
├── Methods.kt         # 7 handlers JSON-RPC
├── Models.kt          # DTOs @Serializable + mapeo bidireccional modelo parser <-> DTO
└── Rpc.kt             # RpcError + RpcCodes
daemon/src/test/kotlin/io/github/bakeneko/daemon/{ModelsTest,MethodsTest}.kt
```

### Providers de Riverpod disponibles (en `app.dart`)
- `daemonClientProvider` (DaemonClient) — override en main.dart
- `databaseProvider` (AppDatabase) — override en main.dart
- `settingsProvider` (StateNotifierProvider<SettingsNotifier, Settings>) — override
- `mangaDaoProvider`, `chapterDaoProvider`, `downloadDaoProvider`, `historyDaoProvider`
- `daemonReadyProvider` (FutureProvider<void>) — llama `daemonClient.start()`

### Providers por feature
- `navProvider` (StateNotifierProvider<NavigationController, NavState>) en shell_view
- `detailsStackProvider` (StateProvider<List<MangaRef>>)
- `readerChapterProvider` (StateProvider<int?>) — abre lector full-screen
- `browseProvider` (StateNotifierProvider<BrowseController, BrowseState>)
- `detailsProvider` (NotifierProvider.family<DetailsController, DetailsState, MangaRef>)
- `readerProvider` (NotifierProvider.family<ReaderController, ReaderState, ReaderArg>)

### Convenciones de código establecidas
- `ConsumerWidget.build(BuildContext, WidgetRef ref)` (NO `Ref`).
- `FamilyNotifier<State, Arg>` con `build(Arg)` + `ref.read(...)` para providers family.
- `NotifierProvider.family<Controller, State, Arg>(Controller.new)`.
- Imports: `package:bakeneko/...` para core, relativos `../...` para features.
- Spanish en UI (textos), inglés en código/identificadores.
- Enum settings: `AppThemeMode` (NO `ThemeMode`, que es de Material).
- SQL a mano en DAOs con `db.db.select(...)` y `db.db.execute(...)`.
- `AppDatabase.rowToMap(Row)` para convertir filas sqlite a Map.

---

## 5. Qué FALTA — fases 6-9 (detallado)

### Fase 6: Home + Biblioteca ⬅️ EMPEZAR AQUÍ

**Home** (`features/home/home_view.dart` — hoy es stub):
- Sección "Continue Reading": cards horizontales de `historyDao.list()` (mangas con
  progreso de lectura). Cada card muestra portada + "Cap. N".
- Sección "Recently Added": `mangaDao.favorites()` (los añadidos a biblioteca
  más recientes), grid horizontal.
- Al clic en un manga → `ref.read(navProvider.notifier).openManga(MangaRef(...))`.
- Reutilizar el widget de portada de Browse (`_MangaCard` — conviene extraerlo a
  `core/widgets/manga_cover.dart` compartido, DRY).

**Biblioteca** (`features/library/library_view.dart` — hoy es stub):
- Tabs de categorías arriba (`categoryDao.list()`), con color de cada categoría.
- Botón "+" para crear categoría (`categoryDao.create(name, color, autoDownload)`).
- Overflow menu (⋮) por categoría: renombrar, borrar, toggle auto-download.
- Panel de filtros de manga (todos / no leídos / leídos / descargados / no
  descargados) — ver mockup `LibraryFilterPanel`.
- Grid de mangas de la categoría activa (o toda la biblioteca si "Todas").
- Popover "Añadir a categoría" al hacer clic largo/dots en una portada: lista de
  categorías con checkbox (`categoryDao.assign/unassign`).
- Categoría default "Favoritos" implícita = `manga.library=1` (flag en tabla).

**Mockup de referencia:** `/home/crow/Downloads/Manga Reader Desktop UI (Community).zip`
— descomprimir y leer `src/App.tsx` (componentes `HomeScreen`, `LibraryScreen`,
`LibraryCategoryTabs`, `AddToCategoryPopover`, `LibraryFilterPanel`,
`LibraryOverflowMenu`, `MangaCover`). Ver Fase 8/9 notas del mockup abajo.

### Fase 7: Descargas

- **`core/downloads/download_manager.dart`** (NUEVO):
  - Cola FIFO persistida en tabla `download` (estados idle/queued/downloading/done/error).
  - Semaphore de 3 descargas paralelas (`package:dart:async` `Semaphore` casero o
    3 Futures encadenados — sin paquete extra).
  - Por capítulo: pedir `chapter.pages` + `page.url` al daemon, bajar cada imagen
    a `Xdg.downloadsRoot/<fuente>/<mangaHash>/<capHash>/0001.jpg` (mismo layout
    que el original → lectura offline idéntica), escribir `completed.txt` al
    terminar (marca de capítulo completo).
  - Escritura a `.part` + rename atómico. No re-descargar páginas existentes.
  - Stream de progreso a la UI via Riverpod (`downloadProgressProvider`).
  - `getDownloadedPages(source, mangaUrl, chapterUrl)` → lista de File para el
    lector offline (el `ReaderController` debe detectar si el capítulo está
    descargado y leer de disco en vez del daemon).

- **`features/downloads/downloads_view.dart`** (hoy stub): cola con estados
  animados (spinner pulsing como `dl-spin`/`dl-pulse` del CSS del mockup),
  estadísticas de almacenamiento (`Xdg.downloadsRoot` tamaño), pausar/cancelar.

- Integrar en `DetailsView`: botón "Descargar" por capítulo y "Descargar Todo".
- Integrar en `ReaderView`: si capítulo descargado → cargar desde disco.

### Fase 8: Extensiones + Ajustes

**Extensiones** (`features/extensions/extensions_view.dart` — hoy stub):
- Lista de fuentes de `daemon.listSources()` con toggle on/off.
- Búsqueda de extensiones (input + filtrado).
- On/off persiste en `settings.enabledSources`.
- Mockup: `ExtensionsScreen` (MangaDex y MangaPlus activados por defecto).

**Ajustes** (`features/settings/settings_view.dart` — hoy stub):
- Categorías del sidebar interno: Reader / Content / Languages / Extensions /
  Appearance (ver mockup `SettingsScreen` + `SETTINGS_CATEGORIES`).
- **Appearance**: `themeMode` (light/dark/system), `accent` (terracotta/sage),
  `gridDensity` (compact/comfortable/large) — todo persiste via
  `SettingsNotifier.update`. Yahay `colorSchemeFor` y `appTheme` listos.
- Reader: `defaultReadMode`, `readerColorFilter` defaults.
- Cada cambio llama `ref.read(settingsProvider.notifier).update((s) => s.copyWith(...))`.
- Preview deAppearance: widget `AppearancePreview` del mockup.

### Fase 9: Pulido

- Estados de error/vacío consistentes en todas las pantallas (extraer widget
  `ErrorView` y `EmptyView` compartidos a `core/widgets/`).
- Daemon crash detection en `DaemonClient` (detectar proceso muerto, banner
  "reiniciando motor de fuentes", re-lanzar con backoff máx. 3 intentos).
- Launcher script `bakeneko` (POSIX shell): fija rutas, arranca la app (que
  lanza el daemon). Empaquetado AppImage/deb opcional.
- `README.md` del repo (cómo correr, qué es).
- `AGENTS.md` para la próxima IA (estilo del original).
- `flutter analyze` 0 issues (incluyendo infos cosméticos), todos los tests
  pasan, build release OK, smoke manual completo (Explorar → Detalles → Lector
  → Descarga → offline → Home → Biblioteca → Ajustes).

---

## 6. Notas del mockup Figma (referencia visual)

El mockup es un export **Figma Make = React + Vite + Tailwind**, NO Flutter.
Está en:
`/home/crow/Downloads/Manga Reader Desktop UI (Community).zip`

Descomprimir y leer (solo referencia, NO portar código React):
```bash
unzip -p "Manga Reader Desktop UI (Community).zip" src/App.tsx   # 103KB, ~1750 líneas
unzip -p "Manga Reader Desktop UI (Community).zip" src/index.css # paleta + CSS
```

### Paleta (YA implementada en `core/theme/app_theme.dart` — NO cambiar)
```
espresso   #1a120b   (sidebar, fondo oscuro)
sage       #a3b19b   (acento sage)
tan        #ddb892
terracotta #e29578   (acento default, primary)
cream      #ede0d4   (foreground oscuro)
```
Light: bg `#ede0d4`, card `#f5ece2`, border `#d4b896`, mutedFg `#7a8c74`.
Dark: bg `#1a120b`, card `#231810`, border `#3a2a1e`, mutedFg `#a3b19b`.
Sidebar siempre espresso en ambos modos. Font **Inter**, radius **10px**.

### Componentes del mockup relevantes para fases 6-8
- `HomeScreen` (line ~1205): sections "Continue Reading" + "Recently Added".
- `LibraryScreen` (~651): tabs de categorías + grid + filtros.
- `LibraryCategoryTabs` (~520): tabs con context-menu (crear/ren/borrar/auto-dl).
- `AddToCategoryPopover` (~446): popover con lista categorías + checkbox.
- `LibraryFilterPanel` (~389): pane lateral de filtros.
- `MangaCover` (~326): card de manga reusable (TAMAÑOS sm/md, estado descarga).
- `DownloadsScreen` (~1554): cola con estados animados, stats de storage.
- `ExtensionsScreen` (~1494): lista fuentes + search + toggle.
- `SettingsScreen` (~1303) + `SETTINGS_CATEGORIES` (~1290): ajustes por categoría.
- `AppearancePreview` (~1255): preview de tema/acento.
- Iconos `Ico.*` (~129): ya mapeados a Material Icons en `core/theme/icons.dart`.
- Animaciones CSS `dl-spin`, `dl-pulse`: spinner de descarga pulsando.

---

## 7. Modelos de datos (BD SQLite)

Schema embebido en `app/lib/core/db/schema.dart` (string SQL). Tablas:

- **manga**(id PK, source, url, title, cover_url, description, blob_json, added_at,
  **library** INT 0/1, UNIQUE(source,url)) — `blob_json` guarda JSON opaco del daemon.
- **chapter**(manga_id FK, url, name, number, blob_json, read INT, PK(manga_id,url)).
- **category**(id PK, name UNIQUE, color, auto_download, created_at).
- **manga_category**(manga_id FK, category_id FK, PK ambos).
- **history**(manga_id PK FK, chapter_index, page_index, updated_at).
- **download**(manga_id PK FK, chapter_url PK, state, total_pages, done_pages).

Migraciones: `PRAGMA user_version`. v0→v1 ejecuta el schema entero. Para
versiones futuras añadir `case` en `AppDatabase._migrate`.

Layout descargas (igual que original): `<dataRoot>/downloads/<sourceName>/<mangaHash>/<chapterHash>/0001.jpg`
donde `mangaHash = mangaUrl.hashCode.toRadixString(16)`, `chapterHash` igual.
Marca de completo: archivo `completed.txt` en el dir del capítulo.

---

## 8. TDD y verificación (regla del proyecto)

> **Tests donde hay lógica, no donde hay UI trivial.** (doas también aplica a tests)

- Antes de implementar: test del comportamiento (DAO, codec, controller sin red).
- Después: `flutter test` verde + `flutter analyze` 0 errores + build linux OK.
- Commit por fase con mensaje `faseN: ...`.
- Smoke manual del daemon con `socat` tras cambios en el daemon Kotlin.

Tests actuales (22): `test/core/xdg_test.dart`, `settings_test.dart`,
`daemon/rpc_test.dart`, `db/database_test.dart`, `db/dao_test.dart`. Patrones:
usar `AppDatabase.memory()` para DAOs, `SettingsStore(file: tempFile)` para settings.

Para tests del daemon (JUnit en `daemon/src/test/...`): `./gradlew test`.

---

## 9. Reglas estrictas (NO romper)

1. **No añadir dependencias sin justificación fuerte.** El conteo de deps es
   parte del valor (doas). Si crees que necesitas X, pensar dos veces si se
   puede con stdlib/lo existente.
2. **Sin code-generation** (no drift, no freezed, no build_runner, no
   riverpod_generator). Modelos a mano.
3. **Sin go_router.** Navegación via `NavigationController` + `IndexedStack`.
4. **Solo Linux.** No tocar nada de Android/iOS/Windows/macOS.
5. **Rutas XDG** para todo lo persistente (NO `~/.futon`, NO paths hardcodeados).
6. **Español en UI**, inglés en código.
7. `ConsumerWidget.build(BuildContext, WidgetRef ref)` — el segundo parámetro es
   `WidgetRef`, NO `Ref`.
8. Enum settings se llama `AppThemeMode` (no colisionar con `ThemeMode` de Material).
9. Un archivo = una responsabilidad. Si crece >300 líneas, considerar partirlo.
10. Commits con `git -c user.name=crow -c user.email=crow@local commit -m "..."`.

---

## 10. Cómo retomar (checklist para la próxima IA)

```bash
cd /home/crow/Documents/Bakeneko-Reader
git log --oneline                              # confirma 7 commits (fases 0-5)
cat docs/superpowers/specs/2026-07-23-bakeneko-flutter-design.md  # spec completo
nix-shell                                      # entorno
# dentro de nix-shell:
cd daemon && ./gradlew shadowJar test          # daemon OK
cd ../app && flutter analyze && flutter test  # app OK (22 tests, 0 errores)
flutter build linux --debug                    # build OK
exit
```

Si todo verde → **Fase 6** (Home + Biblioteca), siguiendo §5 arriba.

**Prompt sugerido para iniciar:**
> "Estoy reanudando el refactor a Flutter de Bakeneko-Reader. Lee
> HANDOFF.md y docs/superpowers/specs/2026-07-23-bakeneko-flutter-design.md.
> Verifica el estado con nix-shell (daemon + app). Continúa por la Fase 6
> (Home + Biblioteca) siguiendo el handoff y el mockup Figma. TDD, commits
> por fase, sin nuevas dependencias."

---

## 11. Recursos

- **Spec:** `docs/superpowers/specs/2026-07-23-bakeneko-flutter-design.md`
- **Original Kotatsu parsers:** `github.com/KotatsuApp/Kotatsu` (parsers), mirror
  jitpack `com.github.AppFuton:futon-parsers:f287c414a6`
- **Mockup:** `/home/crow/Downloads/Manga Reader Desktop UI (Community).zip`
- **futon-parsers JAR caché:** `~/.gradle/caches/modules-2/files-2.1/com.github.AppFuton/futon-parsers/f287c414a6/`
  (usar `javap -p -cp <jar> <clase>` para ver firmas de modelos Kotlin)
- **Void Linux** (xbps, no apt). `doas` para root (no passwordless).

---

*Generado al quedarnos sin tokens. Todo en este doc está verificado salvo las
fases 6-9 (pendientes). Buena suerte.*