## Fase 7: Descargas

### Alcance (decisiones de diseño)
- **`DownloadManager`** (`core/downloads/download_manager.dart`, NUEVO): cola persistida en tabla `download`, **3 descargas paralelas** (semáforo casero con 3 workers), escritura a `.part` + rename atómico, no re-descargar páginas existentes, marca `completed.txt` al terminar.
- **Sin pausa real** (decision acordada abajo): el modelo `DownloadState` no tiene `paused` y añadirlo implica suspender Futures. La UI ofrecerá **cancelar/borrar**, no pausar. Mantengo el alcance fiel al esquema de DB existente.
- **HTTP con `dart:io HttpClient`** (stdlib, **cero dependencias nuevas** — regla doas). Headers del source (Referer/UA) vía `daemon.sourceHeaders`.
- **Progreso a la UI** vía `downloadProgressProvider` (StateNotifier que emite un mapa `chapterKey → DownloadEntry`).
- **Lectura offline**: `DownloadManager.getDownloadedPages(...)` devuelve lista de `File`; el `ReaderController` detecta capítulo descargado y lee de disco en vez del daemon.
- Integración: botón "Descargar" por capítulo + "Descargar todo" en `DetailsView`.

### 1. DAO: extender `DownloadDao` (sin schema changes)
- `List<DownloadEntry> list()` — todos, ordenados.
- `List<DownloadEntry> done()` — state=done (para stats y detección offline).
- `int countChapters()` / `int countManga()` — stats de storage (manga distintos con done).
- Ya existe `forManga`, `pending`, `get`, `remove`, `setState`, `setProgress`.

### 2. `DownloadManager` (NUEVO, la unidad con lógica — TDD)
Constructor recibe `DaemonClient`, `MangaDao`, `DownloadDao`, `Xdg.downloadsRoot`. Métodos públicos:
- `Future<void> enqueue(Manga manga, Chapter chapter)` — marca queued en DB, notifica, arranca pump del worker pool.
- `Stream<DownloadEntry> watch()` — emite cambios de progreso/estado.
- `List<File> pagesFor(Manga manga, Chapter chapter)` — lectura offline (si `completed.txt` existe).
- `bool isComplete(Manga manga, Chapter chapter)`.
- `Future<void> cancel(int mangaId, String chapterUrl)` — quita de cola + borra archivos parciales.
- `Future<void> delete(int mangaId, String chapterUrl)` — borra capítulo completo del disco + fila DB.
- Interno: 3 workers consumen una cola en memoria (sincronizada vía `Completer`/`Queue`), cada uno pide `chapterPages` + `pageUrl` al daemon, baja cada imagen con `HttpClient`, escribe `NNNN.jpg.part` → rename, actualiza `setProgress` en DB y emite por el stream. Al terminar todas → `completed.txt` + state=done.
- **Layout**: `downloadsRoot/<sourceName>/<mangaHash>/<chapterHash>/0001.jpg` donde `hash = url.hashCode.toRadixString(16)` (igual que el original, handoff §7).

### 3. Providers (Riverpod)
- `downloadManagerProvider` (Provider<DownloadManager>) — override en main.dart.
- `downloadProgressProvider` (StreamProvider o StateNotifierProvider) — la UI observa el progreso.

### 4. Tests (TDD — la lógica está en DownloadManager, NO en UI)
- **`test/core/downloads/download_manager_test.dart`** (NUEVO) con un **daemon falso** (clase que implementa la interfaz que DownloadManager usa: `chapterPages`, `pageUrl`, `sourceHeaders`). mocktail o un stub manual (prefiero stub manual mínimo, sin mocktail para esta unidad, al estilo del proyecto). Verifica:
  - enqueue marca queued y arranca workers.
  - tras procesar: archivos `.jpg` escritos en el layout correcto + `completed.txt`.
  - no re-descarga páginas existentes (segunda corrida no re-escribe).
  - `.part` + rename atómico (no queda `.part` al terminar).
  - cancel elimina cola + archivos.
  - 3 paralelas: con N chapters, a lo sumo 3 en state=downloading simultáneo.
- **`test/core/db/download_dao_test.dart`** (extender o nuevo): `list`, `done`, contadores.
- Usa `AppDatabase.memory()` + directorio temporal real (`await Directory.systemTemp.createTemp(...)`) para los archivos.

### 5. Vistas
- **`features/downloads/downloads_view.dart`** (reescribir stub): header "Descargas". Resumen de storage (tamaño del dir + nº chapters, con barra). Sección "Cola" (pendientes, con spinner/barra de progreso) y "Completados" (lista). Botón cancelar/borrar por item. Estados vacíos.
- **`features/details/details_view.dart`** (integrar): botón de descarga por capítulo (icono según estado: idle/download/spinner/done) + "Descargar todo" en el header de capítulos. Al clic → `downloadManagerProvider.enqueue(...)`.
- **`features/reader/reader_controller.dart`** (integrar offline): en `_load`, comprobar `downloadManager.isComplete(...)`; si lo está, leer `pagesFor(...)` y poblar `pageUrls` con `file://` paths sin tocar el daemon.

### 6. No tocar
- Sin nuevas dependencias (HttpClient es stdlib; no añado dio/http).
- Sin codegen.
- Sin pausa (state `paused` no existe en DB).

### Verificación
1. `flutter test` verde (incluye tests del DownloadManager con daemon falso).
2. `flutter analyze` 0 errores.
3. `flutter build linux --debug` OK.
4. Smoke manual: Explorar → abrir manga → Descargar capítulo → ver progreso en Descargas → abrir capítulo offline (desconectando red o validando que lee de disco).

### Commit
`fase7: descargas (cola persistente, 3 paralelas, lectura offline)`

### Orden de ejecución
1. Tests + impl `DownloadDao.list/done/counters`.
2. `DownloadManager` + tests con daemon falso (cola, paralelismo, layout, atomicidad, idempotencia).
3. Providers + override en main.dart.
4. `downloads_view.dart`.
5. Integración Details (botones de descarga).
6. Integración Reader (offline).
7. Verificación + commit.