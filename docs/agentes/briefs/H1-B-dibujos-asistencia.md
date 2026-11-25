# Brief H1-B · Animar los dibujos de asistencia

- **Rama:** `feat/ayuda-dibujos-asistencia` · **Worktree:** `../worktrees/feat-ayuda-dibujos-asistencia`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/H1-comun.md`,
  `docs/especificaciones/como-funciona.md` (sección 4, tabla «Animación de cada dibujo»).
- **Objetivo:** que seis dibujos que hoy están quietos se animen suavemente, tal
  como dice la tabla de la especificación.

## Contexto

Cada dibujo es una función `void paintSceneX(UiSceneCanvas g, double t)` que
pinta en un lienzo de 320 × 220. `t` va de 0 a 1 y se repite cada 3,6 s. Hoy
esas funciones ignoran `t`: pintan el dibujo quieto, ya correcto y aprobado.

- **Modelo a imitar:** `lib/ui/components/scenes/scene_acercar.dart` (ya animado).
- **Herramientas:** `lib/ui/components/scenes/ui_scene_canvas.dart`
  - `UiSceneAnim.wave / appear / bump / step / mix` (curvas de tiempo).
  - `g.group(dx:, dy:, scale:, pivot:, opacity:, draw: () { ... })` para mover,
    escalar o atenuar varias figuras juntas.
  - `g.path(..., progress:)` para que un trazo «se escriba» y
    `g.path(..., dash:, dashOffset:)` para que un punteado «corra».
  - `opacity:` en `g.rrect`, `g.circle`, `g.path` y `g.text`.
- **Referencia visual:** `docs/diseno/referencias/como-funciona/<nombre>.svg`.

## Archivos permitidos

- `lib/ui/components/scenes/scene_pin.dart`
- `lib/ui/components/scenes/scene_teclado.dart`
- `lib/ui/components/scenes/scene_listo.dart`
- `lib/ui/components/scenes/scene_presente.dart`
- `lib/ui/components/scenes/scene_amano.dart`
- `lib/ui/components/scenes/scene_excel.dart`
- `test/ui/escenas_asistencia_test.dart` (**nuevo**)

## Pasos

1. En cada uno de los seis archivos, aplica **exactamente** la animación de su
   fila en la tabla de la especificación. Usa los mismos números.
2. **No cambies las figuras:** conserva cada `g.rrect`, `g.circle`, `g.path` y
   `g.text` con sus mismas coordenadas, colores y grosores. Solo puedes:
   agregarles `opacity:`, `progress:` o `dashOffset:`; envolver varias en
   `g.group(...)`; cambiar un radio cuando la tabla lo pida; y, en `amano`,
   agregar el círculo y el visto que pide la tabla.
3. Conserva el orden en que se pintan las figuras (lo último queda encima).
4. Actualiza el comentario de cada función: quita «Por ahora es un dibujo
   quieto: falta animarlo con `t`.» y describe en una o dos líneas qué se mueve
   (como en `scene_acercar.dart`).
5. En reposo (`t = 0.9`) el dibujo debe verse completo.
6. Crea `test/ui/escenas_asistencia_test.dart` con este contenido exacto:

```dart
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_probe.dart';

void main() {
  for (final kind in [
    UiSceneKind.pin,
    UiSceneKind.teclado,
    UiSceneKind.listo,
    UiSceneKind.presente,
    UiSceneKind.amano,
    UiSceneKind.excel,
  ]) {
    testWidgets('el dibujo ${kind.name} se anima y queda completo en reposo', (tester) async {
      await expectSceneAnimates(tester, kind);
    });
  }
}
```

## Criterios de aceptación (además de los comunes)

- [ ] `flutter test test/ui/escenas_asistencia_test.dart` pasa (6 pruebas).
- [ ] `flutter test test/ui/escena_base_test.dart` sigue pasando (puedes correrla).
- [ ] `grep -c "falta animarlo" lib/ui/components/scenes/scene_{pin,teclado,listo,presente,amano,excel}.dart` da 0 en todos.
- [ ] Ninguna figura cambió de coordenadas ni de color (el agente jefe lo compara con `git diff`).
- [ ] Solo importas `ui_scene_canvas.dart`, `dart:math` y `package:flutter/painting.dart`.

## Qué probará el humano

El recorrido en los dos celulares: que los dibujos se muevan suave y se entiendan.
