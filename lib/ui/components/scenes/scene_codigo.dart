import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// Un estudiante escribe su código estudiantil en su celular.
///
/// Referencia: `docs/diseno/referencias/como-funciona/codigo.svg`.
/// Animación: los puntos del código aparecen uno tras otro, la tecla ocre se
/// hunde al pulsar, el cursor parpadea y la línea punteada corre.
void paintSceneCodigo(UiSceneCanvas g, double t) {
  final p = g.palette;
  var golpe = 0.0;
  for (var i = 0; i < 5; i++) {
    golpe = math.max(golpe, UiSceneAnim.bump(t, 0.13 + 0.12 * i, width: 0.1));
  }
  final keyScale = UiSceneAnim.mix(1, 0.85, golpe);
  final cursorOpacity = UiSceneAnim.step(t, 8).isOdd ? 1.0 : 0.15;

  g.rrect(104, 18, 112, 184, 22, fill: p.surface, stroke: p.ink);
  g.rrect(120, 42, 52, 7, 3.5, fill: p.muted, opacity: 0.6);
  g.rrect(120, 58, 80, 30, 9, fill: p.panel, stroke: p.teacher, strokeWidth: 2.5);
  g.circle(131, 73, 3, fill: p.ink, opacity: UiSceneAnim.appear(t, 0.10, 0.16));
  g.circle(141, 73, 3, fill: p.ink, opacity: UiSceneAnim.appear(t, 0.22, 0.28));
  g.circle(151, 73, 3, fill: p.ink, opacity: UiSceneAnim.appear(t, 0.34, 0.40));
  g.circle(161, 73, 3, fill: p.ink, opacity: UiSceneAnim.appear(t, 0.46, 0.52));
  g.circle(171, 73, 3, fill: p.ink, opacity: UiSceneAnim.appear(t, 0.58, 0.64));
  g.rrect(180, 65, 2.5, 16, 1, fill: p.teacher, opacity: cursorOpacity);
  g.rrect(120, 102, 22, 18, 6, fill: p.panel);
  g.rrect(149, 102, 22, 18, 6, fill: p.panel);
  g.rrect(178, 102, 22, 18, 6, fill: p.panel);
  g.rrect(120, 126, 22, 18, 6, fill: p.panel);
  g.group(
    scale: keyScale,
    pivot: const Offset(160, 135),
    draw: () {
      g.rrect(149, 126, 22, 18, 6, fill: p.accent);
    },
  );
  g.rrect(178, 126, 22, 18, 6, fill: p.panel);
  g.rrect(120, 150, 22, 18, 6, fill: p.panel);
  g.rrect(149, 150, 22, 18, 6, fill: p.panel);
  g.rrect(178, 150, 22, 18, 6, fill: p.panel);
  g.rrect(149, 174, 22, 18, 6, fill: p.panel);
  g.rrect(30, 76, 56, 40, 10, fill: p.surface, stroke: p.line, strokeWidth: 2);
  g.circle(46, 90, 6, fill: p.teacher);
  g.rrect(58, 86, 20, 6, 3, fill: p.muted, opacity: 0.6);
  g.rrect(38, 102, 40, 6, 3, fill: p.ink);
  g.path('M88 96 h12', stroke: p.accent, dash: [2, 7], dashOffset: -18 * t);
}
