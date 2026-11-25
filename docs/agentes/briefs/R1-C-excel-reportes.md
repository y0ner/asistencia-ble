# Brief R1-C · Excel y reportes: retirados, inscritos tarde y exportación que no falle

- **Rama:** `fix/excel-reportes` · **Worktree:** `../worktrees/fix-excel-reportes`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `docs/especificaciones/oleada-2-inscripcion.md` (secciones 7 y 9),
  `lib/data/services/excel_report_service.dart` (completo),
  `lib/features/teacher/course_reports_screen.dart` (completo),
  `lib/data/services/course_overview_service.dart`,
  `lib/core/models/student_model.dart` (`status`, `origin`, `deviceBoundAt`, `retiredAt`),
  `lib/data/local/app_database.dart` (`getStudentsByCourse` = solo activos,
  `getAllStudentsByCourse` = activos y retirados; **no lo edites**).
- **Objetivo:** que el Excel cumpla la especificación con los retirados, que no
  cuente fallas antes de que alguien se inscribiera y que exportar no falle por
  la carpeta de Descargas.

## Archivos permitidos

- `lib/data/services/excel_report_service.dart`
- `lib/features/teacher/course_reports_screen.dart`
- `lib/data/services/course_overview_service.dart`
- `test/excel_correcciones_test.dart` (**nuevo**)
- `test/excel_and_cloud_sync_test.dart`, `test/course_overview_service_test.dart`,
  `test/ui/docente_reportes_test.dart` (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **Los retirados desaparecen del Excel.** `buildCourseSummary` (~línea 356)
   usa `getStudentsByCourse` (solo activos), pero el diálogo de retirar promete
   que «su historial se conserva en los reportes y el Excel». **Arreglo** según
   la especificación (§7 y §9):
   - Usa `getAllStudentsByCourse`. Ordena: activos por `bitIndex` y después
     los retirados por `bitIndex` (**al final**).
   - En la hoja de estudiantes (`Resumen`) agrega las columnas **«Origen»**
     («Lista» o «Agregado en clase», según `wasAddedInClass`),
     **«Celular vinculado desde»** (fecha local `dd/MM/yyyy` de `deviceBoundAt`,
     o vacío) y **«Estado»** («Activo» o «Retirado el dd/MM/yyyy»).
   - Los retirados **no entran** en promedios, en «en riesgo» ni en
     `TotalEstudiantesMatriculados` (que cuenta solo activos). Si la hoja de
     metadatos lista totales, agrega una fila `TotalEstudiantesRetirados`.
   - No cambies cómo se calcula `reportHmacSha256`.
2. **Quien se inscribe tarde queda con fallas de sesiones anteriores.** Hoy a
   cada estudiante se le cuentan todas las sesiones cerradas (~línea 410).
   **Arreglo:** una sesión cerrada cuenta para un estudiante si:
   - la sesión tiene acta guardada y el estudiante aparece en sus `records`
     (compara por `studentCode`); o
   - la sesión no tiene acta y el `enrolledAt` del estudiante es nulo o
     anterior o igual al `startedAt` de la sesión.
   Porcentajes, inasistencias y estados se calculan sobre **sus** sesiones. En
   la hoja `Detalle`, una sesión que no le cuenta va con «—» (no como falla).
3. **«13 de 12» en el resumen de la clase.** En `course_overview_service.dart`
   (~línea 125), `presentCount` cuenta registros de retirados mientras
   `totalStudents` cuenta solo activos. **Arreglo:** cuenta solo registros de
   estudiantes activos.
4. **Exportar falla según el Android.** `_resolveExportDirectory`
   (`course_reports_screen.dart` ~línea 164) elige `/storage/emulated/0/Download`
   si existe, pero en Android 7–10 la app no tiene permiso para escribir ahí, y
   en Android 11+ no puede sobrescribir un archivo que dejó una instalación
   anterior. El error sale al escribir, así que nunca se usa el respaldo.
   **Arreglo:**
   - Intenta escribir en Descargas; si **escribir** lanza (`FileSystemException`
     u otra), escribe en la carpeta privada de la app
     (`p.join(Directory.systemTemp.path, 'reports')`) y sigue igual (diálogo de
     éxito con «Compartir»). Registra el primer error con `debugPrint`.
   - `_checkLatestExportedFile` busca el archivo en las dos carpetas y se queda
     con el más reciente.
5. **Dos clases con el mismo código y grupo comparten archivo.**
   `exportFileNameFor` (~línea 676) solo usa código y grupo. **Arreglo:** agrega
   el semestre y los 6 primeros caracteres de `course.id`, saneados igual:
   `Asistencia_Uniguajira_<codigo>_<grupo>_<semestre>_<id6>.xlsx`.
6. **«100 %» sin sesiones cerradas.** En `course_reports_screen.dart`
   (~línea 274), con estudiantes pero sin sesiones cerradas se muestra «100 %»,
   mientras Inicio y Clase muestran «—». **Arreglo:** usa
   `CourseOverviewService.averageAttendance` y muestra «—» cuando sea nulo.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/excel_correcciones_test.dart` (base en memoria como
`test/excel_and_cloud_sync_test.dart`):

- [ ] Un retirado con asistencias aparece en `Resumen` **después** de todos los
      activos, con «Estado» = «Retirado el …», y no cambia el promedio ni
      «en riesgo» (compara con y sin el retirado).
- [ ] Las columnas «Origen», «Celular vinculado desde» y «Estado» existen con
      los valores esperados para un estudiante de lista sin celular y uno
      agregado en clase con celular.
- [ ] Un estudiante inscrito después de dos sesiones cerradas (no aparece en
      sus actas) y presente en la tercera tiene 100 % y 0 inasistencias.
- [ ] `CourseOverviewService`: con un retirado que tenía asistencia en la
      última sesión, `presentCount <= totalStudents`.
- [ ] `exportFileNameFor` de dos clases con igual código y grupo pero distinto
      semestre o id da nombres distintos.
- [ ] `exportWorkbookToFile` con un directorio donde no se puede escribir
      lanza; la pantalla usa el respaldo (si no puedes probar la pantalla,
      saca la lógica de «intentar y si falla usar el respaldo» a un método
      `@visibleForTesting` estático y pruébalo).
- [ ] Pasan: `flutter test test/excel_correcciones_test.dart`,
      `flutter test test/excel_and_cloud_sync_test.dart`,
      `flutter test test/course_overview_service_test.dart`,
      `flutter test test/ui/docente_reportes_test.dart`.

## Qué probará el humano

Retirar a un estudiante con asistencias, exportar el Excel y abrirlo: aparece
al final como «Retirado el …». Exportar dos veces seguidas sin error.
