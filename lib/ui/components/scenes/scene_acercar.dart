import 'package:flutter/painting.dart';

import 'ui_scene_canvas.dart';

/// El estudiante acerca su celular al del profesor.
///
/// Referencia: `docs/diseno/referencias/como-funciona/acercar.svg`.
/// Animación: los dos celulares se acercan un poco y las ondas laten, primero
/// las de adentro y después las de afuera.
///
/// **Es el dibujo modelo:** los demás siguen esta misma forma.
void paintSceneAcercar(UiSceneCanvas g, double t) {
  final p = g.palette;
  final nudge = 5 * UiSceneAnim.wave(t);
  final inner = UiSceneAnim.mix(0.35, 1, UiSceneAnim.wave(t, phase: 0.6));
  final outer = UiSceneAnim.mix(0.25, 0.8, UiSceneAnim.wave(t, phase: 0.35));

  // Celular del profesor (relleno).
  g.group(
    dx: nudge,
    draw: () {
      g.rrect(36, 30, 88, 148, 18, fill: p.teacher);
      g.circle(80, 92, 20, fill: p.onTeacher, opacity: 0.22);
      g.rrect(56, 126, 48, 8, 4, fill: p.onTeacher, opacity: 0.55);
      g.rrect(64, 142, 32, 8, 4, fill: p.onTeacher, opacity: 0.3);
    },
  );

  // Celular del estudiante (con borde).
  g.group(
    dx: -nudge,
    draw: () {
      g.rrect(196, 30, 88, 148, 18, fill: p.surface, stroke: p.ink);
      g.circle(240, 92, 20, fill: p.panel);
      g.rrect(216, 126, 48, 8, 4, fill: p.ink);
      g.rrect(224, 142, 32, 8, 4, fill: p.muted, opacity: 0.6);
    },
  );

  // Ondas entre los dos.
  g.path('M140 92 q7 12 0 24', stroke: p.accent, strokeWidth: 4, opacity: inner);
  g.path('M150 82 q13 22 0 44', stroke: p.accent, strokeWidth: 4, opacity: outer);
  g.path('M180 92 q-7 12 0 24', stroke: p.accent, strokeWidth: 4, opacity: inner);
  g.path('M170 82 q-13 22 0 44', stroke: p.accent, strokeWidth: 4, opacity: outer);

  g.text(g.studentView ? 'Tu profesor' : 'Tú', 80, 203, size: 13, weight: FontWeight.w700, color: p.ink);
  g.text(g.studentView ? 'Tú' : 'Estudiante', 240, 203, size: 13, weight: FontWeight.w700, color: p.ink);
}
