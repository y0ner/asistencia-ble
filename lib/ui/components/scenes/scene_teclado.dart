import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El profesor dicta el PIN y el estudiante lo escribe en su celular.
///
/// Referencia: `docs/diseno/referencias/como-funciona/teclado.svg`.
/// Animación: las ondas de voz laten, la tecla ocre se hunde, el número aparece y el cursor parpadea.
void paintSceneTeclado(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.path('M42 40 h60 a16 16 0 0 1 16 16 v28 a16 16 0 0 1 -16 16 h-34 l-16 14 v-14 h-10 a16 16 0 0 1 -16 -16 v-28 a16 16 0 0 1 16 -16 z', fill: p.surface, stroke: p.ink);
  g.text('4 7', 72, 80, size: 28, color: p.ink);
  g.rrect(34, 126, 40, 66, 10, fill: p.teacher);
  g.rrect(44, 172, 20, 5, 2.5, fill: p.onTeacher, opacity: 0.55);

  // Ondas de voz.
  g.path(
    'M92 144 q7 9 0 18',
    stroke: p.accent,
    strokeWidth: 3.5,
    opacity: UiSceneAnim.mix(0.35, 1, UiSceneAnim.wave(t, phase: 0.6)),
  );
  g.path(
    'M104 136 q14 17 0 34',
    stroke: p.accent,
    strokeWidth: 3.5,
    opacity: UiSceneAnim.mix(0.25, 0.8, UiSceneAnim.wave(t, phase: 0.35)),
  );

  g.rrect(150, 18, 112, 184, 22, fill: p.surface, stroke: p.ink);
  g.rrect(166, 38, 36, 44, 9, fill: p.panel, stroke: p.teacher, strokeWidth: 2.5);
  g.rrect(210, 38, 36, 44, 9, fill: p.panel, stroke: p.teacher, strokeWidth: 2.5);

  // El «4» de la primera casilla.
  g.text('4', 184, 70, size: 26, color: p.ink, opacity: UiSceneAnim.appear(t, 0.2, 0.28));

  // Cursor parpadeante en la segunda casilla.
  g.rrect(227, 50, 2.5, 20, 1, fill: p.teacher, opacity: UiSceneAnim.step(t, 8).isOdd ? 1 : 0.15);

  g.rrect(166, 96, 22, 18, 6, fill: p.panel);
  g.rrect(195, 96, 22, 18, 6, fill: p.panel);
  g.rrect(224, 96, 22, 18, 6, fill: p.panel);
  g.rrect(166, 120, 22, 18, 6, fill: p.panel);
  g.rrect(195, 120, 22, 18, 6, fill: p.panel);
  g.rrect(224, 120, 22, 18, 6, fill: p.panel);

  // Tecla ocre que se hunde.
  g.group(
    scale: UiSceneAnim.mix(1, 0.85, UiSceneAnim.bump(t, 0.22, width: 0.14)),
    pivot: const Offset(177, 153),
    draw: () {
      g.rrect(166, 144, 22, 18, 6, fill: p.accent);
    },
  );

  g.rrect(195, 144, 22, 18, 6, fill: p.panel);
  g.rrect(224, 144, 22, 18, 6, fill: p.panel);
  g.rrect(195, 168, 22, 18, 6, fill: p.panel);
}
