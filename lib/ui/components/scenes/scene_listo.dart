import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El celular del estudiante muestra que quedó presente.
///
/// Referencia: `docs/diseno/referencias/como-funciona/listo.svg`.
/// Animación: el círculo turquesa crece, el visto se escribe y los rayos ocres laten.
void paintSceneListo(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(104, 18, 112, 184, 22, fill: p.surface, stroke: p.ink);

  // Círculo turquesa que crece.
  g.group(
    scale: UiSceneAnim.mix(0.6, 1, UiSceneAnim.appear(t, 0.05, 0.25)),
    pivot: const Offset(160, 88),
    draw: () {
      g.circle(160, 88, 30, fill: p.teacher);
    },
  );

  // Visto que se escribe.
  g.path(
    'M146 89 l10 10 l19 -21',
    stroke: p.onTeacher,
    strokeWidth: 6,
    progress: UiSceneAnim.appear(t, 0.2, 0.4),
  );

  g.text('¡Presente!', 160, 148, size: 15, color: p.ink);
  g.rrect(136, 162, 48, 7, 3.5, fill: p.muted, opacity: 0.6);

  // Rayos ocres que laten.
  final rayOpacity = UiSceneAnim.mix(0.25, 1, UiSceneAnim.wave(t, phase: 0.6));
  g.path('M82 58 l-12 -7 M76 92 h-14 M82 126 l-12 7', stroke: p.accent, strokeWidth: 3.5, opacity: rayOpacity);
  g.path('M238 58 l12 -7 M244 92 h14 M238 126 l12 7', stroke: p.accent, strokeWidth: 3.5, opacity: rayOpacity);
}
