import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El profesor marca a un estudiante a mano tocando su nombre en la lista.
///
/// Referencia: `docs/diseno/referencias/como-funciona/amano.svg`.
/// Animación: la mano llega, el aro ocre late al tocar y la fila del medio queda marcada.
void paintSceneAmano(UiSceneCanvas g, double t) {
  final p = g.palette;
  final touchBump = UiSceneAnim.bump(t, 0.38, width: 0.2);
  final markOpacity = UiSceneAnim.appear(t, 0.4, 0.5);

  g.rrect(40, 18, 112, 184, 20, fill: p.teacher);

  // Fila 1 (ya marcada).
  g.rrect(52, 44, 88, 34, 10, fill: UiScenePalette.paper);
  g.circle(66, 61, 8, fill: UiScenePalette.paperTint);
  g.rrect(80, 57, 30, 8, 4, fill: UiScenePalette.paperInk);
  g.circle(124, 61, 8, fill: UiScenePalette.paperTeal);
  g.path('M120 61 l3 3 l5 -6', stroke: UiScenePalette.paper, strokeWidth: 2.4);

  // Fila 2 (se marca con el toque).
  g.rrect(52, 86, 88, 34, 10, fill: UiScenePalette.paper);
  g.circle(66, 103, 8, fill: UiScenePalette.paperTint);
  g.rrect(80, 99, 26, 8, 4, fill: UiScenePalette.paperInk);
  g.circle(124, 103, 8, stroke: UiScenePalette.paperMuted, strokeWidth: 2, dash: [3, 3]);
  g.circle(124, 103, 8, fill: UiScenePalette.paperTeal, opacity: markOpacity);
  g.path('M120 103 l3 3 l5 -6', stroke: UiScenePalette.paper, strokeWidth: 2.4, opacity: markOpacity);

  // Fila 3 (ya marcada).
  g.rrect(52, 128, 88, 34, 10, fill: UiScenePalette.paper);
  g.circle(66, 145, 8, fill: UiScenePalette.paperTint);
  g.rrect(80, 141, 32, 8, 4, fill: UiScenePalette.paperInk);
  g.circle(124, 145, 8, fill: UiScenePalette.paperTeal);
  g.path('M120 145 l3 3 l5 -6', stroke: UiScenePalette.paper, strokeWidth: 2.4);

  // Aro ocre que late al tocar.
  g.circle(
    124,
    103,
    UiSceneAnim.mix(15, 21, touchBump),
    stroke: p.accent,
    opacity: UiSceneAnim.mix(1, 0.4, touchBump),
  );

  // Mano que llega.
  g.group(
    dx: UiSceneAnim.mix(14, 0, UiSceneAnim.appear(t, 0.1, 0.3)),
    draw: () {
      g.rrect(226, 76, 56, 70, 22, fill: p.surface, stroke: p.ink);
      g.rrect(144, 92, 100, 22, 11, fill: p.surface, stroke: p.ink);
      g.rrect(228, 94.5, 18, 17, 0, fill: p.surface);
    },
  );

  g.rrect(212, 166, 76, 26, 13, fill: p.accent);
  g.text('A mano', 250, 183.5, size: 12, color: UiScenePalette.paperInk, weight: FontWeight.w700);
}
