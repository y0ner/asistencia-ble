import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El profesor ve una solicitud por aprobar y decide aceptarla o rechazarla.
///
/// Referencia: `docs/diseno/referencias/como-funciona/aprobar.svg`.
/// Animación: la tarjeta de solicitud entra desde la derecha y el botón de
/// visto turquesa late una vez.
void paintSceneAprobar(UiSceneCanvas g, double t) {
  final p = g.palette;
  final cardDx = UiSceneAnim.mix(24, 0, UiSceneAnim.appear(t, 0.05, 0.25));
  final cardOpacity = UiSceneAnim.appear(t, 0.05, 0.2);
  final checkScale = UiSceneAnim.mix(1, 1.18, UiSceneAnim.bump(t, 0.55, width: 0.2));

  g.rrect(38, 24, 104, 172, 20, fill: p.teacher);
  g.rrect(54, 48, 48, 8, 4, fill: p.onTeacher, opacity: 0.55);
  g.rrect(54, 66, 72, 8, 4, fill: p.onTeacher, opacity: 0.3);
  g.rrect(54, 82, 60, 8, 4, fill: p.onTeacher, opacity: 0.3);

  g.group(
    dx: cardDx,
    opacity: cardOpacity,
    draw: () {
      g.rrect(96, 70, 192, 104, 18, fill: p.surface, stroke: p.line, strokeWidth: 2);
      g.rrect(112, 84, 84, 20, 10, fill: p.accent);
      g.text('Por aprobar', 154, 98.5, size: 11, color: UiScenePalette.paperInk, weight: FontWeight.w700);
      g.circle(126, 130, 13, fill: p.panel, stroke: p.teacher, strokeWidth: 2.5);
      g.path('M126 125 v0.5 M126 130 v6', stroke: p.teacher);
      g.rrect(148, 120, 72, 8, 4, fill: p.ink);
      g.rrect(148, 134, 48, 7, 3.5, fill: p.muted, opacity: 0.6);
      g.group(
        scale: checkScale,
        pivot: const Offset(246, 130),
        draw: () {
          g.circle(246, 130, 15, fill: p.teacher);
          g.path('M239 130 l5 5 l9 -10', stroke: p.onTeacher, strokeWidth: 3.5);
        },
      );
      g.circle(272, 96, 11, stroke: p.danger, strokeWidth: 2.5);
      g.path('M268 92 l8 8 M276 92 l-8 8', stroke: p.danger, strokeWidth: 2.5);
    },
  );
}
