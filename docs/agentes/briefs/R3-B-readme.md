# Brief R3-B · README profesional (inglés + español), CONTRIBUTING, CHANGELOG y textos de tienda

- **Rama:** `docs/readme` · **Worktree:** `~/Desktop/Projects/worktrees/asistencia-docs-readme` · **Base:** `release/v1.0.0`
- **Lee primero:** `AGENTS.md`, `docs/diseno/SISTEMA.md`, `docs/especificaciones/como-funciona.md`,
  `run.sh`, `pubspec.yaml`, `lib/core/constants/app_constants.dart`, `lib/core/crypto/`
  y `docs/brand/`.
- **Objetivo:** que el GitHub de **AsistenciaBLE** quede al nivel de proyectos como
  NewPipe: README claro, visual y completo, en inglés (`README.md`) y español
  (`README.es.md`). Además, actualizar `AGENTS.md` y `docs/diseno/SISTEMA.md` al
  nombre nuevo.
- **Ejemplo terminado para imitar la calidad (no copiar el contenido):**
  https://github.com/y0ner/folio (README.md, README.es.md, CONTRIBUTING.md,
  CHANGELOG.md, fastlane/). No tienes red: imita la estructura que describe este brief.

## Datos del proyecto (el jefe los llena; el agente NO inventa nada)

- **Nombre:** AsistenciaBLE. Son **dos apps** desde una sola base de código Flutter:
  **AsistenciaBLE Docente** (`co.edu.uniguajira.asistencia_uniguajira.docente`) y
  **AsistenciaBLE Estudiante** (`co.edu.uniguajira.asistencia_uniguajira.estudiante`).
  Versión **1.0.0** (`pubspec.yaml`, versionCode 1).
- **Repo:** `https://github.com/y0ner/asistencia-ble` · **Licencia:** Apache-2.0 (archivo `LICENSE`).
- **Qué es (EN):** "Serverless, offline attendance for universities: students mark
  attendance by bringing their phone close to the teacher's, over Bluetooth Low Energy."
  **(ES):** "Asistencia sin servidor y sin internet para instituciones de educación
  superior: el estudiante marca acercando su celular al del docente, por Bluetooth de baja energía."
- **Proyecto de grado (sección propia «Academic project» / «Proyecto académico»):**
  «Aplicación móvil para el registro de asistencia por proximidad Bluetooth sin
  servidor en instituciones de educación superior». Autores: Yoner De Jesús Isaza
  Vides y Álvaro Luis Garrido Medina. Director: Miguel Humberto Romero Acuña.
  Docente de Proyecto I: Lisseth Paola Castañeda Vega. Ingeniería de Sistemas,
  Facultad de Ingeniería, Universidad de La Guajira, Riohacha, 2026. La solución es
  para **cualquier IES**; la **prueba piloto** se hace en Ingeniería de Sistemas de
  la Universidad de La Guajira, sede Riohacha. No es una app oficial de la universidad.
- **Funciones** (verifica cada número en el código antes de escribirlo):
  - Cursos sin tocar el sistema académico: importar la lista desde `.xlsx`/`.csv`,
    pegarla desde el portapapeles o agregar estudiantes a mano.
  - Inscripción el primer día: el docente muestra un QR, el estudiante lo escanea,
    escribe su código y el docente aprueba la solicitud (ver `como-funciona.md`).
  - Toma de asistencia: el docente abre la sesión y dicta un PIN de 2 dígitos; el
    estudiante lo escribe y **acerca** su celular. El estudiante emite una etiqueta
    rotativa HMAC-SHA256 que cambia cada 30 s; el docente responde con un eco que
    contiene un mapa de bits de 8 bytes (64 posiciones) y el estudiante ve
    «¡Presente!» sin conexión GATT ni servidor. Umbral de proximidad por RSSI
    (−75 dBm por defecto). Máximo **64 estudiantes por clase**.
  - Lista invertida: el docente marca a un toque a quien no tiene celular o batería.
  - Cierre con acta de sesión firmada; reporte **Excel** (`.xlsx`) con 4 hojas
    (Resumen, Detalle, Sesiones, Metadatos) que se comparte desde el celular.
  - Sincronización **opcional** con Google Sheets/Drive con la cuenta de Google del
    docente (el perfil piloto exige el dominio institucional).
  - Ayuda con dibujos animados: recorrido de primera apertura y centro de ayuda.
  - Diagnóstico de permisos de Bluetooth, ubicación y cámara.
  - Todo funciona **sin internet** durante la clase; los datos viven en SQLite en el celular.
- **Perfiles de compilación:** por defecto, perfil **general** (cualquier
  institución, cualquier cuenta de Google). `INSTITUCION=uniguajira ./run.sh apk`
  compila el perfil **piloto** con el escudo y el dominio `@uniguajira.edu.co`.
- **Requisitos:** Android 7.0+ (minSdk 24), Bluetooth LE con soporte de anuncio
  (advertising) en el celular del docente y del estudiante.
  **Tamaño de la APK:** escribe exactamente `{{APK_SIZE_MB}}` donde va el tamaño (el jefe lo reemplaza).
- **Permisos y por qué** (`android/app/src/main/AndroidManifest.xml`):
  `BLUETOOTH_SCAN` (con `neverForLocation`), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`
  (proximidad); `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE/COARSE_LOCATION` solo
  hasta Android 11 (lo exige el escaneo BLE allí); `CAMERA` (escanear el QR de
  inscripción); `INTERNET` (solo para la sincronización opcional con Google).
- **Stack:** Flutter 3.47.1 / Dart 3.13, sqflite, crypto + cryptography,
  flutter_blue_plus, flutter_ble_peripheral, mobile_scanner + qr_flutter, excel,
  google_sign_in + googleapis, share_plus. Tipografía Figtree (OFL, `assets/fonts/OFL.txt`).
- **Firma de las APK:** SHA-256 del certificado
  `11:4F:E7:08:BD:60:DF:3E:1B:7A:D9:C0:E8:CE:D5:0E:2A:42:84:EE:C4:25:49:A7:26:6B:97:C3:AA:54:DE:5E`.
- **Descarga:** `https://github.com/y0ner/asistencia-ble/releases/latest`, archivos
  `asistenciable-docente-v1.0.0-arm64.apk` y `asistenciable-estudiante-v1.0.0-arm64.apk`.
  Dos botones grandes: "Download Teacher app" y "Download Student app", con enlace
  directo `https://github.com/y0ner/asistencia-ble/releases/latest/download/<archivo>`.
- **Sitio web:** `https://asistencia-ble.vercel.app`.
- **Compilar:** `./run.sh docente android`, `./run.sh estudiante android`,
  `./run.sh apk` (las dos), `./run.sh test`, `./run.sh analyze` (lee `run.sh` para
  los nombres exactos).
- **Cómo se construyó:** agente jefe (Claude Code) que escribe briefs y revisa, y
  agentes Gemini (CLI `agy`) que implementan cada tarea en su worktree por
  oleadas, con PR revisado y pruebas en 2 celulares Android reales
  (`docs/agentes/`, `docs/pruebas/`).

## Imágenes (rutas fijas; el jefe las genera)

- Ícono para el README: `docs/brand/asistenciable-icon-512.png` (ancho 120).
- `fastlane/metadata/android/en-US/images/icon.png` (512 px) y `featureGraphic.png` (1024×500).
- `fastlane/metadata/android/en-US/images/phoneScreenshots/1.png … 8.png` en este orden:
  1 inicio del docente, 2 sesión en vivo del docente, 3 estudiante marcando,
  4 «¡Presente!», 5 inscripción por QR, 6 cierre/reporte, 7 ayuda, 8 inicio del docente en oscuro.
  Aún no existen: enlázalas igual.

## Archivos permitidos

- `README.md` (reemplázalo entero), `README.es.md` (**nuevo**), `CONTRIBUTING.md`
  (**nuevo**), `CHANGELOG.md` (**nuevo**, Keep a Changelog)
- `fastlane/metadata/android/{en-US,es-ES}/{title.txt,short_description.txt,full_description.txt,changelogs/1.txt}` (**nuevos**)
- `AGENTS.md` y `docs/diseno/SISTEMA.md`: **solo** cambiar el nombre «Asistencia
  Uniguajira»/«Asistencia Multimodal Uniguajira» por «AsistenciaBLE» y, donde se
  presente el proyecto, decir que es para IES con piloto en la Uniguajira. Nada más.

## Qué hacer

1. **README** (estructura tipo NewPipe, estilo propio y sobrio):
   - Encabezado HTML centrado: ícono (ancho 120), `<h2>` AsistenciaBLE, `<h4>` frase corta.
   - Dos botones shields.io grandes (`style=for-the-badge`) de descarga (Docente y
     Estudiante). Insignias: release (`github/v/release/y0ner/asistencia-ble`),
     licencia Apache-2.0, Android 7.0+, Flutter, y solo atributos reales (offline,
     serverless, no tracking). **Nada** de insignias de servicios que no se usan.
   - Selector de idioma `English · [Español](README.es.md)`.
   - Barra de anclas separada por `&bull;` y segunda barra (Website · Releases · Changelog).
   - Línea visible: "Current version: **1.0.0** — [release notes](CHANGELOG.md)".
   - Secciones: `## Screenshots` (gráfico destacado + capturas de ancho 200 en filas
     de 4), `## Description`, `## How it works` (los pasos de inscripción y de cada
     clase, quién hace cada uno; una tabla o lista numerada), `## Features`
     agrupadas, `## Download & installation` (cuál app instala cada quien) con
     `### APK signing certificate` (huella en bloque de código), `## Privacy`
     (sin servidor, sin rastreo, datos en el celular, Google solo si el docente
     lo activa; Ley 1581 de 2012 en Colombia), `## Building from source` (incluye
     los perfiles general/piloto), `## Tech stack & architecture`,
     `## Academic project`, `## How it was built`, `## Contributing`,
     `## Third-party`, `## License`.
2. `README.es.md`: misma estructura, traducción natural.
3. `CONTRIBUTING.md` (cómo compilar, ramas `dev`/`main`, commits en español con
   prefijo, pruebas obligatorias, no tocar el protocolo BLE sin discutirlo),
   `CHANGELOG.md` (`## [1.0.0] - 2026-11-25` con Added: las funciones; Changed: el
   nombre pasa a AsistenciaBLE y la marca institucional queda en un perfil piloto;
   licencia Apache-2.0) y textos fastlane (`title.txt` = "AsistenciaBLE",
   `short_description` ≤ 80 caracteres, `full_description` ≤ 4000, `changelogs/1.txt` ≤ 500)
   en en-US y es-ES.
4. Verifica que las anclas coincidan con los encabezados reales (GitHub:
   minúsculas, espacios → `-`, quita `&`).

## Criterios de aceptación

- [ ] `git diff --stat release/v1.0.0` solo muestra archivos permitidos.
- [ ] `wc -m fastlane/metadata/android/*/short_description.txt` ≤ 80; `full_description.txt` ≤ 4000; `changelogs/1.txt` ≤ 500.
- [ ] Ningún dato inventado: cada función y número sale de este brief o del código.
- [ ] `grep -n "TODO\|lorem\|example.com" README*.md CONTRIBUTING.md CHANGELOG.md` sin resultados.
- [ ] `grep -c "{{APK_SIZE_MB}}" README.md README.es.md` ≥ 1 en cada uno.
- [ ] `grep -n -i "uniguajira" README*.md` solo aparece en el contexto del piloto, del proyecto académico o del perfil `INSTITUCION=uniguajira`.
