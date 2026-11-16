# Brief H1-E · Primera apertura y botón de ayuda en las dos apps

- **Rama:** `feat/ayuda-integracion` · **Worktree:** `../worktrees/feat-ayuda-integracion`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/H1-comun.md`,
  `docs/especificaciones/como-funciona.md` (sección 5, «Dónde aparece»),
  `lib/features/shared/permissions_gate.dart` (modelo de «puerta»),
  `lib/data/services/first_run_store.dart` y `lib/app/asistencia_app.dart`.
- **Objetivo:** que el recorrido se muestre **una sola vez** al abrir la app
  (después de los permisos) y que el inicio de las dos apps tenga un botón
  «Ayuda».

## Contexto

Ya existen (no los edites):

- `HowItWorksTourScreen` y `HelpCenterScreen` en
  `lib/features/shared/how_it_works/`. **Otros agentes las construyen en
  paralelo:** en tu rama están vacías, pero sus constructores son definitivos.
- `HowItWorksContent.teacher` / `.student` (textos).
- `FirstRunStore`, `PrefsFirstRunStore` y `MemoryFirstRunStore`.

Hoy `AsistenciaApp` muestra `PermissionsGate(child: flavor.homeScreen)`. El
encabezado del inicio de cada app tiene un botón `Icons.tune_rounded`
(«Ajustes y diagnóstico») que abre `showHardwareDiagnosticDialog`:
`lib/features/teacher/courses_dashboard_screen.dart` (~línea 345) y
`lib/features/student/student_courses_screen.dart` (~línea 326).

## Archivos permitidos

- `lib/features/shared/how_it_works/how_it_works_gate.dart` (**nuevo**)
- `lib/app/app_flavor.dart`
- `lib/app/asistencia_app.dart`
- `lib/features/teacher/courses_dashboard_screen.dart` (**solo** el botón del encabezado y sus importaciones)
- `lib/features/student/student_courses_screen.dart` (**solo** el botón del encabezado y sus importaciones)
- `test/ui/ayuda_primera_vez_test.dart` (**nuevo**)
- `test/app_flavor_test.dart`, `test/ui/docente_inicio_test.dart`,
  `test/ui/estudiante_inicio_test.dart` (**solo** lo que dice el paso 5)

## Pasos

1. **`HowItWorksGate`** (archivo nuevo), un `StatefulWidget`:

   ```dart
   const HowItWorksGate({super.key, required this.content, required this.store, required this.child});
   final HowItWorksContent content;
   final FirstRunStore store;
   final Widget child;
   ```

   - Estado `bool? _seen` (nulo = aún no se sabe).
   - En `initState` llama `widget.store.hasSeenTour()` dentro de `try/catch`.
     Si falla, usa `debugPrint('No se pudo saber si ya vio el recorrido: $error')`
     y toma `true` (no se le estorba a la persona). Usa `if (mounted) setState(...)`.
   - `build`:
     - `_seen == null`: `ColoredBox(color: UiColors.of(context).background, child: const SizedBox.expand())`.
     - `_seen == false`: `HowItWorksTourScreen(content: widget.content, steps: widget.content.tour, firstRun: true, onFinished: _finish)`.
     - `_seen == true`: `widget.child`.
   - `_finish()`: `setState(() => _seen = true)` y luego guarda con
     `widget.store.markTourSeen()`; si falla, `debugPrint` con el error (no
     `catch (_)`). No esperes el guardado para mostrar el inicio.

2. **`AppFlavor`**: agrega el getter
   `HowItWorksContent get helpContent` que devuelve `HowItWorksContent.teacher`
   para `docente` y `HowItWorksContent.student` para `estudiante`.

3. **`AsistenciaApp`**: agrega el parámetro opcional
   `this.firstRunStore = const PrefsFirstRunStore()` (`final FirstRunStore firstRunStore;`)
   y deja el inicio así:

   ```dart
   home: PermissionsGate(
     service: AppPermissionsService(needsCamera: flavor == AppFlavor.estudiante),
     child: HowItWorksGate(
       content: flavor.helpContent,
       store: firstRunStore,
       child: flavor.homeScreen,
     ),
   ),
   ```

4. **Botón «Ayuda» en los dos inicios:** reemplaza el `UiRoundIconButton` de
   `Icons.tune_rounded` por:

   ```dart
   UiRoundIconButton(
     icon: Icons.help_outline_rounded,
     tooltip: 'Ayuda',
     onPressed: () => Navigator.of(context).push(
       MaterialPageRoute(builder: (_) => const HelpCenterScreen(content: HowItWorksContent.teacher)),
     ),
   ),
   ```

   (en el del estudiante, `HowItWorksContent.student`). El diagnóstico se abre
   ahora desde «Permisos del celular» dentro de la ayuda. Quita la importación
   de `hardware_diagnostic_dialog.dart` **solo si** ya no se usa en ese archivo.
   No cambies nada más de esas dos pantallas.

5. **Pruebas existentes** (cambio mínimo):
   - `test/ui/docente_inicio_test.dart` y `test/ui/estudiante_inicio_test.dart`:
     donde buscan el tooltip `'Ajustes y diagnóstico'`, busca `'Ayuda'`. Agrega
     en cada archivo **una** prueba: tocar el botón «Ayuda» abre un
     `HelpCenterScreen` cuyo `content` es el de esa app
     (`tester.widget<HelpCenterScreen>(find.byType(HelpCenterScreen)).content`).
   - `test/app_flavor_test.dart`: pasa
     `firstRunStore: MemoryFirstRunStore(seen: true)` a cada `AsistenciaApp`
     (quita el `const` donde haga falta), cambia `Icons.tune_rounded` por
     `Icons.help_outline_rounded` y, en la prueba que toca ese ícono, comprueba
     que se abre `HelpCenterScreen` en lugar del diálogo de diagnóstico.
   - No cambies ni borres ninguna otra comprobación.

6. **Prueba nueva** `test/ui/ayuda_primera_vez_test.dart` (ver criterios).

## Criterios de aceptación (además de los comunes)

En las pruebas, **no uses `pumpAndSettle`** donde haya un dibujo animado en
pantalla: usa `pump()` y `pump(const Duration(milliseconds: 600))`.

- [ ] `HowItWorksGate` con `MemoryFirstRunStore()` (no visto) y un hijo
      `Text('INICIO')`: muestra un `HowItWorksTourScreen` con `firstRun == true`
      y `steps` igual a `content.tour`; no muestra «INICIO».
- [ ] Al llamar el `onFinished` de ese widget
      (`tester.widget<HowItWorksTourScreen>(...).onFinished!()`) y hacer
      `pump()`, aparece «INICIO», desaparece el recorrido y `store.seen` es `true`.
- [ ] Con `MemoryFirstRunStore(seen: true)` muestra «INICIO» directamente.
- [ ] Con un `FirstRunStore` falso cuyo `hasSeenTour()` lanza un error, muestra
      «INICIO» y `tester.takeException()` es nulo.
- [ ] `AppFlavor.docente.helpContent` es `HowItWorksContent.teacher` y
      `AppFlavor.estudiante.helpContent` es `HowItWorksContent.student`.
- [ ] `flutter test test/app_flavor_test.dart test/ui/docente_inicio_test.dart test/ui/estudiante_inicio_test.dart test/ui/ayuda_primera_vez_test.dart test/ui/permisos_inicio_test.dart`
      pasa (puedes correr esos cinco archivos).
- [ ] `grep -rn "tune_rounded\|Ajustes y diagnóstico" lib test` no devuelve nada.

## Qué probará el humano

Desinstalar e instalar las dos apps: tras los permisos sale el recorrido una
sola vez; al cerrar y abrir ya no sale; el botón «?» del inicio abre la ayuda.
