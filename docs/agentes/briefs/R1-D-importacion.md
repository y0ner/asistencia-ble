# Brief R1-D · Importar listas sin códigos dañados

- **Rama:** `fix/importacion` · **Worktree:** `../worktrees/fix-importacion`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `lib/data/services/roster_import_service.dart` (completo),
  `lib/features/teacher/roster_import_modal.dart` (completo),
  `lib/core/crypto/enrollment_packet_codec.dart` (`isValidStudentCode`; no lo edites),
  `test/roster_import_service_test.dart`. API real del paquete excel en
  `~/.pub-cache/hosted/pub.dev/excel-4.0.6/lib/src/` (`CellValue`,
  `TextCellValue`, `IntCellValue`, `DoubleCellValue`, `FormulaCellValue`, `TextSpan`).
- **Objetivo:** que la importación (CSV, XLSX, texto pegado y alta manual) no
  guarde códigos que nunca van a coincidir por Bluetooth.

**Regla del código estudiantil:** solo números, de 4 a 12 dígitos
(`EnrollmentPacketCodec.isValidStudentCode`). Los ceros a la izquierda se conservan.

## Archivos permitidos

- `lib/data/services/roster_import_service.dart`
- `lib/features/teacher/roster_import_modal.dart`
- `test/importacion_correcciones_test.dart` (**nuevo**)
- `test/roster_import_service_test.dart` (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **No se valida el código** (~líneas 223-255 y `addManualStudent` ~108).
   **Arreglo:** normaliza y valida cada código antes de guardar:
   - quita espacios de los extremos y los espacios internos
     («0182 120016» → «0182120016»);
   - si es un número con decimales en cero («12345.0», «12345,00»), quita los decimales;
   - si tiene notación científica («1,18212E+09», «1.18e9») o no pasa
     `isValidStudentCode`, la fila **no se importa** y se cuenta en un
     contador nuevo `invalidCodesSkipped` del resultado (agrégalo; no
     reutilices `invalidRowsSkipped`).
   - `addManualStudent` con un código inválido lanza `ArgumentError` con un
     mensaje para el docente: «El código debe tener solo números, de 4 a 12 dígitos.»
     y el modal lo muestra tal cual.
   - El modal, en el resumen de la importación, muestra cuántas filas se
     omitieron por código no válido, con una pista: «Revisa que la columna de
     códigos esté como texto en Excel.»
2. **Celdas de XLSX** (~líneas 453-471):
   - `IntCellValue` y `DoubleCellValue` con valor entero → los dígitos del
     número (sin «.0»).
   - `TextCellValue` cuyo `TextSpan` no tiene `text` pero sí `children`
     (formato mixto) → concatena el texto de los hijos (recursivo).
   - `FormulaCellValue` → no uses el texto de la fórmula como dato: la fila
     cuenta en `invalidCodesSkipped` si es la celda del código, o en
     `invalidRowsSkipped` si es la del nombre. El modal agrega la pista
     «Si la lista tiene fórmulas, cópiala y pégala como valores.» cuando haya
     filas omitidas por fórmula (agrega un contador `formulaCellsSkipped`).
3. **CSV de Excel en Windows** (`roster_import_modal.dart` ~línea 155): hoy se
   decodifica con `utf8.decode(allowMalformed: true)` y «PÉREZ» queda «P�REZ».
   **Arreglo:** intenta `utf8.decode(bytes)` estricto; si lanza
   `FormatException`, usa `latin1.decode(bytes)`. Saca esa lógica a una
   función estática pública del servicio (`decodeCsvBytes`) para poder probarla.
4. **Separador y encabezado del CSV** (~líneas 281 y 473-489): el separador se
   elige mirando solo la primera línea (si es un título sin separadores, sale
   `\t` y se importan 0 estudiantes) y el encabezado solo se busca en la
   primera fila. **Arreglo:** elige el separador (`;`, `,`, `\t`) contando en
   las primeras 5 líneas no vacías; busca el encabezado en las primeras 5 filas
   y descarta las filas anteriores a él.
5. **Encabezados no reconocidos** (~líneas 284-285): con
   «N°;Código;Apellidos;Nombres» el nombre se toma de la columna 1 (la del
   código). **Arreglo:**
   - reconoce como código: «codigo», «código», «cod», «cód», «codigo estudiantil»,
     «código estudiantil», «documento» no (no es el código);
   - como nombre completo: «nombre», «nombres y apellidos», «apellidos y nombres»,
     «nombre completo», «estudiante»;
   - si hay columnas separadas «apellidos» y «nombres», el nombre completo es
     `"<nombres> <apellidos>"`;
   - si no se encuentra la columna del nombre, **no** uses por defecto una
     columna que ya es la del código.
   Compara sin tildes, sin mayúsculas y sin espacios extra.
6. **Texto pegado** (`_splitClipboardLine` ~líneas 430-451): el ejemplo del
   cuadro separa con espacios («0182120016 MARÍA PÉREZ»), pero solo se separa
   por tab, `;`, `,` o guion, y un apellido compuesto («PEREZ-GOMEZ») se corta
   en el guion. **Arreglo:** separa por tab, `;` o `,` si los hay; si no, usa
   `^(\d{4,12})\s+(.+?)(?:\s+(\S+@\S+))?$`; un guion solo separa si tiene
   espacios a los dos lados (« - »).
7. **Homónimos descartados** (~líneas 230-233 y 141): dos «MARIA JOSE GOMEZ»
   con códigos distintos → el segundo se omite. **Arreglo:** los duplicados se
   detectan **solo por código**.
8. **Cupo de 64:** las filas omitidas por clase llena se cuentan en un contador
   nuevo `skippedClassFull`, no en `invalidRowsSkipped`, y el modal lo dice:
   «La clase ya está completa (64 estudiantes). No se agregaron N.» El cupo y
   los códigos existentes se cuentan con **activos y retirados**
   (`getAllStudentsByCourse`), porque los retirados conservan su casilla.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/importacion_correcciones_test.dart`:

- [ ] CSV con `12345.0`, `1,18212E+09`, `0182 120016` y `ABC123`: se importan
      `12345` y `0182120016`; los otros dos cuentan en `invalidCodesSkipped`.
- [ ] CSV con una línea de título antes de `CODIGO;NOMBRE`: importa todos los
      estudiantes y no crea uno llamado «NOMBRE».
- [ ] CSV «N°;Código;Apellidos;Nombres» → el nombre es «Nombres Apellidos» y
      el código es el de la columna «Código».
- [ ] `decodeCsvBytes(latin1.encode('0123456789;PÉREZ'))` contiene «PÉREZ».
- [ ] Texto pegado «0182120016 MARÍA PÉREZ-GÓMEZ» → un estudiante con ese
      código y nombre completo.
- [ ] Dos homónimos con códigos distintos → se importan los dos.
- [ ] XLSX (créalo en la prueba con el paquete excel) con una celda entera,
      una con fórmula y una de texto: se comportan como dice el arreglo 2.
- [ ] Clase con 63 estudiantes + CSV de 3 → 1 importado y `skippedClassFull == 2`.
- [ ] `addManualStudent` con «12ab» lanza `ArgumentError`.
- [ ] Pasan: `flutter test test/importacion_correcciones_test.dart` y
      `flutter test test/roster_import_service_test.dart`.

## Qué probará el humano

Importar una lista real exportada de Excel (CSV y XLSX) y pegar una lista: los
códigos y nombres quedan bien y el resumen explica lo que se omitió.
