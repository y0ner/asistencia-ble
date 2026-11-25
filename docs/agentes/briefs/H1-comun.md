# Reglas comunes de la Oleada H1 («Cómo funciona»)

Aplican a todos los briefs `H1-*`, además de `AGENTS.md`.

1. **Lee primero, completos:** `docs/especificaciones/como-funciona.md`,
   `docs/diseno/SISTEMA.md` y los archivos que cite tu brief.
2. **Toca solo tus «Archivos permitidos».** La base ya está hecha y no se
   cambia: `lib/ui/components/scenes/ui_scene.dart`, `ui_scene_canvas.dart`,
   `scene_acercar.dart`, `how_it_works_content.dart`, `first_run_store.dart`
   y `test/support/scene_probe.dart`. Si crees que a la base le falta algo,
   **no la edites**: explícalo en tu respuesta final.
3. **No escribas textos propios.** Todo texto visible sale de
   `HowItWorksContent` (`lib/features/shared/how_it_works/how_it_works_content.dart`).
4. **No cambies las firmas** (constructores, nombres de funciones) que ya
   existen: otros agentes trabajan en paralelo contra ellas.
5. **Colores, tamaños y letras solo con tokens:** `UiColors.of(context)`,
   `UiSpace`, `UiRadius`, `UiSize`, `UiText`, `UiMotion`. En los dibujos, solo
   `g.palette` y las constantes de `UiScenePalette`.
6. **Nada de trampas para pasar pruebas:** no escondas textos (`Opacity(0)`,
   `Offstage`), no fuerces un tema, no silencies errores (`catch (_) {}`), no
   dejes `TODO` ni código simulado, no debilites pruebas existentes.
7. **Debe aguantar** claro y oscuro, un celular de 360 × 640 y la letra del
   sistema al 130 % sin desbordes.
8. **No formatees archivos enteros** (`dart format` no). El diff debe mostrar
   solo tu cambio.
9. **Comandos permitidos:** `flutter analyze --no-pub` y
   `flutter test <tu archivo de prueba>` (solo los que nombra tu brief). Nada
   más. Si una prueba tarda, espera a que termine: no la relances ni te quedes
   esperando una que ya terminó.
10. **Pruebas:** carga la letra como `test/ui/ui_gallery_test.dart`
    (`_loadFigtree`) y usa `UiTheme.light()` / `UiTheme.dark()`.

## Criterios comunes de aceptación

- [ ] `git diff --stat dev` muestra solo tus archivos permitidos.
- [ ] `grep -nP "Color\(0x|(?<![A-Za-z])Colors\.(?!transparent)|fontSize:" <tus archivos de lib/>` no devuelve nada. No uses alias ni extensiones para esquivar la búsqueda.
- [ ] `grep -nE "TODO|catch \(_\)|Opacity\(opacity: 0|Offstage" <tus archivos>` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Tus pruebas nuevas pasan.
