import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El profesor retira a un estudiante de la lista de la clase.
///
/// Referencia: `docs/diseno/referencias/como-funciona/retirar.svg`.
/// Animación: la insignia coral de quitar late una vez y luego la fila del
/// medio se desplaza hacia la derecha atenuándose.
void paintSceneRetirar(UiSceneCanvas g, double t) {
  final p = g.palette;
  final badgeScale = UiSceneAnim.mix(1, 1.2, UiSceneAnim.bump(t, 0.3, width: 0.2));
  final rowDx = UiSceneAnim.mix(0, 26, UiSceneAnim.appear(t, 0.45, 0.7));
  final rowOpacity = UiSceneAnim.mix(1, 0.35, UiSceneAnim.appear(t, 0.45, 0.7));

  // Fila superior (quieta).
  g.rrect(60, 30, 200, 46, 14, fill: p.surface);
  g.circle(84, 53, 12, fill: p.panel);
  g.rrect(104, 49, 70, 8, 4, fill: p.ink);

  // Fila del medio (se retira).
  g.group(
    dx: rowDx,
    opacity: rowOpacity,
    draw: () {
      g.rrect(60, 87, 200, 46, 14, fill: p.surface, stroke: p.danger, strokeWidth: 2.5);
      g.circle(84, 110, 12, fill: p.panel);
      g.rrect(104, 106, 84, 8, 4, fill: p.ink);
      g.group(
        scale: badgeScale,
        pivot: const Offset(236, 110),
        draw: () {
          g.circle(236, 110, 12, fill: p.danger);
          g.path('M230 110 h12', stroke: UiScenePalette.paper);
        },
      );
    },
  );

  // Fila inferior (quieta).
  g.rrect(60, 144, 200, 46, 14, fill: p.surface);
  g.circle(84, 167, 12, fill: p.panel);
  g.rrect(104, 163, 58, 8, 4, fill: p.ink);
}
