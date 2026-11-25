# Brief H1-C · Pantalla del recorrido paso a paso

- **Rama:** `feat/ayuda-recorrido` · **Worktree:** `../worktrees/feat-ayuda-recorrido`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/H1-comun.md`,
  `docs/especificaciones/como-funciona.md` (secciones 2 y 5),
  `lib/features/shared/how_it_works/how_it_works_content.dart` y
  `lib/ui/gallery/ui_gallery_screen.dart` (cómo se usa cada componente).
- **Objetivo:** construir `HowItWorksTourScreen`: una pantalla por paso con
  dibujo, quién lo hace, título, texto y consejo.

## Contexto

`lib/features/shared/how_it_works/how_it_works_tour_screen.dart` ya existe con
su **constructor definitivo** (no lo cambies) y un `build` vacío. Otros agentes
ya abren esta pantalla con ese constructor.

- `steps` puede ser el recorrido completo (`content.tour`, 6 o 7 pasos) o los
  pasos de un tema (1 a 4 pasos).
- `firstRun: true` = se muestra sola la primera vez que se abre la app.
- `onFinished` se llama al tocar «Entendido» o «Saltar». Si es nulo, la
  pantalla hace `Navigator.of(context).pop()`.

## Archivos permitidos

- `lib/features/shared/how_it_works/how_it_works_tour_screen.dart`
- `test/ui/ayuda_recorrido_test.dart` (**nuevo**)

## Cómo debe quedar

Usa `UiPage(header:, body:, bottom:)`.

### Encabezado (`header`)

Una columna con:

1. **Barra:**
   - Si `firstRun` es `false`: `UiTopBar(title: widget.title, titleMaxLines: 1, onBack: () => Navigator.of(context).pop())`.
   - Si `firstRun` es `true`: una fila con margen horizontal `UiSpace.page` y
     alto mínimo `UiSize.touch`: a la izquierda `widget.title` (`UiText.label`,
     color `muted`); a la derecha un `TextButton` con el texto
     `HowItWorksContent.skip` (`UiText.button`, color `primaryText`, alto mínimo
     `UiSize.touch`) que termina el recorrido (ver «Terminar»).
2. **Progreso** (solo si hay más de un paso): una fila con margen horizontal
   `UiSpace.page`, con un tramo por paso (`Expanded`, alto 6, radio
   `UiRadius.pill`), separados 6. Si un paso es `HowSection.everyClass` y el
   anterior es `HowSection.once`, la separación entre esos dos es 14.
   Color de cada tramo: los que van hasta el paso actual, `manualDot` si su
   paso es `HowSection.once` y `primary` en cualquier otro caso; los que
   faltan, `line`. Envuelve la fila en
   `Semantics(label: HowItWorksContent.stepCounter(actual, total))` con
   `ExcludeSemantics` adentro.

### Cuerpo (`body`)

Un `PageView` con un `PageController`, una página por paso (se puede deslizar).
Cada página es un `SingleChildScrollView` con margen
`EdgeInsets.fromLTRB(UiSpace.page, UiSpace.lg, UiSpace.page, UiSpace.lg)` y una
columna alineada a la izquierda (`CrossAxisAlignment.start`) con, en este orden
y separados por `UiSpace.md`:

1. Si `step.section` no es nulo: `UiPill(label: content.sectionLabel(step.section!), tone: ...)`
   con `UiTone.manual` para `HowSection.once` y `UiTone.tint` para `HowSection.everyClass`.
2. `UiScene(kind: step.scene, studentView: content.studentView)` a todo el ancho.
3. Una fila: a la izquierda el **rótulo de quién lo hace** (ver abajo); a la
   derecha, solo si hay más de un paso,
   `HowItWorksContent.stepCounter(indice + 1, total)` (`UiText.label`, color `muted`).
   Si no caben en una fila con letra grande, usa `Wrap` (nunca cortes texto).
4. `step.title` con `UiText.h1`, color `ink`.
5. `step.body` con `UiText.body`, color `muted`.
6. Si `step.tip` no es nulo: una caja con fondo `surface`, borde `line`, radio
   `UiRadius.md` y relleno `UiSpace.md`, con una fila: ícono
   `Icons.lightbulb_outline_rounded` (tamaño 22, color `manualText`) y, en un
   `Expanded`, el consejo con `UiText.label`, color `ink`.

### Rótulo de quién lo hace (widget privado `_ActorBadge`)

Texto: `content.actorLabel(step.actor)` con `UiText.label` y `FontWeight.w700`.
Forma de pastilla (radio `UiRadius.pill`, relleno horizontal `UiSpace.md`,
vertical 6), con un ícono pequeño a la izquierda. El estilo depende del **rol**
de quien hace el paso, no de quién mira:

- Calcula `esProfesor = (step.actor == HowActor.you) != content.studentView`
  (solo cuando `step.actor` no es `HowActor.auto`).
- **Profesor:** fondo `primary`, texto `onPrimary`, e ícono = un rectángulo de
  12 × 16 con radio 3.5 **relleno** de `onPrimary`.
- **Estudiante:** fondo `surface`, borde de 1.5 color `ink`, texto `ink`, e
  ícono = un rectángulo de 12 × 16 con radio 3.5 **sin relleno** y borde de 2
  color `ink`.
- **`HowActor.auto`:** fondo `manualBg`, texto `manualText`, ícono
  `Icons.check_circle_outline_rounded` (tamaño 16, color `manualText`).

Envuelve el rótulo en `Semantics(label: <el mismo texto>)` con `ExcludeSemantics`.

### Botones (`bottom`)

Una fila con relleno `EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.lg)`:

- Si no es el primer paso: `Expanded(child: UiButton(label: HowItWorksContent.back, variant: UiButtonVariant.outline, onPressed: <paso anterior>))` y una separación de `UiSpace.md`.
- Siempre: `Expanded(flex: 2, child: UiButton(label: ..., onPressed: ...))`. En
  el último paso el texto es `HowItWorksContent.done` y termina el recorrido;
  en los demás es `HowItWorksContent.next` y pasa al siguiente.

Mira en `lib/ui/components/ui_layout.dart` si `UiPage` ya le pone margen a
`bottom`; si ya lo pone, no lo dupliques.

### Comportamiento

- El paso actual vive en el estado (`_index`). Cambia con los botones y al
  deslizar (`onPageChanged`).
- Los botones mueven el `PageView` con
  `animateToPage(..., duration: UiMotion.base, curve: UiMotion.curve)`. Si
  `MediaQuery.disableAnimationsOf(context)` es `true`, usa `jumpToPage`.
- **Terminar** («Entendido» o «Saltar»): si `widget.onFinished` no es nulo,
  llámalo; si es nulo, `Navigator.of(context).pop()`.
- Libera el `PageController` en `dispose`.
- Si `steps` está vacío, lanza un `assert` en el constructor del estado
  (`assert(widget.steps.isNotEmpty)`); no dibujes nada especial.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/ui/ayuda_recorrido_test.dart`. Monta la pantalla dentro de
`MaterialApp(theme: ..., home: ...)`. Como los dibujos se animan sin parar,
**no uses `pumpAndSettle`**: usa `pump(const Duration(milliseconds: 600))`.

- [ ] Docente, recorrido completo (`HowItWorksContent.teacher.tour`): muestra
      el título del paso 1, «Lo haces tú», «Paso 1 de 7» y «Una sola vez · Inscribir»;
      no muestra «Atrás». Al tocar «Siguiente» muestra el título del paso 2,
      «Lo hace el estudiante» y «Atrás». «Atrás» vuelve al paso 1.
- [ ] Avanzando hasta el paso 7 el botón dice «Entendido» y al tocarlo se llama
      `onFinished` exactamente una vez.
- [ ] Con `firstRun: true` aparece «Saltar», no hay botón de volver
      (`find.byType(BackButton)` y el tooltip de volver no aparecen) y tocar
      «Saltar» llama `onFinished` una vez.
- [ ] Con `onFinished` nulo dentro de un `Navigator` (abre la pantalla con
      `Navigator.push`), «Entendido» cierra la pantalla.
- [ ] Un tema de un solo paso (`HowItWorksContent.teacher.topics` con id
      `sin-celular`): no muestra «Paso 1 de 1» ni «Atrás»; el botón dice «Entendido».
- [ ] Estudiante (`HowItWorksContent.student.tour`): el paso 3 muestra
      «Lo hace tu profesor» y el paso 6 «Pasa solo».
- [ ] En claro y en oscuro, a 360 × 640 con letra al 130 %
      (`tester.platformDispatcher.textScaleFactorTestValue = 1.3`), recorre
      **todos** los pasos del docente y del estudiante y verifica
      `tester.takeException() == null` en cada uno.
- [ ] Hay un `UiScene` visible en cada paso con el `kind` del paso.

## Qué probará el humano

Abrir la app por primera vez en los dos celulares y recorrer los pasos.
