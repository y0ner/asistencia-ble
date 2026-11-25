# Brief R2-D · Importación: que vuelvan a entrar las listas con encabezados comunes

- **Rama:** `fix/importacion-encabezados` · **Worktree:** `../worktrees/fix-importacion-encabezados`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md` (valen igual
  para R2), `docs/agentes/briefs/R1-D-importacion.md` (lo que se arregló antes),
  `lib/data/services/roster_import_service.dart` (completo, sobre todo
  `_mapRows`, `_headerMapping` y `_normalizeHeaderToken`) y
  `test/importacion_correcciones_test.dart`.
- **Objetivo:** corregir una **regresión** de R1-D. Hoy una lista con
  encabezado pero sin una columna de nombre «reconocida» importa 0 estudiantes.

## Archivos permitidos

- `lib/data/services/roster_import_service.dart`
- `test/importacion_correcciones_test.dart`
- `test/roster_import_service_test.dart` (solo para agregar casos)

## Fallos a corregir

1. **Regresión: listas comunes importan 0 estudiantes.** Antes, si había
   encabezado y no se reconocía la columna del nombre, se usaba la columna 1.
   R1-D quitó ese respaldo. Ahora fallan (todas las filas se cuentan como
   «datos incompletos»):
   - `CODIGO;NOMBRES`: «nombres» solo se usa si también hay «apellidos»;
   - `Código;Nombre del estudiante`, `Código;Apellidos y nombre`, `Código;Alumno`;
   - `ID;Nombre;Correo`: no se reconoce el código.
   **Arreglo** (en este orden):
   - Nombre completo:
     1. la columna de nombre completo reconocida;
     2. si no, nombres + apellidos si están las dos;
     3. si no, solo «nombres» o solo «apellidos» si hay una;
     4. si no, la **primera columna que no sea la del código ni la del correo** y que tenga texto no numérico en la primera fila de datos.
   - Código:
     1. la columna de código reconocida;
     2. si no, la primera columna cuya primera fila de datos sea un código válido
        (`EnrollmentPacketCodec.isValidStudentCode` tras normalizar).
   - Agrega sinónimos: nombre «nombre del estudiante», «nombre estudiante»,
     «apellidos y nombre», «alumno», «nombres completos»; código «id»,
     «codigo alumno». «Documento» o «identificación» **no** son el código.
2. **`_normalizeHeaderToken`** debe juntar los espacios internos repetidos
   («Código  estudiantil» → «codigo estudiantil»), además de quitar tildes y
   mayúsculas, y quitar signos como `:`, `.` o `°` al final.
3. **Prueba débil:** en `test/importacion_correcciones_test.dart` (~línea 52) el
   CSV va separado por comas, así que `1,18212E+09` se parte en «1» y
   «18212E+09» y nunca pasa por el chequeo de notación científica. Usa `;` como
   separador en esa prueba (o comillas) para que de verdad la ejerza.
4. **Prueba que falta:** el cupo de 64 cuenta a los retirados (clase con 62
   activos + 1 retirado + CSV de 3 → 1 importado y `skippedClassFull == 2`).

## Criterios de aceptación (además de los comunes)

Agrega en `test/importacion_correcciones_test.dart`, un caso por fila. Cada
caso importa 2 estudiantes con nombre y código correctos:

- [ ] `CODIGO;NOMBRES`
- [ ] `Código;Nombre del estudiante`
- [ ] `Código;Apellidos y nombre`
- [ ] `ID;Nombre;Correo`
- [ ] `Codigo;Alumno`
- [ ] `Código  estudiantil:;Nombre completo`
- [ ] `N°;Código;Apellidos;Nombres` sigue funcionando como antes.
- [ ] La prueba de notación científica rechaza de verdad `1,18212E+09` por
      notación científica (comprueba que la fila llega completa al chequeo).
- [ ] La prueba del cupo con un retirado.
- [ ] Pasan: `flutter test test/importacion_correcciones_test.dart` y
      `flutter test test/roster_import_service_test.dart`.

## Qué probará el humano

Importar una lista con encabezado «Código;Nombres»: entran todos.
