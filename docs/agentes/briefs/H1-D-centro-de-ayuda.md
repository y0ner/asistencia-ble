# Brief H1-D · Pantalla del centro de ayuda

- **Rama:** `feat/ayuda-centro` · **Worktree:** `../worktrees/feat-ayuda-centro`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/H1-comun.md`,
  `docs/especificaciones/como-funciona.md` (sección 5),
  `lib/features/shared/how_it_works/how_it_works_content.dart` y
  `lib/ui/gallery/ui_gallery_screen.dart` (cómo se usa cada componente).
- **Objetivo:** construir `HelpCenterScreen`: la pantalla «Ayuda» con el acceso
  al recorrido, los temas, «Bueno saber» y «Si algo falla».

## Contexto

`lib/features/shared/how_it_works/help_center_screen.dart` ya existe con su
**constructor definitivo** (no lo cambies) y un `build` vacío.

Los temas abren `HowItWorksTourScreen`
(`lib/features/shared/how_it_works/how_it_works_tour_screen.dart`). **Esa
pantalla la construye otro agente en paralelo:** en tu rama está vacía, así
que solo puedes comprobar que se abre con los parámetros correctos. No la edites.

## Archivos permitidos

- `lib/features/shared/how_it_works/help_center_screen.dart`
- `test/ui/ayuda_centro_test.dart` (**nuevo**)

## Cómo debe quedar

`UiPage(header: UiTopBar(title: HowItWorksContent.helpTitle, onBack: () => Navigator.of(context).pop()), body: ListView(...))`.

El `ListView` lleva `padding: EdgeInsets.only(bottom: UiSpace.xxl)` y, en este orden:

1. **Tarjeta del recorrido** (con margen horizontal `UiSpace.page` y superior
   `UiSpace.sm`): `UiHeroCard` con una columna:
   - Una fila: a la izquierda, en un `Expanded`, `HowItWorksContent.firstTime`
     (`UiText.label`, color `onPrimary`) y debajo `content.tourIntro`
     (`UiText.h2`, color `onPrimary`); a la derecha un
     `SizedBox(width: 132, child: UiScene(kind: UiSceneKind.acercar, studentView: content.studentView))`.
     Si el ancho disponible es menor de 300 o la letra del sistema está por
     encima del 115 % (`MediaQuery.textScalerOf(context).scale(1) > 1.15`), no
     pongas el dibujo al lado: ponlo debajo del texto, con ancho máximo 220.
   - Separación `UiSpace.lg`.
   - `UiButton(label: HowItWorksContent.openTour, variant: UiButtonVariant.onHero, onPressed: ...)`
     que abre el recorrido completo:
     `HowItWorksTourScreen(content: content, steps: content.tour)`.
2. `UiSectionTitle(HowItWorksContent.topicsTitle)`.
3. **Temas** (margen horizontal `UiSpace.page`): una tarjeta por
   `content.topics`, en **dos columnas** separadas `UiSpace.md` (usa
   `LayoutBuilder` + `Wrap` con `spacing` y `runSpacing` de `UiSpace.md`, y
   cada tarjeta con ancho `(ancho - UiSpace.md) / 2`). Con letra por encima del
   115 % o ancho menor de 300: **una columna** (cada tarjeta a todo el ancho).
   Cada tarjeta (widget privado `_TopicTile`): `UiCard(onTap: ...)` con una
   columna alineada a la izquierda:
   - Un cuadro de 40 × 40 con radio `UiRadius.sm` y fondo
     `UiColors.of(context).tone(topic.tone).background`, con `Icon(topic.icon, size: 22, color: ...tone(topic.tone).foreground)`.
     (Mira en `lib/ui/tokens/ui_colors.dart` los nombres reales de los campos de `UiTonePair`.)
   - Separación `UiSpace.md`; `topic.title` (`UiText.bodyStrong`, color `ink`);
     separación `UiSpace.xs`; `topic.subtitle` (`UiText.caption`, color `muted`).
   - En dos columnas, las dos tarjetas de una misma fila deben tener el mismo
     alto (por ejemplo armando filas con `IntrinsicHeight` + `Row` +
     `Expanded` en lugar de `Wrap`; elige lo que no desborde).
   - Al tocar abre `HowItWorksTourScreen(content: content, steps: topic.steps, title: topic.title)`.
   - `Semantics(button: true, label: '${topic.title}. ${topic.subtitle}')`.
4. `UiSectionTitle(HowItWorksContent.factsTitle)`.
5. **Bueno saber** (margen horizontal `UiSpace.page`): `UiListGroup` con una
   fila por `content.facts` (widget privado `_FactRow`): relleno `UiSpace.md`,
   un cuadro de 40 × 40 (radio `UiRadius.sm`, fondo `tint`) con
   `Icon(fact.icon, size: 22, color: tintText)`, separación `UiSpace.md` y, en
   un `Expanded`, `fact.title` (`UiText.bodyStrong`, `ink`) y debajo
   `fact.body` (`UiText.caption`, `muted`). No son tocables.
6. `UiSectionTitle(HowItWorksContent.troubleTitle)`.
7. **Si algo falla** (margen horizontal `UiSpace.page`): `UiListGroup` con:
   - Un `UiNavRow(title: topic.title, subtitle: topic.subtitle, onTap: ...)`
     por cada `content.troubleshooting`, que abre
     `HowItWorksTourScreen(content: content, steps: topic.steps, title: topic.title)`.
   - Al final, `UiNavRow(title: HowItWorksContent.permissionsTitle, subtitle: HowItWorksContent.permissionsSubtitle, onTap: ...)`
     que llama `onOpenPermissions!(context)` si no es nulo y, si es nulo,
     `showHardwareDiagnosticDialog(context)`
     (`lib/features/shared/hardware_diagnostic_dialog.dart`).

Abre las pantallas con
`Navigator.of(context).push(MaterialPageRoute(builder: (_) => ...))`.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/ui/ayuda_centro_test.dart`. Como el dibujo se anima sin
parar, **no uses `pumpAndSettle`**: usa `pump(const Duration(milliseconds: 600))`.
Pasa siempre `onOpenPermissions` en las pruebas (el diálogo real usa Bluetooth).

- [ ] Docente (`HowItWorksContent.teacher`): muestra «Ayuda», «¿Primera vez?»,
      `content.tourIntro`, «Ver el recorrido», los 6 títulos de temas, los
      títulos de «Bueno saber» (incluido el de 64 estudiantes),
      «No encuentra a un estudiante» y «Permisos del celular». Para ver lo de
      abajo desplaza el `ListView` (`tester.scrollUntilVisible` o `drag`).
- [ ] Tocar «Ver el recorrido» abre un `HowItWorksTourScreen` cuyo widget tiene
      `steps` igual a `content.tour` y `firstRun == false`
      (`tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen))`).
- [ ] Tocar el tema «Sin celular» abre un `HowItWorksTourScreen` con `steps`
      igual a los del tema y `title == 'Sin celular'`.
- [ ] Tocar «No encuentra a un estudiante» abre el recorrido de ese tema.
- [ ] Tocar «Permisos del celular» llama `onOpenPermissions` una vez.
- [ ] Estudiante (`HowItWorksContent.student`): muestra sus 4 temas y
      «No encuentra a mi profesor».
- [ ] En claro y en oscuro, a 360 × 640 con letra al 130 %
      (`tester.platformDispatcher.textScaleFactorTestValue = 1.3`) y también a
      390 × 844 con letra normal: desplaza hasta el final y verifica
      `tester.takeException() == null`.

## Qué probará el humano

Abrir «Ayuda» en los dos celulares, entrar a cada tema y volver.
