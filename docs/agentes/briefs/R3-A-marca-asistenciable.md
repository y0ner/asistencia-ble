# Brief R3-A · Marca «AsistenciaBLE» configurable por institución

- **Rama:** `feat/marca-asistenciable` · **Worktree:** `~/Desktop/Projects/worktrees/asistencia-feat-marca-asistenciable` · **Base:** `release/v1.0.0`
- **Lee primero:** `AGENTS.md` (reglas obligatorias) e `INFORME_CAMBIO_DE_NOMBRE.md`
  (resumen abajo; si no está en el worktree, basta este brief).
- **Objetivo:** que la app deje de presentarse como «Asistencia Uniguajira» y se
  llame **AsistenciaBLE**, una solución para cualquier institución de educación
  superior (IES). La marca de la Universidad de La Guajira queda solo en un
  **perfil piloto** que se elige al compilar.

## Contexto (por qué)

El documento de grado ya no es para la Universidad de La Guajira: es para IES
en general, con la **prueba piloto** en Ingeniería de Sistemas de la
Uniguajira (Riohacha). El documento llama a las apps «AsistenciaBLE – Docente»
y «AsistenciaBLE – Estudiante». Hoy el código:

- `lib/core/constants/app_constants.dart:8` `appName = 'Asistencia Uniguajira'` y
  `:11` `institutionalDomain = '@uniguajira.edu.co'` (obligatorio en
  `cloud_sync_service.dart:258`, sugerido en `enrollment_host_screen.dart:473`).
- `lib/ui/components/ui_layout.dart:9` escudo fijo y `:70-85` encabezado con
  «Asistencia» / «Universidad de La Guajira» escritos a mano.
- Textos visibles con «Asistencia Uniguajira»: `student_enrollment_model.dart:79,214,235`,
  `student_enrollment_service.dart:20,28`, `excel_report_service.dart:643` (título)
  y `:747` (nombre del `.xlsx`), `report_share_service.dart:150`.
- Ejemplos `@uniguajira.edu.co` en `roster_import_modal.dart:302-303,402`.
- `demo_seed_service.dart:111-186`: nombres y correos de **personas reales**
  (docente y compañeros). Por privacidad (Ley 1581) deben ser ficticios.
- Comentarios: `ble_packet_codec.dart:48`, `ui.dart:1`, `ui_colors.dart:17`,
  `enrollment_packet_codec.dart:79`, `app_constants.dart:1`,
  `cloud_sync_service.dart:222,241`, `student_enrollment_service.dart:16`.

**No se toca** (romperían los datos de los celulares del piloto o la
compatibilidad entre celulares): `applicationId`/`namespace`, el paquete Kotlin,
`AppConstants.databaseName` (`asistencia_uniguajira.db`), el nombre del paquete
Dart (`package:asistencia_uniguajira/...`) y el formato de los paquetes BLE y del QR.

## Archivos permitidos

- `lib/core/config/institution_config.dart` (**nuevo**)
- `lib/core/constants/app_constants.dart`
- `lib/core/crypto/ble_packet_codec.dart`, `lib/core/crypto/enrollment_packet_codec.dart` (solo comentarios)
- `lib/core/models/student_enrollment_model.dart`
- `lib/data/services/student_enrollment_service.dart`, `demo_seed_service.dart`,
  `report_share_service.dart`, `cloud_sync_service.dart`, `excel_report_service.dart`
- `lib/features/teacher/roster_import_modal.dart`, `lib/features/teacher/enrollment_host_screen.dart`
- `lib/ui/ui.dart`, `lib/ui/tokens/ui_colors.dart` (solo comentarios), `lib/ui/components/ui_layout.dart`
- Cualquier otro archivo de `lib/` **solo** si usa `AppConstants.appName` o
  `AppConstants.institutionalDomain` (cámbialo por la configuración).
- `run.sh`
- `test/**` (ajustar expectativas) y `test/institution_config_test.dart` (**nuevo**)

## Qué hacer

1. **Configuración** en `lib/core/config/institution_config.dart`:
   ```dart
   class InstitutionProfile {            // const, inmutable
     final String id;                    // 'general' | 'uniguajira'
     final String appName;               // 'AsistenciaBLE' en los dos
     final String headerSubtitle;        // texto bajo el nombre en el encabezado
     final String? emailDomain;          // null = cualquier correo válido
     final String emblemAsset;
     final String emblemSemanticLabel;
   }
   abstract final class InstitutionConfig {
     static const general = InstitutionProfile(id: 'general', appName: 'AsistenciaBLE',
       headerSubtitle: 'Asistencia por proximidad', emailDomain: null,
       emblemAsset: 'assets/brand/asistenciable_icono.png', emblemSemanticLabel: 'Ícono de AsistenciaBLE');
     static const uniguajira = InstitutionProfile(id: 'uniguajira', appName: 'AsistenciaBLE',
       headerSubtitle: 'Universidad de La Guajira', emailDomain: '@uniguajira.edu.co',
       emblemAsset: 'assets/brand/escudo_uniguajira.png', emblemSemanticLabel: 'Escudo de la Universidad de La Guajira');
     static const String selectedId = String.fromEnvironment('INSTITUCION', defaultValue: 'general');
     static InstitutionProfile byId(String id) => id == 'uniguajira' ? uniguajira : general;
     static InstitutionProfile get current => byId(selectedId);
   }
   ```
   Documenta cada campo con `///` en español. El asset `assets/brand/asistenciable_icono.png`
   ya existe y ya está en `pubspec.yaml`.
2. **AppConstants:** quita `appName` e `institutionalDomain` (y actualiza el
   comentario de la línea 1). Reemplaza todos sus usos por `InstitutionConfig`.
3. **CloudSyncService:** nuevo parámetro opcional `InstitutionProfile? institution`
   (por defecto `InstitutionConfig.current`), guardado en un campo.
   `isValidInstitutionalEmail`:
   - con `emailDomain` → igual que hoy (dominio exacto, sin distinguir mayúsculas);
   - con `emailDomain == null` → acepta cualquier correo con las **mismas** reglas de
     la parte local que hoy (sin espacios, una sola `@`, sin puntos al inicio/fin
     ni dobles) y un dominio con al menos un punto, sin espacios ni puntos al
     inicio/fin.
   El mensaje de error de la línea ~305 menciona el dominio solo si existe.
   Actualiza el comentario de la clase (`/// Servicio de sincronización con cuentas de Google…`).
4. **Encabezado** (`ui_layout.dart`): emblema, etiqueta semántica, título
   (`appName`) y subtítulo (`headerSubtitle`) desde `InstitutionConfig.current`.
   Quita la constante `uiBrandEmblemAsset` o hazla un getter que lea la configuración
   (revisa sus usos con `grep -rn uiBrandEmblemAsset lib test`).
5. **Textos visibles:** «Asistencia Uniguajira» → «AsistenciaBLE» en los errores
   del QR (pueden seguir siendo literales `const`), el mensaje al compartir y el
   título del Excel: `'AsistenciaBLE (BLE + Mapa de Bits 8B)'`. Nombre del
   archivo: `AsistenciaBLE_<curso>_<grupo>_<semestre>_<id6>.xlsx` (mismo resto del formato).
6. **Ejemplos de formularios:** `jperez@institucion.edu.co`, `mgomez@institucion.edu.co`,
   `usuario@institucion.edu.co`. En `enrollment_host_screen.dart:473`:
   `'nombre${dominio}'` si el perfil trae dominio, si no `'nombre@institucion.edu.co'`.
7. **Datos de demostración** (`demo_seed_service.dart`): los 12 estudiantes y el
   docente con **nombres ficticios** colombianos variados (en el mismo formato
   «APELLIDOS NOMBRES» en mayúsculas que hoy) y correos `@institucion.edu.co`.
   Códigos de estudiante ficticios de 10 dígitos que empiecen por `2026` (cambia
   también `primaryStudentCode` y `secondaryStudentCode`). Docente:
   `docente.demo@institucion.edu.co`. Curso, grupo, semestre y secreto, igual.
8. **Comentarios:** cambia «Asistencia Uniguajira» por «AsistenciaBLE» en los
   comentarios listados. En `enrollment_packet_codec.dart:79`: «(en la
   institución piloto son 10)».
9. **run.sh:** si existe la variable de entorno `INSTITUCION`, agrega
   `--dart-define=INSTITUCION=$INSTITUCION` a `flutter build apk` (los dos
   flavors) y a `flutter run`. Cambia los textos «Asistencia Uniguajira» por
   «AsistenciaBLE» y documenta en la ayuda:
   `INSTITUCION=uniguajira ./run.sh apk   # perfil piloto con escudo y dominio`.
10. **Pruebas:**
    - Ajusta las expectativas que cambian (nombre del `.xlsx`, título del Excel,
      datos demo, `AppConstants.institutionalDomain` → un literal
      `'@institucion.edu.co'` en los datos de prueba). **No debilites** ninguna prueba.
    - Las pruebas de `isValidInstitutionalEmail` que hoy exigen `@uniguajira.edu.co`
      se quedan, pero construyendo el servicio con `institution: InstitutionConfig.uniguajira`.
    - Nuevo `test/institution_config_test.dart`: `byId` (incluye id desconocido →
      `general`), perfil general acepta `ana.perez@gmail.com` y
      `docente@cualquiera.edu.co` y rechaza `sin-arroba`, `a@b`, `.a@x.co`,
      `a..b@x.co`, `a b@x.co`, `a@@x.co`; perfil uniguajira rechaza `docente@gmail.com`.
    - Si alguna prueba de widgets busca el texto «Universidad de La Guajira» o
      «Asistencia» del encabezado, ajústala al perfil general.

## Criterios de aceptación

- [ ] `grep -rn -i "guajira" lib | grep -v "package:asistencia_uniguajira"` devuelve
      **solo** líneas de `lib/core/config/institution_config.dart` y la de
      `databaseName` en `app_constants.dart`.
- [ ] `grep -rn "uniguajira.edu.co" test` solo aparece en pruebas que usan
      `InstitutionConfig.uniguajira`.
- [ ] `grep -rn "institutionalDomain\|AppConstants.appName" lib test` no devuelve nada.
- [ ] `grep -rn "applicationId\|asistencia_uniguajira.db" android lib` igual que antes (no se tocó).
- [ ] `test/institution_config_test.dart` existe con los casos del paso 10.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin `TODO`, sin `catch (_) {}`, sin textos escondidos.

## Qué se probará en el entorno real (lo hace el humano)

1. `./run.sh apk` → instalar **encima** de la versión actual en 2 celulares: los
   cursos, inscripciones y actas siguen ahí; el lanzador dice «AsistenciaBLE Docente/Estudiante».
2. El encabezado muestra el ícono de AsistenciaBLE y «Asistencia por proximidad».
3. `INSTITUCION=uniguajira ./run.sh apk` → escudo y «Universidad de La Guajira»; un
   correo `@gmail.com` no se acepta para sincronizar.
